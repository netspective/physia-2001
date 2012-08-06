#########################################################################
package App::Billing::Output::PDF::FloridaMedicaid;
#########################################################################
use strict;
use App::Billing::Output::Driver;
use App::Billing::Output::PDF;
use App::Billing::Claims;
use App::Billing::Claim::Address;
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
	$self->box30ClaimData($p, $Claim, $cordinates, $procesedProc);
	$self->box31ClaimData($p, $Claim, $cordinates);
	$self->box32ClaimData($p, $Claim, $cordinates);
	$self->box33ClaimData($p, $Claim, $cordinates);
	$self->carrierData($p, $Claim, $cordinates);
	pdflib::PDF_setrgbcolor($p, FORM_RED, FORM_GREEN, FORM_BLUE);
}

sub box1ClaimData
{
	my ($self, $p, $claim, $cordinates)  = @_;
	my $box1Cordinates = $cordinates->{box1};
	my $box1Y = $box1Cordinates->[1];
	my $box1X = $box1Cordinates->[0];
	my $data;
	my $xCoordinate =
		{
			'MEDICAID' => $box1X + 50 + CHECKED_BOX_X,
		};

	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);

	my $temp = uc($claim->getProgramName);
	if ($claim->getStatus == 16)
	{
		$data = 'V';
	}
	elsif ($claim->getStatus == 14)
	{
		$data = 'A';
	}
	else
	{
		$data = 'X';
	}

	pdflib::PDF_show_xy($p, $data, $xCoordinate->{$temp} , $box1Y + CHECKED_BOX_Y - 4 * FORM_FONT_SIZE) if (defined ($xCoordinate->{$temp}));
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
	my ($claimType, $insuredName, $data);
	$claimType = $claim->getClaimType();
	if ($claim->{careReceiver}->getId eq $claim->{insured}->[$claimType]->getId)
	{
		$data = "SAME";
	}
	else
	{
		$data = $claim->{insured}->[$claimType]->getLastName() . " " . $claim->{insured}->[$claimType]->getFirstName() . " " . $claim->{insured}->[$claimType]->getMiddleInitial();
	}
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

	if ($claim->{careReceiver}->getId ne $claim->{insured}->[$claimType]->getId)
	{
		my $data = $claim->{insured}->[$claimType]->getAddress();
		pdflib::PDF_show_xy($p , $data->getAddress1(), $box7X + CELL_PADDING_X + DATA_PADDING_X, $box7Y  - 2.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , $data->getAddress2(), $box7X + CELL_PADDING_X + DATA_PADDING_X, $box7Y  - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_stroke($p);
	}
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
	if ($claim->{careReceiver}->getId ne $claim->{insured}->[$claimType]->getId)
	{
		my $data = $claim->{insured}->[$claimType]->getAddress();
		pdflib::PDF_show_xy($p , $data->getCity(),$box7aX + CELL_PADDING_X + DATA_PADDING_X, $box7aY - 3 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , substr($data->getState(),0,7), $box7aX + CELL_PADDING_X + $stateSpace + 3, $box7aY - 3 * FORM_FONT_SIZE);
		pdflib::PDF_stroke($p);
	}
	
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
	my $data;
	if ($claim->{careReceiver}->getId ne $claim->{insured}->[$claimType]->getId)
	{
		my $data = $claim->{insured}->[$claimType]->getAddress();
		pdflib::PDF_show_xy($p , $data->getZipCode, $box7bX + CELL_PADDING_X  + DATA_PADDING_X, $box7bY - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , substr($data->getTelephoneNo, 0, 3), $box7bX + $stateSpace + CELL_PADDING_X + 20, $box7bY - 3.5 * FORM_FONT_SIZE);
		pdflib::PDF_show_xy($p , substr($data->getTelephoneNo, 3, 25), $box7bX + $stateSpace + CELL_PADDING_X + 50, $box7bY - 3.5 * FORM_FONT_SIZE) if (length($data->getTelephoneNo) > 3);
		pdflib::PDF_stroke($p);
	}
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
	my $font = pdflib::PDF_findfont($p, DATA_FONT_NAME, "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, DATA_FONT_SIZE);
	my $data;

	if ($insured2 eq "")
	{
		$data = "None";
	}
	else
	{
		if ($insured2->getInsurancePlanOrProgramName ne "")
		{
			$data =  $insured2->getLastName . " " . $insured2->getFirstName . " " . $insured2->getMiddleInitial;
		}
	}
	pdflib::PDF_show_xy($p, $data, $box9X + CELL_PADDING_X + DATA_PADDING_X, $box9Y - 3 * FORM_FONT_SIZE - 1);
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
	my $claimType = $claim->getClaimType();

	if ($claim->{careReceiver}->getId ne $claim->{insured}->[$claimType]->getId)
	{
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
	
	my $data = $claim->{treatment}->getIDOfReferingPhysician;
	$data = '0000001-00' if ($data eq '');
	pdflib::PDF_show_xy($p, $data, $box17aX + CELL_PADDING_X + DATA_PADDING_X, $box17aY - 3 * FORM_FONT_SIZE);
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
						$ptr = $ptr . $diagCodes[$diagnosisCount] . ","  ;
					}
					$ptr = substr($ptr, 0, length($ptr)-1);
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

1;