##############################################################################
package App::Page::SDE;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Exporter;
use DBI::StatementManager;
use App::Configuration;
use App::ImageManager;
use App::ResourceDirectory;
use Data::Publish;
use Data::Dumper;
use Devel::Symdump;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(Exporter App::Page);
%RESOURCE_MAP = (
	'sde' => {
		_views => [
			{caption => 'ACL', name => 'acl',},
			{caption => 'Tables', name => 'tables',},
			{caption => 'Statistics', name => 'stats',},
			{caption => 'Statements', name => 'stmgrs',},
			{caption => 'Resources', name => 'resources',},
			{caption => 'Source', name => 'source',},
			],
		},
	);

use constant DEFAULT_HIDE_COLUMNS => 'CR_SESSION_ID,CR_STAMP,CR_USER_ID,CR_ORG_ID,VERSION_ID';

sub getContentHandlers
{
	return ('prepare_view_$_view$');
}

sub initialize
{
	my $self = shift;
	$self->addLocatorLinks(['<IMG SRC="/resources/icons/home-sm.gif" BORDER=0> SDE', '/sde']);
	$self->addContent(qq{
	<style>
		body { background-color: white }
		a { text-decoration: none; }
		a.tableNameParToc { text-decoration: none; color: black; font-weight: bold; }
		a.tableNameChlToc { text-decoration: none; color: navy; }
		a:hover { color : red }
		h1 { font-family: arial,helvetica; font-size: 14pt; font-weight: bold; color: darkred; }
		body { font-family: verdana; font-size : 10pt; }
		td { font-family: verdana; font-size: 10pt; }
		th { font-family: arial,helvetica; font-size: 9pt; color: silver}
		select { font-family: tahoma; font-size: 8pt; }
		.coldescr { font-family: arial, helvetica; font-size: 8pt; color: navy }
	</style>
	});


	# Check user's permission to page
	my $activeView = $self->param('_pm_view');
	if ($activeView) 
	{
		unless($self->hasPermission("page/SDE/$activeView"))
		{
			$self->disable(
					qq{
						<br>
						You do not have permission to view this information. 
						Permission page/SDE/$activeView is required.

						Click <a href='javascript:history.back()'>here</a> to go back.
					});
		}
	}
}

sub prepare_page_content_header
{
	my ($self, $colors, $fonts, $personId, $personData) = @_;
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);
	$self->SUPER::prepare_page_content_header(@_);
	my $urlPrefix = "/sde";
	my $functions = $self->getMenu_Simple(App::Page::MENUFLAG_SELECTEDISLARGER,
		'_view',
		[
			['ACL', "$urlPrefix/acl", 'acl'],
			['Database', "$urlPrefix/tables", 'tables'],
			['Statements', "$urlPrefix/stmgrs", 'stmgrs'],
			['Statistics', "$urlPrefix/stats", 'stats'],
			['Resources', "$urlPrefix/resources", 'resources'],
			['Source', "$urlPrefix/source", 'source'],
		], ' | ');

	push(@{$self->{page_content_header}}, qq{
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TR VALIGN=BOTTOM>
			<TD WIDTH=32>
				$IMAGETAGS{'icon-m/sde'}
			</TD>
			<TD VALIGN=MIDDLE>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					&nbsp;<B>Software Development Environment</B>
				</FONT>
			</TD>
			<TD ALIGN=RIGHT VALIGN=MIDDLE>
				<FONT FACE="Arial,Helvetica" SIZE=2>
				$functions
				</FONT>
			</TD>
			</TR>
		</TABLE>
		});
	return 1;
}

sub getTableListAsOptionsAlpha
{
	my ($self, $list) = @_;
	my $rows = "";
	foreach (sort { $a->{name} cmp $b->{name} } @{$list})
	{
		$rows .= "<option value='/sde/table/$_->{name}'>$_->{name}</option>";
	}
	return $rows;
}

sub getTableListAsOptions
{
	my ($self, $list, $level) = @_;
	$level ||= 0;
	return "recursion level too deep: $level" if $level > 25;

	my $rows = "";
	foreach (sort { $a->{name} cmp $b->{name} } @{$list})
	{
		my $children .= scalar(@{$_->{childTables}}) > 0 ? getTableListAsOptions($self, $_->{childTables}, $level+1) : '';
		my $indent = $level > 0 ? "&nbsp;&nbsp;&nbsp;&nbsp;"x$level : '';
		my $aClass = $level == 0 ? 'tableNameParToc' : 'tableNameChlToc';
		$rows .= "<option value='/sde/table/$_->{name}'>$indent$_->{name}</option>$children";
	}

	return $rows;
}

sub getTableListAsSelect
{
	my ($self, $type, $size) = @_;
	$type ||= 'hier';

	return qq{<SELECT @{[ $size ? "SIZE='$size'" : '']} ONCLICK='if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value'><OPTION SELECTED>Choose table</OPTION>} .
			($type eq 'alpha' ? $self->getTableListAsOptionsAlpha($self->{schema}->{tables}->{asList}) : $self->getTableListAsOptions($self->{schema}->{tables}->{hierarchy}))
			. '</SELECT>';
}

