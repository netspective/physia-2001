package App::Billing::Output::TWCC::TWCC73;


use App::Configuration;
use App::Billing::Output::PDF::Report;
use App::Billing::Claim::TWCC73;
use pdflib 2.01;

use constant LEFT_MARGIN => 48;
use constant TOP_MARGIN => 756; # 792 - 36
use constant BOX_HEIGHT => 22;
use constant LINE_SPACING_SMALL => 5.5;
use constant LINE_SPACING => 10;
use constant MAIN_BOX_Y => 48;
use constant MAIN_BOX_WIDTH => 522;
use constant PART_SPACING => 5;
use constant PART1_HEIGHT => BOX_HEIGHT;
use constant PART_HEIGHT => 14;
use constant BOX1_WIDTH => 166;
use constant BOX2_WIDTH => 62;
use constant BOX3_WIDTH => BOX1_WIDTH - BOX2_WIDTH;
use constant BOX5_WIDTH => 166;
use constant BOX9_WIDTH => MAIN_BOX_WIDTH - BOX1_WIDTH - BOX5_WIDTH;

use constant BOX14_WIDTH => 178;
use constant BOX17_WIDTH => 172;
use constant BOX16_WIDTH => BOX14_WIDTH + BOX17_WIDTH;
use constant BOX19_WIDTH => MAIN_BOX_WIDTH - BOX14_WIDTH - BOX17_WIDTH;

use constant BOX21_WIDTH => 150;
use constant BOX22_WIDTH => MAIN_BOX_WIDTH - BOX21_WIDTH;

use constant BOX23_WIDTH => 62;
use constant BOX24_WIDTH => 128;
use constant BOX25_WIDTH => 136;
use constant BOX26_WIDTH => 42;
use constant BOX27_WIDTH => MAIN_BOX_WIDTH - BOX23_WIDTH - BOX24_WIDTH - BOX25_WIDTH - BOX26_WIDTH;

use constant BOX13_HEIGHT => 76;
use constant BOX14_HEIGHT => 124;
use constant BOX15_HEIGHT => 86;
use constant BOX16_HEIGHT => 74;
use constant BOX17_HEIGHT => 142;
use constant BOX18_HEIGHT => BOX14_HEIGHT + BOX15_HEIGHT - BOX17_HEIGHT;
use constant BOX19_HEIGHT => BOX14_HEIGHT + BOX15_HEIGHT;
use constant BOX20_HEIGHT => BOX16_HEIGHT;
use constant BOX21_HEIGHT => 68;
use constant BOX22_HEIGHT => BOX21_HEIGHT;
use constant BOX23_HEIGHT => 42;

use constant LEFT_LINE => 1;
use constant RIGHT_LINE => 1;
use constant TOP_LINE => 1;
use constant BOTTOM_LINE => 1;
use constant NO_LEFT_LINE => 0;
use constant NO_RIGHT_LINE => 0;
use constant NO_TOP_LINE => 0;
use constant NO_BOTTOM_LINE => 0;
use constant SPC => " ";
use constant DATA_LEFT_PADDING => 6;
use constant DATA_TOP_PADDING => 10;
use constant DATA_FONT_SIZE => 8;
use constant DATA_FONT_COLOR => '0,0,0';
use constant FONT_NAME => 'Helvetica';
use constant BOLD_FONT_NAME => FONT_NAME . '-Bold';
use constant DATEFORMAT_USA => 1;
use constant PHONE_FORMAT_DASHES => 1;
use constant LOGO_PATH => 'C:/Windows/Desktop/shared/blueseal.jpg';
use constant DATE_FORMAT_USA => 1;

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
}

sub drawForm
{
	my($self, $p, $claim, $report) = @_;


	my $mainBoxX = LEFT_MARGIN;
	my $mainBoxY = TOP_MARGIN - MAIN_BOX_Y;

	$self->header($p, $claim, $mainBoxX, $mainBoxY, $report);
	$self->boxPart1($p, $claim, $mainBoxX, $mainBoxY, $report);
	$self->boxTr($p, $claim, $mainBoxX + BOX1_WIDTH + BOX5_WIDTH, $mainBoxY, $report);
	$self->boxSent($p, $claim, $mainBoxX + MAIN_BOX_WIDTH - 70, $mainBoxY, $report);

	$self->box1($p, $claim, $mainBoxX, $mainBoxY - PART1_HEIGHT, $report);
	$self->box2($p, $claim, $mainBoxX, $mainBoxY - PART1_HEIGHT - BOX_HEIGHT, $report);
	$self->box3($p, $claim, $mainBoxX + BOX2_WIDTH, $mainBoxY - PART1_HEIGHT - BOX_HEIGHT, $report);
	$self->box4($p, $claim, $mainBoxX, $mainBoxY - PART1_HEIGHT - 2 * BOX_HEIGHT, $report);
	$self->box5($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY, $report);
	$self->box6($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY - PART1_HEIGHT, $report);
	$self->box7($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY - PART1_HEIGHT - BOX_HEIGHT, $report);
	$self->box8($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY - PART1_HEIGHT - 2 * BOX_HEIGHT, $report);
	$self->boxCity($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY - PART1_HEIGHT - 3 * BOX_HEIGHT, $report);
	$self->box9($p, $claim, $mainBoxX + BOX1_WIDTH + BOX5_WIDTH, $mainBoxY - PART1_HEIGHT, $report);
	$self->box10($p, $claim, $mainBoxX+ BOX1_WIDTH + BOX5_WIDTH, $mainBoxY - PART1_HEIGHT - BOX_HEIGHT, $report);
	$self->box11($p, $claim, $mainBoxX+ BOX1_WIDTH + BOX5_WIDTH, $mainBoxY - PART1_HEIGHT - 2 * BOX_HEIGHT, $report);
	$self->box12($p, $claim, $mainBoxX+ BOX1_WIDTH + BOX5_WIDTH, $mainBoxY - PART1_HEIGHT - 3 * BOX_HEIGHT, $report);

	my $boxPart2Y = $mainBoxY - PART1_HEIGHT - 4 * BOX_HEIGHT - PART_SPACING;
	$self->boxPart2($p, $claim, $mainBoxX, $boxPart2Y, $report);
	$self->box13($p, $claim, $mainBoxX, $boxPart2Y - PART_HEIGHT, $report);

	my $boxPart3Y = $boxPart2Y - PART_HEIGHT - BOX13_HEIGHT - PART_SPACING;
	$self->boxPart3($p, $claim, $mainBoxX, $boxPart3Y, $report);
	my $box14Y = $boxPart3Y - PART_HEIGHT;
	$self->box14($p, $claim, $mainBoxX, $box14Y, $report);
	$self->box15($p, $claim, $mainBoxX, $box14Y - BOX14_HEIGHT, $report);
	$self->box16($p, $claim, $mainBoxX, $box14Y - BOX14_HEIGHT - BOX15_HEIGHT, $report);
	$self->box17($p, $claim, $mainBoxX + BOX14_WIDTH, $box14Y, $report);
	$self->box18($p, $claim, $mainBoxX + BOX14_WIDTH, $box14Y - BOX17_HEIGHT, $report);
	$self->box19($p, $claim, $mainBoxX + BOX14_WIDTH + BOX17_WIDTH, $box14Y, $report);
	$self->box20($p, $claim, $mainBoxX + BOX14_WIDTH + BOX17_WIDTH, $box14Y - BOX19_HEIGHT, $report);

	my $boxPart4Y = $boxPart3Y - PART_HEIGHT - BOX14_HEIGHT - BOX15_HEIGHT - BOX16_HEIGHT - PART_SPACING;
	$self->boxPart4($p, $claim, $mainBoxX, $boxPart4Y, $report);

	my $box21Y = $boxPart4Y - PART_HEIGHT;
	$self->box21($p, $claim, $mainBoxX, $box21Y, $report);
	$self->box22($p, $claim, $mainBoxX + BOX21_WIDTH, $box21Y, $report);

	my $box23Y = $box21Y - BOX21_HEIGHT;
	$self->box23($p, $claim, $mainBoxX, $box23Y, $report);
	$self->box24($p, $claim, $mainBoxX + BOX23_WIDTH, $box23Y, $report);
	$self->box25($p, $claim, $mainBoxX + BOX23_WIDTH + BOX24_WIDTH, $box23Y, $report);
	$self->box26($p, $claim, $mainBoxX + BOX23_WIDTH + BOX24_WIDTH + BOX25_WIDTH, $box23Y, $report);
	$self->box27($p, $claim, $mainBoxX + BOX23_WIDTH + BOX24_WIDTH + BOX25_WIDTH + BOX26_WIDTH, $box23Y, $report);
	$self->footer($p, $claim, $mainBoxX, $box23Y - BOX23_HEIGHT, $report);

}

