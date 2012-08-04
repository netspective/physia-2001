package App::Billing::Output::TWCC::TWCC60;

use App::Billing::Output::PDF::Report;
use App::Billing::Claim::TWCC60;
use pdflib 2.01;
use Number::Format;
use strict;

use constant LEFT_MARGIN => 36;
use constant TOP_MARGIN => 756; # 792 - 36
use constant LINE_SPACING => 8;
use constant MAIN_BOX_Y => 78;
use constant MAIN_BOX_WIDTH => 540;
use constant HALF_MAIN_BOX_WIDTH => MAIN_BOX_WIDTH/2;
use constant QUARTER_MAIN_BOX_WIDTH => MAIN_BOX_WIDTH/4;
use constant ONE_THIRD_MAIN_BOX_WIDTH => MAIN_BOX_WIDTH/3;

use constant BOX_HEIGHT => 23;
use constant BOX1_HEIGHT => 28;
use constant BOX28_HEIGHT => 18;
use constant SHORT_BOX_HEIGHT => 18;
use constant DOUBLE_BOX_HEIGHT => 44;
use constant PART_HEIGHT => 15;
use constant PART_SPACING => 27;

use constant LEFT_LINE => 1;
use constant RIGHT_LINE => 1;
use constant TOP_LINE => 1;
use constant BOTTOM_LINE => 1;
use constant NO_LEFT_LINE => 0;
use constant NO_RIGHT_LINE => 0;
use constant NO_TOP_LINE => 0;
use constant NO_BOTTOM_LINE => 0;
use constant SPC => " ";
use constant DATA_LEFT_PADDING => 3;
use constant DATA_TOP_PADDING => 10;
use constant DATA_FONT_SIZE => 8;
use constant DATA_FONT_COLOR => '0,0,0';
use constant FONT_NAME => 'Times-Roman';
use constant BOLD_FONT_NAME =>  'Times-Bold';
use constant DATA_FONT_NAME => 'Helvetica';
use constant DATEFORMAT_USA => 1;
use constant LEFT_PADDING => 2;
use constant TOP_PADDING => 6;

use constant PAGE2_WIDTH => 792;
use constant PAGE2_HEIGHT => 612;

use constant LEFT_MARGIN_2 => 36;
use constant TOP_MARGIN_2 => 576; # 612 - 36
use constant MAIN_BOX_Y_2 => 30;
use constant BOX_HEIGHT_2 => 22;
use constant BOX_WIDTH_2 => 66;
use constant WIDE_BOX_WIDTH_2 => 158;
use constant BOX_HEAD_HEIGHT_2 => 38;

sub new
{
	my ($type) = shift;
	my $self = {};
	return bless $self, $type;
}

sub printReport
{
	my ($self, $p, $claim) = @_;
	my $report = new App::Billing::Output::PDF::Report();
	$report->newPage($p);
	$self->drawForm($p, $claim, $report);
	$self->fillData($p, $claim, $report);
	$report->endPage($p);
	
	my $properties = {'pageWidth' => PAGE2_WIDTH, 'pageHeight' => PAGE2_HEIGHT};
	$report->newPage($p, $properties);
	$self->drawForm_2($p, $claim, $report);
	$self->fillData_2($p, $claim, $report);
	$report->endPage($p);
}

