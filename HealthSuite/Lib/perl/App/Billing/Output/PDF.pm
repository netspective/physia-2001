#########################################################################
package App::Billing::Output::PDF;
#########################################################################
use strict;
use App::Billing::Output::Driver;
use App::Billing::Claims;
use pdflib 2.01;

use vars qw(@ISA);
use App::Billing::Output::PDF::Worker;

use constant CLAIM_TYPE_WORKCOMP => 6;


use constant FORM_RED => 0.7;
use constant FORM_GREEN => 0.0;
use constant FORM_BLUE => 0.0;
use constant FORM_BAR_RED => 1;
use constant FORM_BAR_GREEN => 0.7;
use constant FORM_BAR_BLUE => 0.7;
use constant FORM_FONT_SIZE => 6.0;
use constant FORM_FONT_NAME => 'Helvetica';
use constant FORM_OTHER_FONT_NAME => 'Times-Italic';

use constant CHECK_BOX_W => 11;
use constant CHECK_BOX_H => 11;

use constant CHECKED_BOX_X => 3;
use constant CHECKED_BOX_Y => 3;

use constant PAGE_HEIGHT => 792;
use constant PAGE_WIDTH => 612;
use constant DATE_LINE_HEIGHT => 14;
use constant THIN_LINE_WIDTH => 0.5;
use constant THICK_LINE_WIDTH => 2;
use constant NORMAL_LINE_WIDTH  => 1;

use constant START_X => 24;
use constant START_Y => 39;
use constant FORM_WIDTH => 567;
use constant FORM_HEIGHT => 661.5;
use constant LINE_SPACING => 22.5;
use constant MEDICARE_EXTRA_SPACE => 4.5;
use constant STARTX_BOX3_SPACE => 205;    # DISTANCE B/W STARTING X AND BOX3
use constant STARTX_BOX1A_SPACE => 351.5; # DISTANCE B/W STARTING X AND BOX1A
use constant STARTX_BOX24E_SPACE => 292; # DISTANCE B/W STARTING X AND BOX24E
use constant STARTX_BOX24ADATE_SPACE => 67; # DISTANCE B/W STARTING X AND BOX24AD
use constant STARTX_BOX24B_SPACE => 127; # DISTANCE B/W STARTING X AND BOX24B
use constant STARTX_BOX24C_SPACE => 149; # DISTANCE B/W STARTING X AND BOX24C
use constant STARTX_BOX24D_SPACE => 172; # DISTANCE B/W STARTING X AND BOX24D
use constant STARTX_BOX24F_SPACE => 351; # DISTANCE B/W STARTING X AND BOX24F
use constant STARTX_BOX24FC_SPACE => 391; # DISTANCE B/W STARTING X AND BOX24FC
use constant STARTX_BOX24G_SPACE => 416; # DISTANCE B/W STARTING X AND BOX24G
use constant STARTX_BOX24H_SPACE => 436; # DISTANCE B/W STARTING X AND BOX24H
use constant STARTX_BOX24I_SPACE => 459; # DISTANCE B/W STARTING X AND BOX24I
use constant STARTX_BOX24J_SPACE => 478; # DISTANCE B/W STARTING X AND BOX24I
use constant STARTX_BOX24K_SPACE => 500; # DISTANCE B/W STARTING X AND BOX24J
use constant STARTX_BOX26_SPACE => 156; # DISTANCE B/W STARTING X AND BOX2A
use constant STARTX_BOX29_SPACE => 430; # DISTANCE B/W STARTING X AND BOX1A
use constant STARTX_BOX27_SPACE => 261; # DISTANCE B/W STARTING X AND BOX1A
use constant BLACK_DASH => 4.5; #
use constant WHITE_DASH => 1.125; #
use constant CELL_PADDING_Y => 1.125; #
use constant CELL_PADDING_X => 2.25; #
use constant DATA_PADDING_X => 9;
use constant BOX24_HEIGHT => 8;

use constant STARTY_MID_SPACE => 374; # DISTANCE B/W STARTING Y AND MID THICK LINE

use constant DATA_RED => 0.0;
use constant DATA_GREEN => 0.0;
use constant DATA_BLUE => 0.0;
use constant DATA_FONT_SIZE => 8.0;
use constant DATA_FONT_NAME => 'Courier';


# this object is inherited from App::Billing::Output::Driver
@ISA = qw(App::Billing::Output::Driver);

sub processClaims
{
	my ($self, %params) = @_;

	my $claimsList = $params{claimList};
	my $claims = $params{claimList}->getClaim();
	my $p = pdflib::PDF_new();
	my $drawBackgroundForm = exists $params{drawBackgroundForm} ? $params{drawBackgroundForm} : 1;
	die "PDF file name is required" unless exists $params{outFile};
	die "Couldn't open PDF file"  if (pdflib::PDF_open_file($p, $params{outFile}) == -1);
	pdflib::PDF_set_info($p, "Creator", "PHYSIA");
	pdflib::PDF_set_info($p, "Author", "PHYSIA");
	pdflib::PDF_set_info($p, "Title", "Claim Form Report");
	my $cordinates;
#	$self->newPage($p);
#	$cordinates = $self->drawForm($p);
#	$self->endPage($p);
	foreach my $claim(@$claims)
	{
		my $once=0;
		my $procesedProc = [];
		if ($claim->haveErrors() == 1)
		{
			$self->newPage($p);

			$self->drawErrors($p,$claim);
			$self->endPage($p);

		}
		else
		{
		my $pp = $self->setPrimaryProcedure($claim);
		while ($self->allProcTraverse($procesedProc,$claim) eq "0")
			{
				$self->newPage($p);
				$cordinates = $self->drawForm($p, $drawBackgroundForm);
				$self->populatePDF($p,$claim, $cordinates, $procesedProc);
				$self->endPage($p);
				$once++;
			}

		$self->reversePrimaryProcedure($claim, $pp);
		}
	}
	$self->closeAndDestroy($p);
}


sub drawErrors
{

	my ($self, $p, $claim) = @_;
	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, 8.0);
	my $y = 747.0;
	pdflib::PDF_show_xy($p , 'The claim with id' . $claim->getId(). " have following errors", 50,$y );
	my $errors = $claim->getErrors();
	my $error;
	$y-=10;
	foreach $error (@$errors)
	{
		pdflib::PDF_show_xy($p , $error->[1] . $error->[2], 60, $y-=10);
	}
}

sub newPage
{
	my ($self, $p)  = @_;
	pdflib::PDF_begin_page($p, PAGE_WIDTH, PAGE_HEIGHT);
}

sub drawLine
{
	my ($self, $pdf, $x2, $y2, $x1, $y1) = @_;

	pdflib::PDF_moveto($pdf, $x1, $y1) if defined $x1;
	pdflib::PDF_lineto($pdf, $x2, $y2);
	pdflib::PDF_stroke($pdf);
}

sub drawPoly
{
	my ($self, $p, $xs, $ys, $color) = @_;
	my ($i,$y);
	pdflib::PDF_setrgbcolor($color->[0], $color->[1], $color->[2]) if defined $color->[0];
	pdflib::PDF_moveto($p, $xs->[0], $ys->[0]);
	for ($i=1; $i<= $#$xs; $i++)
	{
		pdflib::PDF_lineto($p, $xs->[$i], $ys->[$i]);
	}
	pdflib::PDF_lineto($p, $xs->[0], $ys->[0]);
	pdflib::PDF_closepath_fill_stroke($p);
}

sub drawCheckBox
{
	my ($self, $p, $x, $y, $color) = @_;
	unless($color->[0])
	{
		$color->[0] = FORM_RED;
		$color->[1] = FORM_GREEN;
		$color->[2] = FORM_BLUE;
	}
	pdflib::PDF_setrgbcolor($p,$color->[0],$color->[1],$color->[2]);
	pdflib::PDF_rect($p, $x, $y, CHECK_BOX_W,CHECK_BOX_H);
}

sub endPage
{
	my ($self, $p)  = @_;
	pdflib::PDF_end_page($p);
}

sub closeAndDestroy
{
	my ($self, $p)  = @_;

	pdflib::PDF_close($p);
	pdflib::PDF_delete($p);
}

############### FUNCTION RELATED WITH FORM OUTLINE DRAWING #######################
sub drawForm
{
	my ($self, $p, $drawBackgroundForm)  = @_;

	pdflib::PDF_setrgbcolor($p, FORM_RED, FORM_GREEN, FORM_BLUE);
	# pdflib::PDF_setrgbcolor($p, 0.7, 0, 0);

	my $cordinates = $self->drawFormOutline($p, $drawBackgroundForm);

	if($drawBackgroundForm)
	{
		pdflib::PDF_setrgbcolor($p, FORM_RED, FORM_GREEN, FORM_BLUE);
		# pdflib::PDF_setrgbcolor($p, 0.7, 0, 0);
		$self->drawHeader($p);
		pdflib::PDF_setrgbcolor($p, FORM_RED, FORM_GREEN, FORM_BLUE);
		$self->box1($p, $cordinates);
		$self->box1a($p, $cordinates);
		$self->box2($p, $cordinates);
		$self->box3($p, $cordinates);
		$self->box4($p, $cordinates);
		$self->box5($p, $cordinates);
		$self->box5a($p, $cordinates);
		$self->box5b($p, $cordinates);
		$self->box6($p, $cordinates);
		$self->box7($p, $cordinates);
		$self->box7a($p, $cordinates);
		$self->box7b($p, $cordinates);
		$self->box8($p, $cordinates);

		$self->box9($p, $cordinates);
		$self->box9a($p, $cordinates);
		$self->box9b($p, $cordinates);
		$self->box9c($p, $cordinates);
		$self->box9d($p, $cordinates);

		$self->box10($p, $cordinates);
		$self->box10d($p, $cordinates);

		$self->box11($p, $cordinates);
		$self->box11a($p, $cordinates);
		$self->box11b($p, $cordinates);
		$self->box11c($p, $cordinates);
		$self->box11d($p, $cordinates);
		$self->box12($p, $cordinates);
		$self->box13($p, $cordinates);
		$self->box14($p, $cordinates);
		$self->box15($p, $cordinates);
		$self->box16($p, $cordinates);
		$self->box17($p, $cordinates);
		$self->box17a($p, $cordinates);
		$self->box18($p, $cordinates);
		$self->box19($p, $cordinates);
		$self->box20($p, $cordinates);
		$self->box21($p, $cordinates);
		$self->box22($p, $cordinates);
		$self->box23($p, $cordinates);
		$self->box24($p, $cordinates);
		$self->box25($p, $cordinates);
		$self->box26($p, $cordinates);
		$self->box27($p, $cordinates);
		$self->box28($p, $cordinates);
		$self->box29($p, $cordinates);
		$self->box30($p, $cordinates);
		$self->box31($p, $cordinates);
		$self->box32($p, $cordinates);
		$self->box33($p, $cordinates);
	#	$self->box31($p);
	#	$self->box32($p);
	#	$self->box33($p);
	#	pdflib::PDF_setrgbcolor($p, FORM_RED, FORM_GREEN, FORM_BLUE);
		# pdflib::PDF_setrgbcolor($p, 0.7, 0, 0);
		$self->drawTrailer($p);
	}
	return $cordinates;
}

sub drawHeader
{
	my ($self, $p)  = @_;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, 8.0);


	pdflib::PDF_show_xy($p , 'PLEASE', START_X, START_Y + FORM_HEIGHT + 59);
	pdflib::PDF_show_xy($p , 'DO NOT', START_X, START_Y + FORM_HEIGHT + 51);
	pdflib::PDF_show_xy($p , 'STAPLE', START_X, START_Y + FORM_HEIGHT + 43);
	pdflib::PDF_show_xy($p , 'IN THIS',START_X, START_Y + FORM_HEIGHT + 35);
	pdflib::PDF_show_xy($p , 'AREA', START_X, START_Y + FORM_HEIGHT + 27);

	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);

	pdflib::PDF_show_xy($p , 'APPROVED OMB-0938-0008', START_X + 462, START_Y + FORM_HEIGHT + 68);

	pdflib::PDF_show_xy($p , 'PICA', 2 * START_X, START_Y + FORM_HEIGHT + 2);
	pdflib::PDF_show_xy($p , 'PICA', START_X + 525, START_Y + FORM_HEIGHT + 2);
	pdflib::PDF_stroke($p);

	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	pdflib::PDF_rect($p, START_X, START_Y + FORM_HEIGHT, 7, 10);
	pdflib::PDF_rect($p, START_X + 7, START_Y + FORM_HEIGHT, 7, 10);
	pdflib::PDF_rect($p, START_X + 14, START_Y + FORM_HEIGHT, 7, 10);
	pdflib::PDF_rect($p, START_X + 547, START_Y + FORM_HEIGHT, 7, 10);
	pdflib::PDF_rect($p, START_X + 554,START_Y + FORM_HEIGHT, 7, 10);
	pdflib::PDF_rect($p, START_X + 560.5,START_Y + FORM_HEIGHT, 6.5, 10);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	pdflib::PDF_rect($p, START_X + 86, START_Y + FORM_HEIGHT + 56, 147, 15);
	pdflib::PDF_closepath_fill_stroke($p);
	pdflib::PDF_rect($p, START_X + 86, START_Y + FORM_HEIGHT + 45, 147, 5);
	pdflib::PDF_closepath_fill_stroke($p);
	pdflib::PDF_rect($p, START_X + 86, START_Y + FORM_HEIGHT + 33, 147, 5);
	pdflib::PDF_closepath_fill_stroke($p);
	pdflib::PDF_rect($p, START_X + 86, START_Y + FORM_HEIGHT + 14.5, 147, 12);
	pdflib::PDF_closepath_fill_stroke($p);


	$font = pdflib::PDF_findfont($p, FORM_FONT_NAME . "-Bold", "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE + 5);
	pdflib::PDF_show_xy($p , 'HEALTH INSURANCE CLAIM FORM', START_X + 288, START_Y + FORM_HEIGHT + 4);
	pdflib::PDF_stroke($p);
}

sub drawTrailer
{
	my ($self, $p)  = @_;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '(APPROVED BY AMA COUNCIL ON MEDICAL SERVICE 8/88)', START_X + 15, START_Y - 2 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'FORM HCFA-1500 (12-90), FORM RRB-1500.', START_X + 403, START_Y - 2 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'FORM OWCP-1500', START_X + 403, START_Y - 3 * FORM_FONT_SIZE + 1);
	pdflib::PDF_stroke($p);

	$font = pdflib::PDF_findfont($p, "Times-BoldItalic", "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE + 3);
	pdflib::PDF_show_xy($p , 'PLEASE PRINT OR TYPE', START_X + 207, START_Y - 2 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);

#	pdflib::PDF_set_text_matrix($p, 0, 1, -1, 0, 100, 200);
#	pdflib::PDF_show_xy($p , 'FORM', START_X + 4, START_Y - 4 * FORM_FONT_SIZE + 1);
#	pdflib::PDF_stroke($p);


}