sub fillData
{
	my($self, $p, $claim, $report) = @_;

	my $mainBoxX = LEFT_MARGIN;
	my $mainBoxY = TOP_MARGIN - MAIN_BOX_Y;

	$self->box1Data($p, $claim, $mainBoxX, $mainBoxY - PART1_HEIGHT, $report);
	$self->box2Data($p, $claim, $mainBoxX, $mainBoxY - PART1_HEIGHT - BOX_HEIGHT, $report);
	$self->box3Data($p, $claim, $mainBoxX + BOX2_WIDTH, $mainBoxY - PART1_HEIGHT - BOX_HEIGHT, $report);
	$self->box4Data($p, $claim, $mainBoxX, $mainBoxY - PART1_HEIGHT - 2 * BOX_HEIGHT, $report);
	$self->box5Data($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY, $report);
	$self->box6Data($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY - PART1_HEIGHT, $report);
	$self->box7Data($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY - PART1_HEIGHT - BOX_HEIGHT, $report);
	$self->box8Data($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY - PART1_HEIGHT - 2 * BOX_HEIGHT, $report);
	$self->boxCityData($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY - PART1_HEIGHT - 3 * BOX_HEIGHT, $report);
	$self->box9Data($p, $claim, $mainBoxX + BOX1_WIDTH + BOX5_WIDTH, $mainBoxY - PART1_HEIGHT, $report);
	$self->box10Data($p, $claim, $mainBoxX+ BOX1_WIDTH + BOX5_WIDTH, $mainBoxY - PART1_HEIGHT - BOX_HEIGHT, $report);
	$self->box11Data($p, $claim, $mainBoxX+ BOX1_WIDTH + BOX5_WIDTH, $mainBoxY - PART1_HEIGHT - 2 * BOX_HEIGHT, $report);
	$self->box12Data($p, $claim, $mainBoxX+ BOX1_WIDTH + BOX5_WIDTH, $mainBoxY - PART1_HEIGHT - 3 * BOX_HEIGHT, $report);

	my $boxPart2Y = $mainBoxY - PART1_HEIGHT - 4 * BOX_HEIGHT - PART_SPACING;
	$self->box13Data($p, $claim, $mainBoxX, $boxPart2Y - PART_HEIGHT, $report);

	my $boxPart3Y = $boxPart2Y - PART_HEIGHT - BOX13_HEIGHT - PART_SPACING;
	my $box14Y = $boxPart3Y - PART_HEIGHT;
	$self->box14Data($p, $claim, $mainBoxX, $box14Y, $report);
	$self->box15Data($p, $claim, $mainBoxX, $box14Y - BOX14_HEIGHT, $report);
	$self->box16Data($p, $claim, $mainBoxX, $box14Y - BOX14_HEIGHT - BOX15_HEIGHT, $report);
	$self->box17Data($p, $claim, $mainBoxX + BOX14_WIDTH, $box14Y, $report);
	$self->box18Data($p, $claim, $mainBoxX + BOX14_WIDTH, $box14Y - BOX17_HEIGHT, $report);
	$self->box19Data($p, $claim, $mainBoxX + BOX14_WIDTH + BOX17_WIDTH, $box14Y, $report);
	$self->box20Data($p, $claim, $mainBoxX + BOX14_WIDTH + BOX17_WIDTH, $box14Y - BOX19_HEIGHT, $report);

	my $boxPart4Y = $boxPart3Y - PART_HEIGHT - BOX14_HEIGHT - BOX15_HEIGHT - BOX16_HEIGHT - PART_SPACING;
	my $box21Y = $boxPart4Y - PART_HEIGHT;
	$self->box21Data($p, $claim, $mainBoxX, $box21Y, $report);
	$self->box22Data($p, $claim, $mainBoxX + BOX21_WIDTH, $box21Y, $report);

	my $box23Y = $box21Y - BOX21_HEIGHT;
	$self->box26Data($p, $claim, $mainBoxX + BOX23_WIDTH + BOX24_WIDTH + BOX25_WIDTH, $box23Y, $report);
	$self->box27Data($p, $claim, $mainBoxX + BOX23_WIDTH + BOX24_WIDTH + BOX25_WIDTH + BOX26_WIDTH, $box23Y, $report);
}

