##############################################################################
package CGI::Dialog::DataNavigator;
##############################################################################

use strict;
use SDE::CVS ('$Id: DataNavigator.pm,v 1.4 2000-11-27 03:08:41 robert_jenks Exp $', '$Name:  $');
use CGI::Dialog;
use base qw(CGI::Dialog);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP=();


sub new
{
	my $self = CGI::Dialog::new(@_, id => 'query', headColor => '#FFFFFF', bgColor => '#CDD3DB');
	my $page = $self->{page} or die "Page object is invalid";

	# Make sure we have a publish definition
	unless (defined $self->{publDefn} && ref $self->{publDefn} eq 'HASH')
	{
		die 'A publDefn is required and must be a reference to a HASH';
	}

	# Drill down to get the appropriate publDefn
	my $publDefn = $self->getDrilledPublishDefn($page, $self->{publDefn});

	my $outRows = defined $publDefn->{'dnOutRows'} ? $publDefn->{'dnOutRows'} : 10;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'drill_depth', defaultValue => 0,),
		new CGI::Dialog::Field(type => 'hidden', name => 'start_row', defaultValue => 0,),
		new CGI::Dialog::Field(type => 'hidden', name => 'out_rows', defaultValue => 10,),
		new CGI::Dialog::Field(type => 'hidden', name => 'sort_column',),
		new CGI::Dialog::Field(type => 'hidden', name => 'sort_order', defaultValue => 'A',),
		new CGI::Dialog::DataNavigator::Ancestors(publDefn => $self->{publDefn},),
		new CGI::Dialog::DataNavigator::Results(publDefn => $publDefn, sqlStmt => $self->{sqlStmt}, bindParams => $self->{bindParams}),
		new CGI::Dialog::DataNavigator::MultiActions(publDefn => $publDefn,),
		new CGI::Dialog::DataNavigator::StatusBar(publDefn => $publDefn,),
		new CGI::Dialog::DataNavigator::JavaScript(publDefn => $publDefn),
	);

	return $self;
}


sub nextExecMode
{
	# This will force the dialog to always stay in initial entry mode
	return 'I';
}


sub getDrilledPublishDefn
{
	my $self = shift;
	my ($page, $publDefn) = @_;


	my $drillDepth = $page->field('drill_depth');
	$drillDepth = 0 unless defined $drillDepth;

	#$page->addDebugStmt("Drill depth $drillDepth");

	for (1..$drillDepth)
	{
		unless (defined $publDefn->{dnDrillDown})
		{
			die "Can't drill your way out of this one";
		}
		$publDefn = $publDefn->{dnDrillDown};
	}

	return $publDefn;
}


##############################################################################
package CGI::Dialog::DataNavigator::Results;
##############################################################################

use strict;
use SDE::CVS ('$Id: DataNavigator.pm,v 1.4 2000-11-27 03:08:41 robert_jenks Exp $', '$Name:  $');
use Data::Publish;
use CGI::Dialog;
use CGI::ImageManager;
use DBI::StatementManager;
use base qw(CGI::Dialog::ContentItem);

use constant DN_STATEMENT_FLAGS => STMTMGRFLAG_DYNAMICSQL | STMTMGRFLAG_REPLACEVARS;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP=();


