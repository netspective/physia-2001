##############################################################################
package CGI::Layout;
##############################################################################

use strict;
use Exporter;
use Storable qw(dclone);

use vars qw(@ISA @EXPORT $LAYOUT_MANAGER %LAYOUT_STYLE);
use enum qw(BITMASK:LAYOUTFLAG_ HASCALLBACKS REPLACEDEFNVARS REPLACECONTENT);

use constant FMTTEMPLATE_CACHE_KEYNAME => '_tmplCache';

@ISA    = qw(Exporter);
@EXPORT = qw(
	inheritHashValues
	createLayout_html
	);

sub inheritHashValues
{
	my ($destRef, $srcRef) = @_;

	while(my ($key, $value) = each %$srcRef)
	{
		my $skipKey = '-' . $key;
		if(exists $destRef->{$skipKey})
		{
			delete $destRef->{$skipKey};
			next;
		}
		if(ref $value eq 'HASH')
		{
			$destRef->{$key} = {} unless exists $destRef->{$key};
			inheritHashValues($destRef->{$key}, $srcRef->{$key});
		}
		elsif(! exists $destRef->{$key})
		{
			$destRef->{$key} = $value;
		}
	}
}

%LAYOUT_STYLE =
(
	'transparent' =>
	{
		# this the "default" style so we don't override anything
	},

	'panel' =>
	{
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
		},
	},

	'panel.edit' =>
	{
		inherit => 'panel',
		banner =>
		{
			contentColor => '#FFE0E0',
		},
		frame =>
		{
			frameFontOpen => '<FONT FACE="Arial,Helvetica" SIZE=2 COLOR=YELLOW><B>',
			headColor => 'darkred',
			borderColor => 'red',
		},
	},

	'panel.transparent' =>
	{
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
			frameSepCellFmt => "<IMG SRC='/images/background/bar.gif' WIDTH=100% HEIGHT=1>",
		},
	},
);

while(my ($style, $styleInfo) = each %LAYOUT_STYLE)
{
	if(my $inherit = $styleInfo->{inherit})
	{
		foreach(split(/\s*,\s*/, $inherit))
		{
			if(my $inhStyleInfo = $LAYOUT_STYLE{$_})
			{
				inheritHashValues($styleInfo, $inhStyleInfo);
			}
		}
	}
}

sub appendBlockContent
{
	my ($page, $callbacks, $htmlFmt, $layoutDefn, $layoutFlags, $content) = @_;

	my $objectClass = $layoutDefn->{contentClassName} || 'App::Pane';
	my $itemSeparator = $layoutDefn->{contentItemSeparator} || '<BR>';
	if(my $itemType = ref $content)
	{
		if($itemType eq 'ARRAY')
		{
			foreach (@$content)
			{
				if(my $subItemType = ref $_)
				{
					if($subItemType eq 'CODE' || $_->isa($objectClass))
					{
						push(@$callbacks, $_);
						my $index = scalar(@$callbacks)-1;
						push(@$htmlFmt, "#$index#", $itemSeparator);
					}
				}
				else
				{
					push(@$htmlFmt, $_);
				}
			}
		}
		elsif($itemType eq 'CODE' || $content->isa($objectClass))
		{
			push(@$callbacks, $content);
			my $index = scalar(@$callbacks)-1;
			push(@$htmlFmt, "#$index#", $itemSeparator);
		}
	}
	else
	{
		push(@$htmlFmt, $content);
	}
}

sub prepareBlockFormat
{
	my ($page, $callbacks, $htmlFmt, $layoutDefn, $layoutFlags, $layoutArea) = @_;

	my $tableWidth = 'WIDTH=100%';
	my $colSpacing = 3;
	if(ref $layoutArea eq 'HASH')
	{
		$tableWidth = "WIDTH=$layoutArea->{width}" if exists $layoutArea->{width};
		$colSpacing = $layoutArea->{colSpacing} if exists $layoutArea->{colSpacing};
	}
	my ($defaultFontOpen, $defaultFontClose) = ($layoutDefn->{defaultFontOpen} || '<FONT FACE=Arial,Helvetica SIZE=2>', $layoutDefn->{defaultFontClose} || '</FONT>');

	push(@$htmlFmt,
		qq{
			<TABLE $tableWidth BORDER=0 CELLSPACING=0 CELLPADDING=$colSpacing>
			<TR VALIGN=TOP>
			<TD>
			$defaultFontOpen
		});

	my $content = undef;
	if(ref($layoutArea) eq 'HASH')
	{
		$content = $layoutArea->{content};
	}
	else
	{
		$content = $layoutArea;
	}

	if(ref($content) eq 'ARRAY')
	{
		my $colsCount = scalar(@$content);
		my $colWidth = $colsCount > 0 ? int(100 / $colsCount) : 100;
		push(@$htmlFmt,
			qq{
				<TABLE WIDTH=100% BORDER=0 CELLSPACING=0 CELLPADDING=2>
				<TR VALIGN=TOP>
			});
		foreach(@$content)
		{
			push(@$htmlFmt, "<TD WIDTH='$colWidth\%'>$defaultFontOpen");
			appendBlockContent($page, $callbacks, $htmlFmt, $layoutDefn, $layoutFlags, $_);
			push(@$htmlFmt, "$defaultFontClose</TD>");
		}
		push(@$htmlFmt,
			qq{
				</TR>
				</TABLE>
			});
	}
	else
	{
		appendBlockContent($page, $callbacks, $htmlFmt, $layoutDefn, $layoutFlags, $content);
	}

	push(@$htmlFmt,
		qq{
			$defaultFontClose
			</TD>
			</TR>
			</TABLE>
		});
}

