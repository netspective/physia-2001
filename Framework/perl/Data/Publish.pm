##############################################################################
package Data::Publish;
##############################################################################

use strict;
use Exporter;
use Number::Format;
use CGI::Layout;
use Storable qw(dclone);

use vars qw(@ISA @EXPORT %BLOCK_PUBLICATION_STYLE %FORMELEM_STYLE);
use enum qw(BITMASK:PUBLFLAG_ STDRECORDICONS HASCALLBACKS NEEDSTORAGE HASTAILROW REPLACEDEFNVARS CHECKFORDATASEP HIDEBANNER HIDEHEAD HIDETAIL HIDEROWSEP);
use enum qw(BITMASK:PUBLCOLFLAG_ DONTWRAP DONTWRAPHEAD DONTWRAPBODY DONTWRAPTAIL);

@ISA    = qw(Exporter);
@EXPORT = qw(
	PUBLFLAG_STDRECORDICONS
	PUBLFLAG_HIDEHEAD
	PUBLFLAG_HIDETAIL
	PUBLFLAG_HIDEROWSEP
	PUBLCOLFLAG_DONTWRAP
	PUBLCOLFLAG_DONTWRAPHEAD
	PUBLCOLFLAG_DONTWRAPBODY
	PUBLCOLFLAG_DONTWRAPTAIL

	prepareStatementColumns
	createHtmlFromStatement
	createHtmlFromData
);

use constant FORMATTER => new Number::Format(INT_CURR_SYMBOL => '$');
use constant CACHE_DEFN_FMTTEMPLATE => 0;
use constant FMTTEMPLATE_CACHE_KEYNAME => '_tmplCache';

%BLOCK_PUBLICATION_STYLE =
(
	'report' =>
	{
		# this the "default" style so we don't override anything
	},

	'panel.body' =>
	{
		#flags => PUBLFLAG_HIDEHEAD,
		headFontOpen => '<FONT FACE="Arial,Helvetica" SIZE=1 COLOR=NAVY>',
		bodyFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=1>',
		tailFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=1 COLOR=NAVY><B>',
		rowSepStr => '',
	},

	'panel' =>
	{
		flags => PUBLFLAG_HIDEHEAD,
		headFontOpen => '<FONT FACE="Arial,Helvetica" SIZE=1 COLOR=NAVY>',
		bodyFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=1>',
		tailFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=1 COLOR=NAVY><B>',
		rowSepStr => '',
		frame =>
		{
			headColor => '#EEEEEE',
			borderColor => '#CCCCCC',
			contentColor => '#FFFFFF',
			heading => 'No Heading Provided',
			width => '100%',
			editUrl => './stpe-#my.stmtId#?home=/#param.arl#',
		},
	},

	'panel.indialog' =>
	{
		inherit => 'panel',
		frame =>
		{
			editUrl => '../stpe-#my.stmtId#?home=/#param.arl#',
		},
	},

	'panel.static' =>
	{
		inherit => 'panel',
		frame =>
		{
			-editUrl => '',
		},
	},

	'panel.edit' =>
	{
		inherit => 'panel',
		headFontOpen => '<FONT FACE="Arial,Helvetica" SIZE=2 COLOR=NAVY>',
		bodyFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=2>',
		tailFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=2 COLOR=NAVY><B>',
		banner =>
		{
			contentColor => '#FFE0E0',
			bannerFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=2>',
		},
		frame =>
		{
			frameFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=2 COLOR=YELLOW><B>',
			headColor => 'darkred',
			borderColor => 'red',
			closeUrl => '#param.home#',
			-editUrl => '',
			-width => '',
		},
	},

	'panel.transparent' =>
	{
		flags => PUBLFLAG_HIDEHEAD,
		headFontOpen => '<FONT FACE="Arial,Helvetica" SIZE=1 COLOR=NAVY>',
		bodyFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=1>',
		tailFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=1 COLOR=NAVY><B>',
		rowSepStr => '',
		frame =>
		{
			headColor => '#FFFFFF',
			borderWidth => 0,
			borderColor => '#FFFFFF',
			contentColor => '#FFFFFF',
			heading => 'No Heading Provided',
			frameSepCellFmt => "<IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1>",
			editUrl => './stpe-#my.stmtId#?home=/#param.arl#',
			width => '100%',
		},
	},
);

while(my ($style, $styleInfo) = each %BLOCK_PUBLICATION_STYLE)
{
	if(my $inherit = $styleInfo->{inherit})
	{
		foreach(split(/\s*,\s*/, $inherit))
		{
			if(my $inhStyleInfo = $BLOCK_PUBLICATION_STYLE{$_})
			{
				inheritHashValues($styleInfo, $inhStyleInfo);
			}
		}
	}
}

#-----------------------------------------------------------------------------
# The following functions/methods handle publishing of columnar (table/row)
# data [like for reports, panels, etc]
#-----------------------------------------------------------------------------

sub prepareStatementColumns
{
	my ($page, $flags, $stmtHdl, $publDefn) = @_;
	my $namesRef = $stmtHdl ? $stmtHdl->{NAME} : [];

	my $columnDefn = [];
	my $columnNum = 0;
	foreach(@$namesRef)
	{
		my $colName = ucfirst(lc($_));
		$colName =~ s/_/ /g;
		push(@$columnDefn,
				{
					options => 0,
					head => $colName,
					dataFmt => "#&{?}#",
					hAlign => 'CENTER',
					dAlign => 'LEFT',
				});
		$columnNum++;
	}

	$publDefn->{columnDefn} = $columnDefn if $publDefn;
	return $columnDefn;
}