sub drawForm
{
	my($self, $p, $claim, $report) = @_;

	my $mainBoxX = LEFT_MARGIN;
	my $mainBoxY = TOP_MARGIN - MAIN_BOX_Y;

	$self->header($p, $claim, $mainBoxX, $mainBoxY, $report);
	$self->boxPart1($p, $claim, $mainBoxX, $mainBoxY, $report);

	$self->box1($p, $claim, $mainBoxX, $mainBoxY - PART_HEIGHT, $report);
	$self->box2($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $mainBoxY - PART_HEIGHT, $report);
	
	my $box3Y = $mainBoxY - PART_HEIGHT - BOX1_HEIGHT;
	
	$self->box3($p, $claim, $mainBoxX, $box3Y, $report);
	$self->box4($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box3Y, $report);
	$self->box5($p, $claim, $mainBoxX, $box3Y - BOX_HEIGHT, $report);
	$self->box6($p, $claim, $mainBoxX + QUARTER_MAIN_BOX_WIDTH, $box3Y - BOX_HEIGHT, $report);
	$self->box7($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box3Y - BOX_HEIGHT, $report);
	$self->box8($p, $claim, $mainBoxX, $box3Y - 2 * BOX_HEIGHT, $report);
	$self->box9($p, $claim, $mainBoxX + QUARTER_MAIN_BOX_WIDTH, $box3Y - 2 * BOX_HEIGHT, $report);
	$self->box10($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box3Y - 2 * BOX_HEIGHT, $report);
	$self->box11($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH + QUARTER_MAIN_BOX_WIDTH, $box3Y - 2 * BOX_HEIGHT, $report);
	
	my $boxPart2Y = $box3Y - 3 * BOX_HEIGHT - PART_SPACING;
	$self->boxPart2($p, $claim, $mainBoxX, $boxPart2Y, $report);

	my $box12Y = $boxPart2Y - PART_HEIGHT;
	$self->box12($p, $claim, $mainBoxX, $box12Y, $report);
	$self->box27($p, $claim, $mainBoxX, $box12Y - 5 * BOX_HEIGHT, $report);

	my $boxPart3Y = $box12Y - 5 * BOX_HEIGHT - DOUBLE_BOX_HEIGHT - 14;
	$self->boxPart3($p, $claim, $mainBoxX, $boxPart3Y, $report);
	$self->box28($p, $claim, $mainBoxX, $boxPart3Y - PART_HEIGHT, $report);

	my $box29Y = $boxPart3Y - PART_HEIGHT - BOX28_HEIGHT;
	$self->box29($p, $claim, $mainBoxX, $box29Y, $report);
	$self->box30($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box29Y, $report);
	$self->box31($p, $claim, $mainBoxX, $box29Y - BOX_HEIGHT, $report);
	$self->box32($p, $claim, $mainBoxX + QUARTER_MAIN_BOX_WIDTH, $box29Y - BOX_HEIGHT, $report);
	$self->box33($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box29Y - BOX_HEIGHT, $report);
	$self->box34($p, $claim, $mainBoxX, $box29Y - 2 * BOX_HEIGHT, $report);
	$self->box35($p, $claim, $mainBoxX + QUARTER_MAIN_BOX_WIDTH, $box29Y - 2 * BOX_HEIGHT, $report);
	$self->box36($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box29Y - 2 * BOX_HEIGHT, $report);
	$self->box37($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH + QUARTER_MAIN_BOX_WIDTH, $box29Y - 2 * BOX_HEIGHT, $report);
	$self->box38($p, $claim, $mainBoxX, $box29Y - 3 * BOX_HEIGHT, $report);
	
	my $boxPart4Y = $box29Y - 3 * BOX_HEIGHT - DOUBLE_BOX_HEIGHT - PART_SPACING;
	$self->boxPart4($p, $claim, $mainBoxX, $boxPart4Y, $report);
	
	my $box39Y = $boxPart4Y - PART_HEIGHT;
	$self->box39($p, $claim, $mainBoxX, $box39Y, $report);
	$self->box42($p, $claim, $mainBoxX, $box39Y - DOUBLE_BOX_HEIGHT, $report);

	$self->footer($p, $claim, $mainBoxX, $box39Y - DOUBLE_BOX_HEIGHT - BOX_HEIGHT, $report);
}

sub drawForm_2
{
	my($self, $p, $claim, $report) = @_;

	my $mainBoxX_2 = LEFT_MARGIN_2;
	my $mainBoxY_2 = TOP_MARGIN_2 - MAIN_BOX_Y_2;
	$self->header_2($p, $claim, $mainBoxX_2, $mainBoxY_2, $report);
	$self->body_2($p, $claim, $mainBoxX_2, $mainBoxY_2 - BOX_HEAD_HEIGHT_2, $report);
	$self->footer_2($p, $claim, $mainBoxX_2, $mainBoxY_2 - 16 * BOX_HEIGHT_2 - 2 * BOX_HEAD_HEIGHT_2, $report);
}