sub new
{
	my $type = shift;
	my %params = @_;

	unless (defined $params{publDefn})
	{
		die 'A publDefn is required';
	}

	unless (defined $params{publDefn}->{dnQuery} && ref $params{publDefn}->{dnQuery} eq 'CODE')
	{
		die 'A dnQuery callback is required';
	}

	return CGI::Dialog::ContentItem::new($type, %params);
}


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags, $mainData) = @_;
	my $html = '';
	my $publDefn = $self->{publDefn};

	# Get the query callback from the publish definition
	my $dnQuery = $publDefn->{dnQuery};

	# Create the SQL::Generator::Condition object
	my $queryCond = &$dnQuery($page);

	# Generate the SQL and Bind Parameters
	my ($sql, $bindParams) = $self->createStmt($page, $queryCond, $command);

	# Execute the SQL
	my $sth = $self->getStmtHandle($page, $sql, $bindParams);
	if ($sth)
	{
		# Create a publish definition
		$publDefn = $self->createPublDefn($page, $sth, $publDefn);

		# Generate hidden fields for each column of the query
		$html .= $self->createHiddenColumnData($page, $sth, $publDefn);

		# Publish the results
		$html .= $self->getQueryHtml($page, $sth, $publDefn);
	}

	return qq{
		<tr><td colspan="2">$html</td></tr>
	};
}


sub createStmt
{
	my $self = shift;
	my ($page, $queryCond, $command) = @_;

	my $startRow = 0 + $page->field('start_row');
	$startRow = 0 if $startRow eq 'NaN' || $startRow < 0;
	my $showRows = 0 + $page->field('out_rows');
	$showRows = 10 if $showRows eq 'NaN' || $showRows < 10;
	$showRows = 50 if $showRows > 50;
	my $endRow = $startRow + $showRows;

	my ($sql, $bindParams);
	
	if ($command eq 'sql')
	{
		($sql, $bindParams) = ($self->{sqlStmt}, $self->{bindParams});
	}
	else
	{
		# get the SQL from GenerateQuery
		($sql, $bindParams) = $queryCond->genSQL();
	}
	
	$page->replaceVars(\$sql);

	# Add the SQL wrapper to rownum restrictions
	my $cols = join ",\n", map {"\t$_"} $queryCond->outColumns();
	$sql = "SELECT * FROM (\n\nSELECT\n\trownum AS auto_row_number,\n$cols\nFROM (\n\n" . $sql . "\n\n) WHERE rownum <= ?\n\n) WHERE auto_row_number > ?";
	push @{$bindParams}, ($endRow+1), $startRow;

	# Return the final sql & bindParams
	return ($sql, $bindParams);
}


sub getStmtHandle
{
	my $self = shift;
	my ($page, $sql, $bindParams) = @_;
	my $sth;

	# create a DBI statement handle
	eval {
		my $stmtMgr = new DBI::StatementManager();
		$sth = $stmtMgr->execute($page, DN_STATEMENT_FLAGS, $sql, @$bindParams);
	};
	if ($@)
	{
		$page->addDebugStmt("$@");
		$page->addDebugStmt("<pre>$sql</pre>");
		$page->addDebugStmt(join ',', @$bindParams);
		undef $@;
		return undef;
	}

	return $sth;
}


sub createPublDefn
{
	my $self = shift;
	my ($page, $sth, $publDefn) = @_;
	prepareStatementColumns($page, DN_STATEMENT_FLAGS, $sth, $publDefn) unless defined $publDefn->{columnDefn};

	if (defined $publDefn->{dnMultiRowActions})
	{
		$publDefn->{select} = {
			type => 'checkbox',
		};
	}

	if (defined $publDefn->{dnDrillDown} || defined $publDefn->{dnSelectRowAction})
	{
		$publDefn->{bodyRowAttr} = {} unless exists $publDefn->{bodyRowAttr};
		$publDefn->{bodyRowAttr}{onMouseOver} = q{this.style.cursor='hand';this.style.backgroundColor='beige'};
		$publDefn->{bodyRowAttr}{onMouseOut} = q{this.style.cursor='default';this.style.backgroundColor='#FFFFFF'};

		if (defined $publDefn->{dnDrillDown})
		{
			$publDefn->{bodyRowAttr}{onClick} = qq{handleDrillDown(event, '#rowNum#');};
		}
		else
		{
			my $href = $publDefn->{dnSelectRowAction};
			$publDefn->{bodyRowAttr}{onClick} = qq{document.location = '$href'};
		}
	}

	# Convert text colIdx's to numbers
	my %colNames = ();
	my $i = 0;
	foreach (@{$sth->{NAME_lc}})
	{
		$colNames{$_} = $i++;
	}
	foreach (@{$publDefn->{columnDefn}})
	{
		if (ref $_ eq 'HASH' && exists $_->{colIdx})
		{
			$_->{colIdx} =~ s/\#\{(\w+)\}\#/$colNames{$1}/g;
		}
	}

	return $publDefn;
}