sub drawFormOutline
{
	my ($self, $p, $drawBackgroundForm)  = @_;

	my $x;
	my $y;
	my $cordinates ={};
	my $upArr;

	if($drawBackgroundForm)
	{
		pdflib::PDF_setlinewidth($p, THICK_LINE_WIDTH);

		$self->drawLine($p, START_X, START_Y + FORM_HEIGHT,START_X + FORM_WIDTH, START_Y + FORM_HEIGHT); # on the top
		$self->drawLine($p, START_X, START_Y + 374,START_X + FORM_WIDTH, START_Y + 374); # middle line
		$self->drawLine($p, START_X, START_Y ,START_X + FORM_WIDTH, START_Y ); # on the bottom

		pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
		$self->drawLine($p, START_X + FORM_WIDTH + 6, START_Y + 9, START_X + FORM_WIDTH + 6, START_Y + 370);
		$self->drawLine($p, START_X + FORM_WIDTH + 6, START_Y,START_X + FORM_WIDTH , START_Y);
		$self->drawPoly($p,[START_X + FORM_WIDTH + 4, START_X + FORM_WIDTH + 6, START_X + FORM_WIDTH + 8],[START_Y + 9, START_Y + 3 , START_Y + 9]); # DOWN
		$self->drawPoly($p,[START_X + FORM_WIDTH + 4, START_X + FORM_WIDTH + 6, START_X + FORM_WIDTH + 8],[START_Y + 364, START_Y + 370 , START_Y + 364]); # UP

		$self->drawLine($p, START_X + FORM_WIDTH + 8, START_Y + 374,START_X + FORM_WIDTH , START_Y + 374);
		$self->drawLine($p, START_X + FORM_WIDTH + 6, START_Y + FORM_HEIGHT - 4,START_X + FORM_WIDTH + 6, START_Y + 378);
		$self->drawPoly($p,[START_X + FORM_WIDTH + 4, START_X + FORM_WIDTH + 6, START_X + FORM_WIDTH + 8],[START_Y + 381, START_Y + 375 , START_Y + 381]); #DOWN
		$self->drawPoly($p,[START_X + FORM_WIDTH + 4, START_X + FORM_WIDTH + 6, START_X + FORM_WIDTH + 8],[START_Y + FORM_HEIGHT - 6, START_Y + FORM_HEIGHT , START_Y + FORM_HEIGHT - 6]); # UP

		$self->drawLine($p, START_X + FORM_WIDTH + 8, START_Y + FORM_HEIGHT ,START_X + FORM_WIDTH , START_Y + FORM_HEIGHT );
		$self->drawLine($p, START_X + FORM_WIDTH + 6, START_Y + FORM_HEIGHT + 10,START_X + FORM_WIDTH + 6, START_Y + FORM_HEIGHT + 68);
		$self->drawPoly($p,[START_X + FORM_WIDTH + 4, START_X + FORM_WIDTH + 6, START_X + FORM_WIDTH + 8],[START_Y + FORM_HEIGHT + 62, START_Y + FORM_HEIGHT + 68 , START_Y + FORM_HEIGHT + 62]); # UP
		$self->drawPoly($p,[START_X + FORM_WIDTH + 4, START_X + FORM_WIDTH + 6, START_X + FORM_WIDTH + 8],[START_Y + FORM_HEIGHT + 10, START_Y + FORM_HEIGHT + 4 , START_Y + FORM_HEIGHT + 10]); # DOWN

		pdflib::PDF_stroke($p);
		pdflib::PDF_rect($p, START_X , START_Y, FORM_WIDTH, FORM_HEIGHT ); # draw  outline of form
		pdflib::PDF_stroke($p);
	}
	$cordinates->{box1} = [START_X, START_Y + FORM_HEIGHT];
	$self->drawLine($p, START_X, START_Y  + FORM_HEIGHT - LINE_SPACING -  MEDICARE_EXTRA_SPACE + 1.5, START_X + FORM_WIDTH, START_Y  + FORM_HEIGHT - LINE_SPACING - MEDICARE_EXTRA_SPACE + 1.5 ) if $drawBackgroundForm;  # draw  line b/w medicare and 2
	$cordinates->{box2} = [START_X, START_Y  + FORM_HEIGHT - LINE_SPACING -  MEDICARE_EXTRA_SPACE + 1.5];
	$y = START_Y  + FORM_HEIGHT - LINE_SPACING -  MEDICARE_EXTRA_SPACE;
	$self->drawLine($p, START_X, $y - LINE_SPACING, START_X + FORM_WIDTH, $y - LINE_SPACING) if $drawBackgroundForm; # draw  line b/w 2 and 5
	$cordinates->{box5} = [START_X, $y - LINE_SPACING];
	$y -= LINE_SPACING;
	$self->drawLine($p, START_X, $y - LINE_SPACING, START_X + FORM_WIDTH, $y - LINE_SPACING) if $drawBackgroundForm; # line b/w city and patient address
	$cordinates->{box5City} = [START_X, $y - LINE_SPACING];
	$y -= LINE_SPACING;

	$self->drawLine($p, START_X, $y - LINE_SPACING - 1, START_X + STARTX_BOX3_SPACE, $y - LINE_SPACING - 1) if $drawBackgroundForm; # draw partition b/w city line and zip code
	$cordinates->{box5ZipCode} = [START_X, $y - LINE_SPACING - 1];
	$self->drawLine($p, START_X + STARTX_BOX1A_SPACE, $y - LINE_SPACING - 1, START_X + FORM_WIDTH, $y - LINE_SPACING - 1) if $drawBackgroundForm; # draw partition b/w 7city and 7zip code
	$y -= LINE_SPACING;

	$self->drawLine($p, START_X, $y - LINE_SPACING -  MEDICARE_EXTRA_SPACE, START_X + FORM_WIDTH, $y - LINE_SPACING -  MEDICARE_EXTRA_SPACE) if $drawBackgroundForm; # draw partition b/w zip code and other ins. name
	$cordinates->{box9} = [START_X , $y - LINE_SPACING -  MEDICARE_EXTRA_SPACE];
	$y =$y - LINE_SPACING -  MEDICARE_EXTRA_SPACE;

	$self->drawLine($p, START_X, $y - LINE_SPACING , START_X + STARTX_BOX3_SPACE, $y - LINE_SPACING ) if $drawBackgroundForm; # draw partition b/w policy group no. and other name
	$cordinates->{box9a} = [START_X , $y - LINE_SPACING ];
	$self->drawLine($p, START_X + STARTX_BOX1A_SPACE, $y - LINE_SPACING , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm; # draw partition b/w 11 FECA number and 11 Insured date of birth
	$y -= LINE_SPACING;

	$self->drawLine($p, START_X, $y - LINE_SPACING - 1, START_X + STARTX_BOX3_SPACE, $y - LINE_SPACING- 1) if $drawBackgroundForm; # draw partition b/w other date of birth and employer name
	$cordinates->{box9b} = [START_X , $y - LINE_SPACING - 1 ];

	$self->drawLine($p, START_X + STARTX_BOX1A_SPACE, $y - LINE_SPACING - 1, START_X + FORM_WIDTH, $y - LINE_SPACING - 1) if $drawBackgroundForm; # draw partition b/w 11 date of birth  and 11 school name
	$y -= LINE_SPACING;

	$self->drawLine($p, START_X, $y - LINE_SPACING -  MEDICARE_EXTRA_SPACE, START_X + STARTX_BOX3_SPACE, $y - LINE_SPACING -  MEDICARE_EXTRA_SPACE) if $drawBackgroundForm; # draw partition b/w other date of birth and employer name
	$cordinates->{box9c} = [START_X , $y - LINE_SPACING - MEDICARE_EXTRA_SPACE ];
	$self->drawLine($p, START_X + STARTX_BOX1A_SPACE , $y - LINE_SPACING -  MEDICARE_EXTRA_SPACE, START_X + FORM_WIDTH, $y - LINE_SPACING -  MEDICARE_EXTRA_SPACE) if $drawBackgroundForm; # draw partition b/w school name  and 11c
	$y = $y - LINE_SPACING -  MEDICARE_EXTRA_SPACE;

	$self->drawLine($p, START_X, $y - LINE_SPACING , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm;   # partition b/w  9C and 9D
	$cordinates->{box9d} = [START_X , $y - LINE_SPACING ];

	$y -= LINE_SPACING;
	$self->drawLine($p, START_X, $y - LINE_SPACING -1, START_X + FORM_WIDTH, $y - LINE_SPACING - 1) if $drawBackgroundForm;   # line dividing 9d  and 12
	$cordinates->{box12} = [START_X , $y - LINE_SPACING ];

	$self->drawLine($p, START_X + STARTX_BOX3_SPACE, START_Y + FORM_HEIGHT - LINE_SPACING - MEDICARE_EXTRA_SPACE + 1.5, START_X + STARTX_BOX3_SPACE, $y - LINE_SPACING - 1) if $drawBackgroundForm; #   vertical mid  line in  patient address and patient rel
	$y -= LINE_SPACING;
	$y = START_Y + STARTY_MID_SPACE - 1 ;
	$cordinates->{box14} = [START_X , $y ];

	$self->drawLine($p, START_X, $y - LINE_SPACING -1, START_X + FORM_WIDTH, $y - LINE_SPACING - 1) if $drawBackgroundForm;   # line dividing 14  and 17
	$cordinates->{box17} = [START_X , $y - LINE_SPACING - 1 ];
	$cordinates->{box17a} = [START_X + STARTX_BOX3_SPACE - 14 , $y - LINE_SPACING - 1];

	$y -= LINE_SPACING;
	$self->drawLine($p, START_X, $y - LINE_SPACING - 1 , START_X + FORM_WIDTH, $y - LINE_SPACING - 1 ) if $drawBackgroundForm;   # line dividing 17  and 19
	$cordinates->{box19} = [START_X , $y - LINE_SPACING - 1 ];

	$self->drawLine($p, START_X + STARTX_BOX3_SPACE - 14, START_Y + STARTY_MID_SPACE , START_X + STARTX_BOX3_SPACE - 14, $y - LINE_SPACING - 1) if $drawBackgroundForm;   # verical line dividing 14  and 15
	$cordinates->{box15} = [START_X + STARTX_BOX3_SPACE - 14 , START_Y + STARTY_MID_SPACE ];

	$y = $y - LINE_SPACING - MEDICARE_EXTRA_SPACE;
	$self->drawLine($p, START_X, $y - LINE_SPACING , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm;   # line dividing 19  and 21
	$cordinates->{box21} = [START_X , $y - LINE_SPACING ];

	$y = $y - LINE_SPACING - MEDICARE_EXTRA_SPACE + 3;
	$self->drawLine($p, START_X + STARTX_BOX1A_SPACE, $y - LINE_SPACING  , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm;   # line dividing 22  and 23
	$cordinates->{box23} = [START_X , $y - LINE_SPACING];

	$y = $y -  LINE_SPACING - MEDICARE_EXTRA_SPACE + 3;
	$self->drawLine($p, START_X + STARTX_BOX1A_SPACE, $y - LINE_SPACING  , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm;   # line dividing 23  and 24F
	my $start24 = $y -  LINE_SPACING;

	$cordinates->{box24F} = [START_X + STARTX_BOX1A_SPACE, $y - LINE_SPACING];
	$self->drawLine($p, START_X , $y - LINE_SPACING  , START_X + STARTX_BOX24E_SPACE, $y - LINE_SPACING ) if $drawBackgroundForm;   # line dividing 21  and 24
	$cordinates->{box24} = [START_X , $y - LINE_SPACING];

	$self->drawLine($p, START_X, $y - LINE_SPACING - BOX24_HEIGHT, START_X + FORM_WIDTH, $y - LINE_SPACING - BOX24_HEIGHT ) if $drawBackgroundForm;   # line dividing 24  and 24 HEADS
	$cordinates->{box24HeadA} = [START_X , $y - LINE_SPACING - BOX24_HEIGHT];

	$y = $y - LINE_SPACING - BOX24_HEIGHT;
	$self->drawLine($p, START_X, $y - LINE_SPACING + 1, START_X + FORM_WIDTH, $y - LINE_SPACING + 1 ) if $drawBackgroundForm;   # line dividing 24head  and 24-1
	$cordinates->{box24_1} = [START_X , $y - LINE_SPACING + 1];

	my $startProcY = $y - LINE_SPACING + 1;
	$y = $y - LINE_SPACING + MEDICARE_EXTRA_SPACE;
	$self->drawLine($p, START_X, $y - LINE_SPACING + 1, START_X + FORM_WIDTH, $y - LINE_SPACING + 1 ) if $drawBackgroundForm;   # line dividing 24-1  and 24-2
	$cordinates->{box24_2} = [START_X , $y - LINE_SPACING + 1];

	$y -= LINE_SPACING;
	$self->drawLine($p, START_X, $y - LINE_SPACING , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm;   # line dividing 24-2  and 24-3
	$cordinates->{box24_3} = [START_X , $y - LINE_SPACING ];

	$y = $y - LINE_SPACING - 1;
	$self->drawLine($p, START_X, $y - LINE_SPACING , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm;   # line dividing 24-3  and 24-4
	$cordinates->{box24_4} = [START_X , $y - LINE_SPACING ];

	$y = $y - LINE_SPACING - 1;
	$self->drawLine($p, START_X, $y - LINE_SPACING , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm;   # line dividing 24-4  and 24-5
	$cordinates->{box24_5} = [START_X , $y - LINE_SPACING ];

	$y = $y - LINE_SPACING - 2;
	$self->drawLine($p, START_X, $y - LINE_SPACING , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm;   # line dividing 24-5  and 24-6
	$cordinates->{box24_6} = [START_X , $y - LINE_SPACING ];

	$y = $y - LINE_SPACING - 1;
	$self->drawLine($p, START_X, $y - LINE_SPACING , START_X + FORM_WIDTH, $y - LINE_SPACING ) if $drawBackgroundForm;   # line dividing 24-6  and 25
	$cordinates->{box25} = [START_X , $y - LINE_SPACING ];

	if($drawBackgroundForm)
	{
		$self->drawLine($p, START_X + STARTX_BOX24ADATE_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24ADATE_SPACE , $startProcY );   # line dividing 24-FROM and 24-TO
	#	$self->drawLine($p, START_X + STARTX_BOX24ADATE_SPACE, $y - LINE_SPACING , START_X  + STARTX_BOX24ADATE_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24B_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24B_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24C_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24C_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24D_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24D_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24E_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24E_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24F_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24F_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
		$self->drawLine($p, START_X + STARTX_BOX24FC_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24FC_SPACE, $cordinates->{box24_1}->[1]);   # line dividing 24-FROM and 24-TO
		pdflib::PDF_setdash($p, 0,0);
		$self->drawLine($p, START_X + STARTX_BOX24G_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24G_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24H_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24H_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24I_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24I_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24J_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX24J_SPACE, $start24);   # line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24K_SPACE, $y - 2 * LINE_SPACING - 2, START_X  + STARTX_BOX24K_SPACE, $start24);   # line dividing 24-FROM and 24-TO
	}
	$cordinates->{box27} = [START_X + STARTX_BOX27_SPACE, $y - LINE_SPACING ];
	$cordinates->{box28} = [START_X + STARTX_BOX1A_SPACE, $y - LINE_SPACING ];
	$cordinates->{box26} = [START_X + STARTX_BOX26_SPACE, $y - LINE_SPACING ];
	$cordinates->{box29} = [START_X + STARTX_BOX29_SPACE, $y - LINE_SPACING ];
	$cordinates->{box30} = [START_X + STARTX_BOX24K_SPACE, $y - LINE_SPACING ];

	$y = $y - LINE_SPACING - 2;
	if($drawBackgroundForm)
	{
		$self->drawLine($p, START_X + STARTX_BOX27_SPACE, $y - LINE_SPACING, START_X  + STARTX_BOX27_SPACE, $y + 2);   # line dividing 27 and 26
		$self->drawLine($p, START_X + STARTX_BOX29_SPACE, $y - LINE_SPACING  , START_X  + STARTX_BOX29_SPACE, $y + 2);   # line dividing 29 and 28
		$self->drawLine($p, START_X + STARTX_BOX26_SPACE, $y + 2, START_X  + STARTX_BOX26_SPACE, START_Y);   # line dividing 25 and 26
		$self->drawLine($p, START_X, $y - LINE_SPACING , START_X + FORM_WIDTH, $y - LINE_SPACING );   # line dividing 25  and 31
	}
	$cordinates->{box31} = [START_X, $y - LINE_SPACING ];
	$cordinates->{box32} = [$cordinates->{box26}->[0], $y - LINE_SPACING ];
	$cordinates->{box33} = [START_X + STARTX_BOX1A_SPACE, $y - LINE_SPACING ];

	if($drawBackgroundForm)
	{
		pdflib::PDF_setrgbcolor($p, FORM_BAR_RED, FORM_BAR_GREEN, FORM_BAR_BLUE);
		pdflib::PDF_rect($p , START_X + STARTX_BOX24D_SPACE - 3.5, $y + 2.3, 7.5, $startProcY - $y - 2.5); # draw partition of thick block b c,e,f
		pdflib::PDF_closepath_fill_stroke($p);
		pdflib::PDF_rect($p , START_X + STARTX_BOX24E_SPACE - 5, $y + 2.3,  7.5, $startProcY - $y - 2.5);
		pdflib::PDF_closepath_fill_stroke($p);
		pdflib::PDF_rect($p , START_X + STARTX_BOX24F_SPACE - 5, $y + 2.3, 7.5, $startProcY - $y - 2.5);
		pdflib::PDF_closepath_fill_stroke($p);
		pdflib::PDF_setrgbcolor($p, FORM_RED, FORM_GREEN, FORM_BLUE);
		$self->drawLine($p, START_X + STARTX_BOX24D_SPACE, $y + 2.3, START_X  + STARTX_BOX24D_SPACE, $startProcY );   # overwrite the line dividing 24-FROM and 24-TO
		$self->drawLine($p, START_X + STARTX_BOX24E_SPACE, $y + 2.3, START_X  + STARTX_BOX24E_SPACE, $startProcY );   # overwrite line dividing 24-FROM and 24-TO
		pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
		$self->drawLine($p, START_X + STARTX_BOX1A_SPACE , START_Y , START_X + STARTX_BOX1A_SPACE, START_Y + FORM_HEIGHT );   # THICK MID VERTICAL line dividing 1  and 1A
		pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	}
	return $cordinates;
}


sub box1
{
	my ($self, $p, $cordinates)  = @_;
	my $box1Cordinates = $cordinates->{box1};
	my $box1Y = $box1Cordinates->[1];
	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '1.  MEDICARE              MEDICAID                CHAMPUS                CHAMPVA                GROUP                FECA                  OTHER', START_X + CELL_PADDING_X,  $box1Y - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'HEALTH PLAN    	BLK LUNG', $box1Cordinates->[0] + 229, $box1Y - CELL_PADDING_Y - 2 * FORM_FONT_SIZE);
	$self->drawCheckBox($p,$box1Cordinates->[0] + 1, $box1Y - 25);
	$self->drawCheckBox($p,$box1Cordinates->[0] + 50, $box1Y - 25);
	$self->drawCheckBox($p,$box1Cordinates->[0] + 100, $box1Y - 25);
	$self->drawCheckBox($p,$box1Cordinates->[0] + 165, $box1Y - 25);
	$self->drawCheckBox($p,$box1Cordinates->[0] + 214, $box1Y - 25);
	$self->drawCheckBox($p,$box1Cordinates->[0] + 272, $box1Y - 25);
	$self->drawCheckBox($p,$box1Cordinates->[0] + 316, $box1Y - 25);
	pdflib::PDF_stroke($p);
	$font = pdflib::PDF_findfont($p, FORM_OTHER_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '(Medicare #)', $box1Cordinates->[0] + 14, $box1Y - CELL_PADDING_Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '(Medicaid #)', $box1Cordinates->[0] + 65, $box1Y - CELL_PADDING_Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '(Sponsos\'s SSN)', $box1Cordinates->[0] + 115, $box1Y - CELL_PADDING_Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '(VA File #)', $box1Cordinates->[0] + 180, $box1Y - CELL_PADDING_Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '(SSN or ID)', $box1Cordinates->[0] + 231, $box1Y - CELL_PADDING_Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '(SSN)', $box1Cordinates->[0] + 286, $box1Y - CELL_PADDING_Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '(ID)', $box1Cordinates->[0] + 330, $box1Y - CELL_PADDING_Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);

}

sub box1a
{
	my ($self, $p, $cordinates)  = @_;
	my $box1aCordinates = $cordinates->{box1};
	my $box1Y = $box1aCordinates->[1];
	my $box1aX = $box1aCordinates->[0] + STARTX_BOX1A_SPACE;
	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '1a. INSURED\'S ID NUMBER                            (FOR PROGRAM IN ITEM 1)', $box1aX + CELL_PADDING_X, $box1Y - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);

}

sub box2
{
	my ($self, $p, $cordinates)  = @_;
	my $box2Cordinates = $cordinates->{box2};
	my $box2Y = $box2Cordinates->[1];
	my $box2X = $box2Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);

	pdflib::PDF_show_xy($p , '2. PATIENT\'S NAME (Last Name,First Name, Middle Initial)', $box2X + CELL_PADDING_X, $box2Y - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box3
{
	my ($self, $p, $cordinates)  = @_;
	my $box3Cordinates = $cordinates->{box2};
	my $box3Y = $box3Cordinates->[1];
	my $box3X = $box3Cordinates->[0] + STARTX_BOX3_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);

	pdflib::PDF_show_xy($p , '3. PATIENT\'S BIRTH DATE', $box3X + CELL_PADDING_X, $box3Y - FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'MM        DD        YY', $box3X + CELL_PADDING_X + 12, $box3Y - 2 * FORM_FONT_SIZE );
	pdflib::PDF_show_xy($p , 'SEX', $box3X + CELL_PADDING_X + 104, $box3Y - 2 * FORM_FONT_SIZE + 3);
	pdflib::PDF_show_xy($p , 'M', $box3X + CELL_PADDING_X + 79, $box3Y  - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'F', $box3X + CELL_PADDING_X + 117, $box3Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	$self->drawLine($p, $box3X + CELL_PADDING_X + 26, $cordinates->{box5}->[1] + DATE_LINE_HEIGHT, $box3X + CELL_PADDING_X + 26,$cordinates->{box5}->[1]);
	$self->drawLine($p, $box3X + CELL_PADDING_X + 50, $cordinates->{box5}->[1] + DATE_LINE_HEIGHT, $box3X + CELL_PADDING_X + 50,$cordinates->{box5}->[1]);
	pdflib::PDF_setdash($p, 0, 0);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	$self->drawCheckBox($p,$box3X + CELL_PADDING_X + 87, $box3Y - 23);
	$self->drawCheckBox($p,$box3X + CELL_PADDING_X + 124, $box3Y - 23);
	pdflib::PDF_stroke($p);
}

sub box4
{
	my ($self, $p, $cordinates)  = @_;
	my $box4Cordinates = $cordinates->{box2};
	my $box4Y = $box4Cordinates->[1];
	my $box4X = $box4Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '4. INSURED\'S NAME (Last Name,First Name, Middle Initial)', $box4X + CELL_PADDING_X, $box4Y - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box5
{
	my ($self, $p, $cordinates)  = @_;
	my $box5Cordinates = $cordinates->{box5};
	my $box5Y = $box5Cordinates->[1];
	my $box5X = $box5Cordinates->[0] ;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '5. PATIENT\'S ADDRESS (No., Street)', $box5X + CELL_PADDING_X, $box5Y - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box5a
{
	my ($self, $p, $cordinates)  = @_;
	my $box5aCordinates = $cordinates->{box5City};
	my $box5aY = $box5aCordinates->[1];
	my $box5aX = $box5aCordinates->[0] ;
	my $stateSpace = STARTX_BOX3_SPACE - 27;
	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box5aX + $stateSpace, $box5aY, $box5aX + $stateSpace, $cordinates->{box5ZipCode}->[1]); # draw address line
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'CITY', $box5aX + CELL_PADDING_X, $box5aY - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'STATE',$box5aX + CELL_PADDING_X + $stateSpace , $box5aY - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box5b
{
	my ($self, $p, $cordinates)  = @_;
	my $box5bCordinates = $cordinates->{box5ZipCode};
	my $box5bY = $box5bCordinates->[1];
	my $box5bX = $box5bCordinates->[0] ;
	my $stateSpace = STARTX_BOX3_SPACE - 112.7;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box5bX + $stateSpace, $box5bY, $box5bX + $stateSpace,$cordinates->{box9}->[1]); # draw address line
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	pdflib::PDF_stroke($p);
	pdflib::PDF_show_xy($p , 'ZIP CODE', $box5bX + CELL_PADDING_X, $box5bY - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'TELEPHONE (Include Area Code)', $box5bX + $stateSpace + CELL_PADDING_X, $box5bY - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE + 5);
	pdflib::PDF_show_xy($p , '(       )', $box5bX + $stateSpace + CELL_PADDING_X + 4.5, $box5bY - CELL_PADDING_Y - 4 * (FORM_FONT_SIZE - 1));
	pdflib::PDF_stroke($p);
}

sub box6
{
	my ($self, $p, $cordinates)  = @_;
	my $box6Cordinates = $cordinates->{box5};
	my $box6Y = $box6Cordinates->[1];
	my $box6X = $box6Cordinates->[0] + STARTX_BOX3_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);

	pdflib::PDF_show_xy($p , '6. PATIENT RELATIONSHIP TO INSURED ',$box6X + CELL_PADDING_X, $box6Y - FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'Self', $box6X + CELL_PADDING_X + 8, $box6Y - 3 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'Spouse', $box6X + CELL_PADDING_X + 36, $box6Y - 3 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'Child', $box6X + CELL_PADDING_X + 72, $box6Y - 3 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'Other', $box6X + CELL_PADDING_X +107 , $box6Y - 3 * FORM_FONT_SIZE + 2);
	pdflib::PDF_stroke($p);

	$self->drawCheckBox($p,$box6X + CELL_PADDING_X + 21, $box6Y - 21);
	$self->drawCheckBox($p,$box6X + CELL_PADDING_X + 58, $box6Y - 21);
	$self->drawCheckBox($p,$box6X + CELL_PADDING_X + 87, $box6Y - 21);
	$self->drawCheckBox($p,$box6X + CELL_PADDING_X + 124, $box6Y - 21);
	pdflib::PDF_stroke($p);
}

sub box7
{
	my ($self, $p, $cordinates)  = @_;
	my $box7Cordinates = $cordinates->{box5};
	my $box7Y = $box7Cordinates->[1];
	my $box7X = $box7Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '7. INSURED\'S ADDRESS (No., Street)', $box7X + CELL_PADDING_X, $box7Y - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box7a
{
	my ($self, $p, $cordinates)  = @_;
	my $box7aCordinates = $cordinates->{box5City};
	my $box7aY = $box7aCordinates->[1];
	my $box7aX = $box7aCordinates->[0] + STARTX_BOX1A_SPACE;
	my $stateSpace = 171;
	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box7aX + $stateSpace, $box7aY, $box7aX + $stateSpace, $cordinates->{box5ZipCode}->[1]); # draw address line
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'CITY', $box7aX + CELL_PADDING_X, $box7aY - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'STATE',$box7aX + CELL_PADDING_X + $stateSpace , $box7aY - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box7b
{
	my ($self, $p, $cordinates)  = @_;
	my $box7bCordinates = $cordinates->{box5ZipCode};
	my $box7bY = $box7bCordinates->[1];
	my $box7bX = $box7bCordinates->[0] + STARTX_BOX1A_SPACE;
	my $stateSpace = 92.5;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box7bX + $stateSpace, $box7bY, $box7bX + $stateSpace,$cordinates->{box9}->[1]); # draw address line
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	pdflib::PDF_stroke($p);
	pdflib::PDF_show_xy($p , 'ZIP CODE', $box7bX + CELL_PADDING_X, $box7bY - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'TELEPHONE (Include Area Code)', $box7bX + $stateSpace + CELL_PADDING_X, $box7bY - CELL_PADDING_Y - FORM_FONT_SIZE);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE + 5);
	pdflib::PDF_show_xy($p , '(       )', $box7bX + $stateSpace + CELL_PADDING_X + 12, $box7bY - CELL_PADDING_Y - 4 * (FORM_FONT_SIZE - 1));
	pdflib::PDF_stroke($p);
}

sub box8
{
	my ($self, $p, $cordinates)  = @_;
	my $box8Cordinates = $cordinates->{box5City};
	my $box8Y = $box8Cordinates->[1];
	my $box8X = $box8Cordinates->[0] + STARTX_BOX3_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '8. PATIENT STATUS', $box8X + CELL_PADDING_X, $box8Y - FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'Single', $box8X + CELL_PADDING_X + 18, $box8Y - 3 * FORM_FONT_SIZE - 3);
	pdflib::PDF_show_xy($p , 'Married', $box8X + CELL_PADDING_X + 57, $box8Y - 3 * FORM_FONT_SIZE - 3);
	pdflib::PDF_show_xy($p , 'Other', $box8X + CELL_PADDING_X + 106, $box8Y - 3 * FORM_FONT_SIZE - 3);
	pdflib::PDF_stroke($p);
	$self->drawCheckBox($p,$box8X + CELL_PADDING_X + 36, $box8Y - 3 * FORM_FONT_SIZE - 7);
	$self->drawCheckBox($p,$box8X + CELL_PADDING_X + 80, $box8Y - 3 * FORM_FONT_SIZE - 7);
	$self->drawCheckBox($p,$box8X + CELL_PADDING_X + 123, $box8Y - 3 * FORM_FONT_SIZE - 7);
	pdflib::PDF_stroke($p);
	$box8Cordinates = $cordinates->{box5ZipCode};
	$box8Y = $box8Cordinates->[1];
	$box8X = $box8Cordinates->[0] + STARTX_BOX3_SPACE;
	pdflib::PDF_show_xy($p , 'Employed', $box8X + CELL_PADDING_X + 8, $box8Y - 3 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'Full-Time', $box8X + CELL_PADDING_X + 54, $box8Y - 4 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'Student', $box8X + CELL_PADDING_X + 54, $box8Y - 3 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'Part-Time', $box8X + CELL_PADDING_X + 96, $box8Y - 3 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'Student', $box8X + CELL_PADDING_X + 96, $box8Y - 4 * FORM_FONT_SIZE + 2);
	pdflib::PDF_stroke($p);
	$self->drawCheckBox($p,$box8X + CELL_PADDING_X + 36, $box8Y - 3 * FORM_FONT_SIZE - 6);
	$self->drawCheckBox($p,$box8X + CELL_PADDING_X + 80, $box8Y - 3 * FORM_FONT_SIZE - 6);
	$self->drawCheckBox($p,$box8X + CELL_PADDING_X + 123, $box8Y - 3 * FORM_FONT_SIZE - 6);
	pdflib::PDF_stroke($p);
}

sub box9
{
	my ($self, $p, $cordinates)  = @_;
	my $box9Cordinates = $cordinates->{box9};
	my $box9Y = $box9Cordinates->[1];
	my $box9X = $box9Cordinates->[0] ;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '9. OTHER INSURED\'S NAME (Last Name, First Name, Middle Initial)', $box9X + CELL_PADDING_X, $box9Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);

}

sub box9a
{
	my ($self, $p, $cordinates)  = @_;
	my $box9aCordinates = $cordinates->{box9a};
	my $box9aY = $box9aCordinates->[1];
	my $box9aX = $box9aCordinates->[0] ;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'a. OTHER INSURED\'S POLICY OR GROUP NUMBER', $box9aX + CELL_PADDING_X, $box9aY - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);

}

sub box9b
{
	my ($self, $p, $cordinates)  = @_;
	my $box9bCordinates = $cordinates->{box9b};
	my $box9bY = $box9bCordinates->[1];
	my $box9bX = $box9bCordinates->[0] ;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'b. OTHER INSURED\'S DATE OF BIRTH', $box9bX + CELL_PADDING_X, $box9bY - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'MM        DD        YY', $box9bX + CELL_PADDING_X + 6, $box9bY - 2 * FORM_FONT_SIZE - 2);
	pdflib::PDF_show_xy($p , 'SEX', $box9bX + CELL_PADDING_X + 135, $box9bY -  2 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'M',  $box9bX + CELL_PADDING_X + 113, $box9bY - 3 * FORM_FONT_SIZE - 3);
	pdflib::PDF_show_xy($p , 'F', $box9bX + CELL_PADDING_X + 156, $box9bY - 3 * FORM_FONT_SIZE - 3);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	$self->drawLine($p, $box9bX + 25, $cordinates->{box9c}->[1] + DATE_LINE_HEIGHT, $box9bX + 25,$cordinates->{box9c}->[1]);
	$self->drawLine($p, $box9bX + 48, $cordinates->{box9c}->[1] + DATE_LINE_HEIGHT, $box9bX + 48,$cordinates->{box9c}->[1]);
	pdflib::PDF_setdash($p, 0, 0);
	$self->drawLine($p, $box9bX + 107, $cordinates->{box9c}->[1] + DATE_LINE_HEIGHT, $box9bX + 107,$cordinates->{box9c}->[1]);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	$self->drawCheckBox($p,$box9bX + CELL_PADDING_X + 120, $box9bY - 23);
	$self->drawCheckBox($p,$box9bX + CELL_PADDING_X + 162, $box9bY - 23);
	pdflib::PDF_stroke($p);
}

sub box9c
{
	my ($self, $p, $cordinates)  = @_;
	my $box9cCordinates = $cordinates->{box9c};
	my $box9cY = $box9cCordinates->[1];
	my $box9cX = $box9cCordinates->[0] ;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'c. EMPLOYER\'S NAME OR SCHOOL NAME', $box9cX + CELL_PADDING_X, $box9cY - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);

}

sub box9d
{
	my ($self, $p, $cordinates)  = @_;
	my $box9dCordinates = $cordinates->{box9d};
	my $box9dY = $box9dCordinates->[1];
	my $box9dX = $box9dCordinates->[0] ;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'd. INSURANCE PLAN NAME OR PROGRAM NAME',  $box9dX + CELL_PADDING_X, $box9dY - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);

}
sub box10
{
	my ($self, $p, $cordinates)  = @_;
	my $box10Cordinates = $cordinates->{box9};
	my $box10Y = $box10Cordinates->[1];
	my $box10X = $box10Cordinates->[0] + STARTX_BOX3_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '10. IS PATIENT\'S CONDITION RELATED TO:', $box10X + CELL_PADDING_X, $box10Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
	$box10Cordinates = $cordinates->{box9a};
	$box10Y = $box10Cordinates->[1];
	$box10X = $box10Cordinates->[0] + STARTX_BOX3_SPACE;
	pdflib::PDF_show_xy($p , 'a. EMPLOYMENT? (CURRENT OR PREVIOUS)', $box10X + CELL_PADDING_X, $box10Y - FORM_FONT_SIZE - 1);
	$self->drawCheckBox($p,$box10X + CELL_PADDING_X + 36, $box10Y - 3 * FORM_FONT_SIZE - 6);
	$self->drawCheckBox($p,$box10X + CELL_PADDING_X + 80, $box10Y - 3 * FORM_FONT_SIZE - 6);
	pdflib::PDF_stroke($p);
	pdflib::PDF_show_xy($p , 'YES', $box10X + CELL_PADDING_X + 48, $box10Y - 2 * FORM_FONT_SIZE - 7);
	pdflib::PDF_show_xy($p , 'NO', $box10X + CELL_PADDING_X + 92, $box10Y - 2 * FORM_FONT_SIZE - 7);
	pdflib::PDF_stroke($p);
	$box10Cordinates = $cordinates->{box9b};
	$box10Y = $box10Cordinates->[1];
	$box10X = $box10Cordinates->[0] + STARTX_BOX3_SPACE;
	pdflib::PDF_show_xy($p , 'b. AUTO ACCIDENT?                       PLACE (State)', $box10X + CELL_PADDING_X, $box10Y - FORM_FONT_SIZE - 1);
	$self->drawCheckBox($p,$box10X + CELL_PADDING_X + 36, $box10Y - 3 * FORM_FONT_SIZE - 6);
	$self->drawCheckBox($p,$box10X + CELL_PADDING_X + 80, $box10Y - 3 * FORM_FONT_SIZE - 6);
	pdflib::PDF_stroke($p);
	pdflib::PDF_show_xy($p , 'YES', $box10X + CELL_PADDING_X + 48, $box10Y - 2 * FORM_FONT_SIZE - 7);
	pdflib::PDF_show_xy($p , 'NO', $box10X + CELL_PADDING_X + 92, $box10Y - 2 * FORM_FONT_SIZE - 7);
	pdflib::PDF_show_xy($p , '|______|', $box10X + CELL_PADDING_X + 109, $box10Y - 3 * FORM_FONT_SIZE - 5);

	pdflib::PDF_stroke($p);
	$box10Cordinates = $cordinates->{box9c};
	$box10Y = $box10Cordinates->[1];
	$box10X = $box10Cordinates->[0] + STARTX_BOX3_SPACE;
	pdflib::PDF_show_xy($p , 'c. OTHER ACCIDENT?', $box10X + CELL_PADDING_X, $box10Y - FORM_FONT_SIZE - 1);
	$self->drawCheckBox($p,$box10X + CELL_PADDING_X + 36, $box10Y - 3 * FORM_FONT_SIZE - 2);
	$self->drawCheckBox($p,$box10X + CELL_PADDING_X + 80, $box10Y - 3 * FORM_FONT_SIZE - 2);
	pdflib::PDF_stroke($p);
	pdflib::PDF_show_xy($p , 'YES', $box10X + CELL_PADDING_X + 48, $box10Y - 2 * FORM_FONT_SIZE - 7);
	pdflib::PDF_show_xy($p , 'NO', $box10X + CELL_PADDING_X + 92, $box10Y - 2 * FORM_FONT_SIZE - 7);
	pdflib::PDF_stroke($p);



}

sub box10d
{
	my ($self, $p, $cordinates)  = @_;
	my $box10dCordinates = $cordinates->{box9d};
	my $box10dY = $box10dCordinates->[1];
	my $box10dX = $box10dCordinates->[0] + STARTX_BOX3_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '10d. RESERVED FOR LOCAL USE', $box10dX + CELL_PADDING_X, $box10dY - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);

}