sub getTableListAsRows
{
	my ($self, $list, $level) = @_;
	$level ||= 0;
	return "recursion level too deep: $level" if $level > 25;

	my $rows = "";
	foreach (sort { $a->{name} cmp $b->{name} } @{$list})
	{
		my $children .= scalar(@{$_->{childTables}}) > 0 ? getTableListAsRows($self, $_->{childTables}, $level+1) : '';
		my $indent = $level > 0 ? "<td>&nbsp;&nbsp;</td>" : '';
		my $aClass = $level == 0 ? 'tableNameParToc' : 'tableNameChlToc';
		$rows .= "<tr>$indent<td><font face='Tahoma,Arial' size='2'><a class='$aClass' href='/sde/table/$_->{name}'>$_->{name}</a></font>$children</td></tr>";
	}

	return "<table border=0 cellspacing=0 cellpadding=0>$rows</table>";
}

sub queryToHtmlTable
{
	my ($self, $queryText, $tableStrRef, %options) = @_;

	return '' unless $queryText;

	my $hdFontTag="<font face='Arial,Helvetica' size=2 color=white>";
	my $bdFontTag="<font face='Arial,Helvetica' size=2>";

	if(exists $options{debug} && $options{debug})
	{
		${$tableStrRef} .= "<bold><pre>$queryText</pre></bold>";
		return;
	}

	${$tableStrRef} .= qq{
	<table bgcolor=silver border=0 cellspacing=0>
	<tr>
	<td>
	<table bgcolor=silver cellspacing=1 cellpadding=2 border=0>
	};

	my @hideColNames = split(/\s*,\s*/, uc($self->param('hidecols')) || DEFAULT_HIDE_COLUMNS);
	my $foundRecords = 0;
	eval
	{
		my $cursor = $self->{db}->prepare($queryText);
		$cursor->execute();

		my $namesRef = $cursor->{NAME};
		my $colsCount = scalar(@{$namesRef});

		if(! exists $options{showCols})
		{
			for my $i (0..$colsCount-1)
			{
				unless(grep { $namesRef->[$i] eq $_ } @hideColNames)
				{
					push(@{$options{showCols}}, { colNum => $i, colTitle => $namesRef->[$i]});
				}
			}
		}

		${$tableStrRef} .= "<tr bgcolor=navy valign=top align=center>";
		foreach my $colData (@{$options{showCols}})
		{
			${$tableStrRef} .= "<th>$hdFontTag$colData->{colTitle}</th>";
		}
		${$tableStrRef} .= "</tr>";

		my $bgColor='beige';
		while(my $rowRef = $cursor->fetch())
		{
			$foundRecords++;
			${$tableStrRef} .= "<tr bgcolor='$bgColor' valign=top>";
			foreach my $colData (@{$options{showCols}})
			{
				my $anchorBegin = '';
				my $anchorEnd = '';

				if(exists $colData->{colAnchorAttrs})
				{
					#my $attrs = $colData->{colAnchorAttrs};
					#$attrs =~ s/#(\d+)#/$rowRef->[$1]/g;
					$anchorBegin = "<a $colData->{colAnchorAttrs}>";
					$anchorEnd = "</a>";
				}

				${$tableStrRef} .= "<td align=$colData->{align}>$bdFontTag$anchorBegin$rowRef->[$colData->{colNum}]$anchorEnd</td>";
			}
			${$tableStrRef} =~ s/#(\d+)#/$rowRef->[$1]/g;
			${$tableStrRef} .= "</tr>";
			$bgColor = $bgColor eq 'beige' ? 'lightyellow' : 'beige';
		}

		if(! $foundRecords)
		{
			my $headCols = scalar(@{$options{showCols}});
			${$tableStrRef} .= "<TR BGCOLOR=lightyellow><TD colspan=$headCols><font size=2 face='Arial,Helvetica' color=darkred><b>No records found.</b></font></TD></TR>";
		}
	};
	if($@)
	{
		${$tableStrRef} = $@;
	}
	else
	{
		${$tableStrRef} .= qq{
		</table>
		</td>
		</tr>
		</table>
		}
	}
}