sub header
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $i;
	my $arrLeft = [
					"Employee - You are required to report your injury to your employer within 30 days if",
					"your employer has workers' compensation insurance. You have the right to free",
					"assistance from the Texas Workers' Compensation Commission and may be entitled",
					"to certain medical and income benefits. For further information call your local",
					"Commission field office or 1(800)-252-7031"
				];

	my $arrRight = [
					"Trabajador - Es necesario que usted reporte su lesión a su empleador dentro de 30 dias a partir",
					"del dia en que se lesionó, si su empleador tiene seguro de compensación para trabajadores. la",
					"Comisión Tejana de Compensación para Trabajadores le ofrece asistencia gratuita, también",
					"puede que usted tenga derecho a ciertos beneficios médicos y monetarios. Para mayor",
					"información llame a la oficina local de la Comisión 1-800-252-7031."
				];

	for $i(0..4)
	{
		my $properties =
		{
			'text' => $arrLeft->[$i],
			'x' => LEFT_MARGIN,
			'y' => TOP_MARGIN - $i * LINE_SPACING_SMALL,
			'fontWidth' => 5.5
		};
		$report->drawText($p,$properties);
	}

	for $i(0..4)
	{
		$properties =
		{
			'text' => $arrRight->[$i],
			'x' => LEFT_MARGIN + 266,
			'y' => TOP_MARGIN - $i * LINE_SPACING_SMALL,
			'fontWidth' => 5.5
		};
		$report->drawText($p,$properties);
	}

	$properties =
	{
		'text' => "TEXAS WORKERS' COMPENSATION WORK STATUS REPORT",
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 11,
		'x' => LEFT_MARGIN + 82,
		'y' => TOP_MARGIN - 37
	};
	$report->drawText($p,$properties);

	my $webSite = $CONFDATA_SERVER->path_WebSite;
	my $iconPath = File::Spec->catfile($webSite, 'resources', 'icons', 'blueseal.jpg');
	$properties =
	{
		'imagePath' => $iconPath,
		'scale'  => 0.3,
		'x' => LEFT_MARGIN + 230,
		'y' => TOP_MARGIN - 30
	};
	$report->drawImageJPEG($p,$properties);
}

sub boxPart1
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	$properties =
	{
		'x' => $x,
		'y' => $y,
		'width' => BOX1_WIDTH,
		'height' => PART1_HEIGHT
	};
	$report->drawFilledRectangle($p, $properties);

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"PART I: GENERAL INFORMATION",
						'fontName' => BOLD_FONT_NAME,
						'color' => '1,1,1',
						'fontWidth' => 9,
						'x' => $x + 2,
						'y' => $y - 6
					}
				]
			};
	$report->drawBox($p, $x, $y, BOX1_WIDTH, PART1_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub boxTr
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"(for transmission purposes only)",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
			};
	$report->drawBox($p, $x, $y, 0, 0, NO_LEFT_LINE, NO_RIGHT_LINE, NO_TOP_LINE, NO_BOTTOM_LINE, $properties);
}

sub boxSent
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"Date Being Sent",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
			};
	$report->drawBox($p, $x, $y, 70, PART1_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, NO_BOTTOM_LINE, $properties);
}