sub box11
{
	my ($self, $p, $cordinates)  = @_;
	my $box11Cordinates = $cordinates->{box9};
	my $box11Y = $box11Cordinates->[1];
	my $box11X = $box11Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '11. INSURED\'S POLICY GROUP OR FECA NUMBER', $box11X + CELL_PADDING_X, $box11Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
}


sub box11a
{
	my ($self, $p, $cordinates)  = @_;
	my $box11aCordinates = $cordinates->{box9a};
	my $box11aY = $box11aCordinates->[1];
	my $box11aX = $box11aCordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'a. INSURED\'S DATE OF BIRTH', $box11aX + CELL_PADDING_X , $box11aY - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'MM        DD        YY', $box11aX + CELL_PADDING_X + 29, $box11aY - 2 * FORM_FONT_SIZE - 2);
	pdflib::PDF_show_xy($p , 'SEX', $box11aX + CELL_PADDING_X + 151, $box11aY -  2 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'M',  $box11aX + CELL_PADDING_X + 119, $box11aY - 3 * FORM_FONT_SIZE -1);
	pdflib::PDF_show_xy($p , 'F', $box11aX + CELL_PADDING_X + 173, $box11aY - 3 * FORM_FONT_SIZE -1);
	pdflib::PDF_stroke($p);

	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box11aX + 47, $cordinates->{box9b}->[1] + DATE_LINE_HEIGHT , $box11aX + 47,$cordinates->{box9b}->[1]);
	$self->drawLine($p, $box11aX + 69, $cordinates->{box9b}->[1] + DATE_LINE_HEIGHT , $box11aX + 69,$cordinates->{box9b}->[1]);
	pdflib::PDF_setdash($p, 0, 0);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	$self->drawCheckBox($p,$box11aX + CELL_PADDING_X + 127, $box11aY - 22);
	$self->drawCheckBox($p,$box11aX + CELL_PADDING_X + 179, $box11aY - 22);
	pdflib::PDF_stroke($p);
}