sub prepare_TableStruct
{
	my ($self, $showHead) = @_;
	$showHead = 1 unless defined $showHead;

	if(my $table = $self->{schema}->{tables}->{byName}->{$self->param('table')})
	{
		my $updTableUrl = $self->selfRef(_reloadtable=>1);
		my $updTableDataUrl = $self->selfRef(_reloadtabledata=>1);
		my $allTables = $self->getTableListAsSelect();
		my $html = $showHead ? qq{
			<TABLE WIDTH=100% BGCOLOR='#EEEEEE' BORDER=0 CELLPADDING=0 CELLSPACING=0>
			<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;<B>$table->{name}</B> Table ($table->{abbrev})</FONT></TD>
			<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2>@{[ $self->getTableListAsSelect() ]}</FONT></TD></TR>
			<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
			</TABLE>
			<P>$table->{descr}</P>
		} : '';

		my $defaultsCount = 0;
		my $tableForeignRefsCount = 0;
		foreach my $col (@{$table->{colsInOrder}})
		{
			$defaultsCount++ if $col->{default};
			$tableForeignRefsCount += scalar(@{$col->{foreignRefs}}) if exists $col->{foreignRefs};
			$tableForeignRefsCount += scalar(@{$col->{cacheRefs}}) if exists $col->{cacheRefs};
		}
		my $defaultsHead = $defaultsCount > 0 ? "<th>Default</th>" : '';
		my $foreignRefsHead = $tableForeignRefsCount > 0 ? "<th title='Count of external (foreign-key or cache) references to a column'>Refs</th>" : '';

		my $rows = qq{
			<tr bgcolor="black" valign=top>
				<th>&nbsp;</th>
				<th>Column</th>
				<th>Domain</th>
				<th>Type</th>
				$defaultsHead
				$foreignRefsHead
			</tr>
		};

		my $bgColor = 'lightyellow';
		foreach my $col (@{$table->{colsInOrder}})
		{
			my $colName = $col->{name};
			my $colDetailHref = "$table->{name}?column=$col->{name}";
			my $foreignRefsCount = exists $col->{foreignRefs} ? scalar(@{$col->{foreignRefs}}) : 0;
			my $cacheRefsCount = exists $col->{cacheRefs} ? scalar(@{$col->{cacheRefs}}) : 0;
			my $useTypeRefsCount = exists $col->{useTypeRefs} ? scalar(@{$col->{useTypeRefs}}) : 0;
			my $externalRefsCount = $foreignRefsCount + $cacheRefsCount + $useTypeRefsCount;

			my $fKeyHref = '';
			my $fKeyImgSuffix = 'fk';
			my $forwardFkeyHint = $col->{refForward} ? " [*FORWARD REFERENCE*]" : '';
			my $fKeyHint = "$colName is a foreign-key reference to $col->{ref}$forwardFkeyHint";
			if($col->{type} eq 'ref')
			{
				if(my $fcol = $self->{schema}->{columns}->{byQualifiedName}->{$col->{ref}})
				{
					$fKeyHref = "$fcol->{table}->{name}?fKeyFrom=$self->{name}";
				}
				if($col->{refType} eq 'parent')
				{
					$fKeyImgSuffix = 'ck';
					$fKeyHint = "$colName is a child-key: its value is the parent of this record ($col->{ref})$forwardFkeyHint";
				}
				elsif($col->{refType} eq 'self')
				{
					$fKeyImgSuffix = 'sk';
					$fKeyHint = "$colName is a self-reference-key: its value is the parent of this record ($col->{ref})$forwardFkeyHint";
				}
			}
			elsif($col->{useType})
			{
				if(my $fcol = $self->{schema}->{columns}->{byQualifiedName}->{$col->{useType}})
				{
					$fKeyHref = "$fcol->{table}->{name}?fKeyFrom=$self->{name}";
				}
				$fKeyImgSuffix = 'ut';
				$forwardFkeyHint = $col->{useTypeForward} ? " [*FORWARD REFERENCE*]" : '';
				$fKeyHint = "$colName is the same type/defn as $col->{useType}$forwardFkeyHint (useType reference)";
			}

			my $flags = '';
			$flags .= "<img src='/resources/icons/dbdd_pk.gif' title='$colName is a primary key (unique, required, and indexed)'>" if $col->{primarykey};
			$flags .= ' '. "<img src='/resources/icons/dbdd_r.gif' title='$colName is a required column (by the front-end and the dbms)'>" if $col->{required} == 1;
			$flags .= ' '. "<img src='/resources/icons/dbdd_rd.gif' title='$colName is a required column (only by the dbms, not the front-end)'>" if $col->{required} == 2;
			$flags .= ' '. "<a href='$fKeyHref'><img src='/resources/icons/dbdd_$fKeyImgSuffix.gif' border=0 title='$fKeyHint'></a>" if $col->{type} eq 'ref' || $col->{useType};
			$flags .= ' '. "<img src='/resources/icons/dbdd_u.gif' title='Each $colName in the $table->{name} table must have a unique value'>" if $col->{unique};
			$flags .= ' '. "<img src='/resources/icons/dbdd_c.gif' title='$colName is a calculated field (by a dbms trigger)'>" if $col->{calc};
			$flags .= ' '. "<img src='/resources/icons/dbdd_ix.gif' title='$colName is an indexed column'>" if $col->{index};
			$flags .= ' '. "<img src='/resources/icons/dbdd_ch.gif' title='$colName caches data from other columns (for performance benefits)'>" if exists $col->{cache};
			$flags .= ' '. "<img src='/resources/icons/dbdd_ts.gif' title='$colName has a text search table ($table->{abbrev}_\u$col->{name}_Word)'>" if $col->{type} eq 'text_search';
			$flags .= ' '. "<a href='$colDetailHref'><img src='/resources/icons/dbdd_cr.gif' border=0 title='$colName is cached by $cacheRefsCount other columns (for performance benefits)'></a>" if $cacheRefsCount > 0;
			$flags .= ' '. "<a href='$colDetailHref'><img src='/resources/icons/dbdd_fr.gif' border=0 title='$colName is referenced by $foreignRefsCount other columns (as a foreign key)'></a>" if $foreignRefsCount > 0;

			my $allKeys = join(', ', sort keys %$col);

			$bgColor = '#CCDDCC' if $col->{primarykey};
			my $name = "<b>$col->{name}</b>";
			if($col->{name} =~ m/(^cr_|^version_id$|^session_id$)/ || $col->{calc})
			{
				$name = "<i>$col->{name}</i>";
				$bgColor = $col->{calc} ? '#EEEEEE' : '#EEEEEE';
			}
			my $domain = $col->{type} eq 'ref' ? "<font color=red>foreign key</font>" : "<font color=green>$col->{type}</font>";
			my $default = $defaultsCount > 0 ? "<td>$col->{default}</td>" : '';

			my $foreignRefs = $tableForeignRefsCount > 0 ? ("<td align=right><a HREF='$colDetailHref'>" . ($externalRefsCount > 0 ? $externalRefsCount : '') . "</a></td>") : '';
			my $row = qq{
				<tr bgcolor="$bgColor" valign=top>
					<td align=center valign=center>$flags</td>
					<td><a href='$colDetailHref' style='text-decoration:none'>$name</a><div class="coldescr">$col->{descr}</div></td>
					<td>$domain</td>
					<td>$col->{sqldefn}</td>
					$default
					$foreignRefs
				</tr>
			};
			$bgColor = $bgColor eq 'lightyellow' ? 'beige' : 'lightyellow';
			$rows .= $row;
		}

		my $curData = undef;
		queryToHtmlTable($self, "select * from $table->{name} where rownum < 250", \$curData);

		my $defaultQuery = $self->escape("select * from $table->{name} where rownum < 250");
		$html .= qq{
			<table border=0 cellspacing=0>$rows</table>
			<h1>$table->{name} <a href='table/$table->{name}?query=$defaultQuery'>Data</a></h1>
			$curData
			};

		$self->addContent($html);
	}
	else
	{
		$self->addContent("Table @{[$self->param('table')]} does not exist");
	}
}