sub fillData
{
	my($self, $p, $claim, $report) = @_;

	my $mainBoxX = LEFT_MARGIN;
	my $mainBoxY = TOP_MARGIN - MAIN_BOX_Y;

	$self->box1Data($p, $claim, $mainBoxX, $mainBoxY - PART_HEIGHT, $report);
	$self->box2Data($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $mainBoxY - PART_HEIGHT, $report);
	
	my $box3Y = $mainBoxY - PART_HEIGHT - BOX1_HEIGHT;
	
	$self->box3Data($p, $claim, $mainBoxX, $box3Y, $report);
	$self->box4Data($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box3Y, $report);
	$self->box5Data($p, $claim, $mainBoxX, $box3Y - BOX_HEIGHT, $report);
	$self->box6Data($p, $claim, $mainBoxX + QUARTER_MAIN_BOX_WIDTH, $box3Y - BOX_HEIGHT, $report);
	$self->box7Data($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box3Y - BOX_HEIGHT, $report);
	$self->box8Data($p, $claim, $mainBoxX, $box3Y - 2 * BOX_HEIGHT, $report);
	$self->box9Data($p, $claim, $mainBoxX + QUARTER_MAIN_BOX_WIDTH, $box3Y - 2 * BOX_HEIGHT, $report);
	$self->box10Data($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box3Y - 2 * BOX_HEIGHT, $report);
	$self->box11Data($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH + QUARTER_MAIN_BOX_WIDTH, $box3Y - 2 * BOX_HEIGHT, $report);
	
	my $boxPart2Y = $box3Y - 3 * BOX_HEIGHT - PART_SPACING;
	$self->boxPart2($p, $claim, $mainBoxX, $boxPart2Y, $report);

	my $box12Y = $boxPart2Y - PART_HEIGHT;
	$self->box12Data($p, $claim, $mainBoxX, $box12Y, $report);
	$self->box13Data($p, $claim, $mainBoxX + ONE_THIRD_MAIN_BOX_WIDTH, $box12Y, $report);
	$self->box14Data($p, $claim, $mainBoxX + 2 * ONE_THIRD_MAIN_BOX_WIDTH, $box12Y, $report);
	
	$self->box15Data($p, $claim, $mainBoxX, $box12Y - BOX_HEIGHT, $report);
	$self->box16Data($p, $claim, $mainBoxX + ONE_THIRD_MAIN_BOX_WIDTH, $box12Y - BOX_HEIGHT, $report);
	$self->box17Data($p, $claim, $mainBoxX + 2 * ONE_THIRD_MAIN_BOX_WIDTH, $box12Y - BOX_HEIGHT, $report);
	
	$self->box18Data($p, $claim, $mainBoxX, $box12Y - 2 * BOX_HEIGHT, $report);
	$self->box19Data($p, $claim, $mainBoxX + ONE_THIRD_MAIN_BOX_WIDTH, $box12Y - 2 * BOX_HEIGHT, $report);
	$self->box20Data($p, $claim, $mainBoxX + 2 * ONE_THIRD_MAIN_BOX_WIDTH, $box12Y - 2 * BOX_HEIGHT, $report);
	
	$self->box21Data($p, $claim, $mainBoxX, $box12Y - 3 * BOX_HEIGHT, $report);
	$self->box22Data($p, $claim, $mainBoxX + ONE_THIRD_MAIN_BOX_WIDTH, $box12Y - 3 * BOX_HEIGHT, $report);
	$self->box23Data($p, $claim, $mainBoxX + 2 * ONE_THIRD_MAIN_BOX_WIDTH, $box12Y - 3 * BOX_HEIGHT, $report);
	
	$self->box24Data($p, $claim, $mainBoxX, $box12Y - 4 * BOX_HEIGHT, $report);
	$self->box25Data($p, $claim, $mainBoxX + ONE_THIRD_MAIN_BOX_WIDTH, $box12Y - 4 * BOX_HEIGHT, $report);
	$self->box26Data($p, $claim, $mainBoxX + 2 * ONE_THIRD_MAIN_BOX_WIDTH, $box12Y - 4 * BOX_HEIGHT, $report);

	$self->box27Data($p, $claim, $mainBoxX, $box12Y - 5 * BOX_HEIGHT, $report);

	my $boxPart3Y = $box12Y - 5 * BOX_HEIGHT - DOUBLE_BOX_HEIGHT - 14;
	$self->boxPart3($p, $claim, $mainBoxX, $boxPart3Y, $report);
	$self->box28Data($p, $claim, $mainBoxX, $boxPart3Y - PART_HEIGHT, $report);

	my $box29Y = $boxPart3Y - PART_HEIGHT - BOX28_HEIGHT;
	$self->box29Data($p, $claim, $mainBoxX, $box29Y, $report);
	$self->box30Data($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box29Y, $report);
	$self->box31Data($p, $claim, $mainBoxX, $box29Y - BOX_HEIGHT, $report);
	$self->box32Data($p, $claim, $mainBoxX + QUARTER_MAIN_BOX_WIDTH, $box29Y - BOX_HEIGHT, $report);
	$self->box33Data($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box29Y - BOX_HEIGHT, $report);
	$self->box34Data($p, $claim, $mainBoxX, $box29Y - 2 * BOX_HEIGHT, $report);
	$self->box35Data($p, $claim, $mainBoxX + QUARTER_MAIN_BOX_WIDTH, $box29Y - 2 * BOX_HEIGHT, $report);
	$self->box36Data($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH, $box29Y - 2 * BOX_HEIGHT, $report);
	$self->box37Data($p, $claim, $mainBoxX + HALF_MAIN_BOX_WIDTH + QUARTER_MAIN_BOX_WIDTH, $box29Y - 2 * BOX_HEIGHT, $report);
	$self->box38Data($p, $claim, $mainBoxX, $box29Y - 3 * BOX_HEIGHT, $report);
	
}