# example of what a $publDefn would look like:
#{
#	style => 'pane',
#	frame =>
#	{
#		heading => 'Fee Schedules',
#		color => '',
#	},
#	banner =>
#   {
#		color => 'xxx',
#		content => '',
#		actionRows => [{caption => 'abc'}, {caption => 'xyz'}],
#	},
#	stdIcons =>
#	{
#		addUrlFmt => 'a', updUrlFmt => 'b', delUrlFmt => 'c',
#	},
#	icons =>
#	{
#		head =>
#		[
#			{ urlFmt => '/test/me/#0#', imgSrc => '/images/icons/edit_add.gif' },
#		],
#		data =>
#		[
#			{ urlFmt => '/test/me/#0#', imgSrc => '/images/icons/edit_update.gif' },
#			{ urlFmt => '/test/me/#0#', imgSrc => '/images/icons/edit_remove.gif' },
#		],
#	},
#	select =>
#	{
#		type => 'checkbox',
#       location => 'trail',
#       name => 'somename',
#       valueFmt => 'somevalue#x#',
#	},
#	columnDefn =>
#	[
#		{ head => 'ID', url => '/test/#&{?}#'},
#		{ head => 'Code', },
#		{ head => 'Price', dformat => 'currency', tAlign => 'RIGHT', tDataFmt => '&{avg_currency:&{?}}<BR>&{sum_currency:&{?}}',
#         summarize => 'avg', options => 0, hint => 'blah',
#       },
#	],
#},

#
# This method does all the hard work of formatting information into HTML
# and only saves the basic strings necessary to do simple regexp template
# replacements. It handles the one-time preparation of reports, panels,
# and other "data blocks" that need to be displayed in HTML.
#
# NOTE: callers of this function assume that $publDefn is NOT modified
#       in any way
#

