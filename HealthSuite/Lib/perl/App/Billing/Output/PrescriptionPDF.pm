package App::Billing::Output::PrescriptionPDF;

use App::Billing::Output::PDF::Report;
use App::Billing::Prescription::Prescription;
use App::Billing::Prescription::Drugs;
use App::Billing::Prescription::Drug;
use pdflib 2.01;

use strict;

use constant LINE_HEIGHT => 14;
use constant TOP_MARGIN => 75;
use constant BOX_WIDTH => 500;
use constant BOX_HEIGHT_SINGLE => 350;
use constant BOX_HEIGHT_MULTIPLE => 650;
use constant DRUG_DETAIL_HEIGHT => 110;
use constant LEFT_PADDING => .01 * BOX_WIDTH;

use constant LEFT_LINE => 1;
use constant RIGHT_LINE => 1;
use constant TOP_LINE => 1;
use constant BOTTOM_LINE => 1;
use constant NO_LEFT_LINE => 0;
use constant NO_RIGHT_LINE => 0;
use constant NO_TOP_LINE => 0;
use constant NO_BOTTOM_LINE => 0;
use constant FONT_NAME => 'Helvetica';
use constant BOLD_FONT_NAME =>  FONT_NAME . '-Bold';
use constant SPC => " ";
use constant TOP_PADDING => 12;
use constant DATA_FONT_COLOR => '0,0,0';
use constant REPORT_COLOR => '0,0,0';
use constant DATA_FONT_SIZE => 10;
use constant PAGE_HEIGHT => 792;
use constant PAGE_WIDTH => 612;

sub new
{
	my ($type) = shift;
	my $self = {};
	return bless $self, $type;
}

sub printReport
{
	my ($self, $prescription, %params) = @_;

	my $filename = $params{file} ne "" ? $params{file} : "Prescription.pdf";
	my $reportColor = $params{reportColor} ne "" ? $params{reportColor} : REPORT_COLOR;

	my $p = pdflib::PDF_new();
	die "Couldn't open PDF file"  if (pdflib::PDF_open_file($p, $filename) == -1);
	my $report = new App::Billing::Output::PDF::Report(color => $reportColor);

	my $startX = (PAGE_WIDTH - BOX_WIDTH)/2;
	my $startY = (PAGE_HEIGHT - TOP_MARGIN);
	my $single=1;

	my $return = $single ? printSingle($self, $prescription, $p, $report, $startX, $startY) : printMultiple($self, $prescription, $p, $report, $startX, $startY);

	pdflib::PDF_close($p);
	pdflib::PDF_delete($p);

}