sub box1
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"1. Injured Employee's Name",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
			};
	$report->drawBox($p, $x, $y, BOX1_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box2
{
	my($self, $p, $claim, $x, $y, $report) = @_;


	my $properties =
			{
			texts =>
				[
					{
						'text' =>"2. Date of Injury",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX2_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box3
{
	my($self, $p, $claim, $x, $y, $report) = @_;


	my $properties =
			{
			texts =>
				[
					{
						'text' =>"3. Social Security Number",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
			};
	$report->drawBox($p, $x, $y, BOX3_WIDTH, BOX_HEIGHT , NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

}

sub box4
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>"4. Employee's Description of Injury/Accident",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
		};

	$report->drawBox($p, $x, $y, BOX2_WIDTH + BOX3_WIDTH, 2 * BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub box5
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>"5. Doctor's Name and Degree",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, BOX5_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}


sub box6
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>"6. Clinic/Facility Name",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, BOX5_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box7
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>"7. Clinic/Facility/Doctor Phone & Fax",
					'fontWidth' => 6,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX5_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box8
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>"8. Clinic/Facility/Doctor Address (street address)",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, BOX5_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub boxCity
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>"City",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>"State",
						'fontWidth' => 6,
						'x' => $x + 60,
						'y' => $y
					},
					{
						'text' =>"Zip",
						'fontWidth' => 6,
						'x' => $x + 110,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, BOX5_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}



sub box9
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>"9. Employer's Name",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, BOX9_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box10
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>"10. Employer's Fax # or Email Address (if known)",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, BOX9_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box11
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>"11. Insurance Carrier",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, BOX9_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box12
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[
					{
						'text' =>"12. Carrier's Fax # or Email Address (if known)",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, BOX9_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub boxPart2
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	$properties =
	{
		'x' => $x,
		'y' => $y,
		'width' => MAIN_BOX_WIDTH,
		'height' => PART_HEIGHT
	};
	$report->drawFilledRectangle($p, $properties);

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"PART II: WORK STATUS INFORMATION",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 9,
						'color' =>  '1,1,1',
						'x' => $x + 2,
						'y' => $y - 3
					},
					{
						'text' => "(FULLY COMPLETE ONE INCLUDING ESTIMATED DATES AND DESCRIPTION IN 13(c) AS APPLICABLE)",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 6,
						'color' =>  '1,1,1',
						'x' => $x + 180,
						'y' => $y - 3
					}
				]
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, PART_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box13
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' => "13. The injured employee's medical condition resulting from the workers' compensation injury:",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
				{
					'text' => "        through ____________ (date).",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 33
				},
				{
					'text' => "        ____________ (date). The following describes how this injury",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 55
				}
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, BOX13_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = [
				"(a)    will allow the employee                                as of ____________ (date)",
				"(b)    will allow the employee                                as of ____________ (date)                                                                        which are expected to last",
				"(c)    has prevented and still prevents the employee                                           as of ____________ (date) and is expected to continue through"
			];

	my $arrY = [11,22,44];

	for my $i(0..2)
	{
		$properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + 14,
			'y' => $y - $arrY->[$i]
		};
		$report->drawText($p,$properties);
		$properties =
		{
			'x' => $x + 6,
			'y' => $y - $arrY->[$i]
		};
		$report->drawRadioButtonUnSelect($p,$properties);
	}

 	$arr = [
				"to return to work",
				"without restrictions.",
				"to return to work",
				"with the restrictions identified in PART III,",
				"from returning to work",
				"prevents the employee from returning to work:"
			];

	$arrX = [104,249,104,249,178,224];
	$arrY = [11,11,22,22,44,55];

	for my $i(0..5)
	{
		$properties =
		{
			'text' => $arr->[$i],
			'fontName' => BOLD_FONT_NAME,
			'fontWidth' => 7,
			'x' => $x + $arrX->[$i],
			'y' => $y - $arrY->[$i]
		};
		$report->drawText($p,$properties);
	}

	for $i(0..1)
	{
		$properties =
		{
			'x1' => $x + 251,
			'y1' => $y - ($i * 11) - 19,
			'x2' => $x + 251 + 67,
			'y2' => $y - ($i * 11) - 19
		};
		$report->drawLine($p, $properties);
	}
}

sub boxPart3
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	$properties =
	{
		'x' => $x,
		'y' => $y,
		'width' => MAIN_BOX_WIDTH,
		'height' => PART_HEIGHT
	};
	$report->drawFilledRectangle($p, $properties);

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"PART III: ACTIVITY RESTRICTIONS* (ONLY COMPLETELY IF BOX 13(b) IS CHECKED)",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 9,
						'color' => '1,1,1',
						'x' => $x + 2,
						'y' => $y - 3
					}
				]
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, PART_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub boxPart4
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	$properties =
	{
		'x' => $x,
		'y' => $y,
		'width' => MAIN_BOX_WIDTH,
		'height' => PART_HEIGHT
	};
	$report->drawFilledRectangle($p, $properties);

	my $properties =
			{
			texts =>
				[
					{
						'text' =>"PART IV: TREATMENT/FOLLOW-UP APPOINTMENT INFORMATION",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 9,
						'color' =>  '1,1,1',
						'x' => $x + 2,
						'y' => $y - 3
					}
				]
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, PART_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box14
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>"14. POSTURE RESTRICTIONS (if any):",
					'fontWidth' => 7,
					'fontName' => BOLD_FONT_NAME,
					'x' => $x,
					'y' => $y
				},
				{
					'text' => "Max Hours per day:          0   2   4   6   8    Other",
					'fontWidth' => 7,
					'x' => $x + 4,
					'y' => $y - 14
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX14_WIDTH, BOX14_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$arr = ["Standing", "Sitting", "Kneeling/Squatting", "Bending/Stooping", "Pushing/Pulling", "Twisting", "Other: ___________"];

	for my $i(0..6)
	{
		$properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + 4,
			'y' => $y - ($i * 14) - 28
		};
		$report->drawText($p, $properties);

		$properties =
		{
			'x1' => $x + 138,
			'y1' => $y - ($i * 14) - 36,
			'x2' => $x + 158,
			'y2' => $y - ($i * 14) - 36
		};
		$report->drawLine($p, $properties);
		$self->print5RadioButtonUnSelect($p, $claim, $x + 85, $y - ($i * 14) - 28, $report);
	}


}

sub box15
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>"15. RESTRICTIONS SPECIFIC TO (if applicable):",
					'fontName' => BOLD_FONT_NAME,
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX14_WIDTH, BOX15_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$arr = [	"L Hand/Wrist", "L Arm", "L Leg", "L Foot/Ankle", "Other: __________________________",
				"R Hand/Wrist", "R Arm", "R Leg", "R Foot/Ankle",
				"Neck", "Back"
			];

	$arrX = [15,15,15,15,15,90,90,90,90,145,145];
	$arrY = [20,33,46,59,72,20,33,46,59,33,46];

	for my $i(0..10)
	{
		my $properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + $arrX->[$i],
			'y' => $y - $arrY->[$i],
		};
		$report->drawText($p,$properties);

		$properties =
		{
			'x' => $x + $arrX->[$i] - 9,
			'y' => $y - $arrY->[$i],
		};
		$report->drawRadioButtonUnSelect($p,$properties);
	}

}

sub box16
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' => "16.  OTHER RESTRICTIONS (if any):",
					'fontName' => BOLD_FONT_NAME,
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
			],
		lines =>
			[
				{
					'x1' => $x,
					'y1' => $y - 24,
					'x2' => $x + BOX16_WIDTH,
					'y2' => $y - 24,
				},
				{
					'x1' => $x,
					'y1' => $y - 42,
					'x2' => $x + BOX16_WIDTH,
					'y2' => $y - 42,
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX16_WIDTH, BOX16_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = 	[
					"* These restrictions are based on the doctor's best understanding of the employee's essential job functions. If a",
					"particular restriction does not apply, it should be disregarded. If modified duty that meets these restrictions is not",
					"available, the patient should be considered to be off work. Note - these restrictions should be followed outside of work",
					"as well as at work.",
				];

	for my $i(0..3)
	{
		my $properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 6.7,
			'x' => $x,
			'y' => $y - $i * 7 - 42,
		};
		$report->drawText($p,$properties);
	}

}

sub box17
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' => "17. MOTION RESTRICTIONS (if any):",
					'fontName' => BOLD_FONT_NAME,
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
				{
					'text' => "Max Hours per day:          0   2   4   6   8    Other",
					'fontWidth' => 7,
					'x' => $x + 4,
					'y' => $y - 14
				}
			]

	};
	$report->drawBox($p, $x, $y, BOX17_WIDTH, BOX17_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$arr = ["Walking", "Climbing stairs/ladders", "Grasping/Squeezing", "Wrist flexion/extension", "Reaching", "Overhead Reaching", "Keyboarding", "Other: ___________"];

	for my $i(0..7)
	{
		$properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + 4,
			'y' => $y - ($i * 14) - 28
		};
		$report->drawText($p, $properties);

		$properties =
		{
			'x1' => $x + 138,
			'y1' => $y - ($i * 14) - 36,
			'x2' => $x + 158,
			'y2' => $y - ($i * 14) - 36
		};
		$report->drawLine($p, $properties);

		$self->print5RadioButtonUnSelect($p, $claim, $x + 85, $y - ($i * 14) - 28, $report);
	}
}