sub prepare_HtmlBlockFmtTemplate
{
	my ($page, $flags, $publDefn, $style) = @_;

	if(my $style = $BLOCK_PUBLICATION_STYLE{$style || $publDefn->{style}})
	{
		my %copyDefn = %{$publDefn};
		$publDefn = \%copyDefn;
		#$publDefn = dclone($publDefn);
		inheritHashValues($publDefn, $style);
	}

	my ($headFontOpen, $headFontClose) = ($publDefn->{headFontOpen} || '<FONT FACE="Arial,Helvetica" SIZE=2 COLOR=NAVY>', $publDefn->{headFontClose} || '</FONT>');
	my ($bodyFontOpen, $bodyFontClose) = ($publDefn->{bodyFontOpen} || '<FONT FACE="Verdana,Arial,Helvetica" SIZE=2>', $publDefn->{bodyFontClose} || '</FONT>');
	my ($tailFontOpen, $tailFontClose) = ($publDefn->{tailFontOpen} || '<FONT FACE="Verdana,Arial,Helvetica" SIZE=2 COLOR=NAVY><B>', $publDefn->{tailFontClose} || '</B></FONT>');

	my $columnDefn = $publDefn->{columnDefn};
	my $publFlags = exists $publDefn->{flags} ? $publDefn->{flags} : 0;
	my $outColsCount = (scalar(@$columnDefn) * 2) + 1; # because we create "spacer" columns, too

	my ($hSpacer, $dSpacer, $tSpacer) =
		(	exists $publDefn->{hSpacer} ? $publDefn->{hSpacer} : "<TH>$headFontOpen&nbsp;&nbsp;$headFontClose</TH>",
			exists $publDefn->{dSpacer} ? $publDefn->{dSpacer} : "<TH>$bodyFontOpen&nbsp;&nbsp;$bodyFontClose</TH>",
			exists $publDefn->{tSpacer} ? $publDefn->{tSpacer} : "<TH>$tailFontOpen&nbsp;&nbsp;$tailFontClose</TH>",

		);
	my $imgPath = exists $publDefn->{imgPath} ? $publDefn->{imgPath} : "/resources";
	my $colCount = 0;
	my (@headCols, @bodyCols, @tailCols, @colCallbacks, @colValueCallbacks, @storeCols);

	foreach (@$columnDefn)
	{
		my $colOptions = $_->{options};
		my $colIdx = exists $_->{colIdx} ? $_->{colIdx} : $colCount;
		my ($hCellFmt, $dCellFmt, $tCellFmt) =
			(	exists $_->{hCellFmt} ? $_->{hCellFmt} : undef,
				exists $_->{dCellFmt} ? $_->{dCellFmt} : undef,
				exists $_->{tCellFmt} ? $_->{tCellFmt} : undef);

		unless(defined $hCellFmt)
		{
			my $hDataFmt = $_->{hDataFmt} || $_->{head};
			$hDataFmt = qq{<NOBR>$hDataFmt</NOBR>} if $colOptions & (PUBLCOLFLAG_DONTWRAP | PUBLCOLFLAG_DONTWRAPHEAD);
			$hCellFmt = qq{<TH ALIGN=@{[$_->{hAlign} || 'CENTER']} @{[ $_->{hHint} ? "TITLE='$_->{hHint}'" : '' ]}>$headFontOpen$hDataFmt$headFontClose</TH>};
		}
		unless(defined $dCellFmt)
		{
			my $dataFmt = exists $_->{dataFmt} ? $_->{dataFmt} : (exists $_->{img} ? qq{<IMG SRC="$_->{img}" BORDER=0>} : "#$colIdx#");
			my $dAlign = exists $_->{dAlign} ? $_->{dAlign} : undef;
			$dAlign = 'RIGHT' if $_->{dformat} =~ m/^(currency)$/;
			if(ref $dataFmt eq 'CODE')
			{
				$publFlags |= PUBLFLAG_HASCALLBACKS;
				$colCallbacks[$colIdx] = $_->{dataFmt};
				$dataFmt = "&{call:$colIdx}";
			}
			elsif(ref $dataFmt eq 'HASH')
			{
				$publFlags |= PUBLFLAG_HASCALLBACKS;
				$colValueCallbacks[$colIdx] = $_->{dataFmt};
				#$dataFmt = $dataFmt->{_MATCHTYPE} eq 'regexp' ? "&{callifvalmatch:$colIdx}" : "&{callifvaleq:$colIdx}";
				$dataFmt = "&{callifvaleq:$colIdx}";
			}
			elsif(ref $dataFmt eq 'ARRAY')
			{
				$publFlags |= PUBLFLAG_HASCALLBACKS;
				$colValueCallbacks[$colIdx] = $_->{dataFmt};
				#$dataFmt = $dataFmt->{_MATCHTYPE} eq 'regexp' ? "&{callifvalmatch:$colIdx}" : "&{callifvaleq:$colIdx}";
				$dataFmt = "&{callifvaleqidx:$colIdx}";
			}
			else
			{
				if(my $dformat = $_->{dformat})
				{
					$dataFmt = "&{fmt_$dformat:$colIdx}";
					$publFlags |= PUBLFLAG_HASCALLBACKS;
				}
			}
			if($_->{summarize})
			{
				$dAlign = 'RIGHT' unless defined $dAlign;
				$publFlags |= (PUBLFLAG_HASCALLBACKS | PUBLFLAG_NEEDSTORAGE);
				push(@storeCols, $colIdx);
			}
			if($_->{url})
			{
				$dataFmt = qq{<A HREF='$_->{url}' STYLE='text-decoration:none' @{[ $_->{hint} ? "TITLE='$_->{hint}'" : '' ]}>$dataFmt</A>};
			}
			elsif($_->{hint})
			{
				$dataFmt = "<SPAN TITLE='$_->{hint}'>$dataFmt</SPAN>";
			}
			$dataFmt = "<NOBR>$dataFmt</NOBR>" if $colOptions & (PUBLCOLFLAG_DONTWRAP | PUBLCOLFLAG_DONTWRAPBODY);
			$dCellFmt = "<TD ALIGN=@{[$dAlign || 'LEFT']}>$bodyFontOpen$dataFmt$bodyFontClose</TD>";
		}
		unless(defined $tCellFmt)
		{
			my $tDataFmt = $_->{tDataFmt};
			my $tAlign = exists $_->{tAlign} ? $_->{tAlign} : undef;
			if(my $summarize = $_->{summarize})
			{
				my $cbackName = $_->{dformat} ? "$summarize\_$_->{dformat}" : $summarize;
				$tDataFmt = "&{$cbackName:$colIdx}";
				$tAlign = 'RIGHT' unless defined $tAlign;
			}
			if($tDataFmt)
			{
				$publFlags |= (PUBLFLAG_HASCALLBACKS | PUBLFLAG_HASTAILROW | PUBLFLAG_NEEDSTORAGE);
				push(@storeCols, $colIdx) unless grep { $_ == $colIdx } @storeCols;
			}
			$tDataFmt ||= '&nbsp;';
			$tDataFmt = "<NOBR>$tDataFmt</NOBR>" if $colOptions & (PUBLCOLFLAG_DONTWRAP | PUBLCOLFLAG_DONTWRAPTAIL);
			$tCellFmt = "<TD ALIGN=$tAlign>$tailFontOpen$tDataFmt$tailFontClose</TD>";
		}

		# replace &{?} with the current column's index and ## with a single pound (for recursive variables or simple # replacements)
		$hCellFmt =~ s/\&\{\?\}/$colIdx/g;
		$dCellFmt =~ s/\&\{\?\}/$colIdx/g;
		$tCellFmt =~ s/\&\{\?\}/$colIdx/g;

		unless($publFlags & PUBLFLAG_HASCALLBACKS)
		{
			$publFlags |= PUBLFLAG_HASCALLBACKS if $hCellFmt =~ m/\&\{.*?\}/;
			$publFlags |= PUBLFLAG_HASCALLBACKS if $dCellFmt =~ m/\&\{.*?\}/;
			$publFlags |= PUBLFLAG_HASCALLBACKS if $tCellFmt =~ m/\&\{.*?\}/;
		}

		push(@headCols, $hCellFmt, $hSpacer);
		push(@bodyCols, $dCellFmt, $dSpacer);
		push(@tailCols, $tCellFmt, $tSpacer);

		$colCount++;
	}

	# the user may give icons as a hash but we expect is as an array -- so, if they
	# give a hash then lets turn it into an array of one
	my $allIcons = exists $publDefn->{icons} ? dclone($publDefn->{icons}) : undef;
	if($allIcons) {
		$allIcons = [$allIcons] unless ref $allIcons eq 'ARRAY';
	} else {
		$allIcons = [];
	}

	if(my $stdIcons = $publDefn->{stdIcons})
	{
		push(@$allIcons, { location => 'lead', head => [{ urlFmt => $stdIcons->{addUrlFmt}, title => 'Add Record', imgSrc => '/resources/icons/action-edit-add.gif' }] }) if $stdIcons->{addUrlFmt};
		push(@$allIcons, { location => 'trail', data => [{ urlFmt => $stdIcons->{delUrlFmt}, title => 'Delete Record', imgSrc => '/resources/icons/action-edit-remove-x.gif' }] }) if $stdIcons->{delUrlFmt};

		#unless($icons)
		#{
		#	$icons = { location => $stdIcons->{location} || 'trail' };
			#$icons = $publDefn->{icons};
		#}
		#unshift(@{$icons->{head}}, { urlFmt => $stdIcons->{addUrlFmt}, title => 'Add Record', imgSrc => '/resources/icons/action-edit-add.gif' }) if $stdIcons->{addUrlFmt};
		#unshift(@{$icons->{data}}, { urlFmt => $stdIcons->{delUrlFmt}, title => 'Delete Record', imgSrc => '/resources/icons/action-edit-remove-x.gif' }) if $stdIcons->{delUrlFmt};
		#unshift(@{$icons->{data}}, { urlFmt => $stdIcons->{delUrlFmt}, title => 'Delete Record', imgSrc => '/resources/icons/action-edit-remove.gif' }) if $stdIcons->{delUrlFmt};
		#unshift(@{$icons->{data}}, { urlFmt => $stdIcons->{updUrlFmt}, title => 'Edit Record', imgSrc => '/resources/icons/action-edit-update.gif' }) if $stdIcons->{updUrlFmt};
	}
	if(my $bullets = $publDefn->{bullets})
	{
		my $bulletIcons = { location => 'lead' };
		push(@$allIcons, $bulletIcons);

		if(ref $bullets eq 'HASH')
		{
			push(@{$bulletIcons->{data}}, {
					imgSrc => exists $bullets->{imgSrc} ? $bullets->{imgSrc} : '/resources/icons/square-lgray-sm.gif',
					urlFmt => exists $bullets->{urlFmt} ? $bullets->{urlFmt} : (exists $publDefn->{stdIcons} ? (exists $publDefn->{stdIcons}->{updUrlFmt} ? $publDefn->{stdIcons}->{updUrlFmt} : undef) : undef),
					title => exists $bullets->{title} ? $bullets->{title} : 'Edit Record',
					});
		}
		else
		{
			if($bullets =~ m/^1$/)
			{
				push(@{$bulletIcons->{data}}, { imgSrc => '/resources/icons/square-lgray-sm.gif' });
			}
			else
			{
				push(@{$bulletIcons->{data}}, { urlFmt => $bullets, imgSrc => '/resources/icons/square-lgray-hat-sm.gif' });
			}
		}
	}

	foreach my $icons (@$allIcons)
	{
		my $location = $icons->{location} || 'lead';
		my $hcontrol = '';
		foreach (@{$icons->{head}})
		{
			$hcontrol .= "<A HREF='$_->{urlFmt}' TITLE='$_->{title}'><IMG SRC='$_->{imgSrc}' BORDER=0></A> ";
		}
		my $dcontrol = '';
		foreach (@{$icons->{data}})
		{
			$dcontrol .= "<A HREF='$_->{urlFmt}' TITLE='$_->{title}'><IMG SRC='$_->{imgSrc}' BORDER=0></A> ";
		}
		$hcontrol = "<NOBR>$hcontrol</NOBR>" if $hcontrol;
		$dcontrol = "<NOBR>$dcontrol</NOBR>" if $dcontrol;

		if($location eq 'trail')
		{
			push(@headCols, $hcontrol ? "<TD ALIGN=CENTER>$headFontOpen$hcontrol$headFontClose</TD>" : $hSpacer, $hSpacer);
			push(@bodyCols, "<TD ALIGN=CENTER>$bodyFontOpen$dcontrol$bodyFontClose</TD>", $dSpacer);
			push(@tailCols, $tSpacer, $tSpacer);
		}
		else
		{
			unshift(@headCols, $hcontrol ? "<TD ALIGN=CENTER>$headFontOpen$hcontrol$headFontClose</TD>" : $hSpacer, $hSpacer);
			unshift(@bodyCols, "<TD ALIGN=CENTER>$bodyFontOpen$dcontrol$bodyFontClose</TD>", $dSpacer);
			unshift(@tailCols, $tSpacer, $tSpacer);
		}
		$outColsCount += 2;
	}

	if(my $select = $publDefn->{select})
	{
		my $location = $select->{location} || 'lead';
		my $type = $select->{type} || 'checkbox';
		my $name = $select->{name};
		my $valueFmt = $select->{valueFmt} || '#0#';
		my $control = "<INPUT TYPE=\U$type\E NAME='$name' VALUE='$valueFmt'>";

		if($location eq 'trail')
		{
			push(@headCols, $hSpacer, $hSpacer);
			push(@bodyCols, "<TD>$bodyFontOpen$control$bodyFontClose</TD>", $dSpacer);
			push(@tailCols, $tSpacer, $tSpacer);
		}
		else
		{
			unshift(@headCols, $hSpacer, $hSpacer);
			unshift(@bodyCols, "<TD>$bodyFontOpen$control$bodyFontClose</TD>", $dSpacer);
			unshift(@tailCols, $tSpacer, $tSpacer);
		}
		$outColsCount += 2;
	}

	#
	# CODE FOR BANNERS and FRAMES are duplicated in CGI::Layout as well (for performance)
	# so if any changes are made here, be sure to make the same changes there, too.
	#
	my $dataSepStr = exists $publDefn->{dataSepStr} ? $publDefn->{dataSepStr} : "<TR><TD COLSPAN=$outColsCount><HR SIZE=1 COLOR=SILVER WIDTH=100%></TD></TR>";
	my $rowSepStr = exists $publDefn->{rowSepStr} ? $publDefn->{rowSepStr} : "<TR><TD COLSPAN=$outColsCount><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>";
	my $bannerFmt = '';
	if(my $bannerInfo = $publDefn->{banner})
	{
		my ($bannerFontOpen, $bannerFontClose) = ($bannerInfo->{bannerFontOpen} || '<FONT FACE="Arial,Helvetica" SIZE=2>', $bannerInfo->{bannerFontClose} || '</FONT>');
		if($bannerInfo->{content})
		{
			$bannerFmt = qq{
				<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
					<TR><TD>$bannerFontOpen$bannerInfo->{content}$bannerFontClose</TD></TD>
				</TABLE>
				};
		}
		elsif(my $actions = $bannerInfo->{actionRows})
		{
			my @rows = ();
			foreach (@$actions)
			{
				my $icon = $_->{icon} || '/resources/icons/action-edit-add.gif';
				my $img = $_->{img} || "<IMG SRC='$icon' BORDER=0>";
				push(@rows, '<TR VALIGN=TOP>',
						$img ?
						qq{<TD>$bannerFontOpen@{[ $_->{url} ? "<A HREF='$_->{url}'>$img</A>" : $img ]}$bannerFontClose</TD><TD>$bannerFontOpen&nbsp;$bannerFontClose</TD><TD>$bannerFontOpen$_->{caption}$bannerFontClose</TD>} :
						"<TD COLSPAN=3>$bannerFontOpen$_->{caption}$bannerFontClose</TD>",
						'</TR>');
			}
			$bannerFmt = qq{
				<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
					@{[ join('', @rows) ]}
				</TABLE>
				};
		}
		# replace any $xxx vars with the local variables in _this_ method
		# so that, e.g., $bodyFontOpen in a Fmt will be replaced with $bodyFontOpen's value
		#
		$bannerFmt =~ s/\#fmtdefn\.(\w+)\#/eval("\$$1")/ge;
	}

	my ($headRowFmt, $bodyRowFmt, $tailRowFmt) =
	(
		$publFlags & PUBLFLAG_HIDEHEAD ? '' : qq{
			<TR VALIGN=TOP BGCOLOR=@{[ $publDefn->{headBgColor} || 'EEEEDD' ]}>
				$hSpacer @{[ join('', @headCols) ]}
			</TR>
			$rowSepStr
			},
		qq{
			<TR VALIGN=TOP>
				$dSpacer @{[ join('', @bodyCols) ]}
			</TR>
		},
		$publFlags & PUBLFLAG_HIDETAIL ? '' : qq{
				$rowSepStr
				<TR VALIGN=TOP BGCOLOR=@{[ $publDefn->{tailBgColor} || 'DDEEEE' ]}>
					$tSpacer @{[ join('', @tailCols) ]}
				</TR>
		},
	);

	$publFlags |= PUBLFLAG_CHECKFORDATASEP if exists $publDefn->{separateDataColIdx};

	my $fmt =
	{
		flags => $publFlags,
		colCallbacks => \@colCallbacks,
		colValueCallbacks => \@colValueCallbacks,
		storeCols => \@storeCols,
		outColsCount => $outColsCount,
		rowSepStr => $rowSepStr,  # the normal row separator
		dataSepStr => $dataSepStr, # the separator to use when data has '-'
		dataSepCheckColIdx => $publFlags & PUBLFLAG_CHECKFORDATASEP ? $publDefn->{separateDataColIdx} : undef,
		levelIndentStr => '&nbsp;&nbsp;',
		bannerFmt => $bannerFmt,
		headRowFmt => $headRowFmt,
		bodyRowFmt => $bodyRowFmt,
		tailRowFmt => $tailRowFmt,
		noDataMsg => "<TR><TD COLSPAN=$outColsCount><I>$bodyFontOpen<FONT COLOR=RED>No records found.</FONT>$bodyFontClose</I></TD></TR>",
	};

	# now see if the report is overriding anything in $fmt
	while(my ($key, $value) = each %$publDefn)
	{
		next if $key =~ m/^(flags|rowSepStr)$/;
		$fmt->{$key} = $value if exists $publDefn->{$key};
	}

	# in case these were changed by the replacements above, copy them back
	($bannerFmt, $headRowFmt) = ($fmt->{bannerFmt}, $fmt->{headRowFmt});

	#
	# Similar code for BANNERS and FRAMES are duplicated in CGI::Layout as well (for performance)
	# so if any changes are made here, be sure to make the same changes there, too.
	#

	my ($wrapContentOpen, $wrapContentClose, $blockWidth, $dataWidth) = ('', '', '', '');
	if(my $frameInfo = $publDefn->{frame})
	{
		my ($frameFontOpen, $frameFontClose, $frameHeadHrefStyle) = ($frameInfo->{frameFontOpen} || '<FONT FACE="Arial,Helvetica" SIZE=2 COLOR=NAVY><B>', $frameInfo->{frameFontClose} || '</B></FONT>', $frameInfo->{frameHeadHrefStyle} || 'text-decoration:none; color: navy');
		my $frameSepRow = exists $frameInfo->{frameSepCellFmt} ? qq{
			<TR><TD COLSPAN=2>$frameInfo->{frameSepCellFmt}</TD></TR>
			} : '';
		my $bannerRow = $bannerFmt ? qq{
			<TR BGCOLOR=@{[$publDefn->{banner}->{contentColor} || 'lightyellow']}>
				<TD COLSPAN=2>$bannerFmt</TD>
			</TR>
			} : '';
		my $frameBtns = '';
		if(exists $frameInfo->{closeUrl})
		{
			$frameBtns = qq{<A HREF='$frameInfo->{closeUrl}'><IMG SRC='/resources/icons/action-done.gif' BORDER=0></A>} if exists $frameInfo->{closeUrl};
		}
		elsif(exists $frameInfo->{addUrl} && exists $frameInfo->{editUrl})
		{
			$frameBtns .= qq{<A HREF='$frameInfo->{addUrl}'><IMG SRC='/resources/icons/action-add.gif' BORDER=0></A> };
			$frameBtns .= qq{<A HREF='$frameInfo->{editUrl}'><IMG SRC='/resources/icons/action-edit.gif' BORDER=0></A>};
		}
		elsif(exists $frameInfo->{editUrl})
		{
			$frameBtns .= qq{<A HREF='$frameInfo->{editUrl}'><IMG SRC='/resources/icons/action-addedit.gif' BORDER=0></A>};
		}
		my $frameCaption = $frameInfo->{editUrl} ? "<A HREF='$frameInfo->{editUrl}' STYLE='$frameHeadHrefStyle'>$frameInfo->{heading}</A>" : $frameInfo->{heading};
		my $frameHead = $frameBtns ?
			qq{
				<TD>
					<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=100%>
						<TR>
							<TD>$frameFontOpen<NOBR>$frameCaption</NOBR>$frameFontClose</TD>
							<TD>$frameFontOpen&nbsp;&nbsp;$frameFontClose</TD>
							<TD ALIGN=RIGHT>$frameBtns</TD>
						</TR>
					</TABLE>
				</TD>
			} : qq{
				<TD>$frameFontOpen<NOBR>$frameInfo->{heading}</NOBR>$frameFontClose</TD>
			};
		($blockWidth, $dataWidth) = (exists $frameInfo->{width} ? "WIDTH='$frameInfo->{width}'" : '', exists $publDefn->{width} ? "WIDTH='$publDefn->{width}'" : '');
		($wrapContentOpen, $wrapContentClose) =
			(qq{
				<TABLE CELLSPACING=@{[ exists $frameInfo->{borderWidth} ? $frameInfo->{borderWidth} : 1]} CELLPADDING=2 BORDER=0 BGCOLOR=@{[$frameInfo->{borderColor} || '#EEEEEE']} $blockWidth>
					<TR BGCOLOR=@{[$frameInfo->{headColor} || $frameInfo->{borderColor} || '#EEEEEE']}>
					$frameHead
					</TR>
					$frameSepRow
					$bannerRow
					<TR BGCOLOR=@{[$frameInfo->{contentColor} || '#FFFFFF']}>
						<TD>
							<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0 $dataWidth>
								$headRowFmt
			}, qq{
						</TABLE>
					</TD>
				</TR>
			</TABLE>
			});
	}
	else
	{
		($blockWidth, $dataWidth) = (exists $publDefn->{blockWidth} ? "WIDTH='$publDefn->{blockWidth}'" : '', exists $publDefn->{width} ? "WIDTH='$publDefn->{width}'" : '');
		if($bannerFmt)
		{
			($wrapContentOpen, $wrapContentClose) =
				(qq{
					<TABLE CELLSPACING=0 CELLPADDING=2 BORDER=0 $blockWidth>
						<TR>
							<TD>
								$bannerFmt
							</TD>
						</TR>
						<TR BGCOLOR=@{[$frameInfo->{contentColor} || '#FFFFFF']}>
							<TD>
								<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0 $dataWidth>
									$headRowFmt
				}, qq{
								</TABLE>
							</TD>
						</TR>
					</TABLE>
				});
		}
		else
		{
			($wrapContentOpen, $wrapContentClose) =
				(qq{
					<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0 @{[ $dataWidth ? $dataWidth : $blockWidth ]}>
						$headRowFmt
				}, qq{
					</TABLE>
				});
		}
	}
	$fmt->{wrapContentOpen} = $wrapContentOpen;
	$fmt->{wrapContentClose} = $wrapContentClose;

	# replace any my.xxx vars with the local variables in _this_ method or fmtdefn.xxx with
	# variables from the publDefn->{xxx} hash
	#
	$fmt->{headRowFmt} =~ s/\#(fmt|fmtdefn)\.(.*?)\#/$1 eq 'fmt' ? eval("\$$2") : $publDefn->{$2}/ge;
	$fmt->{bodyRowFmt} =~ s/\#(fmt|fmtdefn)\.(.*?)\#/$1 eq 'fmt' ? eval("\$$2") : $publDefn->{$2}/ge;
	$fmt->{tailRowFmt} =~ s/\#(fmt|fmtdefn)\.(.*?)\#/$1 eq 'fmt' ? eval("\$$2") : $publDefn->{$2}/ge;
	$fmt->{wrapContentOpen} =~ s/\#(fmt|fmtdefn)\.(.*?)\#/$1 eq 'fmt' ? eval("\$$2") : $publDefn->{$2}/ge;
	$fmt->{wrapContentClose} =~ s/\#(fmt|fmtdefn)\.(.*?)\#/$1 eq 'fmt' ? eval("\$$2") : $publDefn->{$2}/ge;

	# see if any format has "PAGEVARS" like #session.xxx# or #param.yyy#
	# if there are some, then createHtmlFromStatement will be processing them
	foreach my $key (qw(wrapContentOpen bodyRowFmt tailRowFmt wrapContentClose))
	{
		if($fmt->{$key} =~ m/\#my\..*?#/)
		{
			$fmt->{flags} |= PUBLFLAG_REPLACEDEFNVARS;
			last;
		}
	}
	return $fmt;
}

#
# if any changes are made in createHtmlFromStatement, be sure to make the _exact_ changes in createHtmlFromData
#
sub createHtmlFromStatement
{
	my ($page, $flags, $stmtHdl, $publDefn, $publParams) = @_;

	my @outputRows = ();
	my $rowNum = 0;
	my $fmt = undef;
	my $publFlags = 0;
	eval
	{
		my $style = $publParams->{style} || undef;
		my $fmtCacheName = FMTTEMPLATE_CACHE_KEYNAME . ($style ? ('/' . $style) : '');
		unless($fmt = $publDefn->{$fmtCacheName})
		{
			$fmt = prepare_HtmlBlockFmtTemplate($page, $flags, $publDefn, $style);
			$publDefn->{$fmtCacheName} = $fmt if CACHE_DEFN_FMTTEMPLATE;
		}

		$publFlags = $fmt->{flags};
		my ($rowSepStr, $bodyRowFmt, $levIndentStr) = ($flags & PUBLFLAG_HIDEROWSEP ? '' : $fmt->{rowSepStr}, $fmt->{bodyRowFmt}, $fmt->{levelIndentStr});
		my ($dataSepStr, $dataSepColIdx) = ($fmt->{dataSepStr}, $fmt->{dataSepCheckColIdx});
		my $checkDataSep = $publFlags & PUBLFLAG_CHECKFORDATASEP;

		#
		# we're doing multiple loops for faster performance -- so, it may seem like code copying
		# but it's ok because we don't want to do unnecessary "if then else" processing _inside_ a loop
		# when we can do it _outside_ the loop
		#
		my ($outRow, $rowRef);
		if($publFlags & PUBLFLAG_HASCALLBACKS)
		{
			my $needStorage = $publFlags & PUBLFLAG_NEEDSTORAGE;
			my @colsToStore = @{$fmt->{storeCols}};
			my @colValuesStorage = ();
			my @colCallbacks = @{$fmt->{colCallbacks}};
			my @colValueCallbacks = @{$fmt->{colValueCallbacks}};

			my %callbacks =
				(
					'fmt_currency' => sub { my $value = $rowRef->[$_[0]]; my $fmt = defined $value ? FORMATTER->format_price($value, 2) : ''; defined $value && $value < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
					'fmt_stripLeadingPath' => sub { my $value = $rowRef->[$_[0]]; $value =~ s!^.*/!!; $value },
					'level_indent' => sub { my $level = $rowRef->[-1]; $level < 10 ? ($levIndentStr x $level) : '' },
					'count' => sub { $rowNum },
					'sum' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; $sum; },
					'sum_currency' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; my $fmt = FORMATTER->format_price($sum, 2); $sum < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
					'avg' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; $sum > 0 ? ($sum / scalar(@{$store})) : 0; },
					'avg_currency' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; my $avg = $sum > 0 ? ($sum / scalar(@{$store})) : 0; my $fmt = FORMATTER->format_price($avg, 2); $avg < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
				);
			$callbacks{'call'} = sub { my $activeCol = shift; &{$colCallbacks[$activeCol]}($rowRef, $activeCol, $colValuesStorage[$activeCol]); };
			$callbacks{'callifvaleq'} =	sub	{
					my $activeCol = shift;
					if(my $info = $colValueCallbacks[$activeCol]) {
						my $func = $info->{$rowRef->[$activeCol]} || $info->{_DEFAULT};
						if(ref $func eq 'CODE')	{
							&$func($rowRef, $activeCol, $colValuesStorage[$activeCol]);
						} else {
							$func = $func;
						}
					} else { "callifvaleq info for column $activeCol not found" };
				};
			$callbacks{'callifvaleqidx'} = sub {
					my $activeCol = shift;
					if(my $info = $colValueCallbacks[$activeCol]) {
						$info->[$rowRef->[$activeCol]];
					} else { "callifvaleq info for column $activeCol not found" };
				};
			$callbacks{'callifvalmatch'} = sub {
					my $activeCol = shift;
					if(my $info = $colValueCallbacks[$activeCol]) {
						my ($activeValue, $matched) = ($rowRef->[$activeCol], 0);
						while(my ($k, $func) = each %$info)
						{
							if($activeValue =~ m/$k/)
							{
								if(ref $func eq 'CODE')	{
									return &$func($rowRef, $activeCol, $colValuesStorage[$activeCol]);
								} else {
									return $func = $func;
								}
							};
						}
						return $info->{_DEFAULT};
					} else { "callifvalmatch info for column $activeCol not found" };
				};

			while($rowRef = $stmtHdl->fetch())
			{
				$rowNum++;
				if($checkDataSep && $rowRef->[$dataSepColIdx] eq '-')
				{
					push(@outputRows, $dataSepStr);
				}
				else
				{
					grep
					{
						push(@{$colValuesStorage[$_]}, $rowRef->[$_]);
					} @colsToStore if $needStorage;

					# find the default &{name:ddd} callbacks
					($outRow = $bodyRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
					$outRow =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
					push(@outputRows, $outRow, $rowSepStr);
				}
			}
			if($publFlags & PUBLFLAG_HASTAILROW)
			{
				($outRow = $fmt->{tailRowFmt}) =~ s/\&\{(\w+)\:([\-]?\d+)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
				push(@outputRows, $outRow);
			}
		}
		else
		{
			# only #xxx# formats (where xxx is a column number) are allowed
			if($checkDataSep)
			{
				while($rowRef = $stmtHdl->fetch())
				{
					$rowNum++;
					if($rowRef->[$dataSepColIdx] eq '-')
					{
						push(@outputRows, $dataSepStr);
					}
					else
					{
						($outRow = $bodyRowFmt) =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
						push(@outputRows, $outRow, $rowSepStr);
					}
				}
			}
			else
			{
				while($rowRef = $stmtHdl->fetch())
				{
					$rowNum++;
					($outRow = $bodyRowFmt) =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
					push(@outputRows, $outRow, $rowSepStr);
				}
			}
		}

		# don't end the output with a separator
		pop(@outputRows) if $checkDataSep && $outputRows[$#outputRows] eq $dataSepStr;
	};

	return $@ if $@;
	my $html = $fmt->{wrapContentOpen} . (join('', @outputRows) || $fmt->{noDataMsg}) . $fmt->{wrapContentClose};
	$html =~ s/\#my\.(.*?)\#/$publParams->{$1}/g if $publFlags & PUBLFLAG_REPLACEDEFNVARS;
	return $html;
}

#
# if any changes are made in createHtmlFromStatement, be sure to make the _exact_ changes in createHtmlFromStatement
#
sub createHtmlFromData
{
	my ($page, $flags, $data, $publDefn, $publParams) = @_;

	my @outputRows = ();
	my $rowNum = 0;
	my $fmt = undef;
	my $publFlags = 0;
	eval
	{
		my $style = $publParams->{style} || undef;
		my $fmtCacheName = FMTTEMPLATE_CACHE_KEYNAME . ($style ? ('/' . $style) : '');
		unless($fmt = $publDefn->{$fmtCacheName})
		{
			$fmt = prepare_HtmlBlockFmtTemplate($page, $flags, $publDefn, $style);
			$publDefn->{$fmtCacheName} = $fmt if CACHE_DEFN_FMTTEMPLATE;
		}

		$publFlags = $fmt->{flags};
		my ($rowSepStr, $bodyRowFmt, $levIndentStr) = ($flags & PUBLFLAG_HIDEROWSEP ? '' : $fmt->{rowSepStr}, $fmt->{bodyRowFmt}, $fmt->{levelIndentStr});
		my ($dataSepStr, $dataSepColIdx) = ($fmt->{dataSepStr}, $fmt->{dataSepCheckColIdx});
		my $checkDataSep = $publFlags & PUBLFLAG_CHECKFORDATASEP;

		#
		# we're doing multiple loops for faster performance -- so, it may seem like code copying
		# but it's ok because we don't want to do unnecessary "if then else" processing _inside_ a loop
		# when we can do it _outside_ the loop
		#
		my ($outRow, $rowRef);
		if($publFlags & PUBLFLAG_HASCALLBACKS)
		{
			my $needStorage = $publFlags & PUBLFLAG_NEEDSTORAGE;
			my @colsToStore = @{$fmt->{storeCols}};
			my @colValuesStorage = ();
			my @colCallbacks = @{$fmt->{colCallbacks}};
			my @colValueCallbacks = @{$fmt->{colValueCallbacks}};

			my %callbacks =
				(
					'fmt_currency' => sub { my $value = $rowRef->[$_[0]]; my $fmt = defined $value ? FORMATTER->format_price($value, 2) : ''; defined $value && $value < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
					'fmt_stripLeadingPath' => sub { my $value = $rowRef->[$_[0]]; $value =~ s!^.*/!!; $value },
					'level_indent' => sub { my $level = $rowRef->[-1]; $level < 10 ? ($levIndentStr x $level) : '' },
					'count' => sub { $rowNum },
					'sum' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; $sum; },
					'sum_currency' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; my $fmt = FORMATTER->format_price($sum, 2); $sum < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
					'avg' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; $sum / scalar(@{$store}); },
					'avg_currency' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; my $avg = $sum / scalar(@{$store}); my $fmt = FORMATTER->format_price($avg, 2); $avg < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
				);
			$callbacks{'call'} = sub { my $activeCol = shift; &{$colCallbacks[$activeCol]}($rowRef, $activeCol, $colValuesStorage[$activeCol]); };
			$callbacks{'callifvaleq'} =	sub	{
					my $activeCol = shift;
					if(my $info = $colValueCallbacks[$activeCol]) {
						my $func = $info->{$rowRef->[$activeCol]} || $info->{_DEFAULT};
						if(ref $func eq 'CODE')	{
							&$func($rowRef, $activeCol, $colValuesStorage[$activeCol]);
						} else {
							$func = $func;
						}
					} else { "callifvaleq info for column $activeCol not found" };
				};
			$callbacks{'callifvaleqidx'} = sub {
					my $activeCol = shift;
					if(my $info = $colValueCallbacks[$activeCol]) {
						$info->[$rowRef->[$activeCol]];
					} else { "callifvaleq info for column $activeCol not found" };
				};
			$callbacks{'callifvalmatch'} = sub {
					my $activeCol = shift;
					if(my $info = $colValueCallbacks[$activeCol]) {
						my ($activeValue, $matched) = ($rowRef->[$activeCol], 0);
						while(my ($k, $func) = each %$info)
						{
							if($activeValue =~ m/$k/)
							{
								if(ref $func eq 'CODE')	{
									return &$func($rowRef, $activeCol, $colValuesStorage[$activeCol]);
								} else {
									return $func = $func;
								}
							};
						}
						return $info->{_DEFAULT};
					} else { "callifvalmatch info for column $activeCol not found" };
				};

			#
			# a "for" loop was used instead of "foreach" because of a problem with closures (callbacks)
			# -- could never figure out the solution to the problem without _explicity_ assigned $rowRef
			#
			for($rowNum = 0; $rowNum <= $#$data; $rowNum++)
			{
				$rowRef = $data->[$rowNum];
				if($checkDataSep && $rowRef->[$dataSepColIdx] eq '-')
				{
					push(@outputRows, $dataSepStr);
				}
				else
				{
					grep
					{
						push(@{$colValuesStorage[$_]}, $rowRef->[$_]);
					} @colsToStore if $needStorage;

					# find the default &{name:ddd} callbacks
					($outRow = $bodyRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
					$outRow =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
					push(@outputRows, $outRow, $rowSepStr);
				}
			}
			if($publFlags & PUBLFLAG_HASTAILROW)
			{
				($outRow = $fmt->{tailRowFmt}) =~ s/\&\{(\w+)\:([\-]?\d+)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
				push(@outputRows, $outRow);
			}
		}
		else
		{
			# only #xxx# formats (where xxx is a column number) are allowed
			if($checkDataSep)
			{
				foreach $rowRef (@$data)
				{
					$rowNum++;
					if($rowRef->[$dataSepColIdx] eq '-')
					{
						push(@outputRows, $dataSepStr);
					}
					else
					{
						($outRow = $bodyRowFmt) =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
						push(@outputRows, $outRow, $rowSepStr);
					}
				}
			}
			else
			{
				foreach $rowRef (@$data)
				{
					$rowNum++;
					($outRow = $bodyRowFmt) =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
					push(@outputRows, $outRow, $rowSepStr);
				}
			}
		}

		# don't end the output with a separator
		pop(@outputRows) if $checkDataSep && $outputRows[$#outputRows] eq $dataSepStr;
	};

	return $@ if $@;

	my $html = $fmt->{wrapContentOpen} . (join('', @outputRows) || $fmt->{noDataMsg}) . $fmt->{wrapContentClose};
	$html =~ s/\#my\.(.*?)\#/$publParams->{$1}/g if $publFlags & PUBLFLAG_REPLACEDEFNVARS;
	return $html;
}

#-----------------------------------------------------------------------------
# The following functions/methods handle publishing of HTML form data
# like populating data into a combo box, list box, etc.
#-----------------------------------------------------------------------------

use enum qw(:FORMELEMTYPE_ TEXT SELECT);
use enum qw(:FORMELEM_FLAG_ OK);
use enum qw(:FORMELEMSEL_SRC_ STMTMGR SQLSTMT);
use enum qw(:FORMELEMSEL_FLAG_ OK);

%FORMELEM_STYLE =
(
	# dialogRow
	# simple
	#
);

#
# attributes for elemDefn:
#   caption
#   name
#     _f_<name> will be the name of the CGI parameter
#     _fs_<name> will be the page property that will check the field state flags (hidden, readonly, etc)
#   hint
#   type [one of FORMELEMTYPE_*]
#   select
#		options [bitmasked set of FORMELEMSEL_FLAG_*]
#		type  [checkbox, combobox, multicheck, radio, list, or multilist]
#		source [one of FORMELEMSELECTSRC_* or array reference]
#		bindColsRef
#	  	itemDelim -- HTML to add between each time
#		valueColIdx [default 0]
#		captionColIdx [default 1]
#		size [default 1]
#   options [bitmasked set of FORMELEM_FLAG_*]
#	cssStyle
#	fontOpen
#	fontClose
#   hint
#

sub prepareHtmlFormElemFormat
{
	my ($page, $flags, $elemDefn) = @_;


}

1;