sub prepare_ColumnDetail
{
	my $self = shift;

	if(my $table = $self->{schema}->{tables}->{byName}->{$self->param('table')})
	{
		if(my $col = $table->{colsByName}->{$self->param('column')})
		{
			$self->addContent(qq{
				<TABLE WIDTH=100% BGCOLOR=#EEEEEE BORDER=0 CELLPADDING=0 CELLSPACING=0>
				<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;Column <B>$table->{name}.$col->{name}</FONT></TD>
				<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2>@{[ $self->getTableListAsSelect() ]}</FONT></TD></TR>
				<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
				</TABLE>
				<P>
				$col->{descr}
			});

			my $html = '';
			my @foreignRefs = ();
			if(exists $col->{foreignRefs})
			{
				foreach my $fRefQualified (@{$col->{foreignRefs}})
				{
					my $fRef = $self->{schema}->{columns}->{byQualifiedName}->{uc($fRefQualified)};
					push(@foreignRefs, "<a href='$fRef->{table}->{name}'>$fRefQualified</a>");
				}
			}
			my $fRefsHtml = @foreignRefs ? join("<br>", @foreignRefs) : '';

			my $cachesData = $col->{cache} ? join("<br>", @{$col->{cache}}) : '';
			my @cacheRefs = ();
			if(exists $col->{cacheRefs})
			{
				foreach my $cRefQualified (@{$col->{cacheRefs}})
				{
					my $cRef = $self->{schema}->{columns}->{byQualifiedName}->{uc($cRefQualified)};
					push(@cacheRefs, "<a href='$cRef->{table}->{name}'>$cRefQualified</a>");
				}
			}
			my $cRefsHtml = @cacheRefs ? join("<br>", @cacheRefs) : '';

			my @useTypeRefs = ();
			if(exists $col->{useTypeRefs})
			{
				foreach my $uTypeQualified (@{$col->{useTypeRefs}})
				{
					my $uTypeRef = $self->{schema}->{columns}->{byQualifiedName}->{uc($uTypeQualified)};
					push(@useTypeRefs, "<a href='$uTypeRef->{table}->{name}'>$uTypeQualified</a>");
				}
			}
			my $uTypesHtml = @useTypeRefs ? join("<br>", @useTypeRefs) : '';

			$cachesData =~ s/(\w+:)/<font color=red>$1<\/font>/g;
			$cRefsHtml =~ s/(\w+:)/<font color=red>$1<\/font>/g;

			$html .= qq{
			<table>
				<tr valign=top><td align=right>Domain:</td><td><b>$col->{type}</b></td></tr>
				<tr valign=top><td align=right>Type:</td><td><b>$col->{sqldefn}</b></td></tr>
				<tr valign=top><td align=right>Primary Key:</td><td><b>$col->{primarykey}</b></td></tr>
				<tr valign=top><td align=right>Foreign Key:</td><td><b>$col->{ref}</b></td></tr>
				<tr valign=top><td align=right>Foreign Key Type:</td><td><b>$col->{refType}</b></td></tr>
				<tr valign=top><td align=right>Required:</td><td><b>$col->{required}</b></td></tr>
				<tr valign=top><td align=right>Unique:</td><td><b>$col->{unique}</b></td></tr>
				<tr valign=top><td align=right>Calc:</td><td><b>$col->{calc}</b></td></tr>
				<tr valign=top><td align=right>Indexed:</td><td><b>$col->{index}</b></td></tr>
				<tr valign=top><td align=right>Default:</td><td><b>$col->{default}</b></td></tr>
				<tr valign=top><td align=right>Caches:</td><td><b>$cachesData</b></td></tr>
				<tr valign=top><td align=right>UseType References:</td><td>$uTypesHtml</td></tr>
				<tr valign=top><td align=right>Cache References:</td><td>$cRefsHtml</td></tr>
				<tr valign=top><td align=right>Foreign References:</td><td>$fRefsHtml</td></tr>
			</table>
			};

			$self->addContent($html);
		}
		else
		{
			$self->addContent("Column Table @{[$self->param('column')]} in Table $self->{cgiParams}->{table} does not exist");
		}
	}
	else
	{
		$self->addContent("Table @{[$self->param('column')]} does not exist");
	}
}