sub printSingle
{
	my($self, $prescription, $p, $report, $x, $y) = @_;

	my $drugs = $prescription->{drugs};
	my $allDrugs = $drugs->getDrug();
	for my $i (0..$#$allDrugs)
	{
		my $drug = $allDrugs->[$i];

		$report->newPage($p);
		$report->drawBox($p, $x, $y, BOX_WIDTH, BOX_HEIGHT_SINGLE, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE);

		my ($patientX, $patientY) = $self->printHeader($prescription, $p, $report, $x, $y);
		my $drugY = $patientY - 4 * LINE_HEIGHT;
		my $doseX = $patientX + .30 * BOX_WIDTH;
		my $quantityX = $patientX + .55 * BOX_WIDTH;
		my $sigY = $drugY - 2 * LINE_HEIGHT;
		my $labelY = $sigY - 3 * LINE_HEIGHT;
		my $refillX = $patientX + .60 * BOX_WIDTH;
		my $signatureY = $labelY - 3 * LINE_HEIGHT;
		my $deaY = $signatureY - 3 * LINE_HEIGHT;

		$self->printLabel($p, $patientX, $drugY, $report, 'Drug Name');
		$self->printLabel($p, $doseX, $drugY, $report, 'Dose');
		$self->printLabel($p, $quantityX, $drugY, $report, 'Quantity &/or Duration');
		$self->printLabel($p, $patientX, $sigY, $report, 'Sig:');

		$self->printLabel($p, $patientX, $labelY, $report, 'Label no ___ yes ___');
		$self->printLabel($p, $patientX, $labelY - LINE_HEIGHT, $report, 'Label in Spanish _______');
		$self->printLabel($p, $refillX, $labelY, $report, 'Refill no ___ yes ___ # _____');

		$self->printLabel($p, $patientX, $signatureY, $report, 'Signature _________________________');
		$self->printLabel($p, $quantityX, $signatureY, $report, '___________________________');
		$self->printLabel($p, $patientX, $deaY, $report, 'DEA # ______________________________');

		$self->printLabel($p, $patientX + 55, $signatureY - 11, $report, 'Substitution Permitted');
		$self->printLabel($p, $quantityX, $signatureY - 11, $report, '   No Substitution');

		$report->endPage($p);

	}
}

sub printMultiple
{
	my($self, $prescription, $p, $report, $x, $y) = @_;

	my ($patientX, $patientY);

#	my $drugs = $prescription->{drugs};
	for my $i (0..9) #(0..$#$drugs)
	{
#		my $drug = $prescription->getDrug($i);
		my $drug;
		if ($i % 4 == 0)
		{
			$report->newPage($p);
			$report->drawBox($p, $x, $y, BOX_WIDTH, BOX_HEIGHT_MULTIPLE, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE);
			($patientX, $patientY) = $self->printHeader($prescription, $p, $report, $x, $y);
		}

		my $yNew = $patientY - 3 * LINE_HEIGHT - ($i % 4) * DRUG_DETAIL_HEIGHT;
		$self->printDrugMultiple($drug, $p, $report, $patientX, $yNew);

		if (($i % 4 == 3) || ($i == 9)) #   ($i == $#$drugs))
		{
			$self->printFooter($prescription, $p, $report, $patientX, $patientY - 9 * LINE_HEIGHT - ($i % 4) * DRUG_DETAIL_HEIGHT);
			$report->endPage($p);
		}
	}

}

sub printHeader
{
	my($self, $prescription, $p, $report, $x, $y) = @_;

	my @arrData;
	$arrData[0] = $prescription->{physician}->getName;
	push(@arrData, $prescription->{practice}->getName);

	push(@arrData, $prescription->{practice}->{address}->getAddress1);
	push(@arrData, $prescription->{practice}->{address}->getAddress2) if $prescription->{practice}->{address}->getAddress2 ne '';
	my $cityStateZip = $prescription->{practice}->{address}->getCity . ", " . $prescription->{practice}->{address}->getState . " " . $prescription->{practice}->{address}->getZipCode;
	push(@arrData, $cityStateZip);
	push(@arrData, 'Phone: ' . $prescription->{practice}->{address}->getTelephoneNo(1) . ' Fax: ' . $prescription->{practice}->{address}->getFaxNo(1));
	push(@arrData, 'Email:' . $prescription->{practice}->{address}->getEmailAddress);


	for my $i(0..$#arrData)
	{
#		my $j = pdflib::PDF_stringwidth($p, $arrData[$i], FONT_NAME, 7);
		$self->printData($p, $x, $y, $report, $arrData[$i],
			BOX_WIDTH/2 ,
			TOP_PADDING + $i * LINE_HEIGHT);
	}

	my $patientX = $x + LEFT_PADDING;
	my $patientY = $y - ($#arrData + 3) * LINE_HEIGHT;
	my $dateX = $patientX + .75 * BOX_WIDTH;
	$self->printLabel($p, $patientX, $patientY, $report, 'Patient Name ' . '_' x  int((.54 * BOX_WIDTH)/5));
	$self->printLabel($p, $dateX, $patientY, $report, 'Date ' . '_' x  int((.13 * BOX_WIDTH)/5) );
	$self->printLabel($p, $patientX, $patientY - LINE_HEIGHT, $report, 'Address ' . '_' x  int((.58 * BOX_WIDTH)/5));
	$self->printLabel($p, $dateX, $patientY - LINE_HEIGHT, $report, 'Phone # ' . '_' x int((.10 * BOX_WIDTH)/5));

	$self->printData($p, $patientX, $patientY, $report, $prescription->{patient}->getName, 70, 0);
	$self->printData($p, $dateX, $patientY, $report, $prescription->getDate(1), 24, 0 );
	my $patientAddress = $prescription->{patient}->{address}->getAddress1 . " " .
						$prescription->{patient}->{address}->getAddress2 . " " .
						$prescription->{patient}->{address}->getCity . " " .
						$prescription->{patient}->{address}->getState . " " .
						$prescription->{patient}->{address}->getZipCode;
	$self->printData($p, $patientX, $patientY - LINE_HEIGHT, $report, $patientAddress, 50,0);
	$self->printData($p, $dateX, $patientY - LINE_HEIGHT, $report, $prescription->{patient}->{address}->getTelephoneNo(1), 40, 0);

	return ($patientX, $patientY);
}

sub printDrugMultiple
{
	my ($self, $drug, $p, $report, $x, $y) = @_;

	my $drugY = $y - 1 * LINE_HEIGHT;
	my $doseX = $x + .30 * BOX_WIDTH;
	my $quantityX = $x + .55 * BOX_WIDTH;
	my $sigY = $drugY - 2 * LINE_HEIGHT;
	my $labelY = $sigY - 2 * LINE_HEIGHT;
	my $refillX = $x + .25 * BOX_WIDTH;
	my $substitutionX = $x + .55 * BOX_WIDTH;

	$self->printLabel($p, $x, $drugY, $report, 'Drug Name');
	$self->printLabel($p, $doseX, $drugY, $report, 'Dose');
	$self->printLabel($p, $quantityX, $drugY, $report, 'Quantity &/or Duration');
	$self->printLabel($p, $x, $sigY, $report, 'Sig:');

	$self->printLabel($p, $x, $labelY, $report, 'Label no __ yes __');
	$self->printLabel($p, $refillX, $labelY, $report, 'Refill no __ yes __ # _____');
	$self->printLabel($p, $substitutionX, $labelY, $report, 'Substitution Permitted no __ yes __');

}

sub printFooter
{
	my($self, $prescription, $p, $report, $x, $y) = @_;

	my $spanishY = $y - 2 * LINE_HEIGHT;
	my $signatureY = $spanishY - LINE_HEIGHT;
	my $deaX = $x + 0.55 * BOX_WIDTH;

	$self->printLabel($p, $x, $spanishY, $report, 'Label in Spanish _______');
	$self->printLabel($p, $x, $signatureY, $report, 'Signature _______________________');
	$self->printLabel($p, $deaX, $signatureY, $report, 'DEA # _________________________');

}

sub printLabel
{
	my($self, $p, $x, $y, $report, $label) = @_;

	my $properties =
	{
		'text' => $label,
		'fontName' => FONT_NAME,
		'fontWidth' => 10,
		'x' => $x,
		'y' => $y
	};
	$report->drawText($p, $properties);
}

sub printData
{
	my($self, $p, $x, $y, $report, $data, $xPadding, $yPadding) = @_;

	my $properties =
	{
		'text' => $data,
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $xPadding,
		'y' => $y - $yPadding
	};
	$report->drawText($p, $properties);
}

1;