sub box18
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' => "18. LIFT/CARRY RESTRICTIONS (if any):",
					'fontName' => BOLD_FONT_NAME,
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
				{
					'text' => "for more than ____ hours per day",
					'fontWidth' => 7,
					'x' => $x + 14,
					'y' => $y - 30
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX17_WIDTH, BOX18_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = [	"May not lift/carry objects more than _____ lbs.",
				"May not perform any lifting/carrying",
				"Other: _______________________________"
			];

	my $arrY = [18,42,54];

	for my $i(0..2)
	{
		$properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + 14,
			'y' => $y - $arrY->[$i],
		};
		$report->drawText($p,$properties);
		$properties =
		{
			'x' => $x + 5,
			'y' => $y - $arrY->[$i],
		};
		$report->drawRadioButtonUnSelect($p,$properties);
	}

}

sub box19
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' => "19. MISC. RESTRICTIONS (if any):",
					'fontName' => BOLD_FONT_NAME,
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX19_WIDTH, BOX19_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = 	[
					"Max hours per day of work: _______",
					"Sit/Stretch breaks of ______ per ______",
					"Must wear splint//cast at work",
					"Must use crutches at all times",
					"No driving/operating heavy equipment",
					"Can only drive automatic transmission",
					"No work /",
					"_____ hours/day work:",
					"in extreme hot/cold environments",
					"at heights or on scaffolding",
					"Must keep _______________________:",
					"Elevated",
					"Clean & Dry",
					"No skin contact with: __________________",
					"Dressing changes necessary at work",
					"No Running"
				];

	my $arrX = [15,15,15,15,15,15,15,60,25,25,15,25,75,15,15,15];
	my $arrY = [18,32,46,60,74,88,102,102,116,130,144,158,158,172,186,200];

	for my $i(0..15)
	{
		$properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + $arrX->[$i],
			'y' => $y - $arrY->[$i],
		};
		$report->drawText($p,$properties);
		$properties =
		{
			'x' => $x + $arrX->[$i] - 10,
			'y' => $y - $arrY->[$i],
		};
		$report->drawRadioButtonUnSelect($p,$properties);
	}
}


sub box20
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' => "20. MEDICATION RESTRICTIONS (if any):",
					'fontName' => BOLD_FONT_NAME,
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
				{
					'text' => "Safety/driving Issues)",
					'fontWidth' => 7,
					'x' => $x + 14,
					'y' => $y - 54
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX19_WIDTH, BOX20_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = [	"Must take prescription medication(s)",
				"Advised to take over-the-counter meds",
				"Medication may take drowsy (possible"
			];

	my $arrY = [18,30,42];

	for my $i(0..2)
	{
		$properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + 14,
			'y' => $y - $arrY->[$i],
		};
		$report->drawText($p,$properties);
		$properties =
		{
			'x' => $x + 5,
			'y' => $y - $arrY->[$i],
		};
		$report->drawRadioButtonUnSelect($p,$properties);
	}
}

sub box21
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>  "21. Work Injury Diagnosis Information:",
					'fontName' => BOLD_FONT_NAME,
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
				{
					'text' =>  " ___________________________________",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - 16
				},
				{
					'text' =>  " ___________________________________",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - 35
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX21_WIDTH, BOX21_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box22
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>  "22.  Expected Follow-up Services Include:",
					'fontName' => BOLD_FONT_NAME,
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX22_WIDTH, BOX22_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = 	[
					"Evaluation by the treating doctor on ____________________________ (date) at _____________ am/pm",
					"Referral to/Consult with _______________________on ____________ (date) at _____________ am/pm",
					"Physical medicine __ X per week for __ weeks starting on __________ (date) at _____________ am/pm",
					"Special studies (list): ____________________________ on __________ (date) at _____________ am/pm",
					"None. This is the last scheduled visit for this problem. At this time, no further medical care is anticipated."
				];

	for my $i(0..4)
	{
		my $properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + 14,
			'y' => $y - ($i * 12) - 10,
		};
		$report->drawText($p,$properties);
		$properties =
		{
			'x' => $x + 5,
			'y' => $y - ($i * 12) - 10,
		};
		$report->drawRadioButtonUnSelect($p,$properties);
	}
}

sub box23
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>  "Date / Time of Visit",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
				{
					'text' =>  "Discharge Time",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - 19
				},
				{
					'text' =>  "_____________",
					'fontName' => BOLD_FONT_NAME,
					'x' => $x,
					'y' => $y - 11
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX23_WIDTH, BOX23_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub box24
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>  "EMPLOYEE'S SIGNATURE",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX24_WIDTH, BOX23_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box25
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>  "DOCTOR'S SIGNATURE",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX25_WIDTH, BOX23_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box26
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>  "Visit Type:",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX26_WIDTH, BOX23_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = [	"Initial", "Follow-up"];

	my $arrY = [10,20];

	for my $i(0..1)
	{
		$properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 6.5,
			'x' => $x + 10,
			'y' => $y - $arrY->[$i],
		};
		$report->drawText($p,$properties);
		$properties =
		{
			'x' => $x + 3,
			'y' => $y - $arrY->[$i],
		};
		$report->drawRadioButtonUnSelect($p,$properties);
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
					'text' =>  "Role of Doctor:",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX27_WIDTH, BOX23_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = 	[
					"Designated doctor", "Carrier-selected RME", "TWCC-selected RME",
					"Treating doctor", "Referral doctor", "Consulting doctor", "Other doctor"
				];

	my $arrX = [12,12,12,95,95,95,95];
	my $arrY = [12,22,32,2,12,22,32];

	for my $i(0..6)
	{
		$properties =
		{
			'text' => $arr->[$i],
			'fontWidth' => 7,
			'x' => $x + $arrX->[$i],
			'y' => $y - $arrY->[$i],
		};
		$report->drawText($p,$properties);
		$properties =
		{
			'x' => $x + $arrX->[$i] - 8,
			'y' => $y - $arrY->[$i],
		};
		$report->drawRadioButtonUnSelect($p,$properties);
	}
}

sub footer
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' =>"TWCC 73  (Rev. 06/00)",
		'fontWidth' => 7,
		'x' => $x,
		'y' => $y
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' =>"Rule 129.5",
		'fontWidth' => 7,
		'x' => $x + 240,
		'y' => $y
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' =>"TEXAS WORKERS' COMPENSATION COMMISSION",
		'fontWidth' => 7,
		'x' => $x + 350,
		'y' => $y
	};
	$report->drawText($p, $properties);
}