sub prepareHtmlFormat
{
	my ($page, $flags, $layoutDefn, $style) = @_;

	if(my $style = $LAYOUT_STYLE{$style || $layoutDefn->{style}})
	{
		$layoutDefn = dclone($layoutDefn);
		inheritHashValues($layoutDefn, $style);
	}

	my $layoutFlags = $layoutDefn->{options};
	my @callbacks = ();
	my @contentFmt = ();

	if(ref $layoutDefn->{blocks} eq 'ARRAY')
	{
		foreach my $block (@{$layoutDefn->{blocks}})
		{
			prepareBlockFormat($page, \@callbacks, \@contentFmt, $layoutDefn, \$layoutFlags, $block);
		}
	}
	else
	{
		push(@contentFmt, $layoutDefn->{blocks});
	}

	$layoutFlags |= LAYOUTFLAG_HASCALLBACKS if @callbacks;

	#
	# Similar code FOR BANNERS and FRAMES are duplicated in Data::Publish as well (for performance)
	# so if any changes are made here, be sure to make the same changes there, too.
	#

	my $bannerFmt = '';
	if(my $bannerInfo = $layoutDefn->{banner})
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
				my $icon = $_->{icon} || '/images/icons/edit_add.gif';
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
	}

	my $formAction = exists $layoutDefn->{formAction} ? $layoutDefn->{formAction} : undef;
	my ($wrapContentOpen, $wrapContentClose) = ('', '');
	my ($defaultFontOpen, $defaultFontClose) = ($layoutDefn->{defaultFontOpen} || '<FONT FACE=Arial,Helvetica SIZE=2>', $layoutDefn->{defaultFontClose} || '</FONT>');
	if(my $frameInfo = $layoutDefn->{frame})
	{
		my ($frameFontOpen, $frameFontClose) = ($frameInfo->{frameFontOpen} || '<FONT FACE="Arial,Helvetica" SIZE=2 COLOR=NAVY><B>', $frameInfo->{frameFontClose} || '</B></FONT>');
		my $frameSepRow = exists $frameInfo->{frameSepCellFmt} ? qq{
			<TR><TD COLSPAN=2>$frameInfo->{frameSepCellFmt}</TD></TR>
			} : '';
		my $bannerRow = $bannerFmt ? qq{
			<TR BGCOLOR=@{[$layoutDefn->{banner}->{contentColor} || 'lightyellow']}>
				<TD COLSPAN=2>$bannerFmt</TD>
			</TR>
			} : '';
		($wrapContentOpen, $wrapContentClose) =
			(qq{
				<TABLE CELLSPACING=@{[ exists $frameInfo->{borderWidth} ? $frameInfo->{borderWidth} : 1]} CELLPADDING=2 BORDER=0 BGCOLOR=@{[$frameInfo->{borderColor} || '#EEEEEE']} @{[ $layoutDefn->{width} ? "WIDTH=$layoutDefn->{width}" : '100%' ]}>
					@{[ $formAction ? '<FORM ACTION="$formAction" METHOD="POST">' : '']}
					<TR BGCOLOR=@{[$frameInfo->{headColor} || $frameInfo->{borderColor} || '#EEEEEE']}>
						<TD>$frameFontOpen<NOBR>$frameInfo->{heading}</NOBR>$frameFontClose</TD>
					</TR>
					$frameSepRow
					$bannerRow
					<TR BGCOLOR=@{[$frameInfo->{contentColor} || '#FFFFFF']}>
						<TD COLSPAN=2>
							<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0>
							<TR VALIGN=TOP><TD>
							$defaultFontOpen
			}, qq{
							$defaultFontClose
							<TD></TR>
							</TABLE>
						</TD>
					</TR>
					@{[ $formAction ? '</FORM>' : '']}
				</TABLE>
			});
	}
	else
	{
		if($bannerFmt)
		{
			($wrapContentOpen, $wrapContentClose) =
				(qq{
					<TABLE CELLSPACING=0 CELLPADDING=2 BORDER=0 @{[ $layoutDefn->{width} ? "WIDTH=$layoutDefn->{width}" : '100%' ]}>
						@{[ $formAction ? '<FORM ACTION="$formAction" METHOD="POST">' : '']}
						<TR>
							<TD>
								$bannerFmt
							</TD>
						</TR>
						<TR BGCOLOR=@{[$frameInfo->{contentColor} || '#FFFFFF']}>
							<TD>
								<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0>
								<TR VALIGN=TOP><TD>
								$defaultFontOpen
				}, qq{
								$defaultFontClose
								<TD></TR>
								</TABLE>
							</TD>
						</TR>
						@{[ $formAction ? '</FORM>' : '']}
					</TABLE>
				});
		}
		else
		{
			($wrapContentOpen, $wrapContentClose) =
				(qq{
					<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0 @{[ $layoutDefn->{width} ? "WIDTH=$layoutDefn->{width}" : '100%' ]}>
					@{[ $formAction ? '<FORM ACTION="$formAction" METHOD="POST">' : '']}
					<TR VALIGN=TOP><TD>
						$defaultFontOpen
				}, qq{
						$defaultFontClose
					<TD></TR>
					@{[ $formAction ? '</FORM>' : '']}
					</TABLE>
				});
		}
	}

	# replace any fmtdefn.xxx vars with the local variables in _this_ method
	# so that, e.g., fmtdefn.bodyFontOpen in a Fmt will be replaced with $bodyFontOpen's value
	#
	my $htmlFmt = $wrapContentOpen . join('', @contentFmt) . $wrapContentClose;
	$htmlFmt =~ s/\#fmtdefn\.(.*?)\#/die $1; eval("\$$1")/ge;
	my $fmt =
	{
		flags => $layoutFlags,
		callbacks => \@callbacks,
		htmlFmt => $htmlFmt,
		defaultFontOpen => $defaultFontOpen,
		defaultFontClose => $defaultFontClose,
	};

	$fmt->{flags} |= LAYOUTFLAG_REPLACECONTENT if $fmt->{htmlFmt} =~ m/\#CONTENT\#/;
	$fmt->{flags} |= LAYOUTFLAG_REPLACEDEFNVARS if $fmt->{htmlFmt} =~ m/\#my\.(.*?)\#/;
	return $fmt;
}

