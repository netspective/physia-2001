#########################################################################
package App::Billing::Output::PDF::Worker;
#########################################################################
use strict;
use App::Billing::Output::Driver;
use App::Billing::Output::PDF;
use App::Billing::Claims;
use pdflib 2.01;

use vars qw(@ISA);
@ISA = qw(App::Billing::Output::PDF);

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


sub populate
{
	my ($self, $p, $Claim, $cordinates, $procesedProc)  = @_;

	pdflib::PDF_setrgbcolor($p, DATA_RED, DATA_GREEN, DATA_BLUE);
	$self->box1ClaimData($p, $Claim, $cordinates);
	$self->carrierData($p, $Claim, $cordinates);
	$self->box1aClaimData($p, $Claim, $cordinates);
	$self->box2ClaimData($p, $Claim, $cordinates);
	$self->box3ClaimData($p, $Claim, $cordinates);
	$self->box4ClaimData($p, $Claim, $cordinates);
	$self->box5ClaimData($p, $Claim, $cordinates);
	$self->box5aClaimData($p, $Claim, $cordinates);
	$self->box5bClaimData($p, $Claim, $cordinates);
	$self->box7ClaimData($p, $Claim, $cordinates);
	$self->box7aClaimData($p, $Claim, $cordinates);
	$self->box7bClaimData($p, $Claim, $cordinates);
	$self->box10ClaimData($p, $Claim, $cordinates);
	$self->box11ClaimData($p, $Claim, $cordinates);
	$self->box11dClaimData($p, $Claim, $cordinates);

	$self->box12ClaimData($p, $Claim, $cordinates);
	$self->box13ClaimData($p, $Claim, $cordinates);

	$self->box14ClaimData($p, $Claim, $cordinates);
	$self->box15ClaimData($p, $Claim, $cordinates);
#	$self->box22ClaimData($p, $Claim, $cordinates);
	my $dg = $self->box24ClaimData($p, $Claim, $cordinates, $procesedProc);
	$self->box21ClaimData($p, $Claim, $cordinates, $dg);
	$self->box25ClaimData($p, $Claim, $cordinates);
	$self->box26ClaimData($p, $Claim, $cordinates);
	$self->box27ClaimData($p, $Claim, $cordinates);
	$self->box28ClaimData($p, $Claim, $cordinates, $procesedProc);
	$self->box30ClaimData($p, $Claim, $cordinates, $procesedProc);
	$self->box31ClaimData($p, $Claim, $cordinates);
	$self->box32ClaimData($p, $Claim, $cordinates);
	$self->box33ClaimData($p, $Claim, $cordinates);
	pdflib::PDF_setrgbcolor($p, FORM_RED, FORM_GREEN, FORM_BLUE);
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
	my $insured = $claim->{insured}->[$claimType];
#	my $data = ($claim->getInvoiceSubtype() == CLAIM_TYPE_WORKCOMP) ? $insured->getSsn() : $claim->{insured}->[$claimType]->getSsn();
	my $data = $insured->getSsn();
	pdflib::PDF_show_xy($p , $data , $box1aX + CELL_PADDING_X + DATA_PADDING_X, $box1Y - 3 * FORM_FONT_SIZE);
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
	my $data = ($claim->getInvoiceSubtype() == CLAIM_TYPE_WORKCOMP) ? $claim->{insured}->[$claimType]->getEmployerOrSchoolName : $claim->{insured}->[$claimType]->getLastName() . " " . $claim->{insured}->[$claimType]->getFirstName() . " " . $claim->{insured}->[$claimType]->getMiddleInitial();
	pdflib::PDF_show_xy($p, $data , $box4X + CELL_PADDING_X + DATA_PADDING_X, $box4Y - 3 * FORM_FONT_SIZE);
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
	my $data = ($claim->getInvoiceSubtype() == CLAIM_TYPE_WORKCOMP) ? $claim->{insured}->[$claimType]->getEmployerAddress : $claim->{insured}->[$claimType]->getAddress();
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
	my $data = ($claim->getInvoiceSubtype() == CLAIM_TYPE_WORKCOMP) ? $claim->{insured}->[$claimType]->getEmployerAddress : $claim->{insured}->[$claimType]->getAddress();

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
	my $data = ($claim->getInvoiceSubtype() == CLAIM_TYPE_WORKCOMP) ? $claim->{insured}->[$claimType]->getEmployerAddress : $claim->{insured}->[$claimType]->getAddress();

	pdflib::PDF_show_xy($p , $data->getZipCode, $box7bX + CELL_PADDING_X  + DATA_PADDING_X, $box7bY - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($data->getTelephoneNo, 0, 3), $box7bX + $stateSpace + CELL_PADDING_X + 20, $box7bY - 3.5 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , substr($data->getTelephoneNo, 3, 25), $box7bX + $stateSpace + CELL_PADDING_X + 50, $box7bY - 3.5 * FORM_FONT_SIZE) if (length($data->getTelephoneNo) > 3);
	pdflib::PDF_stroke($p);
}