sub printQ
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' =>"Q",
		'color' => '0.6,0.6,0.6',
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 13,
		'x' => $x,
		'y' => $y
	};
	$report->drawText($p, $properties);
}

sub print5RadioButtonUnSelect
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	for my $i(0..4)
	{
		my $properties =
		{
			'x' => $x + ($i * 9.5),
			'y' => $y
		};
		$report->drawRadioButtonUnSelect($p,$properties);
	}
}

sub boxTopData
{

	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
				'text' => $claim->getId,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 55,
				'y' => $y - 16
			};
	$report->drawText($p, $properties);
}

sub box1Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{careReceiver}->getFirstName . " " . $claim->{careReceiver}->getMiddleInitial . " " .  $claim->{careReceiver}->getLastName,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box2Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{treatment}->getDateOfIllnessInjuryPregnancy(DATEFORMAT_USA),
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box3Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{insured}->[$claim->getClaimType]->getSsn,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box4Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my($data, $first, $rest, $i);
	$data = $claim->{twcc73}->getInjuryDescription;

	$rest = $data;

	while ($rest ne "" and $i < 3)
	{
		($first, $rest) = $report->textSplit($p, $rest, 160, FONT_NAME, DATA_FONT_SIZE);
		$properties =
			{
				'text' => $first,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 5,
				'y' => $y - DATA_TOP_PADDING - 10 * $i
			};
		$report->drawText($p, $properties);
		$i++;
	};
}


sub box5Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{renderingProvider}->getFirstName . " " . $claim->{renderingProvider}->getLastName,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box6Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{renderingOrganization}->getName,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box7Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{renderingOrganization}->{address}->getTelephoneNo(PHONE_FORMAT_DASHES) . " " . $claim->{renderingOrganization}->{address}->getFaxNo,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 9 + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box8Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{renderingOrganization}->{address}->getAddress1,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub boxCityData
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{renderingOrganization}->{address}->getCity,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

	$properties =
		{
			'text' => $claim->{renderingOrganization}->{address}->getState,
			'fontWidth' => DATA_FONT_SIZE,
			'color' => DATA_FONT_COLOR,
			'x' => $x + 60,
			'y' => $y - DATA_TOP_PADDING
		};
	$report->drawText($p, $properties);

	$properties =
		{
			'text' => $claim->{renderingOrganization}->{address}->getZipCode,
			'fontWidth' => DATA_FONT_SIZE,
			'color' => DATA_FONT_COLOR,
			'x' => $x + 110,
			'y' => $y - DATA_TOP_PADDING
		};
	$report->drawText($p, $properties);
}

sub box9Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{insured}->[$claim->getClaimType]->getEmployerOrSchoolName,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box10Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{

		'text' => $claim->{insured}->[$claim->getClaimType]->{employerAddress}->getFaxNo . " " . $claim->{insured}->[$claim->getClaimType]->{employerAddress}->getEmailAddress,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box11Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{payer}->getName,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

}

sub box12Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{payer}->{address}->getFaxNo . " " . $claim->{payer}->{address}->getEmailAddress,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box13Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my($condition, $date1, $date2);
	$condition = $claim->{twcc73}->getMedicalCondition;

	if ($condition == 1)
	{
		$date1 = $claim->{twcc73}->getReturnToWorkDate(DATE_FORMAT_USA);
		$date2 = "";
		$x1 = $x + 185;
		$y1 = $y - 11;
		$x2 = $x;
		$y2 = $y;
	}
	elsif ($condition == 2)
	{
		$date1 = $claim->{twcc73}->getReturnToWorkFromDate(DATE_FORMAT_USA);
		$date2 = $claim->{twcc73}->getReturnToWorkToDate(DATE_FORMAT_USA);
		$x1 = $x + 185;
		$y1 = $y - 22;
		$x2 = $x + 56;
		$y2 = $y - 33;
	}
	elsif ($condition == 3)
	{
		$date1 = $claim->{twcc73}->getReturnToWorkFromDate(DATE_FORMAT_USA);
		$date2 = $claim->{twcc73}->getReturnToWorkToDate(DATE_FORMAT_USA);
		$x1 = $x + 275;
		$y1 = $y - 44;
		$x2 = $x + 30;
		$y2 = $y - 55;
	}

	my $arrY = [11,22,44];

	for my $i(0..2)
	{
		if ($condition == ($i+1) )
		{
			$properties =
			{
				'x' => $x + 6,
				'y' => $y - $arrY->[$i]
			};
			$report->drawRadioButtonSelect($p,$properties);
		}
	}

	my $properties =
	{
		'text' => $date1,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x1,
		'y' => $y1
	};
	$report->drawText($p, $properties);

	$properties =
		{
			'text' => $date2,
			'fontWidth' => DATA_FONT_SIZE,
			'color' => DATA_FONT_COLOR,
			'x' => $x2,
			'y' => $y2
		};
	$report->drawText($p, $properties);
}

sub box14Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arrPosture = [];
	my $arrPostureOther = [];

	$arrPosture->[0] = $claim->{twcc73}->getPostureRestrictionsStanding;
	$arrPosture->[1] = $claim->{twcc73}->getPostureRestrictionsSitting;
	$arrPosture->[2] = $claim->{twcc73}->getPostureRestrictionsKneeling;
	$arrPosture->[3] = $claim->{twcc73}->getPostureRestrictionsBending;
	$arrPosture->[4] = $claim->{twcc73}->getPostureRestrictionsPushing;
	$arrPosture->[5] = $claim->{twcc73}->getPostureRestrictionsTwisting;
	$arrPosture->[6] = $claim->{twcc73}->getPostureRestrictionsOther;

	$arrPostureOther->[0] = $claim->{twcc73}->getPostureRestrictionsStandingOther;
	$arrPostureOther->[1] = $claim->{twcc73}->getPostureRestrictionsSittingOther;
	$arrPostureOther->[2] = $claim->{twcc73}->getPostureRestrictionsKneelingOther;
	$arrPostureOther->[3] = $claim->{twcc73}->getPostureRestrictionsBendingOther;
	$arrPostureOther->[4] = $claim->{twcc73}->getPostureRestrictionsPushingOther;
	$arrPostureOther->[5] = $claim->{twcc73}->getPostureRestrictionsTwistingOther;
	$arrPostureOther->[6] = $claim->{twcc73}->getPostureRestrictionsOtherOther;

	for my $i(0..6)
	{
		$properties =
		{
			'text' => $arrPostureOther->[$i],
			'fontWidth' => 7,
			'x' => $x + 138,
			'y' => $y - ($i * 14) - 28
		};
		$report->drawText($p, $properties);

		for my $j(0..4)
		{
			if ((($j * 2) == $arrPosture->[$i]) and not $arrPostureOther->[$i] ne '')
			{
				$properties =
				{
					'x' => $x + 85 + ($j * 9.5),
					'y' => $y - ($i * 14) - 28,
				};
				$report->drawRadioButtonSelect($p, $properties);
			}
		}
	}

	$properties =
	{
		'text' => $claim->{twcc73}->getPostureRestrictionsOtherText,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 28,
		'y' => $y - 110
	};
	$report->drawText($p, $properties);
}