sub box11b
{
	my ($self, $p, $cordinates)  = @_;
	my $box11bCordinates = $cordinates->{box9b};
	my $box11bY = $box11bCordinates->[1];
	my $box11bX = $box11bCordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'b. EMPLOYER\'S NAME OR SCHOOL NAME', $box11bX + CELL_PADDING_X, $box11bY - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
}

sub box11c
{
	my ($self, $p, $cordinates)  = @_;
	my $box11cCordinates = $cordinates->{box9c};
	my $box11cY = $box11cCordinates->[1];
	my $box11cX = $box11cCordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'c. INSURANCE PLAN NAME OR PROGRAM NAME', $box11cX + CELL_PADDING_X, $box11cY - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
}

sub box11d
{
	my ($self, $p, $cordinates)  = @_;
	my $box11dCordinates = $cordinates->{box9d};
	my $box11dY = $box11dCordinates->[1];
	my $box11dX = $box11dCordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);

	pdflib::PDF_show_xy($p , 'd. IS THERE ANOTHER HEALTH BENEFIT PLAN?', $box11dX + CELL_PADDING_X, $box11dY - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'YES', $box11dX + CELL_PADDING_X + 27, $cordinates->{box12}->[1] + 2 );
	pdflib::PDF_show_xy($p , 'NO', $box11dX + CELL_PADDING_X + 63, $cordinates->{box12}->[1] + 2);
	pdflib::PDF_show_xy($p , 'return to and complete item 9 a-d.', $box11dX + CELL_PADDING_X + 105, $cordinates->{box12}->[1] + 2);
	pdflib::PDF_stroke($p);

	$font = pdflib::PDF_findfont($p, "Times-BoldItalic", "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'if yes,', $box11dX + CELL_PADDING_X + 90, $cordinates->{box12}->[1] + 2);
	pdflib::PDF_stroke($p);
	$self->drawCheckBox($p,$box11dX + CELL_PADDING_X + 13.5, $cordinates->{box12}->[1] + 1);
	$self->drawCheckBox($p,$box11dX + CELL_PADDING_X + 50, $cordinates->{box12}->[1] + 1);
	pdflib::PDF_stroke($p);
}

sub box12
{
	my ($self, $p, $cordinates)  = @_;
	my $box12Cordinates = $cordinates->{box12};
	my $box12Y = $box12Cordinates->[1];
	my $box12X = $box12Cordinates->[0];
	my $capAlign = 10;
	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME . '-Bold' , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'READ BACK OF FORM BEFOE COMPLETING & SIGNING THIS FORM', $box12X + CELL_PADDING_X + 70, $box12Y - FORM_FONT_SIZE - 1);
	$font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '12. PATIENT\'S OR AUTHORIZED PERSON\'S SIGNATURE', $box12X + CELL_PADDING_X, $box12Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'I authorize the release of any medical or other information necessary', $box12X + CELL_PADDING_X + 165 , $box12Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'to process this claim. I also request payment of government benefits either to myself or to the party who accepts assignment', $box12X + CELL_PADDING_X + $capAlign, $box12Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'below.', $box12X + CELL_PADDING_X + $capAlign, $box12Y - 4 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'SIGNED_____________________________________________________', $box12X + CELL_PADDING_X + $capAlign, $box12Y - 7 * FORM_FONT_SIZE - 3.5);
	pdflib::PDF_show_xy($p , 'DATE______________________________', $box12X + CELL_PADDING_X + 232, $box12Y - 7 * FORM_FONT_SIZE - 3.5);
	pdflib::PDF_stroke($p);
}

sub box13
{
	my ($self, $p, $cordinates)  = @_;
	my $box13Cordinates = $cordinates->{box12};
	my $box13Y = $box13Cordinates->[1];
	my $box13X = $box13Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '13. INSURED\'S OR AUTHORIZED PERSON\'S SIGNATURE I authorize', $box13X + CELL_PADDING_X, $box13Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'payment of medical benefits to the undersigned physician or supplier for',$box13X + CELL_PADDING_X + 10, $box13Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'sevices described below.', $box13X + CELL_PADDING_X + 10, $box13Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'SIGNED_____________________________________________________', $box13X + CELL_PADDING_X + 14, $box13Y - 7 * FORM_FONT_SIZE - 3.5);
	pdflib::PDF_stroke($p);
}

sub box14
{
	my ($self, $p, $cordinates)  = @_;
	my $box14Cordinates = $cordinates->{box14};
	my $box14Y = $box14Cordinates->[1];
	my $box14X = $box14Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);

	pdflib::PDF_show_xy($p , '14. DATE OF CURRENT:', $box14X + CELL_PADDING_X, $box14Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'MM        DD        YY', $box14X + CELL_PADDING_X + 6, $box14Y - 2 * FORM_FONT_SIZE - 2);
	pdflib::PDF_show_xy($p , 'ILLNESS (First symptom) OR', $box14X + CELL_PADDING_X + 85, $box14Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'INJURY (Accident) OR', $box14X + CELL_PADDING_X + 85, $box14Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'PREGNANCY (LMP)', $box14X + CELL_PADDING_X + 85, $box14Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box14X + 25, $box14Y  -  FORM_FONT_SIZE - 3, $box14X + 25,$cordinates->{box17}->[1]);
	$self->drawLine($p, $box14X + 48, $box14Y  -  FORM_FONT_SIZE - 3, $box14X + 48,$cordinates->{box17}->[1]);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
	pdflib::PDF_setdash($p, 0, 0);
	$self->drawPoly($p,[$box14X + 83,$box14X + 83, $box14X + 77],[$cordinates->{box14}->[1] - 2, $cordinates->{box17}->[1] + 2, ($cordinates->{box14}->[1] - 2 + $cordinates->{box17}->[1] + 2) /2]);
}

sub box15
{
	my ($self, $p, $cordinates)  = @_;
	my $box15Cordinates = $cordinates->{box15};
	my $box15Y = $box15Cordinates->[1];
	my $box15X = $box15Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '15. IF PATIENT HAS HAD SAME OR SIMILAR ILLNESS.', $box15X + CELL_PADDING_X, $box15Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'GIVE FIRST DATE    MM        DD        YY', $box15X + CELL_PADDING_X + 11, $box15Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box15X + 87, $box15Y  -  FORM_FONT_SIZE - 3, $box15X + 87, $cordinates->{box17}->[1]);
	$self->drawLine($p, $box15X + 108, $box15Y  -  FORM_FONT_SIZE - 3, $box15X + 108, $cordinates->{box17}->[1]);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setdash($p, 0, 0);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
}

sub box16
{
	my ($self, $p, $cordinates)  = @_;
	my $box16Cordinates = $cordinates->{box14};
	my $box16Y = $box16Cordinates->[1];
	my $box16X = $box16Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '16. DATES PATIENT UNABLE TO WORK IN CURRENT OCCUPATION', $box16X + CELL_PADDING_X, $box16Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'MM        DD        YY', $box16X + CELL_PADDING_X + 28, $box16Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'MM        DD        YY', $box16X + CELL_PADDING_X + 129, $box16Y - 2 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p , 'FROM', $box16X + CELL_PADDING_X + 10, $box16Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'TO', $box16X + CELL_PADDING_X + 120, $box16Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	$self->drawLine($p, $box16X + 47, $cordinates->{box17}->[1] + DATE_LINE_HEIGHT , $box16X + 47,$cordinates->{box17}->[1]);
	$self->drawLine($p, $box16X + 70, $cordinates->{box17}->[1] + DATE_LINE_HEIGHT , $box16X + 70,$cordinates->{box17}->[1]);
	$self->drawLine($p, $box16X + 149, $cordinates->{box17}->[1] + DATE_LINE_HEIGHT , $box16X + 149,$cordinates->{box17}->[1]);
	$self->drawLine($p, $box16X + 171, $cordinates->{box17}->[1] + DATE_LINE_HEIGHT , $box16X + 171,$cordinates->{box17}->[1]);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setdash($p, 0, 0);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
}

sub box17
{
	my ($self, $p, $cordinates)  = @_;
	my $box17Cordinates = $cordinates->{box17};
	my $box17Y = $box17Cordinates->[1];
	my $box17X = $box17Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '17. NAME OF REFERRING PHYSICIAN OR OTHER SOURCE', $box17X + CELL_PADDING_X, $box17Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
}

sub box17a
{
	my ($self, $p, $cordinates)  = @_;
	my $box17aCordinates = $cordinates->{box17a};
	my $box17aY = $box17aCordinates->[1];
	my $box17aX = $box17aCordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '17a.  I.D. NUMBER OF REFERRING PHYSICIAN', $box17aX + CELL_PADDING_X, $box17aY - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
}

sub box18
{
	my ($self, $p, $cordinates)  = @_;
	my $box18Cordinates = $cordinates->{box17};
	my $box18Y = $box18Cordinates->[1];
	my $box18X = $box18Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '18. HOSPITALIZATION DATES RELATED TO CURRENT SERVICES', $box18X + CELL_PADDING_X, $box18Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'MM        DD        YY', $box18X + CELL_PADDING_X + 28, $box18Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'MM        DD        YY', $box18X + CELL_PADDING_X + 129, $box18Y - 2 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p , 'FROM', $box18X + CELL_PADDING_X + 10, $box18Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'TO', $box18X + CELL_PADDING_X + 120, $box18Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box18X + 47, $cordinates->{box19}->[1] + DATE_LINE_HEIGHT , $box18X + 47,$cordinates->{box19}->[1]);
	$self->drawLine($p, $box18X + 70, $cordinates->{box19}->[1] + DATE_LINE_HEIGHT , $box18X + 70,$cordinates->{box19}->[1]);
	$self->drawLine($p, $box18X + 149, $cordinates->{box19}->[1] + DATE_LINE_HEIGHT , $box18X + 149,$cordinates->{box19}->[1]);
	$self->drawLine($p, $box18X + 171, $cordinates->{box19}->[1] + DATE_LINE_HEIGHT , $box18X + 171,$cordinates->{box19}->[1]);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setdash($p, 0, 0);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);

}

sub box19
{
	my ($self, $p, $cordinates)  = @_;
	my $box17aCordinates = $cordinates->{box19};
	my $box17aY = $box17aCordinates->[1];
	my $box17aX = $box17aCordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '19. RESERVED FOR LOCAL USE', $box17aX + CELL_PADDING_X, $box17aY - FORM_FONT_SIZE - 1);

	pdflib::PDF_stroke($p);

}

sub box20
{
	my ($self, $p, $cordinates)  = @_;
	my $box20Cordinates = $cordinates->{box19};
	my $box20Y = $box20Cordinates->[1];
	my $box20X = $box20Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);

	pdflib::PDF_show_xy($p , '20. OUTSIDE LAB?                               $ CHARGES', $box20X + CELL_PADDING_X, $box20Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'YES', $box20X + CELL_PADDING_X + 27, $cordinates->{box21}->[1] + 2 );
	pdflib::PDF_show_xy($p , 'NO', $box20X + CELL_PADDING_X + 63, $cordinates->{box21}->[1] + 2);
	pdflib::PDF_stroke($p);
	$self->drawCheckBox($p,$box20X + CELL_PADDING_X + 13.5, $cordinates->{box21}->[1] + 1);
	$self->drawCheckBox($p,$box20X + CELL_PADDING_X + 50, $cordinates->{box21}->[1] + 1);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box20X + 82, $cordinates->{box21}->[1] + DATE_LINE_HEIGHT , $box20X + 82,$cordinates->{box21}->[1]);
	$self->drawLine($p, $box20X + 152, $cordinates->{box21}->[1] + DATE_LINE_HEIGHT , $box20X + 152,$cordinates->{box21}->[1]);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
}

sub box21
{
	my ($self, $p, $cordinates)  = @_;
	my $box21Cordinates = $cordinates->{box21};
	my $box21Y = $box21Cordinates->[1];
	my $box21X = $box21Cordinates->[0];
	my $capAlign = 4;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '21. DIAGNOSIS OR NATURE OF ILLNESS OR INJURY. (RELATE ITEMS 1,2,3 OR 4 TO ITEM 24E BY LINE)', $box21X + CELL_PADDING_X, $box21Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , '1. |________.__', $box21X + CELL_PADDING_X + $capAlign, $box21Y - 4 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , '2. |________.__', $box21X + CELL_PADDING_X + $capAlign, $box21Y - 8 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , '3. |________.__', $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3, $box21Y - 4 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , '4. |________.__', $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3, $box21Y - 8 * FORM_FONT_SIZE + 2);
	pdflib::PDF_stroke($p);

	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box21X + CELL_PADDING_X + 297, $box21Y - FORM_FONT_SIZE +2, $box21X + CELL_PADDING_X + 323, $box21Y - FORM_FONT_SIZE + 2);
	$self->drawLine($p, $box21X + 325, $box21Y - FORM_FONT_SIZE + 2, $box21X + 325,$box21Y - FORM_FONT_SIZE - 1 - DATE_LINE_HEIGHT);
	$self->drawPoly($p,[$box21X + 320, $box21X + 325, $box21X + 330],[$box21Y - FORM_FONT_SIZE - DATE_LINE_HEIGHT + 3, $box21Y - FORM_FONT_SIZE - DATE_LINE_HEIGHT - 5 + 3, $box21Y - FORM_FONT_SIZE - DATE_LINE_HEIGHT + 3]);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
}

sub box22
{
	my ($self, $p, $cordinates)  = @_;
	my $box22Cordinates = $cordinates->{box21};
	my $box22Y = $box22Cordinates->[1];
	my $box22X = $box22Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '22. MEDICAID RESUBMISSION', $box22X + CELL_PADDING_X, $box22Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'CODE                                       ORIGINAL REF. NO.', $box22X + CELL_PADDING_X + 10, $box22Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);

	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box22X + 82, $cordinates->{box23}->[1] + DATE_LINE_HEIGHT , $box22X + 82,$cordinates->{box23}->[1]);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
}

sub box23
{
	my ($self, $p, $cordinates)  = @_;
	my $box23Cordinates = $cordinates->{box23};
	my $box23Y = $box23Cordinates->[1];
	my $box23X = $box23Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '23. PRIOR AUTHORIZATION NUMBER', $box23X + CELL_PADDING_X, $box23Y - FORM_FONT_SIZE - 1);

	pdflib::PDF_stroke($p);
}