sub getDefnTemplateFmt
{
	my ($page, $flags, $layoutDefn, $layoutParams) = @_;

	my $fmt = undef;
	my $style = ref $layoutParams eq 'HASH' ? ($layoutParams->{style} || undef) : undef;
	my $fmtCacheName = FMTTEMPLATE_CACHE_KEYNAME . ($style ? ('/' . $style) : '');
	unless($fmt = $layoutDefn->{$fmtCacheName})
	{
		$fmt = prepareHtmlFormat($page, $flags, $layoutDefn, $style);
		#$self->{$fmtCacheName} = $fmt if $fmt;
	}
	$page->addError("Layout format could not be obtained in getDefnTemplateFmt ('$fmtCacheName').") unless $fmt;
	return $fmt;
}

sub createLayout_html
{
	my ($page, $flags, $layoutDefn, $layoutParams) = @_;
	my $fmt = getDefnTemplateFmt($page, $flags, $layoutDefn, $layoutParams);

	my $layoutFlags = $fmt->{flags};
	my $html = $fmt->{htmlFmt};
	if($layoutFlags & LAYOUTFLAG_HASCALLBACKS)
	{
		my $callbacks = $fmt->{callbacks};
		my $callback = undef;
		$html =~ s/\#(\d+)\#/$callback = $callbacks->[$1]; ref $callback eq 'CODE' ? &$callback($page, $layoutDefn) : $callback->as_html($page, $layoutDefn)/ge;
	}
	$html =~ s/\#my\.(.*?)\#/$layoutParams->{$1}/g if $layoutFlags & LAYOUTFLAG_REPLACEDEFNVARS;
	$html =~ s/\#CONTENT\#/$layoutParams/g if $layoutFlags & LAYOUTFLAG_REPLACECONTENT;
	$html =~ s/\#fmtdefn\.(.*?)\#/$fmt->{$1}/g;

	return $html;
}

1;