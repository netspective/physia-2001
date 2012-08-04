##############################################################################
package Data::Publish;
##############################################################################

use strict;
use Exporter;
use Number::Format;
use CGI::Layout;
use App::Configuration;
use Date::Manip;
use Storable qw(dclone);

use vars qw(@ISA @EXPORT %BLOCK_PUBLICATION_STYLE %FORMELEM_STYLE);
use enum qw(BITMASK:PUBLFLAG_ STDRECORDICONS HASCALLBACKS NEEDSTORAGE HASTAILROW REPLACEDEFNVARS CHECKFORDATASEP HIDEBANNER HIDEHEAD HIDETAIL HIDEROWSEP HIDESUBTOTAL HASSUBTOTAL TEXTCOLUMNIDS ADDDATAJS);
use enum qw(BITMASK:PUBLCOLFLAG_ DONTWRAP DONTWRAPHEAD DONTWRAPBODY DONTWRAPTAIL);

@ISA    = qw(Exporter);
@EXPORT = qw(
	PUBLFLAG_STDRECORDICONS
	PUBLFLAG_HIDEHEAD
	PUBLFLAG_HIDETAIL
	PUBLFLAG_HIDEROWSEP
	PUBLFLAG_HIDESUBTOTAL
	PUBLFLAG_TEXTCOLUMNIDS
	PUBLFLAG_ADDDATAJS
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
#			editUrl => './stpe-#my.stmtId#?home=/#param.arl#',
		},
	},

	'panel.indialog' =>
	{
		inherit => 'panel',
		frame =>
		{
#			editUrl => '../stpe-#my.stmtId#?home=/#param.arl#',
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
			frameHeadHrefStyle => 'text-decoration:none; color: yellow',
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
#			editUrl => './stpe-#my.stmtId#?home=/#param.arl#',
			width => '100%',
		},
	},

	'datanav' =>
	{
		flags => PUBLFLAG_TEXTCOLUMNIDS | PUBLFLAG_ADDDATAJS,
		headBgColor => '#EEEEEE',
		headFontOpen => '<FONT FACE="Arial,Helvetica" SIZE="2" COLOR="#000000">',
		frame => {
			headColor => '#CDD3DB',
			borderWidth => 1,
			borderColor => '#CDD3DB',
			contentColor => '#FFFFFF',
		},
	}
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



sub fmt_stamp
{
	my $page = shift;
	my $stamp = &ParseDate(shift);
	my $stampFormat = $page->session('FORMAT_STAMP') || '%b %e %I:%M %p';
	$stamp = Date_ConvTZ($stamp, 'GMT', $page->session('DAYLIGHT_TZ') );
	return &UnixDate($stamp, $stampFormat);
}


sub fmt_date
{
	my $page = shift;
	my $date = &ParseDate(shift);
	my $dateFormat = $page->session('FORMAT_DATE') || '%m/%d/%Y';
	return &UnixDate($date, $dateFormat);
}