sub fillData_2
{
	my($self, $p, $claim, $report) = @_;

	my $mainBoxX_2 = LEFT_MARGIN_2;
	my $mainBoxY_2 = TOP_MARGIN_2 - MAIN_BOX_Y_2;
	my ($x, $y) = ($mainBoxX_2, $mainBoxY_2 - BOX_HEAD_HEIGHT_2);
	my (@itemMap, @itemMap2, $functionRef, $data, @total, $xpad);

	$itemMap[0] = \&App::Billing::Claim::TWCC60::getDisputedDOS;
	$itemMap[1] = \&App::Billing::Claim::TWCC60::getCPTCode;
	$itemMap[2] = \&App::Billing::Claim::TWCC60::getAmountBilled;
	$itemMap[3] = \&App::Billing::Claim::TWCC60::getMedicalFee;
	$itemMap[4] = \&App::Billing::Claim::TWCC60::getTotalAmountPaid;
	$itemMap[5] = \&App::Billing::Claim::TWCC60::getAmountInDispute;
	$itemMap2[0] = \&App::Billing::Claim::TWCC60::getIncreasedReimburse;
	$itemMap2[1] = \&App::Billing::Claim::TWCC60::getMaintainingReduction;

	my $twcc60 = $claim->getTWCC60;
	my $count = $#{$twcc60->{first4Fields}}; 
	my $formatter = new Number::Format('INT_CURR_SYMBOL'=>'$');
	
	for my $h(0..$count)
	{
		for my $i(0..5)
		{
			$functionRef = $itemMap[$i];
			$data = &$functionRef($twcc60, $h);
			if ($i == 2 || $i == 3 || $i == 4 || $i == 5)
			{
				$total[$i] += $data;
				$data = $formatter->format_price($data);
				$xpad = pdflib::PDF_stringwidth($p, $data, DATA_FONT_NAME, DATA_FONT_SIZE);
				$self->boxData($p, $claim, $x + $i * BOX_WIDTH_2, $y - $h * BOX_HEIGHT_2, $report, $data, 50 - $xpad, 7);
			}
			else
			{
				$self->boxData($p, $claim, $x + $i * BOX_WIDTH_2, $y - $h * BOX_HEIGHT_2, $report, $data, 10, 7);
			}
		}
	}
	
	for my $h(0..$count)
	{
		for my $i(0..1)
		{
			$functionRef = $itemMap2[$i];
			$data = &$functionRef($twcc60, $h);
			$self->boxData($p, $claim, $x + 6 * BOX_WIDTH_2 + $i * WIDE_BOX_WIDTH_2, $y - $h * BOX_HEIGHT_2, $report, $data, 5, 7);
		}
	}
	
	my $arrX = [0,0,145,210,275,345];
	
	for my $i(2..5)
	{
		$data = $formatter->format_price($total[$i]);
		$xpad = pdflib::PDF_stringwidth($p, $data, DATA_FONT_NAME, DATA_FONT_SIZE);
		my $properties =
		{
			'text' => $data,
			'fontWidth' => DATA_FONT_SIZE,
			'color' => DATA_FONT_COLOR,
			'x' => $x + $arrX->[$i] + 36 - $xpad,
			'y' => $y - 16 * BOX_HEIGHT_2 - 15
		};
		$report->drawText($p,$properties);
	}

	
}

sub header
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $i;
	my $arrLeft = [
					"Mail fee disputes to:",
					"Texas Workers' Compenstion Commission",
					"Medical Dispute Resolution",
					"801, Austin Avenue, suite 1010",
					"Waco, TX 76701"
				];


	my $arrCenter = [
					"Mail all other disputes to:",
					"Texas Workers' Compenstion Commission",
					"Medical Dispute Resolution, MS-48",
					"4000 S,. IH-35",
					"Austin, Texas 78704-7491"
				];
				
	my $arrRight = [
					"HCP:  health care provider",
					"IC:   insurance carrier",
					"IE:   injured employee",
					"TD:   treating doctor"
				];

	for $i(0..4)
	{
		my $properties =
		{
			'text' => $arrLeft->[$i],
			'x' => LEFT_MARGIN,
			'y' => TOP_MARGIN - $i * LINE_SPACING,
			'fontName' => BOLD_FONT_NAME, 
			'fontWidth' => 7
		};
		$report->drawText($p,$properties);
	}

	for $i(0..4)
	{
		my $properties =
		{
			'text' => $arrCenter->[$i],
			'x' => LEFT_MARGIN + 202,
			'y' => TOP_MARGIN - $i * LINE_SPACING,
			'fontName' => BOLD_FONT_NAME,
			'fontWidth' => 7
		};
		$report->drawText($p,$properties);
	}

	for $i(0..3)
	{
		my $properties =
		{
			'text' => $arrRight->[$i],
			'x' => LEFT_MARGIN + 446,
			'y' => TOP_MARGIN - $i * LINE_SPACING,
			'fontName' => FONT_NAME,
			'fontWidth' => 7
		};
		$report->drawText($p,$properties);
	}

	my $properties =
	{
		'text' => "MEDICAL DISPUTE RESOLUTION REQUEST / RESPONSE",
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 11,
		'x' => LEFT_MARGIN + 116,
		'y' => TOP_MARGIN - 56
	};
	$report->drawText($p,$properties);
}