sub prepare_TableQuery
{
	my $self = shift;
	my $html = '';
	my $query = $self->param('query');

	queryToHtmlTable($self, $query, \$html);
	$self->addContent(qq{
		<TABLE WIDTH=100% BGCOLOR='#EEEEEE' BORDER=0 CELLPADDING=0 CELLSPACING=0>
		<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;SQL Query</FONT></TD>
		<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2>@{[ $self->getTableListAsSelect() ]}</FONT></TD></TR>
		<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		<P>
		<form method="post">
<textarea name="query" cols=80 rows=8>
$query
</textarea>
		<br>
		Hide Columns: <input type="text" size="80" name="hidecols" value="@{[ $self->param('hidecols') || DEFAULT_HIDE_COLUMNS ]}">
		<br>
		<input type="submit">
		</form>
		<p>
		}, $html);
}

sub prepare_TableList
{
	my ($self, $refreshed) = @_;
	my $msg = $refreshed ? qq{
		<P><font color=red>Refreshed $self->{schemaFile}</font></P>
	} : '';
	$self->addContent(qq{
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE BORDER=0 CELLPADDING=0 CELLSPACING=0>
		<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;All Tables</font></TD>
		<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2>@{[ $self->getTableListAsSelect() ]}</FONT></TD></TR>
		<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		$msg
		<BR><A HREF='tables/refresh'>Refresh (reload) $self->{schemaFile} now.</A>
		<P>
		<TABLE CELLSPACING=10>
			<TD>
				<B>Entity-Relationship</B><BR>
				@{[ $self->getTableListAsSelect('hier', 30) ]}
			</TD>
			<TD>
				<B>Alphabetical</B><BR>
				@{[ $self->getTableListAsSelect('alpha', 30) ]}
			</TD>
		</TABLE>
		});
}

sub prepare_view_tables
{
	my $self = shift;
	my @pathItems = $self->param('arl_pathItems');

	$self->addLocatorLinks(['Database Tables', '/sde/table']);

	if($self->param('query'))
	{
		$self->addLocatorLinks(["\u$pathItems[1] Query", '/sde/table/' . $pathItems[1]]);
		$self->param('table', $pathItems[1]);
		$self->prepare_TableQuery();
	}
	elsif($self->param('column'))
	{
		$self->addLocatorLinks(["\u$pathItems[1]", '/sde/table/' . $pathItems[1]]);
		$self->addLocatorLinks(["Column " . $self->param('column'), '/sde/table/' . $pathItems[1] . '?' . 'column=' . $self->param('column')]);
		$self->param('table', $pathItems[1]);
		$self->prepare_ColumnDetail();
		$self->addContent('<P>');
		$self->prepare_TableStruct(0);
	}
	elsif(scalar(@pathItems) > 1 && $pathItems[1] eq 'refresh')
	{
		Schema::API::clearCache();
		$self->loadSchema();
		$self->prepare_TableList(1);
	}
	elsif(scalar(@pathItems) > 1)
	{
		$self->addLocatorLinks(["\u$pathItems[1]", '/sde/table/' . $pathItems[1]]);
		$self->param('table', $pathItems[1]);
		$self->prepare_TableStruct();
	}
	else
	{
		$self->prepare_TableList();
	}

	return 1;
}

sub prepare_view_table
{
	return prepare_view_tables(@_);
}

#---------------------------------------------------------------------------------

sub getStmtMgrsList
{
	my ($self, $type, $size) = @_;

	my $rows = "";
	foreach my $stMgrObjId (sort keys %{$ALL_STMT_MANAGERS})
	{
		my $stMgrObjName = $stMgrObjId;
		$stMgrObjName =~ s/^App::Statements:://;
		$rows .= $type eq 'select' ?
			"<option value='/sde/stmgr/$stMgrObjId'>$stMgrObjName</option>" :
			"<a href='/sde/stmgr/$stMgrObjId'>$stMgrObjName</a><BR>";
			;
	}

	return $type eq 'select' ? qq{
		<SELECT @{[ $size ? "SIZE='$size'" : '']} ONCLICK='if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value'>
		<OPTION SELECTED>Choose Statement Manager</OPTION>
		$rows
		</SELECT>
	} : $rows;
}

sub getStmtsList
{
	my ($self, $stMgrId, $stMgr, $type, $size) = @_;

	my $rows = "";
	foreach my $stmtId (sort keys %{$stMgr})
	{
		# ignore "private" variables
		next if $stmtId =~ m/^_/;
		next if $stmtId =~ m/^publishDefn/;

		$rows .= $type eq 'select' ?
			"<option value='/sde/stmgr/$stMgrId/$stmtId'>$stmtId</option>" :
			"<a href='/sde/stmgr/$stMgrId/$stmtId'>$stmtId</a><font color=#555555><pre>@{[ $stMgr->{$stmtId} ]}</pre></font><P>";
			;
	}

	return $type eq 'select' ? qq{
		<SELECT @{[ $size ? "SIZE='$size'" : '']} ONCLICK='if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value'>
		<OPTION SELECTED>Choose Statement</OPTION>
		$rows
		</SELECT>
	} : $rows;
}