sub box24
{
	my ($self, $p, $cordinates)  = @_;
	my $box24Cordinates = $cordinates->{box24};
	my $box24Y = $box24Cordinates->[1];
	my $box24X = $box24Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);

	$box24Cordinates = $cordinates->{box24};
	$box24Y = $box24Cordinates->[1];
	$box24X = $box24Cordinates->[0];

	pdflib::PDF_show_xy($p , '24.        A', $box24X + CELL_PADDING_X, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'B', $box24X + CELL_PADDING_X + STARTX_BOX24B_SPACE + 7, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'C', $box24X + CELL_PADDING_X + STARTX_BOX24C_SPACE + 10, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'D', $box24X + CELL_PADDING_X + STARTX_BOX24D_SPACE + 52, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'E', $box24X + CELL_PADDING_X + STARTX_BOX24E_SPACE + 30, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'F', $box24X + CELL_PADDING_X + STARTX_BOX24F_SPACE + 30, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'G', $box24X + CELL_PADDING_X + STARTX_BOX24G_SPACE + 8, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'H', $box24X + CELL_PADDING_X + STARTX_BOX24H_SPACE + 8, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'I', $box24X + CELL_PADDING_X + STARTX_BOX24I_SPACE + 9, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'J', $box24X + CELL_PADDING_X + STARTX_BOX24J_SPACE + 6, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'K', $box24X + CELL_PADDING_X + STARTX_BOX24K_SPACE + 27, $box24Y - FORM_FONT_SIZE - 1);

	$box24Cordinates = $cordinates->{box24HeadA};
	$box24Y = $box24Cordinates->[1];
	$box24X = $box24Cordinates->[0];
	pdflib::PDF_show_xy($p, 'DATE(S)   OF   SERVICE', $box24X + CELL_PADDING_X + 32, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'From                                     To',$box24X + CELL_PADDING_X + 25, $box24Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'MM        DD        YY',$box24X + CELL_PADDING_X + 4, $box24Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'MM        DD        YY',$box24X + CELL_PADDING_X + STARTX_BOX24ADATE_SPACE + 2, $box24Y - 3 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p, 'Place', $box24X + STARTX_BOX24B_SPACE + CELL_PADDING_X + 2, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'of', $box24X + STARTX_BOX24B_SPACE + CELL_PADDING_X + 5, $box24Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'Service',$box24X + STARTX_BOX24B_SPACE  + 1, $box24Y - 3 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p, 'Type', $box24X + STARTX_BOX24C_SPACE + CELL_PADDING_X + 3, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'of', $box24X + STARTX_BOX24C_SPACE + CELL_PADDING_X + 5, $box24Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'Service', $box24X + STARTX_BOX24C_SPACE  + 1.5, $box24Y - 3 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p, 'PROCEDURES, SERVICES, OR SUPPLIES', $box24X + STARTX_BOX24D_SPACE, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, '     (Explain Unusual Circumstances)', $box24X + STARTX_BOX24D_SPACE + CELL_PADDING_X + 16, $box24Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'CPT/HCPCS      |    MODIFIER', $box24X + STARTX_BOX24D_SPACE + CELL_PADDING_X + 2, $box24Y - 3 * FORM_FONT_SIZE - 2);

	pdflib::PDF_show_xy($p, 'DIAGNOSIS', $box24X + STARTX_BOX24E_SPACE + CELL_PADDING_X + 14, $box24Y - 2 * FORM_FONT_SIZE + 4);
	pdflib::PDF_show_xy($p, 'CODE', $box24X + STARTX_BOX24E_SPACE + CELL_PADDING_X + 20, $box24Y - 3 * FORM_FONT_SIZE + 4);

	pdflib::PDF_show_xy($p, '$ CHARGES', $box24X + STARTX_BOX24F_SPACE + CELL_PADDING_X + 14, $box24Y - 3 * FORM_FONT_SIZE + 4);

	pdflib::PDF_show_xy($p, 'DAYS', $box24X + STARTX_BOX24G_SPACE + CELL_PADDING_X, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'OR', $box24X + STARTX_BOX24G_SPACE + CELL_PADDING_X + 2, $box24Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'UNITS', $box24X + STARTX_BOX24G_SPACE + 1, $box24Y - 3 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p, 'EPSDT', $box24X + STARTX_BOX24H_SPACE + CELL_PADDING_X, $box24Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'Family', $box24X + STARTX_BOX24H_SPACE + CELL_PADDING_X, $box24Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p, 'Plan', $box24X + STARTX_BOX24H_SPACE + CELL_PADDING_X + 2, $box24Y - 3 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p, 'EMG', $box24X + STARTX_BOX24I_SPACE + CELL_PADDING_X + 1, $box24Y - 2 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p, 'COB', $box24X + STARTX_BOX24J_SPACE + CELL_PADDING_X + 2, $box24Y - 2 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p, 'RESERVED FOR', $box24X + STARTX_BOX24K_SPACE + CELL_PADDING_X + 4, $box24Y -  2 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p, 'LOCAL USE', $box24X + STARTX_BOX24K_SPACE + CELL_PADDING_X + 8, $box24Y - 3 * FORM_FONT_SIZE + 2);

	pdflib::PDF_stroke($p);

	my @ys = ($cordinates->{box24_2}->[1], $cordinates->{box24_3}->[1], $cordinates->{box24_4}->[1], $cordinates->{box24_5}->[1], $cordinates->{box24_6}->[1], $cordinates->{box25}->[1]);
	my $y;
	my $i =1;
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);

	foreach $y (@ys)
	{
		pdflib::PDF_show_xy($p , $i++ , $box24X - 6 , $y + 6);

		pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
		$self->drawLine($p, $box24X + 21, $y + DATE_LINE_HEIGHT, $box24X + 21,$y);
		$self->drawLine($p, $box24X + 45, $y + DATE_LINE_HEIGHT, $box24X + 45, $y);
		$self->drawLine($p, $box24X + STARTX_BOX24ADATE_SPACE + 17, $y + DATE_LINE_HEIGHT, $box24X + STARTX_BOX24ADATE_SPACE + 17,$y);
		$self->drawLine($p, $box24X + STARTX_BOX24ADATE_SPACE + 40, $y + DATE_LINE_HEIGHT, $box24X + STARTX_BOX24ADATE_SPACE + 40, $y);
		$self->drawLine($p, $box24X + STARTX_BOX24D_SPACE + 70, $y + DATE_LINE_HEIGHT, $box24X + STARTX_BOX24D_SPACE + 70, $y);
		pdflib::PDF_setdash($p, 0, 0);
		$self->drawLine($p, $box24X + STARTX_BOX24D_SPACE + 49, $y + DATE_LINE_HEIGHT, $box24X + STARTX_BOX24D_SPACE + 49, $y);
		pdflib::PDF_stroke($p);
	}
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);

}

sub box25
{
	my ($self, $p, $cordinates)  = @_;
	my $box25Cordinates = $cordinates->{box25};
	my $box25Y = $box25Cordinates->[1];
	my $box25X = $box25Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '25. FEDERAL TAX I.D. NUMBER', $box25X + CELL_PADDING_X, $box25Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'SSN  EIN', $box25X + CELL_PADDING_X + 110, $box25Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);

	$self->drawCheckBox($p,$box25X + CELL_PADDING_X + 112.5, $cordinates->{box31}->[1] + 1);
	$self->drawCheckBox($p,$box25X + CELL_PADDING_X + 126, $cordinates->{box31}->[1] + 1);

	pdflib::PDF_stroke($p);
}

sub box26
{
	my ($self, $p, $cordinates)  = @_;
	my $box26Cordinates = $cordinates->{box26};
	my $box26Y = $box26Cordinates->[1];
	my $box26X = $box26Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '26. PATIENT\'S ACCOUNT NUMBER', $box26X + CELL_PADDING_X, $box26Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
}

sub box27
{
	my ($self, $p, $cordinates)  = @_;
	my $box27Cordinates = $cordinates->{box27};
	my $box27Y = $box27Cordinates->[1];
	my $box27X = $box27Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '27. ACCEPT ASSIGNMENT?', $box27X + CELL_PADDING_X, $box27Y - FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '(For govt. claims, see back)', $box27X + CELL_PADDING_X + 6, $box27Y - 2 * FORM_FONT_SIZE + 2);
	pdflib::PDF_show_xy($p , 'YES', $box27X + CELL_PADDING_X + 16, $box27Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'NO', $box27X + CELL_PADDING_X + 53 , $box27Y - 3 * FORM_FONT_SIZE - 1);

	$self->drawCheckBox($p,$box27X + CELL_PADDING_X + 1, $cordinates->{box31}->[1] + 1);
	$self->drawCheckBox($p,$box27X + CELL_PADDING_X + 39, $cordinates->{box31}->[1] + 1);
	pdflib::PDF_stroke($p);
}

sub box28
{
	my ($self, $p, $cordinates)  = @_;
	my $box28Cordinates = $cordinates->{box28};
	my $box28Y = $box28Cordinates->[1];
	my $box28X = $box28Cordinates->[0];
	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '28. TOTAL CHARGE', $box28X + CELL_PADDING_X, $box28Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , '$', $box28X + CELL_PADDING_X + 3, $box28Y - 3 *FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	$self->drawLine($p, $box28X + 56, $cordinates->{box31}->[1] + DATE_LINE_HEIGHT , $box28X + 56,$cordinates->{box31}->[1]);
	pdflib::PDF_setdash($p, 0, 0);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);

}

sub box29
{
	my ($self, $p, $cordinates)  = @_;
	my $box29Cordinates = $cordinates->{box29};
	my $box29Y = $box29Cordinates->[1];
	my $box29X = $box29Cordinates->[0];
	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '29. AMOUNT PAID', $box29X + CELL_PADDING_X, $box29Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , '$', $box29X + CELL_PADDING_X + 4, $box29Y - 3 *FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box29X + 50, $cordinates->{box31}->[1] + DATE_LINE_HEIGHT , $box29X + 50,$cordinates->{box31}->[1]);
	pdflib::PDF_setdash($p, 0, 0);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
}

sub box30
{
	my ($self, $p, $cordinates)  = @_;
	my $box30Cordinates = $cordinates->{box30};
	my $box30Y = $box30Cordinates->[1];
	my $box30X = $box30Cordinates->[0];
	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '30. BALANCE DUE', $box30X + CELL_PADDING_X, $box30Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , '$', $box30X + CELL_PADDING_X + 4, $box30Y - 3 *FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
	pdflib::PDF_setdash($p, BLACK_DASH, WHITE_DASH);
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box30X + 45, $cordinates->{box31}->[1] + DATE_LINE_HEIGHT , $box30X + 45,$cordinates->{box31}->[1]);
	pdflib::PDF_setdash($p, 0, 0);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);
}

sub box31
{
	my ($self, $p, $cordinates)  = @_;
	my $box31Cordinates = $cordinates->{box31};
	my $box31Y = $box31Cordinates->[1];
	my $box31X = $box31Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '31. SIGNATURE OF PHYSICIAN OR SUPPLIER', $box31X + CELL_PADDING_X, $box31Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'INCLUDING DEGREES OR CREDENTIALS' , $box31X + CELL_PADDING_X + 10, $box31Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , '(I certify that the statements on the reverse',$box31X + CELL_PADDING_X + 10, $box31Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'apply to this bill and are made a part thereof.)', $box31X + CELL_PADDING_X + 10, $box31Y - 4 * FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'SIGNED', $box31X + CELL_PADDING_X, START_Y + 2);
	pdflib::PDF_show_xy($p , 'DATE', $box31X + CELL_PADDING_X + 108, START_Y + 2);

	pdflib::PDF_stroke($p);
}

sub box32
{
	my ($self, $p, $cordinates)  = @_;
	my $box32Cordinates = $cordinates->{box32};
	my $box32Y = $box32Cordinates->[1];
	my $box32X = $box32Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE - 0.5);
	pdflib::PDF_show_xy($p , '32. NAME AND ADDRESS OF FACILITY WHERE SERVICES WERE', $box32X + CELL_PADDING_X , $box32Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , 'RENDERED (if other than home or office)', $box32X + CELL_PADDING_X + 10, $box32Y - 2 * FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
}

sub box33
{
	my ($self, $p, $cordinates)  = @_;
	my $box33Cordinates = $cordinates->{box33};
	my $box33Y = $box33Cordinates->[1];
	my $box33X = $box33Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, FORM_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , '33. PHYSICIAN\'S, SUPPLIER\'S BILLING NAME, ADDRESS, ZIP CODE', $box33X + CELL_PADDING_X , $box33Y - FORM_FONT_SIZE - 1);
	pdflib::PDF_show_xy($p , '& PHONE #', $box33X + CELL_PADDING_X + 10, $box33Y - 2 * FORM_FONT_SIZE - 1);

	pdflib::PDF_show_xy($p , 'PIN#', $box33X + CELL_PADDING_X , START_Y + 2);
	pdflib::PDF_show_xy($p , 'GRP#', $box33X + CELL_PADDING_X + 103, START_Y + 2);

	pdflib::PDF_stroke($p);

	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	$self->drawLine($p, $box33X + CELL_PADDING_X + 100, START_Y, $box33X + CELL_PADDING_X + 100, START_Y + DATE_LINE_HEIGHT);
	pdflib::PDF_setlinewidth($p, NORMAL_LINE_WIDTH);

}


sub populatePDF
{
	my ($self, $p, $Claim, $cordinates, $procesedProc)  = @_;

	pdflib::PDF_setrgbcolor($p, DATA_RED, DATA_GREEN, DATA_BLUE);
	if ($Claim->getInvoiceSubtype() == CLAIM_TYPE_WORKCOMP)
	{
		my $pdfWorker = new App::Billing::Output::PDF::Worker();
		$pdfWorker->populate($p, $Claim, $cordinates, $procesedProc);
	}
	else
	{
		$self->box1ClaimData($p, $Claim, $cordinates);
		$self->box1aClaimData($p, $Claim, $cordinates);
		$self->box2ClaimData($p, $Claim, $cordinates);
		$self->box3ClaimData($p, $Claim, $cordinates);
		$self->box4ClaimData($p, $Claim, $cordinates);
		$self->box5ClaimData($p, $Claim, $cordinates);
		$self->box5aClaimData($p, $Claim, $cordinates);
		$self->box5bClaimData($p, $Claim, $cordinates);
		$self->box6ClaimData($p, $Claim, $cordinates);
		$self->box7ClaimData($p, $Claim, $cordinates);
		$self->box7aClaimData($p, $Claim, $cordinates);
		$self->box7bClaimData($p, $Claim, $cordinates);
		$self->box11ClaimData($p, $Claim, $cordinates);
		$self->box8ClaimData($p, $Claim, $cordinates);
		$self->box10ClaimData($p, $Claim, $cordinates);
		$self->box11aClaimData($p, $Claim, $cordinates);
		$self->box11bClaimData($p, $Claim, $cordinates);
		$self->box11cClaimData($p, $Claim, $cordinates);
		$self->box11dClaimData($p, $Claim, $cordinates);
		$self->box9ClaimData($p, $Claim, $cordinates);
		$self->box9aClaimData($p, $Claim, $cordinates);
		$self->box9bClaimData($p, $Claim, $cordinates);
		$self->box9cClaimData($p, $Claim, $cordinates);
		$self->box9dClaimData($p, $Claim, $cordinates);
		$self->box12ClaimData($p, $Claim, $cordinates);
		$self->box13ClaimData($p, $Claim, $cordinates);
		$self->box14ClaimData($p, $Claim, $cordinates);
		$self->box15ClaimData($p, $Claim, $cordinates);
		$self->box16ClaimData($p, $Claim, $cordinates);
		$self->box17ClaimData($p, $Claim, $cordinates);
		$self->box17aClaimData($p, $Claim, $cordinates);
		$self->box18ClaimData($p, $Claim, $cordinates);
		$self->box20ClaimData($p, $Claim, $cordinates);
		$self->box22ClaimData($p, $Claim, $cordinates);
		$self->box23ClaimData($p, $Claim, $cordinates);
		my $dg = $self->box24ClaimData($p, $Claim, $cordinates, $procesedProc);
		$self->box21ClaimData($p, $Claim, $cordinates, $dg);
		$self->box25ClaimData($p, $Claim, $cordinates);
		$self->box26ClaimData($p, $Claim, $cordinates);
		$self->box27ClaimData($p, $Claim, $cordinates);
		$self->box28ClaimData($p, $Claim, $cordinates, $procesedProc);
		$self->box29ClaimData($p, $Claim, $cordinates, $procesedProc);
		$self->box30ClaimData($p, $Claim, $cordinates, $procesedProc);
		$self->box31ClaimData($p, $Claim, $cordinates);
		$self->box32ClaimData($p, $Claim, $cordinates);
		$self->box33ClaimData($p, $Claim, $cordinates);
		$self->carrierData($p, $Claim, $cordinates);
	}
	pdflib::PDF_setrgbcolor($p, FORM_RED, FORM_GREEN, FORM_BLUE);


}

sub box1ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box1Cordinates = $cordinates->{box1};
	my $box1Y = $box1Cordinates->[1];
	my $box1X = $box1Cordinates->[0];
	my $xCoordinate =
		{
			'MEDICARE' => $box1X + 1 + CHECKED_BOX_X,
			'MEDICAID' => $box1X + 50 + CHECKED_BOX_X,
			'CHAMPUS' => $box1X + 100 + CHECKED_BOX_X,
			'CHAMPVA' => $box1X + 165 + CHECKED_BOX_X,
			'GROUP HEALTH PLAN' => $box1X + 214 + CHECKED_BOX_X,
			'FECA' => $box1X + 272 + CHECKED_BOX_X,
			'OTHER' => $box1X + 316 + CHECKED_BOX_X,
		};

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);

	my $temp = uc($claim->getProgramName);
	pdflib::PDF_show_xy($p, 'X', $xCoordinate->{$temp} , $box1Y + CHECKED_BOX_Y - 4 * FORM_FONT_SIZE) if (defined ($xCoordinate->{$temp}));
	pdflib::PDF_stroke($p);
}