sub createHiddenColumnData
{
	my $self = shift;
	my ($page, $sth, $publDefn) = @_;
	my $html = '';

	unless (defined $publDefn->{name})
	{
		die "publDefn must have a name";
	}
	my $name = $publDefn->{name};

	# Add hidden fields for each column unless there is already a param with the same name
	my %params = map {$_, 1} $page->param();
	foreach my $column (@{$sth->{NAME_lc}})
	{
		my $fieldName = "dn.${name}.${column}";
		unless (exists $params{$fieldName})
		{
			$html .= qq{<input type="hidden" name="$fieldName">\n};
		}
	}

	return "\n$html\n";
}


sub getQueryHtml
{
	my $self = shift;
	my ($page, $sth, $publDefn) = @_;
	my $html = '';

	# Use Data::Publish to format the results
	$html .= createHtmlFromStatement($page, DN_STATEMENT_FLAGS, $sth, $publDefn, {style => 'datanav', maxRows => $page->field('out_rows')});
	$page->property('nextPageExists', $sth->fetch());
	$sth->finish();

	# Wrap the results in a <tr> to put in the dialog's <table>
	my $id = "_id_" . $self->{name};
	$html = qq{<tr valign="top" id="$id"><td width=$self->{_spacerWidth} colspan="2">$html</td></tr>};


	return $html;
}



##############################################################################
package CGI::Dialog::DataNavigator::Ancestors;
##############################################################################

use strict;
use SDE::CVS ('$Id: DataNavigator.pm,v 1.4 2000-11-27 03:08:41 robert_jenks Exp $', '$Name:  $');
use CGI::Dialog;
use CGI::ImageManager;
use base qw(CGI::Dialog::ContentItem);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP=();


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags, $mainData) = @_;
	my $html;

	my $drillDepth = $page->field('drill_depth');
	$drillDepth = 0 unless defined $drillDepth;

	my $publDefn = $self->{publDefn};

	for (0..$drillDepth)
	{
		if (defined $publDefn->{dnAncestorFmt})
		{
			my $imageName = $_ eq $drillDepth ? 'icons/folder-orange-open' : 'icons/folder-orange-closed';
			$html .= getImageTag('design/transparent-line', {width => 16, height => 13}) x $_;
			$html .= $IMAGETAGS{$imageName} . '&nbsp;';
			$html .= qq{<a href="javascript:setDrill($_)">} unless $_ == $drillDepth;
			my $ancestorFmt = $publDefn->{dnAncestorFmt};
			if (ref $ancestorFmt eq 'CODE')
			{
				$html .= &$ancestorFmt($page, $dialog);
			}
			else
			{
				$html .= $publDefn->{dnAncestorFmt};
			}
			$html .= "</a>" unless $_ == $drillDepth;
			$html .= "<br>\n";
		}


		if (defined $publDefn->{dnDrillDown})
		{
			$publDefn = $publDefn->{dnDrillDown};
		}
	}

	return qq{<tr><td colspan="2">$html</td></tr>};
}


##############################################################################
package CGI::Dialog::DataNavigator::MultiActions;
##############################################################################