sub prepare_view_stmgrs
{
	my $self = shift;
	my @pathItems = $self->param('arl_pathItems');

	$self->addLocatorLinks(['Statement Managers', '/sde/stmgrs']);
	my $allMgrs = $self->getStmtMgrsList('select');

	if(scalar @pathItems == 1)
	{
		$self->addContent(qq{
				<TABLE WIDTH=100% BGCOLOR=#EEEEEE BORDER=0 CELLPADDING=0 CELLSPACING=0>
				<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;Statement Managers</font></TD>
				<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2>$allMgrs</FONT></TD></TR>
				<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
				</TABLE>
			<P>
			@{[ $self->getStmtMgrsList() ]}
			});
	}
	elsif(scalar @pathItems == 2)
	{
		my $stMgrObjId = $pathItems[1];
		my $stMgrObj = $ALL_STMT_MANAGERS->{$stMgrObjId};
		$self->addLocatorLinks([$stMgrObjId, '/sde/stmgr/' . $stMgrObjId]);
		$self->addContent(qq{
				<TABLE WIDTH=100% BGCOLOR=#EEEEEE BORDER=0 CELLPADDING=0 CELLSPACING=0>
				<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;$stMgrObjId</font></TD>
				<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2>$allMgrs</FONT></TD></TR>
				<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
				</TABLE>
			<P>
			@{[ $self->getStmtsList($stMgrObjId, $stMgrObj) ]}
			});
	}
	elsif(scalar @pathItems == 3)
	{
		my $stMgrObjId = $pathItems[1];
		my $stMgrObj = $ALL_STMT_MANAGERS->{$stMgrObjId};
		my $stmtId = $pathItems[2];
		my $stmtObj = $stMgrObj->{$stmtId};
		my $sql = $self->param('query') || $stmtObj;

		my @curBindValues = $self->param('bind_param');
		my $run = $self->param('_run');

		my $stmtHdl = undef;
		my $bindParamsCount = 0;
		my $bindInputsHtml = '';

		eval
		{
			$stmtHdl = $self->{db}->prepare($sql);
			for(my $i = 0; $i < $stmtHdl->{NUM_OF_PARAMS}; $i++)
			{
				$bindInputsHtml .= "Param @{[ $i + 1]}: <INPUT NAME='bind_param' VALUE='@{[ $curBindValues[$i] ]}' SIZE=45><BR>";
			}
		};
		if($@ || ! $stmtHdl)
		{
			$self->addContent('<P><FONT COLOR=RED>', $@, '</FONT></P>');
		}

		my $output = '';
		if($run)
		{
			$output = $stMgrObj->createHtml($self, 0, $stmtId, \@curBindValues);
		}

		$sql =~ s/^\s+//gm;
		my @sqlLines = split(/\n/, $sql);
		my $stmtLines = scalar(@sqlLines) + 3;

		$self->addLocatorLinks([$stMgrObjId, "/sde/stmgr/$stMgrObjId"]);
		$self->addLocatorLinks([$stmtId, "/sde/stmgr/$stMgrObjId/$stmtId"]);
		$self->addContent(qq{
				<TABLE WIDTH=100% BGCOLOR=#EEEEEE BORDER=0 CELLPADDING=0 CELLSPACING=0>
				<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;Statement <b>$stmtId</b></font></TD>
				<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2>@{[ $self->getStmtsList($stMgrObjId, $stMgrObj, 'select') ]}</FONT></TD></TR>
				<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
				</TABLE>
				<P>
				<form method="post" href="/">
					<input type="hidden" name="_run" value="1">
					$bindInputsHtml
					<textarea name="query" cols=80 rows=$stmtLines>
$sql
					</textarea>
					<br>
					<input type="submit">
				</form>
				<P>
				$output
			});

	}
}

sub prepare_view_stmgr
{
	prepare_view_stmgrs(@_);
}

#---------------------------------------------------------------------------------