sub box15Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arrX = [15,15,15,15,15,90,90,90,90,145,145];
	my $arrY = [20,33,46,59,72,20,33,46,59,33,46];
	my $arrRestrict = ["LH","LA","LL","LF","O","RH","RA","RL","RF","N","B"];

	for my $i(0..10)
	{
		if ($claim->{twcc73}->getSpecificRestrictions =~ m/$arrRestrict->[$i]/)
		{
			$properties =
			{
				'x' => $x + $arrX->[$i] - 9,
				'y' => $y - $arrY->[$i],
			};
			$report->drawRadioButtonSelect($p,$properties);
		}
	}

	$properties =
	{
		'text' => $claim->{twcc73}->getSpecificRestrictionsOther,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 36,
		'y' => $y - 70
	};
	$report->drawText($p, $properties);

}

sub box16Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my($data, $first, $rest, $i);
	$data = $claim->{twcc73}->getOtherRestrictions;

	$rest = $data;

	while ($rest ne "" and $i < 2)
	{
		($first, $rest) = $report->textSplit($p, $rest, 345, FONT_NAME, DATA_FONT_SIZE);
		$properties =
			{
				'text' => $first,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x,
				'y' => $y - 12 - 15 * $i
			};
		$report->drawText($p, $properties);
		$i++;
	};
}

sub box17Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arrMotion = [];
	my $arrMotionOther = [];

	$arrMotion->[0] = $claim->{twcc73}->getMotionRestrictionsWalking;
	$arrMotion->[1] = $claim->{twcc73}->getMotionRestrictionsClimbing;
	$arrMotion->[2] = $claim->{twcc73}->getMotionRestrictionsGrasping;
	$arrMotion->[3] = $claim->{twcc73}->getMotionRestrictionsWrist;
	$arrMotion->[4] = $claim->{twcc73}->getMotionRestrictionsReaching;
	$arrMotion->[5] = $claim->{twcc73}->getMotionRestrictionsOverhead;
	$arrMotion->[6] = $claim->{twcc73}->getMotionRestrictionsKeyboard;
	$arrMotion->[7] = $claim->{twcc73}->getMotionRestrictionsOther;

	$arrMotionOther->[0] = $claim->{twcc73}->getMotionRestrictionsWalkingOther;
	$arrMotionOther->[1] = $claim->{twcc73}->getMotionRestrictionsClimbingOther;
	$arrMotionOther->[2] = $claim->{twcc73}->getMotionRestrictionsGraspingOther;
	$arrMotionOther->[3] = $claim->{twcc73}->getMotionRestrictionsWristOther;
	$arrMotionOther->[4] = $claim->{twcc73}->getMotionRestrictionsReachingOther;
	$arrMotionOther->[5] = $claim->{twcc73}->getMotionRestrictionsOverheadOther;
	$arrMotionOther->[6] = $claim->{twcc73}->getMotionRestrictionsKeyboardOther;
	$arrMotionOther->[7] = $claim->{twcc73}->getMotionRestrictionsOtherOther;

	for my $i(0..7)
	{
		$properties =
		{
			'text' => $arrMotionOther->[$i],
			'fontWidth' => 7,
			'x' => $x + 138,
			'y' => $y - ($i * 14) - 28
		};
		$report->drawText($p, $properties);

		for my $j(0..4)
		{
			if (($j * 2) == $arrMotion->[$i]  and not $arrMotionOther->[$i] ne '')
			{
				$properties =
				{
					'x' => $x + 85 + ($j * 9.5),
					'y' => $y - ($i * 14) - 28,
				};
				$report->drawRadioButtonSelect($p, $properties);
			}
		}
	}

	$properties =
	{
		'text' => $claim->{twcc73}->getMotionRestrictionsOtherText,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 28,
		'y' => $y - 125
	};
	$report->drawText($p, $properties);

}

sub box18Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arrY = [18,42,54];
	my $arrLift = [];

	$arrLift->[0] = $claim->{twcc73}->getLiftRestrictionsWeight;
	$arrLift->[1] = $claim->{twcc73}->getLiftRestrictionsHours;
	$arrLift->[2] = $claim->{twcc73}->getLiftRestrictionsOther;

	my $arrLiftX = [125,60,38];
	my $arrLiftY = [18,30,54];

	for my $i(0..2)
	{
		if ($claim->{twcc73}->getLiftRestrictions == ($i+1) )
		{
			$properties =
			{
				'x' => $x + 5,
				'y' => $y - $arrY->[$i],
			};
			$report->drawRadioButtonSelect($p,$properties);
		}
	}

	if ($claim->{twcc73}->getLiftRestrictions == 1 )
	{
		for my $j(0..1)
		{
			$properties =
			{
				'text' => $arrLift->[$j],
				'fontWidth' => 7,
				'color' => DATA_FONT_COLOR,
				'x' => $x + $arrLiftX->[$j],
				'y' => $y - $arrLiftY->[$j]
			};
			$report->drawText($p, $properties);
		}
	}
	elsif ($claim->{twcc73}->getLiftRestrictions == 3 )
	{
		$properties =
		{
			'text' => $arrLift->[2],
			'fontWidth' => 7,
			'color' => DATA_FONT_COLOR,
			'x' => $x + $arrLiftX->[2],
			'y' => $y - $arrLiftY->[2]
		};
		$report->drawText($p, $properties);
	}
}