sub box1aClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box1aCordinates = $cordinates->{box1};
	my $box1Y = $box1aCordinates->[1];
	my $box1aX = $box1aCordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $claimType = $claim->getClaimType();
	my $data = $claim->{insured}->[$claimType]->getMemberNumber();
	pdflib::PDF_show_xy($p , $data , $box1aX + CELL_PADDING_X + DATA_PADDING_X, $box1Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box2ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box2Cordinates = $cordinates->{box2};
	my $box2Y = $box2Cordinates->[1];
	my $box2X = $box2Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{careReceiver}->getLastName() .", " . $claim->{careReceiver}->getFirstName() . " " . $claim->{careReceiver}->getMiddleInitial() , $box2X + CELL_PADDING_X + DATA_PADDING_X, $box2Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);

}

sub box3ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box3Cordinates = $cordinates->{box2};
	my $box3Y = $box3Cordinates->[1];
	my $box3X = $box3Cordinates->[0] + STARTX_BOX3_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $date  = $self->returnDate($claim->{careReceiver}->getDateOfBirth());

	my $temp =
		 {
			'1' => $box3X + CELL_PADDING_X + 87 + CHECKED_BOX_X,
			'2' => $box3X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'MALE' => $box3X + CELL_PADDING_X + 87 + CHECKED_BOX_X,
			'FEMALE' => $box3X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'M' => $box3X + CELL_PADDING_X + 87 + CHECKED_BOX_X,
			'F' => $box3X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
		 };
	pdflib::PDF_show_xy($p , $date->[0], $box3X + CELL_PADDING_X + 11, $box3Y - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $date->[1], $box3X + CELL_PADDING_X + 32, $box3Y - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $date->[2], $box3X + CELL_PADDING_X + 54, $box3Y - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'X', $temp->{uc($claim->{careReceiver}->getSex)}, $box3Y - 23 + CHECKED_BOX_Y ) if defined $temp->{uc($claim->{careReceiver}->getSex)};
	pdflib::PDF_stroke($p);

}


sub box4ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box4Cordinates = $cordinates->{box2};
	my $box4Y = $box4Cordinates->[1];
	my $box4X = $box4Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $claimType = $claim->getClaimType();
	my $data = $claim->{insured}->[$claimType]->getLastName() . " " . $claim->{insured}->[$claimType]->getFirstName() . " " . $claim->{insured}->[$claimType]->getMiddleInitial();
	pdflib::PDF_show_xy($p, $data , $box4X + CELL_PADDING_X + DATA_PADDING_X, $box4Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box5ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box5Cordinates = $cordinates->{box5};
	my $box5Y = $box5Cordinates->[1];
	my $box5X = $box5Cordinates->[0] ;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{careReceiver}->{address}->getAddress1(), $box5X + CELL_PADDING_X + DATA_PADDING_X, $box5Y - 2.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{careReceiver}->{address}->getAddress2(), $box5X + CELL_PADDING_X + DATA_PADDING_X, $box5Y - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);

}

sub box5aClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box5aCordinates = $cordinates->{box5City};
	my $box5aY = $box5aCordinates->[1];
	my $box5aX = $box5aCordinates->[0] ;
	my $stateSpace = STARTX_BOX3_SPACE - 27;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{careReceiver}->{address}->getCity(), $box5aX + CELL_PADDING_X  + DATA_PADDING_X, $box5aY - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($claim->{careReceiver}->{address}->getState(), 0, 5), $box5aX + CELL_PADDING_X + $stateSpace + 3 , $box5aY - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);

}

sub box5bClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box5bCordinates = $cordinates->{box5ZipCode};
	my $box5bY = $box5bCordinates->[1];
	my $box5bX = $box5bCordinates->[0] ;
	my $stateSpace = STARTX_BOX3_SPACE - 112.7;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{careReceiver}->{address}->getZipCode, $box5bX + CELL_PADDING_X + DATA_PADDING_X, $box5bY - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($claim->{careReceiver}->{address}->getTelephoneNo, 0, 3), $box5bX + $stateSpace + CELL_PADDING_X + 10, $box5bY - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($claim->{careReceiver}->{address}->getTelephoneNo, 3, 25) , $box5bX + $stateSpace + CELL_PADDING_X + 6 + 30, $box5bY - 3.5 * FORM_FONT_SIZE) if (length($claim->{careReceiver}->{address}->getTelephoneNo) > 3);
	pdflib::PDF_stroke($p);

}

sub box6ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;

	my $box6Cordinates = $cordinates->{box5};
	my $box6Y = $box6Cordinates->[1];
	my $box6X = $box6Cordinates->[0] + STARTX_BOX3_SPACE;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $temp =
		{
#			'01' => $box6X + CELL_PADDING_X + 21 + CHECKED_BOX_X,
#			'2' => $box6X + CELL_PADDING_X + 58 + CHECKED_BOX_X,
#			'3' => $box6X + CELL_PADDING_X + 87 + CHECKED_BOX_X,
#			'4' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
#			'SELF' => $box6X + CELL_PADDING_X + 21 + CHECKED_BOX_X,
#			'SPOUSE' => $box6X + CELL_PADDING_X + 58 + CHECKED_BOX_X,
#			'CHILD' => $box6X + CELL_PADDING_X + 87 + CHECKED_BOX_X,
#			'OTHER' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'01' => $box6X + CELL_PADDING_X + 21 + CHECKED_BOX_X,
			'02' => $box6X + CELL_PADDING_X + 58 + CHECKED_BOX_X,
			'03' => $box6X + CELL_PADDING_X + 87 + CHECKED_BOX_X,
			'04' => $box6X + CELL_PADDING_X + 87 + CHECKED_BOX_X,
			'05' => $box6X + CELL_PADDING_X + 87 + CHECKED_BOX_X,
			'06' => $box6X + CELL_PADDING_X + 87 + CHECKED_BOX_X,
			'07' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'08' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'09' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'10' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'11' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'12' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'13' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'50' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'14' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'15' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'16' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'17' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'18' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'19' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
			'99' => $box6X + CELL_PADDING_X + 124 + CHECKED_BOX_X,
		};

	my $claimType = $claim->getClaimType();
	pdflib::PDF_show_xy($p ,'X' , $temp->{uc($claim->{insured}->[$claimType]->getRelationshipToPatient)} , $box6Y - 21 + CHECKED_BOX_Y) if defined ($temp->{uc($claim->{insured}->[$claimType]->getRelationshipToPatient)});
	pdflib::PDF_stroke($p);
}

sub box7ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;

	my $box7Cordinates = $cordinates->{box5};
	my $box7Y = $box7Cordinates->[1];
	my $box7X = $box7Cordinates->[0] + STARTX_BOX1A_SPACE;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $claimType = $claim->getClaimType();
	my $data = $claim->{insured}->[$claimType]->getAddress();
	pdflib::PDF_show_xy($p , $data->getAddress1(), $box7X + CELL_PADDING_X + DATA_PADDING_X, $box7Y  - 2.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $data->getAddress2(), $box7X + CELL_PADDING_X + DATA_PADDING_X, $box7Y  - 3.5 * FORM_FONT_SIZE);

	pdflib::PDF_stroke($p);
}

sub box7aClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box7aCordinates = $cordinates->{box5City};
	my $box7aY = $box7aCordinates->[1];
	my $box7aX = $box7aCordinates->[0] + STARTX_BOX1A_SPACE;
	my $stateSpace = 171;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $claimType = $claim->getClaimType();
	my $data = $claim->{insured}->[$claimType]->getAddress();

	pdflib::PDF_show_xy($p , $data->getCity(),$box7aX + CELL_PADDING_X + DATA_PADDING_X, $box7aY - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($data->getState(),0,7), $box7aX + CELL_PADDING_X + $stateSpace + 3, $box7aY - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box7bClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;

	my $box7bCordinates = $cordinates->{box5ZipCode};
	my $box7bY = $box7bCordinates->[1];
	my $box7bX = $box7bCordinates->[0] + STARTX_BOX1A_SPACE;
	my $stateSpace = 92.5;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $claimType = $claim->getClaimType();
	my $data = $claim->{insured}->[$claimType]->getAddress();

	pdflib::PDF_show_xy($p , $data->getZipCode, $box7bX + CELL_PADDING_X  + DATA_PADDING_X, $box7bY - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($data->getTelephoneNo, 0, 3), $box7bX + $stateSpace + CELL_PADDING_X + 20, $box7bY - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($data->getTelephoneNo, 3, 25), $box7bX + $stateSpace + CELL_PADDING_X + 50, $box7bY - 3.5 * FORM_FONT_SIZE) if (length($data->getTelephoneNo) > 3);
	pdflib::PDF_stroke($p);
}

sub box8ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box8Cordinates = $cordinates->{box5City};
	my $box8Y = $box8Cordinates->[1];
	my $box8X = $box8Cordinates->[0] + STARTX_BOX3_SPACE;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $temp1 =
		{
			'S' =>   [$box8X + CELL_PADDING_X + 36 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'M' =>  [$box8X + CELL_PADDING_X + 80 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'U' =>    [$box8X + CELL_PADDING_X + 123 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'D' =>    [$box8X + CELL_PADDING_X + 123 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'W' =>    [$box8X + CELL_PADDING_X + 123 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'X' =>    [$box8X + CELL_PADDING_X + 123 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'P' =>    [$box8X + CELL_PADDING_X + 123 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
		};

	$box8Cordinates = $cordinates->{box5ZipCode};
	$box8Y = $box8Cordinates->[1];
	$box8X = $box8Cordinates->[0] + STARTX_BOX3_SPACE;
	my $temp2 =
		{
			'0' =>[$box8X + CELL_PADDING_X + 80 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'1' =>[$box8X + CELL_PADDING_X + 123 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'F' =>[$box8X + CELL_PADDING_X + 80 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'P' =>[$box8X + CELL_PADDING_X + 123 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'STUDENT (FULL-TIME)' =>[$box8X + CELL_PADDING_X + 80 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
			'STUDENT (PART-TIME)' =>[$box8X + CELL_PADDING_X + 123 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 7 + CHECKED_BOX_Y],
		};

	pdflib::PDF_show_xy($p , 'X', $temp1->{uc($claim->{careReceiver}->getStatus)}->[0], $temp1->{uc($claim->{careReceiver}->getStatus)}->[1]) if defined  ($temp1->{uc($claim->{careReceiver}->getStatus)});
	pdflib::PDF_show_xy($p , 'X', $box8X + CELL_PADDING_X + 36 + CHECKED_BOX_X, $box8Y - 3 * FORM_FONT_SIZE - 6 + CHECKED_BOX_Y) if (($claim->{careReceiver}->getEmploymentStatus ne '5') && ($claim->{careReceiver}->getEmploymentStatus ne ""));
	pdflib::PDF_show_xy($p , 'X', $temp2->{uc($claim->{careReceiver}->getStudentStatus)}->[0], $temp2->{uc($claim->{careReceiver}->getStudentStatus)}->[1]) if defined  ($temp2->{uc($claim->{careReceiver}->getStudentStatus)});
	pdflib::PDF_stroke($p);
}

sub box10ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $box10Cordinates = $cordinates->{box9a};
	my $box10Y = $box10Cordinates->[1];
	my $box10X = $box10Cordinates->[0] + STARTX_BOX3_SPACE;
	my $temp =
			{
				'1' => $box10X + CELL_PADDING_X + 36 + CHECKED_BOX_X,
				'0' => $box10X + CELL_PADDING_X + 80 + CHECKED_BOX_X,
				'Y' => $box10X + CELL_PADDING_X + 36 + CHECKED_BOX_X,
				'N' => $box10X + CELL_PADDING_X + 80 + CHECKED_BOX_X,
				};
	pdflib::PDF_show_xy($p , 'X', $temp->{uc($claim->getConditionRelatedToEmployment())}, $box10Y - 3 * FORM_FONT_SIZE - 6 + CHECKED_BOX_Y) if defined ($temp->{uc($claim->getConditionRelatedToEmployment)});
	$box10Cordinates = $cordinates->{box9b};
	$box10Y = $box10Cordinates->[1];
	$box10X = $box10Cordinates->[0] + STARTX_BOX3_SPACE;
	pdflib::PDF_show_xy($p , 'X', $temp->{uc($claim->getConditionRelatedToAutoAccident)}, $box10Y - 3 * FORM_FONT_SIZE - 6 + CHECKED_BOX_Y) if defined ($temp->{uc($claim->getConditionRelatedToAutoAccident)});
	pdflib::PDF_show_xy($p , uc($claim->getConditionRelatedToAutoAccidentPlace), $box10X + CELL_PADDING_X + 115, $box10Y - 3 * FORM_FONT_SIZE - 2);
	$box10Cordinates = $cordinates->{box9c};
	$box10Y = $box10Cordinates->[1];
	$box10X = $box10Cordinates->[0] + STARTX_BOX3_SPACE;
	pdflib::PDF_show_xy($p , 'X', $temp->{uc($claim->getConditionRelatedToOtherAccident)}, $box10Y - 3 * FORM_FONT_SIZE - 2 + CHECKED_BOX_Y) if defined ($temp->{uc($claim->getConditionRelatedToOtherAccident)});
	pdflib::PDF_stroke($p);
}

sub box9ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box9Cordinates = $cordinates->{box9};
	my $box9Y = $box9Cordinates->[1];
	my $box9X = $box9Cordinates->[0];
	my $claimType = $claim->getClaimType();
	my $insured1 = $claim->{insured}->[$claimType];
	my $insured2 = $claim->{insured}->[$claimType + 1];

	if (($insured1 ne "") && ($insured2 ne ""))
	{
		if ($insured2->getInsurancePlanOrProgramName ne "")
		{
			my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
			die "Couldn't set font"  if ($font == -1);
			pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
			pdflib::PDF_show_xy($p , $insured2->getLastName . " " . $insured2->getFirstName . " " . $insured2->getMiddleInitial, $box9X + CELL_PADDING_X + DATA_PADDING_X, $box9Y - 3 * FORM_FONT_SIZE - 1);
			pdflib::PDF_stroke($p);
		}
	}
}

sub box9aClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box9aCordinates = $cordinates->{box9a};
	my $box9aY = $box9aCordinates->[1];
	my $box9aX = $box9aCordinates->[0];
	my $claimType = $claim->getClaimType();
	my $insured1 = $claim->{insured}->[$claimType];
	my $insured2 = $claim->{insured}->[$claimType + 1];

	if (($insured1 ne "") && ($insured2 ne ""))
	{
		if ($insured2->getInsurancePlanOrProgramName ne "")
		{
			my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
			die "Couldn't set font"  if ($font == -1);
			pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
			if(uc($insured1->getInsurancePlanOrProgramName) eq "MEDICARE")
			{
				pdflib::PDF_show_xy($p , "MEDIGAP " . $insured2->getMemberNumber() . " " . $insured2->getPolicyGroupOrFECANo, $box9aX + CELL_PADDING_X + DATA_PADDING_X, $box9aY - 3 * FORM_FONT_SIZE - 1);
			}
			else
			{
				pdflib::PDF_show_xy($p , $insured2->getPolicyGroupOrFECANo, $box9aX + CELL_PADDING_X + DATA_PADDING_X, $box9aY - 3 * FORM_FONT_SIZE - 1);
			}
			pdflib::PDF_stroke($p);
		}
	}
}

sub box9bClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box9bCordinates = $cordinates->{box9b};
	my $box9bY = $box9bCordinates->[1];
	my $box9bX = $box9bCordinates->[0];
	my $claimType = $claim->getClaimType();
	my $insured1 = $claim->{insured}->[$claimType];
	my $insured2 = $claim->{insured}->[$claimType + 1];

	if (($insured1 ne "") && ($insured2 ne ""))
	{
		if ($insured2->getInsurancePlanOrProgramName ne "")
		{
			my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
			die "Couldn't set font"  if ($font == -1);
			pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);

			my $date  = $self->returnDate($insured2->getDateOfBirth());
			my $temp =
			 {
				'1' => $box9bX + CELL_PADDING_X + 120 + CHECKED_BOX_X,
				'2' => $box9bX + CELL_PADDING_X + 175 + CHECKED_BOX_X,
				'MALE' => $box9bX + CELL_PADDING_X + 120 + CHECKED_BOX_X,
				'FEMALE' => $box9bX + CELL_PADDING_X + 175 + CHECKED_BOX_X,
				'M' => $box9bX + CELL_PADDING_X + 120 + CHECKED_BOX_X,
				'F' => $box9bX + CELL_PADDING_X + 175 + CHECKED_BOX_X,
			 };
			if	($date->[0] ne "")
			{

				pdflib::PDF_show_xy($p , $date->[0], $box9bX + CELL_PADDING_X + DATA_PADDING_X, $box9bY - 3.5 * FORM_FONT_SIZE);
				pdflib::PDF_show_xy($p , $date->[1], $box9bX + 35, $box9bY - 3.5 * FORM_FONT_SIZE);
				pdflib::PDF_show_xy($p , $date->[2], $box9bX + 55, $box9bY - 3.5 * FORM_FONT_SIZE);
			}
			pdflib::PDF_show_xy($p , 'X', $temp->{uc($insured2->getSex())}, $box9bY - 22 + CHECKED_BOX_Y) if defined $temp->{uc($insured2->getSex())};
			pdflib::PDF_stroke($p);
		}
	}
}

sub box9cClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box9cCordinates = $cordinates->{box9c};
	my $box9cY = $box9cCordinates->[1];
	my $box9cX = $box9cCordinates->[0];

	my $claimType = $claim->getClaimType();
	my $insured1 = $claim->{insured}->[$claimType];
	my $insured2 = $claim->{insured}->[$claimType + 1];

	if (($insured1 ne "") && ($insured2 ne ""))
	{
		if ($insured2->getInsurancePlanOrProgramName ne "")
		{
			my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
			die "Couldn't set font"  if ($font == -1);
			pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
			pdflib::PDF_show_xy($p , $insured2->getEmployerOrSchoolName, $box9cX + CELL_PADDING_X + DATA_PADDING_X, $box9cY - 3 * FORM_FONT_SIZE);
			pdflib::PDF_stroke($p);
		}
	}
}

sub box9dClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box9dCordinates = $cordinates->{box9d};
	my $box9dY = $box9dCordinates->[1];
	my $box9dX = $box9dCordinates->[0];
	my $claimType = $claim->getClaimType();
	my $insured1 = $claim->{insured}->[$claimType];
	my $insured2 = $claim->{insured}->[$claimType + 1];

	if (($insured1 ne "") && ($insured2 ne ""))
	{
		if ($insured2->getInsurancePlanOrProgramName ne "")
		{
			my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
			die "Couldn't set font"  if ($font == -1);
			pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
			if(uc($insured1->getInsurancePlanOrProgramName) eq "MEDICARE")
			{
				pdflib::PDF_show_xy($p , $insured2->getMedigapNo, $box9dX + CELL_PADDING_X + DATA_PADDING_X, $box9dY - 3 * FORM_FONT_SIZE);
			}
			else
			{
				pdflib::PDF_show_xy($p , $insured2->getInsurancePlanOrProgramName, $box9dX + CELL_PADDING_X + DATA_PADDING_X, $box9dY - 3 * FORM_FONT_SIZE);
			}
			pdflib::PDF_stroke($p);
		}
	}
}

sub box11ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box11Cordinates = $cordinates->{box9};
	my $box11Y = $box11Cordinates->[1];
	my $box11X = $box11Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{insured}->[0]->getPolicyGroupOrFECANo, $box11X + CELL_PADDING_X + DATA_PADDING_X, $box11Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);

}

sub box11aClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box11aCordinates = $cordinates->{box9a};
	my $box11aY = $box11aCordinates->[1];
	my $box11aX = $box11aCordinates->[0] + STARTX_BOX1A_SPACE;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);

	my $date  = $self->returnDate($claim->{insured}->[0]->getDateOfBirth());
	my $temp =
		 {
			'1' => $box11aX + CELL_PADDING_X + 127 + CHECKED_BOX_X,
			'2' => $box11aX + CELL_PADDING_X + 179 + CHECKED_BOX_X,
			'MALE' => $box11aX + CELL_PADDING_X + 127 + CHECKED_BOX_X,
			'FEMALE' => $box11aX + CELL_PADDING_X + 179 + CHECKED_BOX_X,
			'M' => $box11aX + CELL_PADDING_X + 127 + CHECKED_BOX_X,
			'F' => $box11aX + CELL_PADDING_X + 179 + CHECKED_BOX_X,
		 };
	if 	($date->[0] ne "")
	{
		pdflib::PDF_show_xy($p , $date->[0], $box11aX + 34, $box11aY - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[1], $box11aX + 55, $box11aY - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[2], $box11aX + 72, $box11aY - 3.5 * FORM_FONT_SIZE);
	}
	pdflib::PDF_show_xy($p , 'X', $temp->{uc($claim->{insured}->[0]->getSex())}, $box11aY - 22 + CHECKED_BOX_Y) if defined $temp->{uc($claim->{insured}->[0]->getSex())};
	pdflib::PDF_stroke($p);
}