sub box11ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box11Cordinates = $cordinates->{box9};
	my $box11Y = $box11Cordinates->[1];
	my $box11X = $box11Cordinates->[0] + STARTX_BOX1A_SPACE;
	my $claimType = $claim->getClaimType();
	my $insured = $claim->{insured}->[$claimType];


	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , $insured->getPolicyGroupOrFECANo, $box11X + CELL_PADDING_X + DATA_PADDING_X, $box11Y - 3 * FORM_FONT_SIZE - 1);
#	pdflib::PDF_show_xy($p , "N/A", $box11X + CELL_PADDING_X + DATA_PADDING_X, $box11Y - 3 * FORM_FONT_SIZE - 1);
	pdflib::PDF_stroke($p);
}


sub box11dClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box11dCordinates = $cordinates->{box9d};
	my $box11dY = $box11dCordinates->[1];
	my $box11dX = $box11dCordinates->[0] + STARTX_BOX1A_SPACE;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	pdflib::PDF_show_xy($p , 'X', $box11dX + CELL_PADDING_X + 50 + CHECKED_BOX_X, $cordinates->{box12}->[1] + 1 + CHECKED_BOX_Y);
	pdflib::PDF_stroke($p);
}

sub box29ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box29Cordinates = $cordinates->{box29};
	my $box29Y = $box29Cordinates->[1];
	my $box29X = $box29Cordinates->[0];

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);

	pdflib::PDF_show_xy($p , "0", $box29X + 45 - pdflib::PDF_stringwidth($p ,"0", $font, DATA_FONT_SIZE) , $box29Y - 3 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , "00", $box29X + 55, $box29Y - 3 * FORM_FONT_SIZE);
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
	pdflib::PDF_show_xy($p , $serviceProvider->getName(), $box31X + CELL_PADDING_X + 0, START_Y + 20);
	pdflib::PDF_show_xy($p , $serviceProvider->getProfessionalLicenseNo(), $box31X + CELL_PADDING_X + 0, START_Y + 12);
	pdflib::PDF_show_xy($p , $claim->getInvoiceDate(), $box31X + CELL_PADDING_X + 100, START_Y + 12);
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
	my $physician = $claim->{payToProvider};
	my $billingFacility = $claim->{payToOrganization};
	my $add = $billingFacility->getAddress();

	pdflib::PDF_show_xy($p ,$billingFacility->getName() , $box33X + CELL_PADDING_X + 10, $box33Y - 4 * FORM_FONT_SIZE );
	pdflib::PDF_show_xy($p ,$add->getAddress1() , $box33X + CELL_PADDING_X + 10, $box33Y - 5.2 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $add->getCity() . "    " . $add->getState() . "    " . $add->getZipCode(), $box33X + CELL_PADDING_X + 10, $box33Y - 6.4 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $add->getTelephoneNo(1), $box33X + CELL_PADDING_X + 10, $box33Y - 7.6 * FORM_FONT_SIZE);
	pdflib::PDF_show_xy($p , $physician->getPIN(), $box33X + CELL_PADDING_X + 25, START_Y + 2);
	pdflib::PDF_show_xy($p ,$billingFacility->getGRP() , $box33X + CELL_PADDING_X + 130, START_Y + 2);
	pdflib::PDF_stroke($p);

}

sub carrierData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $address = $claim->{payer}->getAddress;

	if ($address ne "")
	{
		pdflib::PDF_show_xy($p , $claim->{payer}->getName, START_X + 250, START_Y + FORM_HEIGHT + 51);
		pdflib::PDF_show_xy($p , $address->getAddress1, START_X + 250, START_Y + FORM_HEIGHT + 51 - FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $address->getCity . " " . $address->getState . " " . $address->getZipCode , START_X + 250, START_Y + FORM_HEIGHT + 51 - 2 * FORM_FONT_SIZE);
		pdflib::PDF_stroke($p);
	}
}


1;