sub boxPart1
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"PART I: REQUESTOR INFORMATION - Requestor completes this section",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 8,
						'x' => $x + 2,
						'y' => $y - 2
					}
				]
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, PART_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box1
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' => "Type of Requestor:",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 8.5,
						'x' => $x,
						'y' => $y - 5
					},
					{
						'text' => "( ) HCP       ( ) IC        ( ) IE",
						'fontName' => FONT_NAME,
						'fontWidth' => 8.5,
						'x' => $x + 82,
						'y' => $y - 5
					}
				]
			};
	$report->drawBox($p, $x, $y, HALF_MAIN_BOX_WIDTH, BOX1_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box2
{
	my($self, $p, $claim, $x, $y, $report) = @_;


	my $properties =
			{
			texts =>
				[
					{
						'text' => "Type of Dispute:",
						'fontWidth' => 8.5,
						'fontName' => BOLD_FONT_NAME,
						'x' => $x,
						'y' => $y - TOP_PADDING
					},
					{
						'text' => "( ) TWCC Refund Order Appeal  ( ) Medical Necessity",
						'fontName' => FONT_NAME,
						'fontWidth' => 8.5,
						'x' => $x + 64,
						'y' => $y - TOP_PADDING
					},
					{
						'text' => "( ) Carrier Request for Refund  ( ) Fee Reimbursement  ( ) Preauthorization",
						'fontName' => FONT_NAME,
						'fontWidth' => 8.5,
						'x' => $x,
						'y' => $y - TOP_PADDING - 10
					},
				],
			};
	$report->drawBox($p, $x, $y, HALF_MAIN_BOX_WIDTH, BOX1_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box3
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"Requestor's Name",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
			};
	$report->drawBox($p, $x, $y, HALF_MAIN_BOX_WIDTH, BOX_HEIGHT , LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

}

sub box4
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Requestor's Address",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};

	$report->drawBox($p, $x, $y, HALF_MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub box5
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Contact Person's Name",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}


sub box6
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>  "Contact's Telephone #",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>  "(       )",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y - 9
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box7
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' => "Requestor's City, State, ZIP",
					'fontName' => FONT_NAME,
					'fontWidth' => 8,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, HALF_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box8
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Contact's Fax #",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>  "(       )",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y - 9
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box9
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Contact's E-mail",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box10
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "FEIN",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box11
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Professional License # (if applicable)",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub boxPart2
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"PART II: GENERAL CLAIM INFORMATION - Requestor completes this section; respondent supplements information",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 9,
						'x' => $x + 2,
						'y' => $y - 3
					},
					{
						'text' => "REQUESTOR - Send or mail two complete copies of REQUEST with documentation to TWCC at address above",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y + 18
					}
				]
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, PART_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box12
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arr = 	[
					["IE's Name:", "TD's Name:", "IC's Name:"],
					["Date of Injury:", "TD's Telephone #:      (       )", "IC's Telephone #:      (       )"],
					["IE's Telephone #:      (       )", "TD's Fax #:      (       )", "IC's Fax #:      (       )"],
					["IE's Social Security #:", "TD's Email:", "IC's Email:"],
					["IE's TWCC #:", "Employer's Name:", "IE's Carrier Claim #:"]
				];
	
	for my $i(0..4)
	{
		for my $j(0..2)
		{
			my $properties =
				{
					texts =>
						[
							{
								'text' => $arr->[$i][$j],
								'fontName' => FONT_NAME,
								'fontWidth' => 8,
								'x' => $x + $j * ONE_THIRD_MAIN_BOX_WIDTH + LEFT_PADDING,
								'y' => $y - $i * BOX_HEIGHT - TOP_PADDING
							}
						]
				};
			$report->drawBox($p,  $x + $j * ONE_THIRD_MAIN_BOX_WIDTH,  $y - $i * BOX_HEIGHT, ONE_THIRD_MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
		}
	}
}

sub box27
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Has the carrier filed a notice of denial relating to liability for or compensability of the injury that has not yet been resolved?  (  ) No  (  ) Yes",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x + LEFT_PADDING,
						'y' => $y - TOP_PADDING
					},
					{
						'text' => "Has the carrier filed a notice of dispute relating to extent of injury that has not yet been resolved and that is related to this dispute?  (  ) No  (  ) Yes",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x + LEFT_PADDING,
						'y' => $y - TOP_PADDING - 22
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, DOUBLE_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub boxPart3
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' => "PART III: RESPONDENT INFORMATION - Respondent completes this section",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 8,
						'x' => $x + 2,
						'y' => $y - 3
					}
				]
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, PART_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box28
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Type of Respondent:",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 8.5,
						'x' => $x + LEFT_PADDING,
						'y' => $y - TOP_PADDING
					},
					{
						'text' => "(  ) HCP      (  ) IC      (  ) IE",
						'fontName' => FONT_NAME,
						'fontWidth' => 8.5,
						'x' => $x + LEFT_PADDING + 82,
						'y' => $y - TOP_PADDING
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, BOX28_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box29
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"Respondent's Name",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
			};
	$report->drawBox($p, $x, $y, HALF_MAIN_BOX_WIDTH, BOX_HEIGHT , LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

}