sub box11bClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box11bCordinates = $cordinates->{box9b};
	my $box11bY = $box11bCordinates->[1];
	my $box11bX = $box11bCordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{insured}->[0]->getEmployerOrSchoolName, $box11bX + CELL_PADDING_X + DATA_PADDING_X, $box11bY - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box11cClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box11cCordinates = $cordinates->{box9c};
	my $box11cY = $box11cCordinates->[1];
	my $box11cX = $box11cCordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{insured}->[0]->getInsurancePlanOrProgramName, $box11cX + CELL_PADDING_X + DATA_PADDING_X, $box11cY - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box11dClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box11dCordinates = $cordinates->{box9d};
	my $box11dY = $box11dCordinates->[1];
	my $box11dX = $box11dCordinates->[0] + STARTX_BOX1A_SPACE;
	my $claimType = $claim->getClaimType();
	my $insured1 = $claim->{insured}->[$claimType];
	my $insured2 = $claim->{insured}->[$claimType + 1];
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);

	my $temp =
			{
				'1' => $box11dX + CELL_PADDING_X + 13.5 + CHECKED_BOX_X,
				'0' => $box11dX + CELL_PADDING_X + 50 + CHECKED_BOX_X,
			};

	if (($insured1 ne "") && ($insured2 ne ""))
	{
		if (($insured1->getInsurancePlanOrProgramName ne "" ) && ($insured2->getInsurancePlanOrProgramName ne ""))
		{
			pdflib::PDF_show_xy($p , 'X', $temp->{'1'}, $cordinates->{box12}->[1] + 1 + CHECKED_BOX_Y);
		} elsif (($insured2->getInsurancePlanOrProgramName eq ""))
		{
			pdflib::PDF_show_xy($p , 'X', $temp->{'0'}, $cordinates->{box12}->[1] + 1 + CHECKED_BOX_Y);
		}
	}
	pdflib::PDF_stroke($p);
}

sub box12ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box12Cordinates = $cordinates->{box12};
	my $box12Y = $box12Cordinates->[1];
	my $box12X = $box12Cordinates->[0];
	my $capAlign = 10;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , uc($claim->{careReceiver}->getSignature()) =~ /C|S|B|P/ ? 'Signature on File' : "Signature on File", $box12X + CELL_PADDING_X + $capAlign + 50, $box12Y - 7 * FORM_FONT_SIZE);
#	pdflib::PDF_show_xy($p , uc($claim->{careReceiver}->getSignature()) =~ /C|S|B|P/ ? $claim->{careReceiver}->getSignatureDate() : "", $box12X + CELL_PADDING_X + 250, $box12Y - 7 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->getInvoiceDate(), $box12X + CELL_PADDING_X + 250, $box12Y - 7 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box13ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box13Cordinates = $cordinates->{box12};
	my $box13Y = $box13Cordinates->[1];
	my $box13X = $box13Cordinates->[0] + STARTX_BOX1A_SPACE;
	my $capAlign = 10;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , (uc($claim->{careReceiver}->getSignature()) =~ /M|B/) ? 'Signature on File' : "Signature on File", $box13X + CELL_PADDING_X + $capAlign + 50, $box13Y - 7 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box14ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box14Cordinates = $cordinates->{box14};
	my $box14Y = $box14Cordinates->[1];
	my $box14X = $box14Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $date  = $self->returnDate($claim->{treatment}->getDateOfIllnessInjuryPregnancy());
	if 	($date->[0] ne "")
	{
		pdflib::PDF_show_xy($p , $date->[0], $box14X + 10, $box14Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[1], $box14X + 33, $box14Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[2], $box14X + 54, $box14Y - 3.5 * FORM_FONT_SIZE);
	}
	pdflib::PDF_stroke($p);
}

sub box15ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;

	my $box15Cordinates = $cordinates->{box15};
	my $box15Y = $box15Cordinates->[1];
	my $box15X = $box15Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $date  = $self->returnDate($claim->{treatment}->getDateOfSameOrSimilarIllness());
	if ($date->[0] ne "")
	{
		pdflib::PDF_show_xy($p , $date->[0], $box15X + 72, $box15Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[1], $box15X + 95, $box15Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[2], $box15X + 114, $box15Y - 3.5 * FORM_FONT_SIZE);
	}
	pdflib::PDF_stroke($p);

}

sub box16ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box16Cordinates = $cordinates->{box14};
	my $box16Y = $box16Cordinates->[1];
	my $box16X = $box16Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);

	my $date  = $self->returnDate($claim->{treatment}->getDatePatientUnableToWorkFrom());
	if ($date->[0] ne "")
	{
		pdflib::PDF_show_xy($p , $date->[0], $box16X + 30, $box16Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[1], $box16X + 53, $box16Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[2], $box16X + 76, $box16Y - 3.5 * FORM_FONT_SIZE);
	}

	$date  = $self->returnDate($claim->{treatment}->getDatePatientUnableToWorkTo());
	if 	($date->[0] ne "")
	{
		pdflib::PDF_show_xy($p , $date->[0], $box16X + 135, $box16Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[1], $box16X + 156, $box16Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[2], $box16X + 177, $box16Y - 3.5 * FORM_FONT_SIZE);
	}
	pdflib::PDF_stroke($p);
}

sub box17ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box17Cordinates = $cordinates->{box17};
	my $box17Y = $box17Cordinates->[1];
	my $box17X = $box17Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{treatment}->getRefProviderLastName . ", " . $claim->{treatment}->getRefProviderFirstName  . " " . $claim->{treatment}->getRefProviderMiName, $box17X + CELL_PADDING_X + DATA_PADDING_X, $box17Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box17aClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box17aCordinates = $cordinates->{box17a};
	my $box17aY = $box17aCordinates->[1];
	my $box17aX = $box17aCordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p ,  $claim->{treatment}->getIDOfReferingPhysician, $box17aX + CELL_PADDING_X + DATA_PADDING_X, $box17aY - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box18ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box18Cordinates = $cordinates->{box17};
	my $box18Y = $box18Cordinates->[1];
	my $box18X = $box18Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);

	my $date  = $self->returnDate($claim->{treatment}->getHospitilizationDateFrom());
	if 	($date->[0] ne "")
	{
		pdflib::PDF_show_xy($p , $date->[0], $box18X + 34, $box18Y - 3.4 * FORM_FONT_SIZE );
		pdflib::PDF_show_xy($p , $date->[1], $box18X + 55, $box18Y - 3.4 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[2], $box18X + 77, $box18Y - 3.4 * FORM_FONT_SIZE);
	}
	$date  = $self->returnDate($claim->{treatment}->getHospitilizationDateTo());
	if 	($date->[0] ne "")
	{
		pdflib::PDF_show_xy($p , $date->[0], $box18X + 134, $box18Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[1], $box18X + 155, $box18Y - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $date->[2], $box18X + 177, $box18Y - 3.5 * FORM_FONT_SIZE);
	}
	pdflib::PDF_stroke($p);
}

sub box20ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box20Cordinates = $cordinates->{box19};
	my $box20Y = $box20Cordinates->[1];
	my $box20X = $box20Cordinates->[0] + STARTX_BOX1A_SPACE;


	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $temp =
			{
				'Y' => $box20X + CELL_PADDING_X + 13.5 + CHECKED_BOX_X,
				'N' => $box20X + CELL_PADDING_X + 50 + CHECKED_BOX_X,
				};
	if ($temp->{uc($claim->{treatment}->getOutsideLab)} ne "")
	{
		pdflib::PDF_show_xy($p , 'X', $temp->{uc($claim->{treatment}->getOutsideLab)}, $cordinates->{box21}->[1] + 1 + CHECKED_BOX_X);
		pdflib::PDF_show_xy($p , $claim->{treatment}->getOutsideLabCharges, $box20X + 145 - pdflib::PDF_stringwidth($p ,$claim->{treatment}->getOutsideLabCharges, $font, DATA_FONT_SIZE), $box20Y - 3 * FORM_FONT_SIZE);
		}
	pdflib::PDF_stroke($p);
}

sub box21ClaimDataPre
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box21Cordinates = $cordinates->{box21};
	my $box21Y = $box21Cordinates->[1];
	my $box21X = $box21Cordinates->[0];
	my $capAlign = 4;
	my $lineSize = 35;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	##########
#	$tb->[0]->{$diagCodes[$diagnosisCount]}
	my @temp;
    if ($claim->{diagnosis}->[0] ne "")
	{
		@temp = split (/\./,$claim->{diagnosis}->[0]->getDiagnosis);
		pdflib::PDF_show_xy($p , $temp[0], $box21X + CELL_PADDING_X + $capAlign + $lineSize - pdflib::PDF_stringwidth($p ,$temp[0], $font, DATA_FONT_SIZE), $box21Y - 4 * FORM_FONT_SIZE + 1);
		pdflib::PDF_show_xy($p , $temp[1], $box21X + CELL_PADDING_X + $capAlign + $lineSize + 3, $box21Y - 4 * FORM_FONT_SIZE + 1);
		}
    if ($claim->{diagnosis}->[1] ne "")
	{
		@temp = split (/\./,$claim->{diagnosis}->[1]->getDiagnosis);
		pdflib::PDF_show_xy($p , $temp[0], $box21X + CELL_PADDING_X + $capAlign + $lineSize - pdflib::PDF_stringwidth($p ,$temp[0], $font, DATA_FONT_SIZE), $box21Y - 8 * FORM_FONT_SIZE + 4);
		pdflib::PDF_show_xy($p , $temp[1], $box21X + CELL_PADDING_X + $capAlign + $lineSize + 3 , $box21Y - 8 * FORM_FONT_SIZE + 4);
		}
	if ($claim->{diagnosis}->[2] ne "")
	{
		@temp = split (/\./,$claim->{diagnosis}->[2]->getDiagnosis);
		pdflib::PDF_show_xy($p , $temp[0], $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3 + $lineSize - pdflib::PDF_stringwidth($p ,$temp[0], $font, DATA_FONT_SIZE), $box21Y - 4 * FORM_FONT_SIZE + 1);
		pdflib::PDF_show_xy($p , $temp[1], $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3 + $lineSize + 3, $box21Y - 4 * FORM_FONT_SIZE + 1);
		}
    if ($claim->{diagnosis}->[3] ne "")
	{
		@temp = split (/\./,$claim->{diagnosis}->[3]->getDiagnosis);
		pdflib::PDF_show_xy($p , $temp[0], $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3 + $lineSize - pdflib::PDF_stringwidth($p ,$temp[0], $font, DATA_FONT_SIZE) , $box21Y - 8 * FORM_FONT_SIZE + 4);
		pdflib::PDF_show_xy($p , $temp[1], $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3 + $lineSize + 3 , $box21Y - 8 * FORM_FONT_SIZE + 4);
		}
	pdflib::PDF_stroke($p);
}

sub box21ClaimData
{
	my ($self, $p, $claim, $cordinates, $tb)  = @_;
	my $box21Cordinates = $cordinates->{box21};
	my $box21Y = $box21Cordinates->[1];
	my $box21X = $box21Cordinates->[0];
	my $capAlign = 4;
	my $lineSize = 35;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	##########
#	$dgs = $tb->[0]->{$diagCodes[$diagnosisCount]}

	my $dgs = $tb->[0];
	my @temp;
	my $dgs1;
	foreach $dgs1(keys (%$dgs))
	{
		if ($dgs->{$dgs1} eq "1")
		{
		@temp = split (/\./,$dgs1);
		pdflib::PDF_show_xy($p , $temp[0], $box21X + CELL_PADDING_X + $capAlign + $lineSize - pdflib::PDF_stringwidth($p ,$temp[0], $font, DATA_FONT_SIZE), $box21Y - 4 * FORM_FONT_SIZE + 1);
		pdflib::PDF_show_xy($p , $temp[1], $box21X + CELL_PADDING_X + $capAlign + $lineSize + 3, $box21Y - 4 * FORM_FONT_SIZE + 1);
		}
		if ($dgs->{$dgs1} eq "2")
		{
			@temp = split (/\./,$dgs1);
			pdflib::PDF_show_xy($p , $temp[0], $box21X + CELL_PADDING_X + $capAlign + $lineSize - pdflib::PDF_stringwidth($p ,$temp[0], $font, DATA_FONT_SIZE), $box21Y - 8 * FORM_FONT_SIZE + 4);
			pdflib::PDF_show_xy($p , $temp[1], $box21X + CELL_PADDING_X + $capAlign + $lineSize + 3 , $box21Y - 8 * FORM_FONT_SIZE + 4);
		}
		if ($dgs->{$dgs1} eq "3")
		{
			@temp = split (/\./,$dgs1);
			pdflib::PDF_show_xy($p , $temp[0], $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3 + $lineSize - pdflib::PDF_stringwidth($p ,$temp[0], $font, DATA_FONT_SIZE), $box21Y - 4 * FORM_FONT_SIZE + 1);
			pdflib::PDF_show_xy($p , $temp[1], $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3 + $lineSize + 3, $box21Y - 4 * FORM_FONT_SIZE + 1);
		}
		if ($dgs->{$dgs1} eq "4")
		{
			@temp = split (/\./,$dgs1);
			pdflib::PDF_show_xy($p , $temp[0], $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3 + $lineSize - pdflib::PDF_stringwidth($p ,$temp[0], $font, DATA_FONT_SIZE) , $box21Y - 8 * FORM_FONT_SIZE + 4);
			pdflib::PDF_show_xy($p , $temp[1], $box21X + CELL_PADDING_X + STARTX_BOX3_SPACE - 3 + $lineSize + 3 , $box21Y - 8 * FORM_FONT_SIZE + 4);
		}
		pdflib::PDF_stroke($p);
	}
}