sub fmt_time
{
	my $page = shift;
	my $time = &ParseDate(shift);
	my $timeFormat = $page->session('FORMAT_TIME') || '%r';
	$time = Date_ConvTZ($time, 'GMT', $page->session('DAYLIGHT_TZ') );
	return &UnixDate($time, $timeFormat);
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
	my ($subTotalFontOpen, $subTotalFontClose) = ($publDefn->{subTotalFontOpen} || '<FONT FACE="Verdana,Arial,Helvetica" SIZE=2 COLOR=NAVY><B>', $publDefn->{subTotalFontClose} || '</B></FONT>');

	my $columnDefn = $publDefn->{columnDefn};
	my $publFlags = exists $publDefn->{flags} ? $publDefn->{flags} : 0;
	my $outColsCount = (scalar(@$columnDefn) * 2) + 1; # because we create "spacer" columns, too

	my ($hSpacer, $dSpacer, $tSpacer,$sSpacer) =
		(	exists $publDefn->{hSpacer} ? $publDefn->{hSpacer} : "<TH>$headFontOpen&nbsp;&nbsp;$headFontClose</TH>",
			exists $publDefn->{dSpacer} ? $publDefn->{dSpacer} : "<TH>$bodyFontOpen&nbsp;&nbsp;$bodyFontClose</TH>",
			exists $publDefn->{tSpacer} ? $publDefn->{tSpacer} : "<TH>$tailFontOpen&nbsp;&nbsp;$tailFontClose</TH>",
			exists $publDefn->{sSpacer} ? $publDefn->{sSpacer} : "<TH>$subTotalFontOpen&nbsp;&nbsp;$subTotalFontClose</TH>",
		);
	my $imgPath = exists $publDefn->{imgPath} ? $publDefn->{imgPath} : "/resources";
	my $colCount = 0;
	my (@headCols, @bodyCols, @tailCols, @subTotalCols, @colCallbacks, @colValueCallbacks, @storeCols);

	foreach (@$columnDefn)
	{
		my $colOptions = $_->{options};
		my $colIdx = exists $_->{colIdx} ? $_->{colIdx} : $colCount;
		my ($hCellFmt, $dCellFmt, $tCellFmt,$sCellFmt) =
			(	exists $_->{hCellFmt} ? $_->{hCellFmt} : undef,
				exists $_->{dCellFmt} ? $_->{dCellFmt} : undef,
				exists $_->{tCellFmt} ? $_->{tCellFmt} : undef,
				exists $_->{sCellFmt} ? $_->{sCellFmt} : undef
				);

		unless(defined $hCellFmt)
		{
			my $hDataFmt = $_->{hDataFmt} || $_->{head};
			$hDataFmt = qq{<NOBR>$hDataFmt</NOBR>} if $colOptions & (PUBLCOLFLAG_DONTWRAP | PUBLCOLFLAG_DONTWRAPHEAD);
			$hCellFmt = qq{<TH ALIGN=@{[$_->{hAlign} || 'CENTER']} VALIGN=@{[$_->{hVAlign} || 'TOP']} @{[ $_->{hHint} ? "TITLE='$_->{hHint}'" : '' ]}>$headFontOpen$hDataFmt$headFontClose</TH>};
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
				$dataFmt = qq{<A HREF="$_->{url}" STYLE='text-decoration:none' @{[ $_->{hint} ? "TITLE='$_->{hint}'" : '' ]}>$dataFmt</A>};
			}
			elsif($_->{hint})
			{
				$dataFmt = "<SPAN TITLE='$_->{hint}'>$dataFmt</SPAN>";
			}
			$dataFmt = "<NOBR>$dataFmt</NOBR>" if $colOptions & (PUBLCOLFLAG_DONTWRAP | PUBLCOLFLAG_DONTWRAPBODY);
			$dCellFmt = "<TD ALIGN=@{[$dAlign || 'LEFT']} VALIGN=@{[$_->{dVAlign} || 'TOP']}>$bodyFontOpen$dataFmt$bodyFontClose</TD>";
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
				#Store column just in case doing a sum_ function on other column then colIdx (example '&{sum_currency:13} when colIdx = 11)
				$tDataFmt=~ /\:(\d+)/;
				push(@storeCols, $1) unless grep { $_ == $1 } @storeCols;
				$tDataFmt=~ /(\d+)\,(\d+)/;
				if($1 && $2)
				{
					push(@storeCols, $1) unless grep { $_ == $1 } @storeCols;
					push(@storeCols, $2) unless grep { $_ == $2 } @storeCols;
				};

			}
			$tDataFmt ||= '&nbsp;';
			$tDataFmt = "<NOBR>$tDataFmt</NOBR>" if $colOptions & (PUBLCOLFLAG_DONTWRAP | PUBLCOLFLAG_DONTWRAPTAIL);
			$tCellFmt = "<TD ALIGN=$tAlign VALIGN=@{[$_->{tVAlign} || 'TOP']}>$tailFontOpen$tDataFmt$tailFontClose</TD>";
		}

		#Sets up callbacks and cell format for subtotals
		unless (defined $sCellFmt)
		{

			my $sDataFmt = $_->{sDataFmt};
			my $sAlign = exists $_->{sAlign} ? $_->{sAlign} : undef;
			if(my $summarize = $_->{summarize})
			{
				my $cbackName = $_->{dformat} ? "$summarize\_$_->{dformat}" : $summarize;

				#Sub total callbacks have a differant name
				my $subCback=$cbackName."_sub_total";
				$sDataFmt = "&{$subCback:$colIdx}";
				$sAlign = 'RIGHT' unless defined $sAlign;
			}
			#Doing a group by on a summarized field is ignored
			elsif (my $groupBy =$_->{groupBy})
			{
				#Set sub total flag
				$sDataFmt =$groupBy;
				$publFlags |= PUBLFLAG_HASSUBTOTAL;
			}


			$sDataFmt ||= '&nbsp;';
			$sDataFmt = "<NOBR>$sDataFmt</NOBR>" if $colOptions & (PUBLCOLFLAG_DONTWRAP | PUBLCOLFLAG_DONTWRAPTAIL);
			$sCellFmt = "<TD ALIGN=$sAlign VALIGN=@{[$_->{sVAlign} || 'TOP']}>$subTotalFontOpen$sDataFmt$subTotalFontClose</TD>";
		}
		# replace &{?} with the current column's index and ## with a single pound (for recursive variables or simple # replacements)
		$hCellFmt =~ s/\&\{\?\}/$colIdx/g;
		$dCellFmt =~ s/\&\{\?\}/$colIdx/g;
		$tCellFmt =~ s/\&\{\?\}/$colIdx/g;
		$sCellFmt =~ s/\&\{\?\}/$colIdx/g;

		unless($publFlags & PUBLFLAG_HASCALLBACKS)
		{
			$publFlags |= PUBLFLAG_HASCALLBACKS if $hCellFmt =~ m/\&\{.*?\}/;
			$publFlags |= PUBLFLAG_HASCALLBACKS if $dCellFmt =~ m/\&\{.*?\}/;
			$publFlags |= PUBLFLAG_HASCALLBACKS if $tCellFmt =~ m/\&\{.*?\}/;
			$publFlags |= PUBLFLAG_HASCALLBACKS if $sCellFmt =~ m/\&\{.*?\}/;
		}

		push(@headCols, $hCellFmt, $hSpacer);
		push(@bodyCols, $dCellFmt, $dSpacer);
		push(@tailCols, $tCellFmt, $tSpacer);
		push(@subTotalCols, $sCellFmt, $sSpacer);

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
		if(ref $bullets eq 'HASH')
		{
			my $bulletIcons = { location => 'lead' };
			push(@$allIcons, $bulletIcons);

			push(@{$bulletIcons->{data}}, {
					imgSrc => exists $bullets->{imgSrc} ? $bullets->{imgSrc} : '/resources/icons/square-lgray-sm.gif',
					urlFmt => exists $bullets->{urlFmt} ? $bullets->{urlFmt} : (exists $publDefn->{stdIcons} ? (exists $publDefn->{stdIcons}->{updUrlFmt} ? $publDefn->{stdIcons}->{updUrlFmt} : undef) : undef),
					title => exists $bullets->{title} ? $bullets->{title} : 'Edit Record',
					});
		}
		elsif(ref $bullets eq 'ARRAY')
		{
			for (@{$bullets})
			{
				my $bulletIcons = { location => 'lead' };
				push(@$allIcons, $bulletIcons);

				if (ref $_ eq 'HASH')
				{
					push(@{$bulletIcons->{data}}, {
						imgSrc => exists $_->{imgSrc} ? $_->{imgSrc} : '/resources/icons/square-lgray-sm.gif',
						urlFmt => exists $_->{urlFmt} ? $_->{urlFmt} : (exists $publDefn->{stdIcons} ? (exists $publDefn->{stdIcons}->{updUrlFmt} ? $publDefn->{stdIcons}->{updUrlFmt} : undef) : undef),
						title => exists $_->{title} ? $_->{title} : 'Edit Record',
					});
				}
				else
				{
					push(@{$bulletIcons->{data}}, {
						urlFmt => $_, imgSrc => '/resources/icons/square-lgray-hat-sm.gif', title => 'Edit Record',
					});
				}
			}
		}
		else
		{
			my $bulletIcons = { location => 'lead' };
			push(@$allIcons, $bulletIcons);

			if($bullets =~ m/^1$/)
			{
				push(@{$bulletIcons->{data}}, { imgSrc => '/resources/icons/square-lgray-sm.gif', title => 'Edit Record' });
			}
			else
			{
				push(@{$bulletIcons->{data}}, { urlFmt => $bullets, imgSrc => '/resources/icons/square-lgray-hat-sm.gif', title => 'Edit Record' });
			}
		}
	}

	foreach my $icons (@$allIcons)
	{
		my $location = $icons->{location} || 'lead';
		my $hcontrol = '';
		foreach (@{$icons->{head}})
		{
			$hcontrol .= qq{<A HREF="$_->{urlFmt}" TITLE="$_->{title}">} if $_->{urlFmt};
			$hcontrol .= qq{<IMG SRC="$_->{imgSrc}" BORDER=0>};
			$hcontrol .= qq{</A>} if $_->{urlFmt};;
			$hcontrol .= ' ';
		}
		my $dcontrol = '';
		foreach (@{$icons->{data}})
		{
			$dcontrol .= qq{<A HREF="$_->{urlFmt}" TITLE="$_->{title}">} if $_->{urlFmt};
			$dcontrol .= qq{<IMG SRC="$_->{imgSrc}" BORDER=0>};
			$dcontrol .= qq{</A>} if $_->{urlFmt};
			$dcontrol .= ' ';
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
		my @attrsHtml = ();
		my $location = $select->{location} || 'lead';

		my $type = $select->{type} || 'checkbox';
		push @attrsHtml, qq{type="$type"};

		my $attrs = defined $select->{attrs} && ref($select->{attrs}) eq 'HASH' ? $select->{attrs} : {};
		push @attrsHtml, map {$_ . '="' . $attrs->{$_} . '"'} keys %$attrs;

		push @attrsHtml, qq{name="$select->{name}"} if defined $select->{name};

		my $valueFmt = $select->{valueFmt} || '#0#';
		push @attrsHtml, qq{value="$valueFmt"};

		my $control = '<input ' . join(' ', @attrsHtml) . '>';

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
	my $groupBySepStr = exists $publDefn->{groupBySepStr} ? $publDefn->{groupBySepStr} : "";
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

	my $bodyRowAttr =
		join ' ',
			map {$_ . '="' . $publDefn->{bodyRowAttr}->{$_} . '"'}
				keys %{$publDefn->{bodyRowAttr}}
					if defined $publDefn->{bodyRowAttr};

	my ($headRowFmt, $bodyRowFmt, $tailRowFmt,$subTotalRowFmt) =
	(
		$publFlags & PUBLFLAG_HIDEHEAD ? '<TBODY>' : qq{
			<THEAD>
			<TR VALIGN=TOP BGCOLOR=@{[ $publDefn->{headBgColor} || 'EEEEDD' ]}>
				$hSpacer @{[ join('', @headCols) ]}
			</TR>
			$rowSepStr
			</THEAD>
			<TBODY>
			},
		qq{
			<TR VALIGN=TOP $bodyRowAttr>
				$dSpacer @{[ join('', @bodyCols) ]}
			</TR>
		},
		$publFlags & PUBLFLAG_HIDETAIL ? '</TBODY>' : qq{
				</TBODY>
				<TFOOT>
				$rowSepStr
				<TR VALIGN=TOP BGCOLOR=@{[ $publDefn->{tailBgColor} || 'DDEEEE' ]}>
					$tSpacer @{[ join('', @tailCols) ]}
				</TR>
				</TFOOT>
		},
		$publFlags & PUBLFLAG_HIDESUBTOTAL ? '' : qq{
				$rowSepStr
				<TR VALIGN=TOP BGCOLOR=@{[ $publDefn->{tailBgColor} || 'DCDCDC ' ]}>
					$sSpacer @{[ join('', @subTotalCols) ]}
				</TR>
				$groupBySepStr

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
		subTotalRowFmt => $subTotalRowFmt,
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
			$frameBtns = qq{<A HREF="$frameInfo->{closeUrl}"><IMG SRC="/resources/icons/action-done.gif" BORDER=0></A>} if exists $frameInfo->{closeUrl};
		}
		elsif(exists $frameInfo->{addUrl} && exists $frameInfo->{editUrl})
		{
			$frameBtns .= qq{<A HREF="$frameInfo->{addUrl}"><IMG SRC="/resources/icons/action-add.gif" BORDER=0></A> };
			$frameBtns .= qq{<A HREF="$frameInfo->{editUrl}"><IMG SRC="/resources/icons/action-edit.gif" BORDER=0></A>};
		}
		elsif(exists $frameInfo->{editUrl})
		{
			$frameBtns .= qq{<A HREF="$frameInfo->{editUrl}"><IMG SRC="/resources/icons/action-addedit.gif" BORDER=0></A>};
		}
		my $frameCaption = $frameInfo->{editUrl} ? qq{<A HREF="$frameInfo->{editUrl}" STYLE="$frameHeadHrefStyle">$frameInfo->{heading}</A>} : $frameInfo->{heading};
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

	my $initArrayJS = '';  # Used for PUBLFLAG_ADDDATAJS

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
		my ($rowSepStr, $bodyRowFmt, $levIndentStr,$subTotalRowFmt) = ($flags & PUBLFLAG_HIDEROWSEP ? '' : $fmt->{rowSepStr}, $fmt->{bodyRowFmt}, $fmt->{levelIndentStr},$fmt->{subTotalRowFmt});
		my ($dataSepStr, $dataSepColIdx) = ($fmt->{dataSepStr}, $fmt->{dataSepCheckColIdx});
		my $checkDataSep = $publFlags & PUBLFLAG_CHECKFORDATASEP;

		# See if they want to store the row data as a javascript array of hashes
		my $rowDataJS = '';
		if ($publFlags & PUBLFLAG_ADDDATAJS)
		{
			# Create an array variable init string to put at the top of the results
			my $dataArrayName = defined $publDefn->{name} ? $publDefn->{name} : int(rand 99999);
			$dataArrayName = "publish_${dataArrayName}_rows";
			$initArrayJS = "<script>$dataArrayName = new Array();</script>";

			# Create the necessary JS code to add each rows data to the array
			$rowDataJS = join ',', map {"'$_' : '#{$_}#'"} @{$stmtHdl->{NAME_lc}};
			$rowDataJS = '<script>' . $dataArrayName . "[#rowNum#] = { $rowDataJS };</script>";

			$publFlags |= PUBLFLAG_HASCALLBACKS;
		}

		# If they want to use column names then we need a cross reference hash
		my %colNames = ();
		if ($publFlags & PUBLFLAG_TEXTCOLUMNIDS)
		{
			my $i = 0;
			foreach (@{$stmtHdl->{NAME_lc}})
			{
				$colNames{$_} = $i++;
			}
			$bodyRowFmt =~ s/\#\{(\w+)\}\#/\#$colNames{$1}\#/g;
			$subTotalRowFmt =~ s/\#\{(\w+)\}\#/\#$colNames{$1}\#/g;

			# Strip special characters from field to make it safe to use as JS data
			$rowDataJS =~ s/\#\{(\w+)\}\#/\&\{js_safe:$colNames{$1}\}/g;
		}

		# Add the row JS to the body row format
		$bodyRowFmt .= $rowDataJS;

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
			my @colSubStorage = ();
			my @colCallbacks = @{$fmt->{colCallbacks}};
			my @colValueCallbacks = @{$fmt->{colValueCallbacks}};

			my %callbacks =
				(
					'fmt_currency' => sub { my $value = $rowRef->[$_[0]]; my $fmt = defined $value ? FORMATTER->format_price($value, 2) : ''; defined $value && $value < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
					'fmt_stripLeadingPath' => sub { my $value = $rowRef->[$_[0]]; $value =~ s!^.*/!!; $value },
					'fmt_stamp' => sub
					{
						my $stamp = &ParseDate($rowRef->[$_[0]]);
						my $stampFormat = $page->session('FORMAT_STAMP') || '%b %e %I:%M %p';
						$stamp = Date_ConvTZ($stamp, 'GMT', $page->session('DAYLIGHT_TZ') );
						return &UnixDate($stamp, $stampFormat);
					},
					'fmt_date' => sub
					{
						my $date = &ParseDate($rowRef->[$_[0]]);
						my $dateFormat = $page->session('FORMAT_DATE') || '%m/%d/%Y';
						return &UnixDate($date, $dateFormat);
					},
					'fmt_time' => sub
					{
						my $time = &ParseDate($rowRef->[$_[0]]);
						my $timeFormat = $page->session('FORMAT_TIME') || '%r';
						$time = Date_ConvTZ($time, 'GMT', $page->session('DAYLIGHT_TZ') );
						return &UnixDate($time, $timeFormat);
					},
					'level_indent' => sub { my $level = $rowRef->[-1]; $level < 10 ? ($levIndentStr x $level) : '' },
					'count' => sub { $rowNum },
					'sum' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; $sum; },
					'sum_currency' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; my $fmt = FORMATTER->format_price($sum, 2); $sum < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
					'avg' => sub
					{
						my $store = $colValuesStorage[$_[0]];
						my $sum = 0;
						grep { $sum += $_ } @{$store};
						$sum > 0 ? ($sum / scalar(@{$store})) : 0;
					},
					'avg_currency' => sub
					{
						my $store = $colValuesStorage[$_[0]];
						my $sum = 0;
						grep { $sum += $_ } @{$store};
						my $avg = scalar(@{$store}) > 0 ? ($sum / scalar(@{$store})) : 0;
						my $fmt = FORMATTER->format_price($avg, 2);
						$avg < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt
					},
					'sum_sub_total' => sub { my $store = $colSubStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; $sum; },
					'sum_currency_sub_total' => sub { my $store = $colSubStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; my $fmt = FORMATTER->format_price($sum, 2); $sum < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
					'avg_sub_total' => sub
					{
						my $store = $colSubStorage[$_[0]];
						my $sum = 0;
						grep { $sum += $_ } @{$store};
						scalar(@{$store}) > 0 ? ($sum / scalar(@{$store})) : 0;
					},
					'avg_currency_sub_total' => sub
					{
						my $store = $colSubStorage[$_[0]];
						my $sum = 0; grep { $sum += $_ } @{$store};
						my $avg = scalar(@{$store}) > 0 ? ($sum / scalar(@{$store})) : 0;
						my $fmt = FORMATTER->format_price($avg, 2);
						$avg < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt
					},
					'sum_percent' => sub
					{
						my @position = split (',',$_[0]);
						my $numerator = $position[0];
						my $denominator = $position[1];
						my $sum_numerator = 0;
						my $sum_denominator = 0;
						my $store_numerator =$colValuesStorage[$numerator];
						my $store_denominator =$colValuesStorage[$denominator];
						grep {$sum_numerator+=$_}@{$store_numerator};
						grep {$sum_denominator+=$_}@{$store_denominator};
						$sum_denominator >0 ? sprintf "%3.2f" , (($sum_numerator / $sum_denominator) * 100) : '0.00';
					},
					'js_safe' => sub
					{
						my $data = $rowRef->[$_[0]];
						$data =~ s/\'/\\\'/g;
						$data =~ s/\r//g;
						$data =~ s/\n//g;
						return $data;
					},

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
			if ($publFlags & PUBLFLAG_HASSUBTOTAL)
			{
				my $groupByTextPrev=undef;
				my $groupByTextCur=undef;
				my $data_row = 0;
				my $outSubTotalRow;
				my $data;
				while($rowRef = $stmtHdl->fetch())
				{
					$rowNum++;
					if($checkDataSep && $rowRef->[$dataSepColIdx] eq '-')
					{
						push(@outputRows, $dataSepStr);
					}
					else
					{


						#Set up subtotal cur data
						($groupByTextCur = $subTotalRowFmt)=~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
						$groupByTextPrev=$groupByTextCur unless defined $groupByTextPrev;
						if ($groupByTextCur ne $groupByTextPrev)
						{
							($outSubTotalRow = $subTotalRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
							my $subRow=$data;
							$outSubTotalRow=~ s/\#([\-]?\d+)\#/$subRow->[$1]/g;
							push(@outputRows,$outSubTotalRow);
							$groupByTextPrev=$groupByTextCur;
							@colSubStorage = ();

						}
						@$data=@$rowRef;
						grep
						{
							push(@{$colSubStorage[$_]},$rowRef->[$_]);
						} @colsToStore if $needStorage;

						grep
						{
							push(@{$colValuesStorage[$_]}, $rowRef->[$_]);
						} @colsToStore if $needStorage;

						# find the default &{name:ddd} callbacks
						($outRow = $bodyRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
						$outRow =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
						$outRow =~ s/\#rowNum#/$rowNum/g;
						push(@outputRows, $outRow, $rowSepStr);
					}
					last if defined $publParams->{maxRows} && $rowNum == $publParams->{maxRows};
				}
				($outSubTotalRow = $subTotalRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
				my $subRow=$data;
				$outSubTotalRow =~ s/\#([\-]?\d+)\#/$subRow->[$1]/g;
				push(@outputRows,$outSubTotalRow);
				if($publFlags & PUBLFLAG_HASTAILROW)
				{
					$outRow = $fmt->{tailRowFmt};
					$outRow =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;

					push(@outputRows, $outRow);
				}
				else
				{
					$outRow = '</TBODY>';
					push(@outputRows, $outRow);
				}
			}
			else
			{

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
						($outRow = $bodyRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
						$outRow =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
						$outRow =~ s/\#rowNum#/$rowNum/g;
						push(@outputRows, $outRow, $rowSepStr);
					}
					last if defined $publParams->{maxRows} && $rowNum == $publParams->{maxRows};
				}
				if($publFlags & PUBLFLAG_HASTAILROW)
				{
					$outRow = $fmt->{tailRowFmt};
					$outRow =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
					push(@outputRows, $outRow);
				}
				else
				{
					$outRow = '</TBODY>';
					push(@outputRows, $outRow);
				}
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
						$outRow =~ s/\#rowNum#/$rowNum/g;
						push(@outputRows, $outRow, $rowSepStr);
					}
					last if defined $publParams->{maxRows} && $rowNum == $publParams->{maxRows};
				}
			}
			else
			{

				while($rowRef = $stmtHdl->fetch())
				{
					$rowNum++;
					($outRow = $bodyRowFmt) =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
					$outRow =~ s/\#rowNum#/$rowNum/g;
					push(@outputRows, $outRow, $rowSepStr);
					last if defined $publParams->{maxRows} && $rowNum == $publParams->{maxRows};
				}
			}
		}

		# don't end the output with a separator
		pop(@outputRows) if $checkDataSep && $outputRows[$#outputRows] eq $dataSepStr;
	};

	unless (defined $publParams->{maxRows} && $rowNum == $publParams->{maxRows})
	{
		$stmtHdl->finish();
		undef $stmtHdl;
	}
	return $@ if $@;
	my $html = $fmt->{wrapContentOpen} . $initArrayJS . (join('', @outputRows) || $fmt->{noDataMsg}) . $fmt->{wrapContentClose};
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
		my ($rowSepStr, $bodyRowFmt, $levIndentStr,$subTotalRowFmt) = ($flags & PUBLFLAG_HIDEROWSEP ? '' : $fmt->{rowSepStr}, $fmt->{bodyRowFmt}, $fmt->{levelIndentStr},$fmt->{subTotalRowFmt});
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
			my @colSubStorage = ();
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
					'avg' => sub
					{
						my $store = $colValuesStorage[$_[0]];
						my $sum = 0;
						grep { $sum += $_ } @{$store};
						scalar(@{$store}) > 0 ? ($sum / scalar(@{$store})) : 0;
					},
					'avg_currency' => sub
					{
						my $store = $colValuesStorage[$_[0]];
						my $sum = 0; grep { $sum += $_ } @{$store};
						my $avg = scalar(@{$store}) > 0 ? ($sum / scalar(@{$store})) : 0;
						my $fmt = FORMATTER->format_price($avg, 2);
						$avg < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt
					},

					'sum_sub_total' => sub { my $store = $colSubStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; $sum; },
					'sum_currency_sub_total' => sub { my $store = $colSubStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; my $fmt = FORMATTER->format_price($sum, 2); $sum < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
					'avg_sub_total' => sub
					{
						my $store = $colSubStorage[$_[0]];
						my $sum = 0;
						grep { $sum += $_ } @{$store};
						scalar(@{$store}) > 0 ? ($sum / scalar(@{$store})) : 0;
					},
					'avg_currency_sub_total' => sub
					{
						my $store = $colSubStorage[$_[0]];
						my $sum = 0; grep { $sum += $_ } @{$store};
						my $avg = scalar(@{$store}) > 0 ? ($sum / scalar(@{$store})) : 0;
						my $fmt = FORMATTER->format_price($avg, 2);
						$avg < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt
					},
					'sum_percent' => sub
					{
						my @position = split (',',$_[0]);
						my $numerator = $position[0];
						my $denominator = $position[1];
						my $sum_numerator = 0;
						my $sum_denominator = 0;
						my $store_numerator =$colValuesStorage[$numerator];
						my $store_denominator =$colValuesStorage[$denominator];
						grep {$sum_numerator+=$_}@{$store_numerator};
						grep {$sum_denominator+=$_}@{$store_denominator};
						$sum_denominator >0 ? sprintf "%3.2f" , (($sum_numerator / $sum_denominator) * 100) : '0.00';
					}

					#'avg' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; $sum / scalar(@{$store}); },
					#'avg_currency' => sub { my $store = $colValuesStorage[$_[0]]; my $sum = 0; grep { $sum += $_ } @{$store}; my $avg = $sum / scalar(@{$store}); my $fmt = FORMATTER->format_price($avg, 2); $avg < 0 ? "<FONT COLOR=RED>$fmt</FONT>" : $fmt },
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

			#Check if sub total are needed
			#Move if/else outside of loops for performance
			if ($publFlags & PUBLFLAG_HASSUBTOTAL)
			{
				my $groupByTextPrev=undef;
				my $groupByTextCur=undef;
				my $data_row = 0;
				my $outSubTotalRow;
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

						#Set up subtotal cur data
						($groupByTextCur = $subTotalRowFmt)=~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
						$groupByTextPrev=$groupByTextCur unless defined $groupByTextPrev;

						if ($groupByTextCur ne $groupByTextPrev)
						{
							($outSubTotalRow = $subTotalRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
							my $subRow=$data->[$data_row];
							$outSubTotalRow=~ s/\#([\-]?\d+)\#/$subRow->[$1]/g;
							push(@outputRows,$outSubTotalRow);
							$data_row = $rowNum;
							$groupByTextPrev=$groupByTextCur;
							@colSubStorage = ();
						}

						grep
						{
							push(@{$colSubStorage[$_]},$rowRef->[$_]);
						} @colsToStore if $needStorage;

						grep
						{
							push(@{$colValuesStorage[$_]}, $rowRef->[$_]);
						} @colsToStore if $needStorage;

						# find the default &{name:ddd} callbacks
						($outRow = $bodyRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
						$outRow =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
						push(@outputRows, $outRow, $rowSepStr);

					}
					last if defined $publParams->{maxRows} && $rowNum == $publParams->{maxRows};
				}

				($outSubTotalRow = $subTotalRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
				my $subRow=$data->[$data_row];
				$outSubTotalRow=~ s/\#([\-]?\d+)\#/$subRow->[$1]/g;
				push(@outputRows,$outSubTotalRow);
				if($publFlags & PUBLFLAG_HASTAILROW)
				{
					($outRow = $fmt->{tailRowFmt}) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' not found in \%callbacks"/ge;
					push(@outputRows, $outRow);
				}
				else
				{
					$outRow = '</TBODY>';
					push(@outputRows, $outRow);
				}
			}
			else
			{
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
						($outRow = $bodyRowFmt) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1'  not found in \%callbacks"/ge;
						$outRow =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
						push(@outputRows, $outRow, $rowSepStr);
					}
					last if defined $publParams->{maxRows} && $rowNum == $publParams->{maxRows};
				}
				if($publFlags & PUBLFLAG_HASTAILROW)
				{
					($outRow = $fmt->{tailRowFmt}) =~ s/\&\{(\w+)\:([\-]?\d+(\,\d+)?)\}/exists $callbacks{$1} ? &{$callbacks{$1}}($2) : "Callback '$1' value '$2' not found in \%callbacks"/ge;
					push(@outputRows, $outRow);
				}
				else
				{
					$outRow = '</TBODY>';
					push(@outputRows, $outRow);
				}
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
					last if defined $publParams->{maxRows} && $rowNum == $publParams->{maxRows};
				}
			}
			else
			{
				foreach $rowRef (@$data)
				{
					$rowNum++;
					($outRow = $bodyRowFmt) =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
					push(@outputRows, $outRow, $rowSepStr);
					last if defined $publParams->{maxRows} && $rowNum == $publParams->{maxRows};
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