use strict;
use SDE::CVS ('$Id: DataNavigator.pm,v 1.4 2000-11-27 03:08:41 robert_jenks Exp $', '$Name:  $');
use CGI::Dialog;
use CGI::ImageManager;
use base qw(CGI::Dialog::ContentItem);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP=();


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags, $mainData) = @_;
	my $nextPageExists = $page->property('nextPageExists');
	my $startRow = $page->field('start_row') || 0;
	my $outRows = $page->field('out_rows') || 10;
	
	my $publDefn = $self->{publDefn};

	my $html = qq{<table cellspacing="0" cellpadding="0" width="100%" border="0" bgcolor="#CDD3DB"><tr>};

	# Add multi-row action buttons
	if (defined $publDefn->{dnMultiRowActions})
	{
		$html .= qq{<td valign="middle">
				<img src="" width="5" height="0">$IMAGETAGS{'images/design/right-to-up-arrow'}<br>
			</td><td valign="middle">
				@{[ $self->getButtonHtml('Sign', href => '/temp/') ]}
			</td><td valign="middle">
				@{[ getImageTag('images/design/arrow-spacer', {width => '8'}) ]}<br>
			</td><td valign="middle">
				@{[ $self->getButtonHtml('File', href => '/temp/') ]}
			</td>
		};
	}

	# Add a spacer column
	$html .= qq{<td width="100%"><img src="" width="8" height="1"></td>};

	# First Page Button
	if ($startRow >= (2 * $outRows))
	{
		$html .=
			qq{<td valign="middle">
				@{[ $self->getButtonHtml('First Page', image => 'widgets/vcr/skip-back', onClick => 'changePage(-999)') ]}
			</td><td valign="middle">
				<img src="" width="8" height="1"><br>
			</td>};
	}

	# Prev Page Button
	unless ($startRow == 0)
	{
		$html .=
			qq{<td valign="middle">
				@{[ $self->getButtonHtml('Prev Page', image => 'widgets/vcr/fast-back', onClick => 'changePage(-1)') ]}
			</td><td valign="middle">
				<img src="" width="8" height="1"><br>
			</td>};
	}


	# Next Page Button
	if ($nextPageExists)
	{
		$html .=
			qq{<td valign="middle">
				@{[ $self->getButtonHtml('Next Page', image => 'widgets/vcr/fast-fwd', onClick => 'changePage(1)') ]}
			</td><td>
				<img src="" width="10" height="1"><br>
			</td>};
	}

	$html .= qq{</tr><tr><td><img src="" width="10" height="5"></td></tr></table>};

	return qq{<tr><td colspan="2">$html</td></tr>};
}


sub getButtonHtml
{
	my ($self, $label, %options) = @_;
	my $html;

	my $onClick = '';
	if (defined $options{onClick})
	{
		$onClick = $options{onClick};
	}
	else
	{
		$onClick = "document.location = '$options{href}'" if defined $options{href};
	}

	$html = qq{<table cellpadding="1" cellspacing="0" style="border: 2; border-style: outset; background-color: #EEEEEE;" onClick="$onClick" onMouseOver="this.style.cursor='hand';this.style.backgroundColor='beige'" onMouseOut="this.style.cursor='default';this.style.backgroundColor='#EEEEEE'"></tr><td align="right" valign="bottom" style="font-family: tahoma helvetica sans-serif; color: black; font-size: 8pt; font-weight: bold;">};

	$label = "<nobr>&nbsp;$label&nbsp;</nobr>";

	if (defined $options{href})
	{
		$label = qq{<a href="$options{href}" style="text-decoration: none; color: black;">$label</a>};
	}

	if (defined $options{image})
	{
		my $image = "<nobr>&nbsp;$IMAGETAGS{$options{image}}&nbsp;</nobr>";
		if (defined $options{href})
		{
			$image = qq{<a href="$options{href}" style="text-decoration: none;">$image</a>};
		}

		$html .= '<table cellspacing="0" cellpadding="0" border="0"><tr>';
		$html .= qq{<td valign="middle" style="font-family: tahoma helvetica sans-serif; color: black; font-size: 8pt; font-weight: bold;">$image</td>};
		$html .= qq{<td valign="middle" style="font-family: tahoma helvetica sans-serif; color: black; font-size: 8pt; font-weight: bold;">$label</a></td>};
		$html .= '</tr></table>';
	}
	else
	{
		$html .= $label;
	}

	$html .= '</td></tr></table>';

	return $html;
}