sub box22ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box22Cordinates = $cordinates->{box21};
	my $box22Y = $box22Cordinates->[1];
	my $box22X = $box22Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{treatment}->getMedicaidResubmission, $box22X + CELL_PADDING_X, $box22Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{treatment}->getResubmissionReference, $box22X + 82, $box22Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box23ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box23Cordinates = $cordinates->{box23};
	my $box23Y = $box23Cordinates->[1];
	my $box23X = $box23Cordinates->[0] + STARTX_BOX1A_SPACE;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{treatment}->getPriorAuthorizationNo, $box23X + CELL_PADDING_X + DATA_PADDING_X, $box23Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box24ClaimData
{
	my ($self, $p, $claim, $cordinates, $procesedProc)  = @_;
 	my $box24Cordinates = $cordinates->{box24HeadA};
	my $box24X = $box24Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $y;
	pdflib::PDF_setlinewidth($p, THIN_LINE_WIDTH);
	my $i =0;
	my $procedure;
	my @ys = ($cordinates->{box24_2}->[1], $cordinates->{box24_3}->[1], $cordinates->{box24_4}->[1], $cordinates->{box24_5}->[1], $cordinates->{box24_6}->[1], $cordinates->{box25}->[1]);
	my $diagnosisMap = {};
	my $ptr;
    my $cod;
	my $tb = $self->diagnosisTable($claim, $procesedProc);
	my $procedures = $claim->{procedures};
	my $mj;
	my $procedurest = $tb->[1];
	my $sortedCharges = $self->feeSort($claim, $procedurest);
	my $amount = $sortedCharges->{'sorted amount'};
	my $procNo;
	my $procedureNo = 0;
	for (my $i =0; $i <= $#$procedurest;)
	{
		my @procNos = split(/,/,$sortedCharges->{$amount->[$i]});
		foreach $procNo(@procNos)
		{
			my $procedure = $claim->{procedures}->[$procNo];

			if ($procedure ne "")
			{
				if (uc($procedure->getItemStatus) ne "VOID")
				{

				$y = $ys[$procedureNo];

					my $date  = $self->returnDate($procedure->getDateOfServiceFrom());
					pdflib::PDF_show_xy($p, $date->[0], $box24X + 8, $y + 6);
					pdflib::PDF_show_xy($p, $date->[1], $box24X + 26, $y + 6);
					pdflib::PDF_show_xy($p, $date->[2], $box24X + 46, $y + 6);

					$date  = $self->returnDate($procedure->getDateOfServiceTo());
					pdflib::PDF_show_xy($p, $date->[0], $box24X + STARTX_BOX24ADATE_SPACE + 2, $y + 6);
					pdflib::PDF_show_xy($p, $date->[1], $box24X + STARTX_BOX24ADATE_SPACE + 22, $y + 6);
					pdflib::PDF_show_xy($p, $date->[2], $box24X + STARTX_BOX24ADATE_SPACE + 40, $y + 6);
					pdflib::PDF_show_xy($p, $procedure->getPlaceOfService(), $box24X + STARTX_BOX24B_SPACE + CELL_PADDING_X + 7, $y + 6);
					pdflib::PDF_show_xy($p, $procedure->getTypeOfService(), $box24X + STARTX_BOX24C_SPACE + CELL_PADDING_X + 4, $y + 6);
					pdflib::PDF_show_xy($p, $procedure->getCPT(), $box24X + STARTX_BOX24D_SPACE + CELL_PADDING_X + 10, $y + 6);
					my @modifier = split (/ /, $procedure->getModifier());
					pdflib::PDF_show_xy($p, $modifier[0], $box24X + STARTX_BOX24D_SPACE + 55, $y + 6);
					for ($mj = 1; $mj <= $#modifier; $mj++)
					{
						pdflib::PDF_show_xy($p, $modifier[1], $box24X + STARTX_BOX24D_SPACE + 75 + ($mj-1) * 12, $y + 6);
					}
					$cod = $procedure->getDiagnosis;
					$cod =~ s/ //g;
					my @diagCodes = split(/,/, $cod);
					for	(my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
					{
						$ptr = $ptr . $tb->[0]->{$diagCodes[$diagnosisCount]} . ","  ;
					}
					$ptr = substr($ptr, 0, length($ptr)-1);
#				$ptr =~ s/$,//g;
					pdflib::PDF_show_xy($p , $ptr , $box24X + STARTX_BOX24E_SPACE + CELL_PADDING_X + 14, $y + 6);
					$ptr = "";
					my @amount  = split (/\./ , $procedure->getCharges());
					pdflib::PDF_show_xy($p , $amount[0], START_X + STARTX_BOX24FC_SPACE - pdflib::PDF_stringwidth($p ,$amount[0], $font, DATA_FONT_SIZE) - 4, $y + 6);
					pdflib::PDF_show_xy($p , substr($amount[1] . "00", 0, 2), START_X + STARTX_BOX24G_SPACE - pdflib::PDF_stringwidth($p , substr($amount[1] . "00", 0, 2), $font, DATA_FONT_SIZE) - 4, $y + 6);
					pdflib::PDF_show_xy($p , substr ('000' . $procedure->getDaysOrUnits(), length('000' . $procedure->getDaysOrUnits()) - 3), $box24X + STARTX_BOX24H_SPACE - 17, $y + 6);
					pdflib::PDF_show_xy($p , $procedure->getEmergency(), $box24X + STARTX_BOX24I_SPACE + 6, $y + 6);
					pdflib::PDF_stroke($p);
					$procedureNo++;
				}
			}
		}
		$i++;
	}
	return $tb;
}


sub box25ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box25Cordinates = $cordinates->{box25};
	my $box25Y = $box25Cordinates->[1];
	my $box25X = $box25Cordinates->[0];
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);

	pdflib::PDF_show_xy($p , $claim->{payToOrganization}->getTaxId eq "" ?  $claim->{payToOrganization}->getTaxId : $claim->{payToOrganization}->getTaxId, $box25X + CELL_PADDING_X + DATA_PADDING_X, $box25Y - 3 * FORM_FONT_SIZE );
	my $temp = {
			'S' => $box25X + CELL_PADDING_X + 112.5 + CHECKED_BOX_X,
			'E' => $box25X + CELL_PADDING_X + 126 + CHECKED_BOX_X,
			};
	pdflib::PDF_show_xy($p , 'X', $box25X + CELL_PADDING_X + 126 + CHECKED_BOX_X, $cordinates->{box31}->[1] + 1 + CHECKED_BOX_Y) if (uc($claim->{payToOrganization}->getTaxId) ne "");
	pdflib::PDF_stroke($p);
}

sub box26ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box26Cordinates = $cordinates->{box26};
	my $box26Y = $box26Cordinates->[1];
	my $box26X = $box26Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $claim->{careReceiver}->getAccountNo, $box26X + CELL_PADDING_X + DATA_PADDING_X, $box26Y - 3 * FORM_FONT_SIZE );
	pdflib::PDF_stroke($p);
}

sub box27ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;

	my $box27Cordinates = $cordinates->{box27};
	my $box27Y = $box27Cordinates->[1];
	my $box27X = $box27Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $temp =
			{
				'1' => $box27X + CELL_PADDING_X + 1 + CHECKED_BOX_X,
				'0' => $box27X + CELL_PADDING_X + 39 + CHECKED_BOX_X,
				'Y' => $box27X + CELL_PADDING_X + 1 + CHECKED_BOX_X,
				'N' => $box27X + CELL_PADDING_X + 39 + CHECKED_BOX_X,
				'' => $box27X + CELL_PADDING_X + 1 + CHECKED_BOX_X,
				};
	pdflib::PDF_show_xy($p , 'X', $temp->{uc($claim->getAcceptAssignment)}, $cordinates->{box31}->[1] + 1 + CHECKED_BOX_Y) if defined ($temp->{uc($claim->getAcceptAssignment)});
	pdflib::PDF_stroke($p);
}

sub box28ClaimData
{
	my ($self, $p, $claim, $cordinates, $procesedProc)  = @_;
	my $box28Cordinates = $cordinates->{box28};
	my $box28Y = $box28Cordinates->[1];
	my $box28X = $box28Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my @amount  = split (/\./ , $claim->getTotalCharge);
	if ($self->allProcTraverse($procesedProc, $claim) eq "0")
	{
		$amount[0]="Contd..";
		$amount[1]="  ";
	}
	pdflib::PDF_show_xy($p , $amount[0], $box28X + 50 - pdflib::PDF_stringwidth($p ,$amount[0], $font, DATA_FONT_SIZE) , $box28Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($amount[1] . "00", 0, 2), $box28X + 60, $box28Y - 3 * FORM_FONT_SIZE);

	pdflib::PDF_stroke($p);

}

sub box29ClaimData
{
	my ($self, $p, $claim, $cordinates, $procesedProc)  = @_;
	my $box29Cordinates = $cordinates->{box29};
	my $box29Y = $box29Cordinates->[1];
	my $box29X = $box29Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my @amount  = split (/\./ , abs($claim->getTotalChargePaid));
	if ($self->allProcTraverse($procesedProc, $claim) eq "0")
	{
		$amount[0]="Contd..";
		$amount[1]="  ";
	}
	pdflib::PDF_show_xy($p , $amount[0], $box29X + 45 - pdflib::PDF_stringwidth($p ,$amount[0], $font, DATA_FONT_SIZE) , $box29Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($amount[1] . "00", 0, 2), $box29X + 55, $box29Y - 3 * FORM_FONT_SIZE);

	pdflib::PDF_stroke($p);

}

sub box30ClaimData
{
	my ($self, $p, $claim, $cordinates, $procesedProc)  = @_;
	my $box30Cordinates = $cordinates->{box30};
	my $box30Y = $box30Cordinates->[1];
	my $box30X = $box30Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my @amount  = split (/\./ , abs(abs($claim->getTotalCharge) - abs($claim->getTotalChargePaid)));
	if ($self->allProcTraverse($procesedProc, $claim) eq "0")
	{
		$amount[0]="Contd";
		$amount[1]="  ";
	}
	pdflib::PDF_show_xy($p , $amount[0], $box30X + 40 - pdflib::PDF_stringwidth($p ,$amount[0], $font, DATA_FONT_SIZE) , $box30Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($amount[1] . "00", 0, 2), $box30X + 50, $box30Y - 3 * FORM_FONT_SIZE);

	pdflib::PDF_stroke($p);
}

sub box31ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box31Cordinates = $cordinates->{box31};
	my $box31Y = $box31Cordinates->[1];
	my $box31X = $box31Cordinates->[0];
	my $serviceProvider = $claim->getRenderingProvider();

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $serviceProvider->getName(), $box31X + CELL_PADDING_X + 0, START_Y + 12);
	pdflib::PDF_show_xy($p , $claim->getInvoiceDate(), $box31X + CELL_PADDING_X + 100, START_Y + 12);
	pdflib::PDF_stroke($p);
}

sub box32ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box32Cordinates = $cordinates->{box32};
	my $box32Y = $box32Cordinates->[1];
	my $box32X = $box32Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $billRecevier = $claim->{renderingOrganization};
	my $add = $billRecevier->getAddress();
	pdflib::PDF_show_xy($p , $billRecevier->getName(), $box32X + CELL_PADDING_X + 10, $box32Y - 4 * FORM_FONT_SIZE );
	pdflib::PDF_show_xy($p , $add->getAddress1(), $box32X + CELL_PADDING_X + 10, $box32Y - 5.2 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $add->getAddress2(), $box32X + CELL_PADDING_X + 10, $box32Y - 6.2 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $add->getCity() . "    " . $add->getState() . "    " . $add->getZipCode(), $box32X + CELL_PADDING_X + 10, $box32Y - 7.2 * FORM_FONT_SIZE);
	pdflib::PDF_stroke($p);
}

sub box33ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box33Cordinates = $cordinates->{box33};
	my $box33Y = $box33Cordinates->[1];
	my $box33X = $box33Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $facility = $claim->{payToOrganization};
	my $physician = $claim->{payToProvider};
	my $add = $facility->getAddress();

	pdflib::PDF_show_xy($p ,$facility->getName() , $box33X + CELL_PADDING_X + 10, $box33Y - 4 * FORM_FONT_SIZE );
	pdflib::PDF_show_xy($p ,$add->getAddress1() , $box33X + CELL_PADDING_X + 10, $box33Y - 5.2 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $add->getCity() . "    " . $add->getState() . "    " . $add->getZipCode(), $box33X + CELL_PADDING_X + 10, $box33Y - 7.4 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $physician->getPIN(), $box33X + CELL_PADDING_X + 25, START_Y + 2);
	if($physician->getInsType() ne '99')
	{
		pdflib::PDF_show_xy($p ,$facility->getGRP() , $box33X + CELL_PADDING_X + 130, START_Y + 2);
	}
	pdflib::PDF_stroke($p);

}

sub carrierData
{
	my ($self, $p, $claim, $cordinates)  = @_;

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $claimType = $claim->getClaimType();
	my $payer = $claim->{policy}->[$claimType];
	if ($payer ne "")
	{
		my $address = $payer->getAddress();
		pdflib::PDF_show_xy($p , $payer->getName, START_X + 250, START_Y + FORM_HEIGHT + 51);
		pdflib::PDF_show_xy($p , $address->getAddress1, START_X + 250, START_Y + FORM_HEIGHT + 51 - FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $address->getCity . " " . $address->getState . " " . $address->getZipCode , START_X + 250, START_Y + FORM_HEIGHT + 51 - 2 * FORM_FONT_SIZE);
		pdflib::PDF_stroke($p);
	}
}



sub returnDate
{
	my ($self,$value) = @_;

	my @date;

#	$date[2] = substr($value,5,10); # this code is for ddmmmyyyy
#	$date[0] = substr($value,0,2);
#	$date[1] = substr($value,2,3);


	$date[2] = substr($value,0,4); # this code is for yyyymmdd
	$date[0] = substr($value,4,2);
	$date[1] = substr($value,6,2);

	return \@date;

}

sub diagnosisTable
{
	my ($self, $claim, $processedProc)  = @_;
	my $diag;
	my $procCount;
	my @targetproc;
	my $cod;
	my %diagTable;
	my $tempCount;

	my $procedures = $claim->{procedures};
	for my $i (0..$#$procedures)
	{
		my $procedure = $procedures->[$i];
		if (uc($procedure->getItemStatus) eq "VOID")
		{
			$processedProc->[$i] = 1;
		}
	}
	for my $i (0..$#$procedures)
	{
		if (($diag <= 4) && ($procCount < 6) && ($processedProc->[$i] != 1))
		{
			my $procedure = $procedures->[$i];
			$cod = $procedure->getDiagnosis;
			$cod =~ s/ //g;
			my @diagCodes = split(/,/, $cod);
			for (my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
			{
				$tempCount = 0;
				if (not (exists($diagTable{$diagCodes[$diagnosisCount]})))
				{
					$tempCount++;
				}
			}
			if ($tempCount + $diag <= 4)
			{
				for (my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
				{
					if (not (exists($diagTable{$diagCodes[$diagnosisCount]})))
					{
						$diag++;
						$diagTable{$diagCodes[$diagnosisCount]} = $diag;
					}
				}
				$processedProc->[$i] = 1;
				push(@targetproc, $i);
				$procCount++;
			}
		}
	}
	return 	[\%diagTable, \@targetproc];
}

sub feeSort
{
	my ($self, $claim, $targetProcedures) = @_;

	my $procedures = $claim->{procedures};
	my %charges;
	my	$procedure;
	for my $i (0..$#$targetProcedures)
	{
		$procedure = $procedures->[$targetProcedures->[$i]];
		$charges{$procedure->getCharges()} = $targetProcedures->[$i] . "," . $charges{$procedure->getCharges()};
	}
	my @as = sort {$b <=> $a} keys %charges;
	$charges{'sorted amount'} = \@as;
	return \%charges;
}


sub allProcTraverse
{
	my ($self, $procesedProc, $claim) = @_;
	my $procs = $claim->{procedures};
	my $sum = 0;

	for my $i (0..$#$procs)
	{
		$sum = ($procesedProc->[$i] eq "1") ? ++$sum : $sum;
	}
	return $sum >= ($#$procs + 1) ? 1 : 0;
}


sub setPrimaryProcedure
{
	my ($self, $claim) = @_;

	my $procedures = $claim->{procedures};
	my $dg = $claim->{'diagnosis'}->[0]->getDiagnosis()	if defined ($claim->{'diagnosis'}->[0]);
	my $procedure;
	my $primaryProcedure = -1;
	foreach my $i (0..$#$procedures)
	{
		$procedure = $procedures->[$i];
		if ($procedure ne "")
		{
			 $primaryProcedure = $procedure->getDiagnosis() =~ /$dg/ ? $i : -1;

		}
	}
	if ($primaryProcedure != -1)
	{
		my $temp = $claim->{procedures}->[0];
		$claim->{procedures}->[0] = $claim->{procedures}->[$primaryProcedure];
		$claim->{procedures}->[$primaryProcedure] = $temp;
	}
	return  $primaryProcedure;
}

sub reversePrimaryProcedure
{
	my ($self, $claim, $primaryProcedure) = @_;
	if ($primaryProcedure != -1)
	{
		my $procedure = $claim->{procedures}->[$primaryProcedure];
		$claim->{procedures}->[$primaryProcedure] = $claim->{procedures}->[0];
		$claim->{procedures}->[0] = $procedure;
	}
}

1;