sub box30
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Respondent's Address",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};

	$report->drawBox($p, $x, $y, HALF_MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub box31
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Contact Person's Name",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}


sub box32
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>  "Contact's Telephone #",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>  "(       )",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y - 9
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box33
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' => "Respondent's City, State, ZIP",
					'fontName' => FONT_NAME,
					'fontWidth' => 8,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, HALF_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box34
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Contact's Fax #",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>  "(       )",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y - 9
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box35
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Contact's E-mail",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box36
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "FEIN",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box37
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Professional License # (if applicable)",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, QUARTER_MAIN_BOX_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box38
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' => "Has the issue(s) been resolved? ( ) No       ( ) Yes  If yes, describe how it was resolved and attach documents",
						'fontName' => FONT_NAME,
						'fontWidth' => 8,
						'x' => $x + LEFT_PADDING,
						'y' => $y - TOP_PADDING
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, DOUBLE_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub boxPart4
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' => "PART IV: TWCC TRACKING INFORMATION - TWCC completes this section",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 8,
						'x' => $x + 2,
						'y' => $y - 3
					},
					{
						'text' => "RESPONDENT - Send or mail one complete copy of RESPONSE with documentation to REQUESTOR and one to TWCC",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 8,
						'x' => $x,
						'y' => $y + 18
					}
				]
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, PART_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box39
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arr = 	[
					"Date Stamp for Receipt from Requestor",
					"Date Request sent to Respondent",
					"Date Stamp for Receipt from Respondent"
				];
	
	for my $i(0..2)
	{
		my $properties =
				{
					texts =>
						[
							{
								'text' => $arr->[$i],
								'fontName' => FONT_NAME,
								'fontWidth' => 8,
								'x' => $x + $i * ONE_THIRD_MAIN_BOX_WIDTH,
								'y' => $y
							}
						]
				};
		$report->drawBox($p,  $x + $i * ONE_THIRD_MAIN_BOX_WIDTH,  $y, ONE_THIRD_MAIN_BOX_WIDTH, DOUBLE_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	}
}

sub box42
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arr = 	[
					"Was Request Complete?  ( ) No   ( ) Yes",
					"TWCC Tracking #",
					"Was Response Complete?  ( ) No   ( ) Yes"
				];
	
	for my $i(0..2)
	{
		my $properties =
				{
					texts =>
						[
							{
								'text' => $arr->[$i],
								'fontName' => FONT_NAME,
								'fontWidth' => 8.5,
								'x' => $x + $i * ONE_THIRD_MAIN_BOX_WIDTH + LEFT_PADDING,
								'y' => $y - TOP_PADDING
							}
						]
				};
		$report->drawBox($p,  $x + $i * ONE_THIRD_MAIN_BOX_WIDTH,  $y, ONE_THIRD_MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	}
}

sub footer
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => "PLEASE TYPE OR PRINT - ALL INFORMATION MUST BE LEGIBLE",
		'fontWidth' => 9,
		'fontName' => BOLD_FONT_NAME,
		'x' => $x + 126,
		'y' => $y - 18
	};
	$report->drawText($p, $properties);

	my $arr =	[ 	
					"TWCC 60a/b (Rev 08/2000)",
					"Medical Review Division",
					"Rule 133.305",
					"TEXAS WORKERS' COMPENSATION COMMISSION"
				];
				
	my $arrX = [0,128,260,350];

	for my $i(0..3)
	{
		my $properties =
			{
				'text' => $arr->[$i],
				'fontWidth' => 8,
				'x' => $x + $arrX->[$i],
				'y' => $y - 48
			};
		$report->drawText($p, $properties);
	}
}

sub box1Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my $arrX = [83,125,160];
	
	my $properties =
	{
		'text' => "X",
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arrX->[$claim->{twcc60}->getRequestorType - 1],
		'y' => $y - 5
	};
	$report->drawText($p, $properties);
}

sub box2Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my $arrX = [65,180,1,108,191];
	my $arrY = [6,6,16,16,16];
	
	my $properties =
	{
		'text' => "X",
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x  + $arrX->[$claim->{twcc60}->getDisputeType - 1],
		'y' => $y  - $arrY->[$claim->{twcc60}->getDisputeType - 1]
	};
	$report->drawText($p, $properties);
}