sub getConfigHtml
{
	return
	qq{
		<TABLE>
		<TR BGCOLOR=#EEEEEE><TD COLSPAN=2><B>Configuration</TD></TR>
		<TR><TD ALIGN=RIGHT>Name:</TD><TD><B>@{[ $CONFDATA_SERVER->name_Config() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Group:</TD><TD><B>@{[ $CONFDATA_SERVER->name_Group() ]}</TD></TR>
		<TR BGCOLOR=#EEEEEE><TD COLSPAN=2><B>Database</TD></TR>
		<TR><TD ALIGN=RIGHT>Connect key:</TD><TD><B>@{[ $CONFDATA_SERVER->db_ConnectKey() ]}</TD></TR>
		<TR BGCOLOR=#EEEEEE><TD COLSPAN=2><B>Paths</TD></TR>
		<TR><TD ALIGN=RIGHT>Root:</TD><TD><B>@{[ $CONFDATA_SERVER->path_root() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Temp:</TD><TD><B>@{[ $CONFDATA_SERVER->path_temp() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Database:</TD><TD><B>@{[ $CONFDATA_SERVER->path_Database() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Schema SQL:</TD><TD><B>@{[ $CONFDATA_SERVER->path_SchemaSQL() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Billing template:</TD><TD><B>@{[ $CONFDATA_SERVER->path_BillingTemplate() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Reports:</TD><TD><B>@{[ $CONFDATA_SERVER->path_Reports() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Org Report:</TD><TD><B>@{[ $CONFDATA_SERVER->path_OrgReports() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Org Directory:</TD><TD><B>@{[ $CONFDATA_SERVER->path_OrgDirectory() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>PDF Output:</TD><TD><B>@{[ $CONFDATA_SERVER->path_PDFOutput() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>PDF Output HREF:</TD><TD><B>@{[ $CONFDATA_SERVER->path_PDFOutputHREF() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Application Config:</TD><TD><B>@{[ $CONFDATA_SERVER->path_AppConf() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>EDI Data:</TD><TD><B>@{[ $CONFDATA_SERVER->path_EDIData() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Per-Se EDI Data:</TD><TD><B>@{[ $CONFDATA_SERVER->path_PerSeEDIData() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Per-Se EDI Data Icoming:</TD><TD><B>@{[ $CONFDATA_SERVER->path_PerSeEDIDataIncoming() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Per-Se EDI Data Outgoing:</TD><TD><B>@{[ $CONFDATA_SERVER->path_PerSeEDIDataOutgoing() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Per-Se EDI Errors:</TD><TD><B>@{[ $CONFDATA_SERVER->path_PerSeEDIErrors() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Per-Se EDI Errors (delimited):</TD><TD><B>@{[ $CONFDATA_SERVER->path_PerSeEDIErrorsDelim() ]}</TD></TR>
		<TR BGCOLOR=#EEEEEE><TD COLSPAN=2><B>Files</TD></TR>
		<TR><TD ALIGN=RIGHT>Schema defn:</TD><TD><B>@{[ $CONFDATA_SERVER->file_SchemaDefn() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Access control defn:</TD><TD><B>@{[ $CONFDATA_SERVER->file_AccessControlDefn() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Build log:</TD><TD><B>@{[ $CONFDATA_SERVER->file_BuildLog() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Access Control:</TD><TD><B>@{[ $CONFDATA_SERVER->file_AccessControlDefn() ]}</TD></TR>
		<TR><TD ALIGN=RIGHT>Access Control Auto Permissions:</TD><TD><B>@{[ $CONFDATA_SERVER->file_AccessControlAutoPermissons() ]}</TD></TR>
		</TABLE>
	}
}

#---------------------------------------------------------------------------------

sub prepare_view_source
{
	my $self = shift;
	my @pathItems = $self->param('arl_pathItems');

	$self->addLocatorLinks(['Source', '/sde/source']);
	$self->addContent(qq{
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE BORDER=0 CELLPADDING=0 CELLSPACING=0>
		<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;Source Code</FONT></TD>
		<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2></FONT></TD></TR>
		<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		<P>
		<FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">
		<PRE>@{[ Devel::Symdump->inh_tree() ]}</PRE>
		</FONT>
		});

	return 1;
}

#---------------------------------------------------------------------------------

sub prepare_view_resources
{
	my $self = shift;
	my @pathItems = $self->param('arl_pathItems');
	my $arl = $self->param('arl');
	my @path = @pathItems;
	my $view = shift @path;

	$self->addLocatorLinks(['Resources', '/sde/resource']);
	$self->addContent(qq{
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE BORDER=0 CELLPADDING=0 CELLSPACING=0>
		<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;Resources</FONT></TD>
		<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2></FONT></TD></TR>
		<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		<BR>
		<A HREF="/sde/resources">\%App::ResourceDirectory::RESOURCES</A> = (<BR>
		@{[ $self->displayResources('/sde/resource', \@path) ]}
		);
		});

	return 1;
}

sub displayResources
{
	my $self = shift;
	my $arl = shift;
	my $path = shift;
	my $resources = shift || \%App::ResourceDirectory::RESOURCES;
	my $pathItem = shift @$path;
	my $data = qq{<table width="100%" style="margin-left: 25">};
	foreach my $key (sort keys %$resources)
	{
		my $href = "$arl/$key";
		if (defined $pathItem && $key eq $pathItem)
		{
			unless (exists $resources->{$pathItem})
			{
				return "<font color=red size=5>Error: ARL Path Item '$pathItem' doesn't exists</font><br>\n"
			}
			unless ( ref($resources->{$pathItem}) eq 'HASH')
			{
				return "<font color=red size=5>Error: ARL Path Item '$pathItem' is data element not a resource</font><br>\n";
			}
			$data .= '<tr><td colspan=3>...</td></tr>';
			$data .= qq{<tr><td colspan=3><a href=$href>$pathItem</a>\&nbsp;\&nbsp;=> </td></tr>};
			$data .= '<tr><td colspan=3><font color=red>{</td></tr>';
			$data .= '<tr><td colspan=3>' . $self->displayResources($href, $path, $resources->{$pathItem}) . '</td></tr>';
			$data .= '<tr><td colspan=3><font color=red>},</td></tr>';
			$data .= '<tr><td colspan=3>...</td></tr>';
		}
		elsif (! defined $pathItem)
		{
			my $value = ref($resources->{$key});
			for ($value)
			{
				$_ eq 'HASH' and do {last;};
				$_ eq 'ARRAY' and do { $value = '[ ' . join(', ', map("<font color=teal>$_</font>",map {ref($_) eq 'HASH' ? $self->hashAsStr($_) . "<BR>" : "'$_'";} @{$resources->{$key}} )) . ' ]'; last;};
				$_ eq '' and do { $value = "<font color=teal>'$resources->{$key}'</font>"; last; };
				$value = "Reference to <B>$value</B>";
			}
			$data .= $value eq 'HASH' ? qq{<tr><td colspan=3><a href=$href>$key</a>\&nbsp;\&nbsp;=> {...}</td></tr>\n} : "<tr><td width=1 valign=top><nobr>$key</nobr></td><td width=50 align=center valign=top>=\&gt;<td>$value</td></tr>\n";
		}
			
	}
	$data .= qq{</table>\n};
	return $data;
}

sub hashAsStr
{
	my ($self, $hashRef) = @_;
	my $data = "{ ";
	while (my ($key, $value) = each %$hashRef)
	{
		$data .= "$key =\&gt; $value, ";
	}
	$data .= " }";
	return $data;
}

sub prepare_view_resource
{
	prepare_view_resources(@_);
}


#---------------------------------------------------------------------------------

sub prepare_view_acl
{
	my $self = shift;
	my @pathItems = $self->param('arl_pathItems');
	my $arl = $self->param('arl');
	my @path = @pathItems;
	my $view = shift @path;

	$self->addLocatorLinks(['ACL', '/sde/acl']);
	$self->addContent(qq{
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE BORDER=0 CELLPADDING=0 CELLSPACING=0>
		<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;Resources</FONT></TD>
		<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2></FONT></TD></TR>
		<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		<BR>
		@{[ $self->displayAcl() ]}
		});

	return 1;
}

sub displayAcl
{
	my ($self) = @_;
	my $publishDefn =
	{
		style => 'panel.static',
		width => '100%',
		frame =>
		{
			heading => $self->{heading},
			headColor => 'white',
			borderColor => 'white',
			contentColor => 'white',
		},
		columnDefn => [
			{ head => 'Variable', dataFmt => '<B>#0#:</B>', dAlign => 'RIGHT' },
			{ head => 'Value' },
			],
		rowSepStr => "\n<IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1>\n",
	};
	my $acl = $self->{acl};	
	my $allowPerms = '';
	my $denyPerms = '';
	foreach my $item (sort keys %{$acl->{permissionIds}})
	{
		#my $allowed = $self->hasPermission($item) ? '(allowed)' : '';
		#$allPerms .= ($allowed ? '<FONT COLOR=green>' : '') . "$item: " . $acl->{permissionIds}->{$item}->[Security::AccessControl::PERMISSIONINFOIDX_CHILDPERMISSIONS]->run_list() . " $allowed" . ($allowed ? '</FONT>' : '') . " <BR>";
		if ($self->hasPermission($item))
		{
			$allowPerms .= "<FONT COLOR=green>$item: " . $acl->{permissionIds}->{$item}->[Security::AccessControl::PERMISSIONINFOIDX_CHILDPERMISSIONS]->run_list() . "</FONT><BR>\n";
		}
		else
		{
			$denyPerms .= "<FONT COLOR=red>$item: " . $acl->{permissionIds}->{$item}->[Security::AccessControl::PERMISSIONINFOIDX_CHILDPERMISSIONS]->run_list() . "</FONT><BR>\n";
		}
	}

	$denyPerms = 'NONE' unless $denyPerms;
	$allowPerms = 'NONE' unless $allowPerms;
	my $userRoles = $self->session('aclRoleNames');
	my $data =
		[
			['User Roles', ref $userRoles eq 'ARRAY' ? join(', ', @{$userRoles}) : '(none)'],
			['User Permissions', $self->{permissions}->run_list()],
			['ACL File(s)', join(',<BR>', $acl->{sourceFiles}->{primary}, @{$acl->{sourceFiles}->{includes}})],
			['Denied Permissions', $denyPerms],
			['Allowed Permissions', $allowPerms],
		];
	return createHtmlFromData($self, $self->{flags}, $data, $publishDefn);
}


#---------------------------------------------------------------------------------

sub prepare_view_stats
{
	my $self = shift;
	my @pathItems = $self->param('arl_pathItems');
	my $arl = $self->param('arl');
	my @path = @pathItems;
	my $view = shift @path;

	$self->addLocatorLinks(['Statistics', '/sde/stats']);
	$self->addContent(qq{
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE BORDER=0 CELLPADDING=0 CELLSPACING=0>
		<TR><TD><FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">&nbsp;Resources</FONT></TD>
		<TD ALIGN=RIGHT><FONT FACE="Arial,Helvetica" SIZE=2></FONT></TD></TR>
		<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		<BR>
		Process ID: $$<BR>
		<BR>
		#component.stp-sde.dbstats#
	});

	return 1;
}


#---------------------------------------------------------------------------------

sub prepare
{
	my ($self) = @_;


	$self->addContent(qq{
		<P>
		<A HREF='/sde/tables'>Database Tables</A><BR> @{[ $self->getTableListAsSelect() ]}<p>
		<A HREF='/sde/stmgrs'>Statement Managers</A><BR> @{[ $self->getStmtMgrsList('select') ]}
		<P>
		<A HREF='/perl-status'>View active modules</A>
		<P>
			@{[ $self->getConfigHtml() ]}
		});
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->param('_view', $pathItems->[0]);
	$self->printContents();

	return 0;
}

1;
