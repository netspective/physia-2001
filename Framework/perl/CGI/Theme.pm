package CGI::Theme;

use strict;
use warnings;
use Class::Struct;

struct
(
	menuAreaAttrs => '$',
	menuFontAttrs => '$',
	menuFontHoverColor => '$',
	logoAreaAttrs => '$',
	headerAreaAttrs => '$',
	workAreaAttrs => '$'
);

sub getAll
{
	my $self = shift;
	return (
		$self->menuAreaAttrs,
		$self->menuFontAttrs,
		$self->menuFontHoverColor,
		$self->logoAreaAttrs,
		$self->headerAreaAttrs,
		$self->workAreaAttrs
		);
}

sub getPhysiaDefault
{
	return $physia::defaultTheme if defined $physia::defaultTheme;
	
	$physia::defaultTheme = new CGI::Theme;
	my $theme = $physia::defaultTheme;
	$theme->menuAreaAttrs('BGCOLOR="#DCDCDC" HEIGHT="25"');
	$theme->menuFontAttrs('FACE="Arial,Helvetica" SIZE="2" COLOR="#0B3170"');
	$theme->menuFontHoverColor('red');
	$theme->logoAreaAttrs('BGCOLOR="#DCDCDC" HEIGHT="25" VALIGN="TOP" ALIGN="CENTER"');
	$theme->logoImgAttrs('SRC="/images/main/menu_logo1.gif"');
	$theme->headerAreaAttrs('BGCOLOR="#0B3170" style="border-bottom:1px solid white"');
	$theme->workAreaAttrs('BGCOLOR=darkslateblue TOPMARGIN="0" LEFTMARGIN="0" MARGINWIDTH="0" MARGINHEIGHT="0"');
}

1;