sub box3Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->getRequestorName, 
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box4Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->{requestorAddress}->getAddress1,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box5Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->getRequestorContactName,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box6Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
				substr($claim->{twcc60}->{requestorAddress}->getTelephoneNo, 0, 3) . "  " . substr($claim->{twcc60}->{requestorAddress}->getTelephoneNo, 3, 3) . "-" . substr($claim->{twcc60}->{requestorAddress}->getTelephoneNo, 6, 4),
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box7Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
				$claim->{twcc60}->{requestorAddress}->getCity,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box8Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
				substr($claim->{twcc60}->{requestorAddress}->getFaxNo, 0, 3) . "  " . substr($claim->{twcc60}->{requestorAddress}->getFaxNo, 3, 3) . "-" . substr($claim->{twcc60}->{requestorAddress}->getFaxNo, 6, 4),
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box9Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->{requestorAddress}->getEmailAddress,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box10Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->getRequestorFEIN,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box11Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->getRequestorLicenseNo,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box12Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{careReceiver}->getName, 45, 6);
}

sub box13Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{renderingProvider}->getName, 45, 6);
}

sub box14Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{payer}->getName, 45, 6);
}

sub box15Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
					$claim->{treatment}->getDateOfIllnessInjuryPregnancy(DATEFORMAT_USA), 
					55, 6);
}

sub box16Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
					substr($claim->{renderingProvider}->{address}->getTelephoneNo, 0, 3) . "   " . substr($claim->{renderingProvider}->{address}->getTelephoneNo, 3, 3) . "-" . substr($claim->{renderingProvider}->{address}->getTelephoneNo, 6, 4),
					75, 6);
}

sub box17Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
					substr($claim->{payer}->{address}->getTelephoneNo, 0, 3) . "   " . substr($claim->{payer}->{address}->getTelephoneNo, 3, 3) . "-" . substr($claim->{payer}->{address}->getTelephoneNo, 6, 4),
					73, 6);
}

sub box18Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
					substr($claim->{careReceiver}->{address}->getTelephoneNo, 0, 3) . "   " . substr($claim->{careReceiver}->{address}->getTelephoneNo, 3, 3) . "-" . substr($claim->{careReceiver}->{address}->getTelephoneNo, 6, 4),
					73, 6);
}

sub box19Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
					substr($claim->{renderingProvider}->{address}->getFaxNo, 0, 3) . "   " . substr($claim->{renderingProvider}->{address}->getFaxNo, 3, 3) . "-" . substr($claim->{renderingProvider}->{address}->getFaxNo, 6, 4),
					75, 6);
}

sub box20Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
					substr($claim->{payer}->{address}->getFaxNo, 0, 3) . "   " . substr($claim->{payer}->{address}->getFaxNo, 3, 3) . "-" . substr($claim->{payer}->{address}->getFaxNo, 6, 4),
					75, 6);
}

sub box21Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{careReceiver}->getSsn,	85, 6);
}

sub box22Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
				$claim->{renderingProvider}->{address}->getEmailAddress,
				75, 6);
}

sub box23Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{payer}->{address}->getEmailAddress, 75, 6);
}

sub box24Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
				$claim->{insured}->[$claim->getClaimType]->getPolicyGroupOrFECANo,
				75, 6);
}

sub box25Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
				$claim->{insured}->[$claim->getClaimType]->getEmployerOrSchoolName,
				85, 6);
}

sub box26Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report,  $claim->getId, 80, 6);
}

sub box27Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my $arrX1 = [429,404];
	
	my $properties =
	{
		'text' => "X",
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arrX1->[$claim->{twcc60}->getNoticeOfDenial - 1],
		'y' => $y - 6
	};
	$report->drawText($p, $properties);

	my $arrX2 = [450,425];
	
	$properties =
	{
		'text' => "X",
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arrX2->[$claim->{twcc60}->getNoticeOfDispute - 1],
		'y' => $y - 28
	};
	$report->drawText($p, $properties);
}

sub box28Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my $arrX = [86,128,161];
	
	my $properties =
	{
		'text' => "X",
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arrX->[$claim->{twcc60}->getRespondentType - 1],
		'y' => $y - 6
	};
	$report->drawText($p, $properties);
}

sub box29Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->getRespondentName,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box30Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->{respondentAddress}->getAddress1,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box31Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->getRespondentContactName,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box32Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
				substr($claim->{twcc60}->{respondentAddress}->getTelephoneNo, 0, 3) . "  " . substr($claim->{twcc60}->{respondentAddress}->getTelephoneNo, 3, 3) . "-" . substr($claim->{twcc60}->{respondentAddress}->getTelephoneNo, 6, 4),
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box33Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
				$claim->{twcc60}->{respondentAddress}->getCity,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box34Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, 
				substr($claim->{twcc60}->{respondentAddress}->getFaxNo, 0, 3) . "  " . substr($claim->{twcc60}->{respondentAddress}->getFaxNo, 3, 3) . "-" . substr($claim->{twcc60}->{respondentAddress}->getFaxNo, 6, 4),
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box35Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->{respondentAddress}->getEmailAddress,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box36Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->getRespondentFEIN,
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box37Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	$self->boxData($p, $claim, $x, $y, $report, $claim->{twcc60}->getRespondentLicenseNo, 
				DATA_LEFT_PADDING, DATA_TOP_PADDING);
}