sub box19Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arrX = [15,15,15,15,15,15,15,60,25,25,15,25,75,15,15,15];
	my $arrY = [18,32,46,60,74,88,102,102,116,130,144,158,158,172,186,200];
	my $arr19 = [];

	$arr19->[0] = $claim->{twcc73}->getMiscRestrictionsMaxHours;
	$arr19->[1] = $claim->{twcc73}->getMiscRestrictionsSitBreaks;
	$arr19->[2] = $claim->{twcc73}->getMiscRestrictionsWearSplint;
	$arr19->[3] = $claim->{twcc73}->getMiscRestrictionsCrutches;
	$arr19->[4] = $claim->{twcc73}->getMiscRestrictionsNoDriving;
	$arr19->[5] = $claim->{twcc73}->getMiscRestrictionsDriveAutoTrans;
	$arr19->[6] = $claim->{twcc73}->getMiscRestrictionsNoWork;
	$arr19->[7] = $claim->{twcc73}->getMiscRestrictionsHoursPerDay;
	$arr19->[8] = $claim->{twcc73}->getMiscRestrictionsTemp;
	$arr19->[9] = $claim->{twcc73}->getMiscRestrictionsHeight;
	$arr19->[10] = $claim->{twcc73}->getMiscRestrictionsMustKeep;
	$arr19->[11] = $claim->{twcc73}->getMiscRestrictionsElevated;
	$arr19->[12] = $claim->{twcc73}->getMiscRestrictionsCleanDry;
	$arr19->[13] = $claim->{twcc73}->getMiscRestrictionsNoSkinContact;
	$arr19->[14] = $claim->{twcc73}->getMiscRestrictionsDressing;
	$arr19->[15] = $claim->{twcc73}->getMiscRestrictionsNoRunning;
	$arr19->[16] = $claim->{twcc73}->getMiscRestrictionsSitBreaksPer;

	for my $i(0..15)
	{
		if ($arr19->[$i] ne '')
		{
			$properties =
			{
				'x' => $x + $arrX->[$i] - 10,
				'y' => $y - $arrY->[$i],
			};
			$report->drawRadioButtonSelect($p,$properties);
		}
	}

	my $properties =
	{
		'text' => $arr19->[0],
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 100,
		'y' => $y - 18
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $arr19->[1],
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 82,
		'y' => $y - 32
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $arr19->[16],
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 120,
		'y' => $y - 32
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $arr19->[7],
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 60,
		'y' => $y - 102
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $arr19->[10],
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 48,
		'y' => $y - 144
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $arr19->[13],
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 82,
		'y' => $y - 172
	};
	$report->drawText($p, $properties);

}

sub box20Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arrY = [18,30,42];
	my $arr20 = [];
	$arr20->[0] = $claim->{twcc73}->getMedicationRestrictionsMustTake;
	$arr20->[1] = $claim->{twcc73}->getMedicationRestrictionsAdvised;
	$arr20->[2] = $claim->{twcc73}->getMedicationRestrictionsDrowsy;

	for my $i(0..2)
	{
		if ($arr20->[$i] ne '')
		{
			$properties =
			{
				'x' => $x + 5,
				'y' => $y - $arrY->[$i],
			};
			$report->drawRadioButtonSelect($p,$properties);
		}
	}
}

sub box21Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my($data, $first, $rest, $i);
	$data = $claim->{twcc73}->getWorkInjuryDiagnosisInfo;

	$rest = $data;

	while ($rest ne "" and $i < 3)
	{
		($first, $rest) = $report->textSplit($p, $rest, 145, FONT_NAME, DATA_FONT_SIZE);
		$properties =
			{
				'text' => $first,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x,
				'y' => $y - 14 - 18 * $i
			};
		$report->drawText($p, $properties);
		$i++;
	};
}

sub box22Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arrX = [128,88,130,80,2000,70,190,196,200,269,269,269,269];
	my $arrY = [10,22,34,46,2000,34,22,34,46,10,22,34,46];
	my $arr22 = [];
	$arr22->[0] = $claim->{twcc73}->getFollowupServiceEvaluationDate(DATE_FORMAT_USA);
	$arr22->[1] = $claim->{twcc73}->getFollowupServiceConsultWith;
	$arr22->[2] = $claim->{twcc73}->getFollowupServicePhysMedWeeks;
	$arr22->[3] = $claim->{twcc73}->getFollowupServiceSpecialStudies;
	$arr22->[4] = $claim->{twcc73}->getFollowupServiceNone;
	$arr22->[5] = $claim->{twcc73}->getFollowupServicePhysMedWeeksPer;
	$arr22->[6] = $claim->{twcc73}->getFollowupServiceConsultDate(DATE_FORMAT_USA);
	$arr22->[7] = $claim->{twcc73}->getFollowupServicePhysMedDate(DATE_FORMAT_USA);
	$arr22->[8] = $claim->{twcc73}->getFollowupServiceSpecialStudiesDate(DATE_FORMAT_USA);
	$arr22->[9] = $claim->{twcc73}->getFollowupServiceEvaluationTime;
	$arr22->[10] = $claim->{twcc73}->getFollowupServiceConsultTime;
	$arr22->[11] = $claim->{twcc73}->getFollowupServicePhysMedTime;
	$arr22->[12] = $claim->{twcc73}->getFollowupServiceSpecialStudiesTime;

	for my $i(0..4)
	{
		if ($arr22->[$i] ne '')
		{
			$properties =
			{
				'x' => $x + 5,
				'y' => $y - ($i * 12) - 10
			};
			$report->drawRadioButtonSelect($p,$properties);
		}
	}

	for my $j(0..12)
	{
		$properties =
		{
			'text' => $arr22->[$j],
			'fontWidth' => DATA_FONT_SIZE,
			'color' => DATA_FONT_COLOR,
			'x' => $x + $arrX->[$j],
			'y' => $y - $arrY->[$j]
		};
		$report->drawText($p, $properties);
	}
}

sub box26Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arrY = [10,20];

	for my $i(0..1)
	{
		if ($claim->{twcc73}->getVisitType == $i+1)
		{
			$properties =
			{
				'x' => $x + 3,
				'y' => $y - $arrY->[$i],
			};
			$report->drawRadioButtonSelect($p,$properties);
		}
	}
}

sub box27Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arrX = [12,12,12,95,95,95,95];
	my $arrY = [12,22,32,2,12,22,32];

	for my $i(0..6)
	{
		if ($claim->{twcc73}->getDoctorRole == $i+1)
		{
			$properties =
			{
				'x' => $x + $arrX->[$i] - 8,
				'y' => $y - $arrY->[$i],
			};
			$report->drawRadioButtonSelect($p,$properties);
		}
	}
}

1;
