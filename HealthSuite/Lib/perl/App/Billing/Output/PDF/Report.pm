package App::Billing::Output::PDF::Report;

use strict;
use pdflib 2.01;
use constant TWCC_PDF_LEFT => 1;
use constant TWCC_PDF_BOTTOM => 1;
use constant TWCC_PDF_TOP => 1;
use constant TWCC_PDF_RIGHT => 1;

use constant TWCC_FORM_FONT_NAME => 'Helvetica';
use constant TWCC_FORM_FONT_WIDTH => 8;
use constant TWCC_PADDING_LEFT => 2; # previously 5
use constant TWCC_PADDING_TOP => 7; # previously 5
use constant TWCC_LINE_THICKNESS => 1;
use constant TWCC_FORM_RED => 0.7;
use constant TWCC_FORM_GREEN => 0.0;
use constant TWCC_FORM_BLUE => 0.0;
use constant TWCC_CHECK_BOX_WIDTH => 5;
use constant TWCC_CHECK_BOX_HEIGHT => 5;
use constant TWCC_PAGE_WIDTH => 612;
use constant TWCC_PAGE_HEIGHT => 792;

sub new
{
	my ($type, %params) = @_;
	return bless \%params, $type;
}

sub drawBox
{
	my ($self, $pdf, $x1, $y1, $width, $height, $left, $right, $top, $bottom, $properties) = @_;

	$x1+=0;
	$y1+=0;
	$self->setColor($pdf, $properties);
	pdflib::PDF_setdash($pdf, 0, 0);
	if ($left == TWCC_PDF_LEFT)
	{
		pdflib::PDF_moveto($pdf, $x1, $y1) ;
		pdflib::PDF_lineto($pdf, $x1, $y1 - $height); # left Line
		pdflib::PDF_stroke($pdf);
	}
	if ($bottom == TWCC_PDF_BOTTOM)
	{
		pdflib::PDF_moveto($pdf, $x1, $y1 - $height) ;
		pdflib::PDF_lineto($pdf, $x1 + $width, $y1 - $height); # bottom Line
		pdflib::PDF_stroke($pdf);
	}
	if ($top == TWCC_PDF_TOP)
	{
		pdflib::PDF_moveto($pdf, $x1, $y1) ;
		pdflib::PDF_lineto($pdf, $x1 + $width, $y1); # Top Line
		pdflib::PDF_stroke($pdf);
	}
	if ($right == TWCC_PDF_RIGHT)
	{
		
		pdflib::PDF_moveto($pdf, $x1 + $width, $y1);
		pdflib::PDF_lineto($pdf, $x1 + $width, $y1 - $height); # Top Line
		pdflib::PDF_stroke($pdf);
	}
	my $texts = $properties->{'texts'};
	my $lines = $properties->{'lines'};
	my $arrows = $properties->{'arrows'};
	my $checkBoxes = $properties->{'checkBoxes'};
	for my $element(@{$texts})
	{
		$self->drawText($pdf, $element);
	}
	for my $element(@{$lines})
	{
		$self->drawLine($pdf, $element);
	}
	for my $element(@{$arrows})
	{
		$self->drawArrow($pdf, $element);
	}
	for my $element(@{$checkBoxes})
	{
		$self->drawCheckBox($pdf, $element);
	}
}

sub drawText
{
	my ($self, $pdf, $properties) = @_;
	my $font = pdflib::PDF_findfont($pdf, $properties->{'fontName'} eq "" ? TWCC_FORM_FONT_NAME : $properties->{'fontName'}, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($pdf, $font, $properties->{'fontWidth'} eq "" ? TWCC_FORM_FONT_WIDTH : $properties->{'fontWidth'});
	$self->setColor($pdf, $properties);
	pdflib::PDF_show_xy($pdf, $properties->{'text'}, $properties->{'x'} + TWCC_PADDING_LEFT, $properties->{'y'} - TWCC_PADDING_TOP);
}

sub drawLine
{
	my ($self, $pdf, $properties) = @_;
	
	$self->setColor($pdf, $properties);
	pdflib::PDF_setlinewidth($pdf, $properties->{'thickness'} eq "" ? TWCC_LINE_THICKNESS : $properties->{'thickness'});
	pdflib::PDF_setdash($pdf, $properties->{'blackDash'} + 0, $properties->{'whiteDash'} + 0);
	pdflib::PDF_moveto($pdf, $properties->{'x1'}, $properties->{'y1'});
	pdflib::PDF_lineto($pdf, $properties->{'x2'}, $properties->{'y2'});
	pdflib::PDF_stroke($pdf);
}

sub drawCheckBox
{
	my ($self, $pdf, $properties) = @_;
#	$self->setColor($pdf, $properties);
	my $width = $properties->{'width'} ne "" ? $properties->{'width'} : TWCC_CHECK_BOX_WIDTH;
	my $height = $properties->{'height'} ne "" ? $properties->{'height'} : TWCC_CHECK_BOX_HEIGHT;

	pdflib::PDF_setrgbcolor($pdf, 0.7, 0, 0);
	pdflib::PDF_rect($pdf, $properties->{'x'}, $properties->{'y'}, $width , $height);
	pdflib::PDF_stroke($pdf);
}

sub drawArrow
{
	my ($self, $pdf, $properties) = @_;
	my ($i, $y, $xs, $ys);
	$xs =[$properties->{'x1'}, $properties->{'x2'}, $properties->{'x3'}];
	$ys =[$properties->{'y1'}, $properties->{'y2'}, $properties->{'y3'}];
	$self->setColor($pdf, $properties);
	pdflib::PDF_moveto($pdf, $xs->[0], $ys->[0]);
	for ($i=1; $i<= $#$xs; $i++)
	{
		pdflib::PDF_lineto($pdf, $xs->[$i], $ys->[$i]);
	}
	pdflib::PDF_lineto($pdf, $xs->[0], $ys->[0]);
	pdflib::PDF_closepath_fill_stroke($pdf);
}

sub setColor
{
	my ($self, $pdf, $properties) = @_;

	my @rgb = split(/,/, $properties->{'color'});
	my $color;
	$color->[0] = $rgb[0];
	$color->[1] = $rgb[1];
	$color->[2] = $rgb[2];
	unless($properties->{'color'})
	{
		$color->[0] = TWCC_FORM_RED;
		$color->[1] = TWCC_FORM_GREEN;
		$color->[2] = TWCC_FORM_BLUE;
	}
	pdflib::PDF_setrgbcolor($pdf, $color->[0], $color->[1], $color->[2]);
}

sub newPage
{
	my ($self, $p)  = @_;
	pdflib::PDF_begin_page($p, TWCC_PAGE_WIDTH, TWCC_PAGE_HEIGHT);
}

sub endPage
{
	my ($self, $p)  = @_;
	pdflib::PDF_end_page($p);
}

1;