sub box38Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my $arrX = [139,105];
	
	my $properties =
	{
		'text' => "X",
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arrX->[$claim->{twcc60}->getIssueResolved - 1],
		'y' => $y - 6
	};
	$report->drawText($p, $properties);
	
	$properties =
		{
			'text' => $claim->{twcc60}->getIssueResolvedDesc,
			'fontWidth' => DATA_FONT_SIZE,
			'color' => DATA_FONT_COLOR,
			'x' => $x + 3,
			'y' => $y - 18
		};
	$report->drawText($p, $properties);
}


sub header_2
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => "TABLE OF DISPUTED SERVICES",
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 11,
		'x' => $x + 270,
		'y' => $y + 30 
	};
	$report->drawText($p, $properties);
	
	$properties = {};
	for my $i(0..5)
	{
		$report->drawBox($p,  $x + $i * BOX_WIDTH_2,  $y, BOX_WIDTH_2, BOX_HEAD_HEIGHT_2, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE);
	}
	
	for my $i(0..1)
	{
		$report->drawBox($p,  $x + 6 * BOX_WIDTH_2 + $i * WIDE_BOX_WIDTH_2,  $y, WIDE_BOX_WIDTH_2, BOX_HEAD_HEIGHT_2, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
	}
	
	my $arr =	[ 	
					"DISPUTED","CPT CODE(s)","AMOUNT", "MEDICAL FEE", "TOTAL", "AMOUNT IN","REQUESTOR'S RATIONALE FOR", "REQUESTOR'S RATIONALE FOR", 
					"DOS", "BILLED", "GUIDELINE", "AMOUNT", "DISPUTE", "INCREASED REIMBURSEMENT OR", "MAINTAINING THE REDUCTION OR",
					"MAR", "PAID", "REFUND", "DENIAL"
				];
				
	my $arrX = [14,73,144,202,280,336,400,558,  24,148,207,277,342,400,558,  220,284,400,558];
	my $arrY = [10,10,10,10,10,10,10,10,  20,20,20,20,20,20,20,  30,30,30,30];

	for my $i(0..18)
	{
		my $properties =
			{
				'text' => $arr->[$i],
				'fontName' => BOLD_FONT_NAME,
				'fontWidth' => 8,
				'x' => $x + $arrX->[$i] - 2,
				'y' => $y - $arrY->[$i] + 3
			};
		$report->drawText($p, $properties);
	}
	
	
}

sub body_2
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties = {};
	for my $h(0..15)
	{
		for my $i(0..5)
		{
			$report->drawBox($p,  $x + $i * BOX_WIDTH_2,  $y - $h * BOX_HEIGHT_2, BOX_WIDTH_2, BOX_HEIGHT_2, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
		}
	}
	
	for my $h(0..15)
	{
		for my $i(0..1)
		{
			$report->drawBox($p,  $x + 6 * BOX_WIDTH_2 + $i * WIDE_BOX_WIDTH_2,  $y - $h * BOX_HEIGHT_2, WIDE_BOX_WIDTH_2, BOX_HEIGHT_2, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
		}
	}
	
	for my $i(0..5)
	{
		$report->drawBox($p,  $x + $i * BOX_WIDTH_2,  $y - 16 * BOX_HEIGHT_2, BOX_WIDTH_2, BOX_HEAD_HEIGHT_2, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
	}
	
	$properties =
	{
		'text' => "TOTALS",
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 11,
		'x' => $x + 8,
		'y' => $y - 16 * BOX_HEIGHT_2 - 14
	};
	$report->drawText($p, $properties);
	

}

sub footer_2
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $arr =	[ "DOS: dates of services",	"MAR:  maximum allowable reimbursement"];
	my $arrX = [0,130];
	for my $i(0..1)
	{
		my $properties =
		{
			'text' => $arr->[$i],
			'fontName' => FONT_NAME,
			'fontWidth' => 8,
			'x' => $x + $arrX->[$i],
			'y' => $y - 14
		};
		$report->drawText($p, $properties);
	}	
	
	my $properties = 
	{
		'text' => "PLEASE TYPE OR PRINT - ALL INFORMATION MUST BE LEGIBLE",
		'fontName' => 'Helvetica-Bold',
		'fontWidth' => 7,
		'x' => $x + 250,
		'y' => $y - 48
	};
	$report->drawText($p, $properties);
	
	$arr =	[ "TWCC 60a/b (Rev 08/2000)", "Medical Review Division"	];
	$arrX = [0,625];
	for my $i(0..1)
	{
		my $properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + $arrX->[$i],
			'y' => $y - 48
		};
		$report->drawText($p, $properties);
	}	
}

sub boxData
{
	my($self, $p, $claim, $x, $y, $report, $data, $xPadding, $yPadding) = @_;
	
	my $properties =
	{
		'text' => $data,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $xPadding,
		'y' => $y - $yPadding
	};
	$report->drawText($p, $properties);
}

1;