##############################################################################
package CGI::Dialog::DataNavigator::StatusBar;
##############################################################################

use strict;
use SDE::CVS ('$Id: DataNavigator.pm,v 1.4 2000-11-27 03:08:41 robert_jenks Exp $', '$Name:  $');
use CGI::Dialog;
use CGI::ImageManager;
use base qw(CGI::Dialog::ContentItem);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP=();


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags, $mainData) = @_;
	my $html = '';

	return $html;
}


##############################################################################
package CGI::Dialog::DataNavigator::JavaScript;
##############################################################################

use strict;
use SDE::CVS ('$Id: DataNavigator.pm,v 1.4 2000-11-27 03:08:41 robert_jenks Exp $', '$Name:  $');
use CGI::Dialog;
use CGI::ImageManager;
use base qw(CGI::Dialog::ContentItem);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP=();


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags, $mainData) = @_;

	my $publDefn = $self->{publDefn};
	my $publName = $publDefn->{name};
	my $arrayName = 'publish_' . $publDefn->{name} . '_rows';
	my $nextDrillDepth = ($page->field('drill_depth') || 0) + 1;

	my $html = qq{
		<script language="JavaScript1.2">
		<!--

		function changePage(offset)
		{

			var showRows = 20;
			var outRowsObj = "document.dialog._f_out_rows";
			if (outRowsObj = eval(outRowsObj))
			{
				showRows = parseInt(outRowsObj.value);
			}

			var rowOffset = offset * showRows;
			var fieldObj = "document.dialog._f_start_row";
			if(startRow = eval(fieldObj))
			{
				var newStart = Number(startRow.value) + rowOffset;
				if (newStart < 0)
					newStart = 0;
				startRow.value = newStart;
			}
			document.all.dialog.submit();
		}

		function resetStartRow()
		{
			var fieldObj = "document.dialog._f_start_row";
			//alert('Resetting Start Row to 0');
			if(startRow = eval(fieldObj))
				startRow.value = 0;
		}

		function handleDrillDown(event, selectedId)
		{
			// Make sure they didn't click on a form field or an A tag
			if (event.srcElement.tagName == 'A' || event.srcElement.tagName == 'INPUT')
			{
				return;
			}

			// Save all of the values about the row they selected in hidden form fields
			for (var colName in $arrayName\[selectedId])
			{
				var fieldObj = document.dialog['dn.${publName}.' + colName];
				//var fieldObjName = "document.dialog.['dn.${publName}." + colName + "']";
				//if (fieldObj = eval(fieldObjName))
				//{
					//alert ("Setting " + fieldObjName + " to " + $arrayName\[selectedId][colName]);
					fieldObj.value = $arrayName\[selectedId][colName];
				//}
			}

			// Increment the drill depth and reset back to the first page of results
			document.dialog._f_drill_depth.value = $nextDrillDepth;
			resetStartRow();

			// Auto-magically resubmit the form
			document.dialog.submit();
		}

		function setDrill(newDepth)
		{
			document.dialog._f_drill_depth.value = newDepth;
			resetStartRow();
			document.dialog.submit();
		}

		function setSortOrder(colName)
		{
			var curSortColumn = document.dialog._f_sort_column.value;
			var curSortOrder = document.dialog._f_sort_order.value;

			if (colName == curSortColumn)
			{
				// Swap the order
				if (curSortOrder == 'A')
					document.dialog._f_sort_order.value = 'D';
				else
					document.dialog._f_sort_order.value = 'A';
			}
			else
			{
				document.dialog._f_sort_column.value = colName;
				document.dialog._f_sort_order.value = 'A';
			}
		}

		// -->
		</script>
	};

	return $html;
}



1;
