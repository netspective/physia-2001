package App::Billing::Output::PDF::Report;

use strict;
use pdflib 2.01;
#use pdflib_pl 8.0;
use constant TWCC_PDF_LEFT => 1;
use constant TWCC_PDF_BOTTOM => 1;
use constant TWCC_PDF_TOP => 1;
use constant TWCC_PDF_RIGHT => 1;

use constant TWCC_FORM_FONT_NAME => 'Helvetica';
use constant TWCC_FORM_FONT_WIDTH => 8;
use constant TWCC_PADDING_LEFT => 2; # previously 5
use constant TWCC_PADDING_TOP => 7; # previously 5
use constant TWCC_LINE_THICKNESS => 1;
use constant TWCC_FORM_RED => 0.0; # 0.7
use constant TWCC_FORM_GREEN => 0.0;
use constant TWCC_FORM_BLUE => 0.0;
use constant TWCC_CHECK_BOX_WIDTH => 5;
use constant TWCC_CHECK_BOX_HEIGHT => 5;
use constant TWCC_PAGE_WIDTH => 612;
use constant TWCC_PAGE_HEIGHT => 792;
use constant TWCC_RADIUS => 3.5;
use constant TWCC_INNER_RADIUS => 1;

sub new
{
	my ($type, %params) = @_;
	my $self = {};
	$self->{'color'} = $params{'color'} eq '' ? '0,0,0' :  $params{'color'};
	return bless $self, $type;
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

	$self->setColor($pdf, $self);

}


sub getLength
{
	my ($self, $pdf, $properties) = @_;
	my $font = pdflib::PDF_findfont($pdf, $properties->{'fontName'} eq "" ? TWCC_FORM_FONT_NAME : $properties->{'fontName'}, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($pdf, $font, $properties->{'fontWidth'} eq "" ? TWCC_FORM_FONT_WIDTH : $properties->{'fontWidth'});
	my $length = pdflib::PDF_stringwidth($pdf, $properties->{'text'}, $font, $properties->{'fontWidth'} eq "" ? TWCC_FORM_FONT_WIDTH : $properties->{'fontWidth'});
	return $length;
}

sub drawText
{
	my ($self, $pdf, $properties) = @_;
	my $font = pdflib::PDF_findfont($pdf, $properties->{'fontName'} eq "" ? TWCC_FORM_FONT_NAME : $properties->{'fontName'}, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($pdf, $font, $properties->{'fontWidth'} eq "" ? TWCC_FORM_FONT_WIDTH : $properties->{'fontWidth'});
	$self->setColor($pdf, $properties);
	pdflib::PDF_show_xy($pdf, $properties->{'text'}, $properties->{'x'} + TWCC_PADDING_LEFT, $properties->{'y'} - TWCC_PADDING_TOP);
	$self->setColor($pdf, $self);

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
	$self->setColor($pdf, $self);

}

sub drawCheckBox
{
	my ($self, $pdf, $properties) = @_;
	$self->setColor($pdf, $properties);
	my $width = $properties->{'width'} ne "" ? $properties->{'width'} : TWCC_CHECK_BOX_WIDTH;
	my $height = $properties->{'height'} ne "" ? $properties->{'height'} : TWCC_CHECK_BOX_HEIGHT;
	pdflib::PDF_rect($pdf, $properties->{'x'}, $properties->{'y'}, $width , $height);
	pdflib::PDF_stroke($pdf);
	$self->setColor($pdf, $self);

}

sub drawRadioButtonUnSelect
{
	my ($self, $pdf, $properties) = @_;
	$self->setColor($pdf, $properties);
	my $radius = $properties->{'raduis'} ne "" ? $properties->{'radius'} : TWCC_RADIUS;

	pdflib::PDF_circle($pdf, $properties->{'x'} + $radius, $properties->{'y'} - $radius, $radius);
	pdflib::PDF_stroke($pdf);
	$self->setColor($pdf, $self);

}

sub drawRadioButtonSelect
{
	my ($self, $pdf, $properties) = @_;
	$self->setColor($pdf, $properties);
	my $radius = $properties->{'raduis'} ne "" ? $properties->{'radius'} : TWCC_RADIUS;
	my $innerRadius = TWCC_INNER_RADIUS;

	pdflib::PDF_circle($pdf, $properties->{'x'} + $radius, $properties->{'y'} - $radius, $radius);
	pdflib::PDF_stroke($pdf);
	pdflib::PDF_circle($pdf, $properties->{'x'} + $radius, $properties->{'y'} - $radius, $innerRadius);
	pdflib::PDF_fill_stroke($pdf);
	$self->setColor($pdf, $self);

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
	$self->setColor($pdf, $self);

}

sub setColor
{
	my ($self, $pdf, $properties) = @_;
	my $color = $properties->{'color'} eq '' ?  $self->{'color'} : $properties->{'color'};
	my @rgb = split(/,/, $color);
	pdflib::PDF_setrgbcolor($pdf, $rgb[0], $rgb[1], $rgb[2]);
}

sub newPage
{
	my ($self, $p, $properties)  = @_;
	my $pageWidth = $properties->{'pageWidth'} ne "" ? $properties->{'pageWidth'} : TWCC_PAGE_WIDTH;
	my $pageHeight = $properties->{'pageHeight'} ne "" ? $properties->{'pageHeight'} : TWCC_PAGE_HEIGHT;
	pdflib::PDF_begin_page($p, $pageWidth, $pageHeight);
}

sub endPage
{
	my ($self, $p)  = @_;
	pdflib::PDF_end_page($p);
}

sub textSplit
{
	my($self, $p, $string, $clipWidth, $fontName, $fontWidth) = @_;

	my $totalWidth = 0;
	my $first;
	my $rest;

	my @words = split(" ", $string);
	my $sp = pdflib::PDF_stringwidth($p, " ", $fontName, $fontWidth);

	foreach my $word (@words)
	{
		$totalWidth = $totalWidth  + pdflib::PDF_stringwidth($p, $word, $fontName, $fontWidth) + $sp;
		if ($totalWidth <= $clipWidth)
		{
			$first = join(" ", $first, $word);
		}
		else
		{
			$rest = join(" ", $rest, $word);
		}
	}
	return ($first, $rest);
}

sub drawImageJPEG
{
	my($self, $p, $properties) = @_;
	my $scale = $properties->{'scale'} eq "" ? 1 : $properties->{'scale'};

	my $tmp = pdflib::PDF_open_JPEG($p, $properties->{'imagePath'});
	pdflib::PDF_place_image($p, $tmp, $properties->{'x'}, $properties->{'y'}, $scale);
}

sub drawFilledRectangle
{
	my($self, $p, $properties) = @_;

	$self->setColor($p, $properties);
	if ($properties->{'fillColor'} ne '')
	{
		my @rgb = split(/,/, $properties->{'fillColor'});
		pdflib::PDF_setrgbcolor_fill($p, $rgb[0], $rgb[1], $rgb[2]);
	}

	pdflib::PDF_rect($p, $properties->{'x'}, $properties->{'y'}, $properties->{'width'}, -1 * $properties->{'height'});
	pdflib::PDF_closepath_fill_stroke($p);
	$self->setColor($p, $self);

}

1;
