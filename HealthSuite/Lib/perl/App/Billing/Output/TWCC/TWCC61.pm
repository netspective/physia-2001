package App::Billing::Output::TWCC::TWCC61;

use App::Billing::Output::PDF::Report;
use pdflib 2.01;

use constant LEFT_MARGIN => 48;
use constant TOP_MARGIN => 756; # 792 - 36
use constant BOX_HEIGHT => 22;
use constant LINE_SPACING => 9;
use constant MAIN_BOX_Y => 65;
use constant MAIN_BOX_WIDTH => 516;
use constant BOX1_WIDTH => 196;
use constant BOX2_WIDTH => 62;
use constant HEADING_Y => 50;
use constant HEADING_X => 85;
use constant RIGHT_BOX_HEIGHT => 28;
use constant RIGHT_BOX_WIDTH => 181;
use constant RIGHT_BOX_PADDING => 8;
use constant LEFT_LINE => 1;
use constant RIGHT_LINE => 1;
use constant TOP_LINE => 1;
use constant BOTTOM_LINE => 1;
use constant NO_LEFT_LINE => 0;
use constant NO_RIGHT_LINE => 0;
use constant NO_TOP_LINE => 0;
use constant NO_BOTTOM_LINE => 0;
use constant NOTICE_BOX_HEIGHT => 97;
use constant BOX13_HEIGHT => 37;
use constant BOX14_HEIGHT => 61;
use constant BOX17_HEIGHT => 280;
use constant SPC => " ";
use constant BOX17_PADDING => 6;
use constant BOX17_SPACING => 13.5;
use constant BOX17_LINE_PADDING => 13;
use constant BOX17_TOP_PADDING => 4;
use constant DATA_TOP_PADDING => 11;
use constant DATA_LEFT_PADDING => 2;
use constant FONT_NAME => 'Helvetica';
use constant BOLD_FONT_NAME => FONT_NAME . '-Bold';
use constant DATA_FONT_COLOR => '0,0,0';
use constant DATA_FONT_SIZE => 8;
use constant DATEFORMAT_USA => 1;

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
	my ($self, $p, $claim, $report) = @_ ;

	my $mainBoxX = LEFT_MARGIN;
	my $mainBoxY = TOP_MARGIN - MAIN_BOX_Y;

	my $properties =
	{
		'text' =>"Send To:",
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 8,
		'x' => LEFT_MARGIN,
		'y' => TOP_MARGIN
	};
	$report->drawText($p,$properties);

	$properties =
	{
		'text' =>"Workers' Compensation Insurance Carrier (Block #12)",
		'x' => LEFT_MARGIN,
		'y' => TOP_MARGIN - LINE_SPACING,
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 8
	};
	$report->drawText($p,$properties);

	$properties =
	{
		'text' =>"and the Injured Employee (Block #1)",
		'x' => LEFT_MARGIN,
		'y' => TOP_MARGIN - 2 * LINE_SPACING,
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 8
	};
	$report->drawText($p,$properties);

	$properties =
	{
		'text' =>"INITIAL MEDICAL REPORT - WORKERS' COMPENSATION INSURANCE",
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 10,
		'x' => LEFT_MARGIN + HEADING_X,
		'y' => TOP_MARGIN - HEADING_Y
	};
	$report->drawText($p,$properties);

	my $rightBoxX=LEFT_MARGIN + 333;
	my $rightBoxY=TOP_MARGIN;

	$properties =
			{
			texts =>
				[
					{
						'text' =>"TWCC#",
						'fontWidth' => 6,
						'x' => $rightBoxX,
						'y' => $rightBoxY - RIGHT_BOX_PADDING
					},
					{
						'text' =>"Carrier's Claim #",
						'fontWidth' => 6,
						'x' => $rightBoxX,
						'y' => $rightBoxY - LINE_SPACING - RIGHT_BOX_PADDING
					}
				],

			lines =>
				[
					{
						'x1' => $rightBoxX + 25,
						'y1' => $rightBoxY - 15,
						'x2' => $rightBoxX + 25 + 118,
						'y2' => $rightBoxY - 15
					},

					{
						'x1' => $rightBoxX + 48,
						'y1' => $rightBoxY - 25,
						'x2' => $rightBoxX + 65 + 110,
						'y2' => $rightBoxY - 25
					}
				]
			};

	$report->drawBox($p, $rightBoxX, $rightBoxY, RIGHT_BOX_WIDTH, RIGHT_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
			{
			texts =>
				[
					{
						'text' =>"1. Injured Employee's Name (Last, First, M.I.)",
						'fontWidth' => 6,
						'x' => $mainBoxX,
						'y' => $mainBoxY
					}
				],
			};
	$report->drawBox($p, $mainBoxX, $mainBoxY, BOX1_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
			{
			texts =>
				[
					{
						'text' =>"2. Date of Birth",
						'fontWidth' => 6,
						'x' => $mainBoxX + BOX1_WIDTH ,
						'y' => $mainBoxY
					}
				],
			};

	$report->drawBox($p, $mainBoxX + BOX1_WIDTH, $mainBoxY, BOX2_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
			{
			texts =>
				[
					{
						'text' =>"8. Date of Injury",
						'fontWidth' => 6,
						'x' => $mainBoxX + MAIN_BOX_WIDTH/2 ,
						'y' => $mainBoxY
					}
				]
			};

	$report->drawBox($p, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY, MAIN_BOX_WIDTH/4, BOX_HEIGHT , NO_LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
			{
			texts =>
				[
					{
						'text' =>"9. Social Security Number",
						'fontWidth' => 6,
						'x' => $mainBoxX + MAIN_BOX_WIDTH * 3/4,
						'y' => $mainBoxY
					}
				]
			};

	$report->drawBox($p, $mainBoxX + MAIN_BOX_WIDTH * 3/4 , $mainBoxY, MAIN_BOX_WIDTH/4, BOX_HEIGHT,  NO_LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
		{
			texts =>
				[
					{
						'text' =>"3. Employee's Mailing Address (Street or P.O. Box)",
						'fontWidth' => 6,
						'x' => $mainBoxX,
						'y' => $mainBoxY - BOX_HEIGHT
					}
				]
		};
	$report->drawBox($p, $mainBoxX, $mainBoxY - BOX_HEIGHT, MAIN_BOX_WIDTH/2, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
		{
			texts =>
				[
					{
						'text' =>"10. Employer's Name",
						'fontWidth' => 6,
						'x' => $mainBoxX + MAIN_BOX_WIDTH/2,
						'y' => $mainBoxY - BOX_HEIGHT
					}
				]
		};
	$report->drawBox($p, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - BOX_HEIGHT, MAIN_BOX_WIDTH/2, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
		{
			texts =>
				[
					{
						'text' =>"City                              State                  Zip Code              Phone No.",
						'fontWidth' => 6,
						'x' => $mainBoxX,
						'y' => $mainBoxY - 2 * BOX_HEIGHT
					},
					{
						'text' => "(          )",
						'fontWidth' => 7,
						'x' => $mainBoxX + 155,
						'y' => $mainBoxY - 2 * BOX_HEIGHT - DATA_TOP_PADDING
					}
				]
		};
	$report->drawBox($p, $mainBoxX, $mainBoxY - 2 * BOX_HEIGHT, MAIN_BOX_WIDTH/2, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
		{
			texts =>
				[
					{
						'text' =>"11. Employer's Mailing Address (Street or P.O. Box)",
						'fontWidth' => 6,
						'x' => $mainBoxX + MAIN_BOX_WIDTH/2,
						'y' => $mainBoxY- 2 * BOX_HEIGHT
					}
				]
		};
	$report->drawBox($p, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY- 2 * BOX_HEIGHT, MAIN_BOX_WIDTH/2, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
		{
			texts =>
				[
					{
						'text' =>"4. Date of Visit",
						'fontWidth' => 6,
						'x' => $mainBoxX,
						'y' => $mainBoxY - 3 * BOX_HEIGHT
					}
				]
		};
	$report->drawBox($p, $mainBoxX, $mainBoxY- 3 * BOX_HEIGHT, BOX2_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
		{
			texts =>
				[
					{
						'text' =>"5. Doctor's Name and Title",
						'fontWidth' => 6,
						'x' => $mainBoxX+BOX2_WIDTH,
						'y' => $mainBoxY- 3 * BOX_HEIGHT
					}
				]
		};
	$report->drawBox($p, $mainBoxX + BOX2_WIDTH, $mainBoxY- 3 * BOX_HEIGHT, BOX1_WIDTH, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
	{
		texts =>
			[
				{
					'text' =>"City                                                             State                                                Zip Code",
					'fontWidth' => 6,
					'x' => $mainBoxX + MAIN_BOX_WIDTH/2,
					'y' => $mainBoxY - 3 * BOX_HEIGHT
				}
			]
	};
	$report->drawBox($p, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 3 * BOX_HEIGHT, MAIN_BOX_WIDTH/2, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
	{
		texts =>
			[
				{
					'text' =>"6. Federal Tax I.D. No.",
					'fontWidth' => 6,
					'x' => $mainBoxX,
					'y' => $mainBoxY - 4 * BOX_HEIGHT
				}
			]
	};
	$report->drawBox($p, $mainBoxX, $mainBoxY - 4 * BOX_HEIGHT, MAIN_BOX_WIDTH/4, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
	{
		texts =>
			[
				{
					'text' =>"7. Professional License No.",
					'fontWidth' => 6,
					'x' => $mainBoxX + MAIN_BOX_WIDTH/4,
					'y' => $mainBoxY - 4 * BOX_HEIGHT
				}
			]
	};
	$report->drawBox($p, $mainBoxX + MAIN_BOX_WIDTH/4, $mainBoxY - 4 * BOX_HEIGHT, MAIN_BOX_WIDTH/4, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$properties =
	{
		texts =>
			[
				{
					'text' =>"12. Workers' Compensation Insurance Carrier",
					'fontWidth' => 6,
					'x' => $mainBoxX + MAIN_BOX_WIDTH/2,
					'y' => $mainBoxY - 4 * BOX_HEIGHT
				}
			]
	};
	$report->drawBox($p, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 4 * BOX_HEIGHT, MAIN_BOX_WIDTH/2, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

#notice box begin

	my $noticeBoxX = $mainBoxX;
	my $noticeBoxY= $mainBoxY - 5 * BOX_HEIGHT;

	$properties =
			{
			texts =>
				[
					{
						'text' => "NOTICE TO INJURED EMPLOYEE :",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 9,
						'x' => $noticeBoxX,
						'y' => $noticeBoxY - 8
					},
					{
						'text' => "You are required to report the injury to your employer within 30 days if your employer elects to",
						'fontWidth' => 8.5,
						'x' => $noticeBoxX + 150,
						'y' => $noticeBoxY - 8
					},
					{
						'text' => "provide workers' compensation insurance coverage.  You  have the right to free assistance from the Texas Workers' Compensation",
						'fontWidth' => 8.5,
						'x' => $noticeBoxX,
						'y' => $noticeBoxY - 8 - LINE_SPACING
					},
					{
						'text' => "Commission. You may be entitled to certain benefits for medical care and disablility. For further information call your nearest Texas Workers'",
						'fontWidth' => 8.2,
						'x' => $noticeBoxX,
						'y' => $noticeBoxY - 8 - LINE_SPACING * 2
					},
					{
						'text' => "Compensation Commission Field Office or 1 (800) 252-7031.",
						'fontWidth' => 8.5,
						'x' => $noticeBoxX,
						'y' => $noticeBoxY - 8 - LINE_SPACING * 3
					},
					{
						'text' => "NOTIFICATIÓN AL TRABAJADOR LESIONADO:",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 9,
						'x' => $noticeBoxX,
						'y' => $noticeBoxY - 8 - LINE_SPACING * 5
					},
					{
						'text' => "Usted debe repotar la lesión a su empresario en 30 dias, si su empresario elije",
						'fontWidth' => 8.5,
						'x' => $noticeBoxX + 205,
						'y' => $noticeBoxY - 8 - LINE_SPACING * 5
					},
					{
						'text' => "tener seguro de compensación para trabajadores. Usted tiene derecho a asistencia gratis por parte de la Comisión Tejana de Compensación",
						'fontWidth' => 8.2,
						'x' => $noticeBoxX,
						'y' => $noticeBoxY - 8 - LINE_SPACING * 6
					},
					{
						'text' => "para Trabajadores. Puedo que usted tenga derecho a ciertos medicos y de desabilidad. Para mayor información llame a la",
						'fontWidth' => 8.6,
						'x' => $noticeBoxX,
						'y' => $noticeBoxY - 8 - LINE_SPACING * 7
					},
					{
						'text' => "oficina local de la Comisión. Tejana de Compensación para Trabajadores más cercana o llame al 1 (800) 252-7031.",
						'fontWidth' => 8,
						'x' => $noticeBoxX,
						'y' => $noticeBoxY - 8 - LINE_SPACING * 8
					}


				],

			lines =>
				[
					{
						'x1' => $noticeBoxX + 2,
						'y1' => $noticeBoxY - 16.5,
						'x2' => $noticeBoxX + 2 + 145,
						'y2' => $noticeBoxY - 16.5
					},

					{
						'x1' => $noticeBoxX + 2,
						'y1' => $noticeBoxY - 61.5,
						'x2' => $noticeBoxX + 2 + 200,
						'y2' => $noticeBoxY - 61.5
					}
				]
			};

	$report->drawBox($p, $noticeBoxX, $noticeBoxY, MAIN_BOX_WIDTH, NOTICE_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
#notice box end
#diagnosis

	my $box13X = $mainBoxX;
	my $box13Y= $mainBoxY - 5 * BOX_HEIGHT - NOTICE_BOX_HEIGHT;

	$properties =
			{
			texts =>
				[
					{
						'text' => "13. Diagnosis (ICD-9 Codes and Descriptions)       Relate Diagnosis to Procedure by Reference to Letters a, b, c)",
						'fontWidth' => 6,
						'x' => $box13X,
						'y' => $box13Y
					},
					{
						'text' => "a)" . SPC x 29 . "." . SPC x 30 . "b)" . SPC x 30 . "." . SPC x 30 . "c)" . SPC x 29 . "."  ,
						'fontWidth' => 6,
						'x' => $box13X + 18,
						'y' => $box13Y - LINE_SPACING * 1.6
					}
				],

			lines =>
				[
					{
						'x1' => $box13X + 349,
						'y1' => $box13Y - LINE_SPACING * .8,
						'x2' => $box13X + MAIN_BOX_WIDTH - 15,
						'y2' => $box13Y - LINE_SPACING * .8
					},

					{
						'x1' => $box13X + MAIN_BOX_WIDTH - 15,
						'y1' => $box13Y -  LINE_SPACING * .8,
						'x2' => $box13X + MAIN_BOX_WIDTH - 15,
						'y2' => $box13Y - LINE_SPACING * 3
					},
					{
						'x1' => $box13X + 349,
						'y1' => $box13Y - LINE_SPACING * .8,
						'x2' => $box13X + MAIN_BOX_WIDTH - 15,
						'y2' => $box13Y - LINE_SPACING * .8
					},
					{
						'x1' => $box13X + 30,
						'y1' => $box13Y - BOX_HEIGHT,
						'x2' => $box13X + 71,
						'y2' => $box13Y - BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 4
					},
					{
						'x1' => $box13X + 78,
						'y1' => $box13Y - BOX_HEIGHT,
						'x2' => $box13X + 102,
						'y2' => $box13Y - BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 4
					},
					{
						'x1' => $box13X + 135,
						'y1' => $box13Y - BOX_HEIGHT,
						'x2' => $box13X + 177,
						'y2' => $box13Y - BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 4
					},
					{
						'x1' => $box13X + 186,
						'y1' => $box13Y - BOX_HEIGHT,
						'x2' => $box13X + 215,
						'y2' => $box13Y - BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 4
					},
					{
						'x1' => $box13X + 242,
						'y1' => $box13Y - BOX_HEIGHT,
						'x2' => $box13X + 281,
						'y2' => $box13Y - BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 4
					},
					{
						'x1' => $box13X + 292,
						'y1' => $box13Y - BOX_HEIGHT,
						'x2' => $box13X + 318,
						'y2' => $box13Y - BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 4
					}
				]
			};
	$report->drawBox($p, $box13X, $box13Y, MAIN_BOX_WIDTH, BOX13_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	$properties =
			{
				'x1' => $box13X + MAIN_BOX_WIDTH - 17,
				'y1' => $box13Y - 25,
				'x2' => $box13X + MAIN_BOX_WIDTH - 13,
				'y2' => $box13Y - 25,
				'x3' => $box13X + MAIN_BOX_WIDTH - 15,
				'y3' => $box13Y - 28,
			};
	$report->drawArrow($p, $properties);

	my $box14X = $mainBoxX;
	my $box14Y= $box13Y - BOX13_HEIGHT;

	$properties =
			{
			texts =>
				[
					{
						'text' => "14. Treatment at this Visit (CPT Code and Modifiers, If Necessary, and Description) - DO NOT INCLUDE OFFICE VISIT",
						'fontWidth' => 6,
						'x' => $box14X,
						'y' => $box14Y
					},
					{
						'text' => "." .  SPC x 20 . ".",
						'fontWidth' => 6,
						'x' => $box14X + 100,
						'y' => $box14Y - 16
					},
					{
						'text' => "." .  SPC x 20 . ".",
						'fontWidth' => 6,
						'x' => $box14X + 100,
						'y' => $box14Y - 16 - BOX_HEIGHT/2
					},
					{
						'text' => "." .  SPC x 20 . ".",
						'fontWidth' => 6,
						'x' => $box14X + 100,
						'y' => $box14Y - 16 - BOX_HEIGHT
					},
					{
						'text' => "." .  SPC x 20 . ".",
						'fontWidth' => 6,
						'x' => $box14X + 100,
						'y' => $box14Y - 16 - 1.5 * BOX_HEIGHT
					}
				],

			lines =>
				[
					{
						'x1' => $box14X + 31,
						'y1' => $box14Y - BOX_HEIGHT,
						'x2' => $box14X + 99,
						'y2' => $box14Y - BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 111,
						'y1' => $box14Y - BOX_HEIGHT,
						'x2' => $box14X + 133,
						'y2' => $box14Y - BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 143,
						'y1' => $box14Y - BOX_HEIGHT,
						'x2' => $box14X + 167,
						'y2' => $box14Y - BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 31,
						'y1' => $box14Y - 1.5 * BOX_HEIGHT,
						'x2' => $box14X + 99,
						'y2' => $box14Y - 1.5 * BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 111,
						'y1' => $box14Y - 1.5 * BOX_HEIGHT,
						'x2' => $box14X + 133,
						'y2' => $box14Y - 1.5 * BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 143,
						'y1' => $box14Y - 1.5 * BOX_HEIGHT,
						'x2' => $box14X + 167,
						'y2' => $box14Y - 1.5 * BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 31,
						'y1' => $box14Y - 2 * BOX_HEIGHT,
						'x2' => $box14X + 99,
						'y2' => $box14Y - 2 * BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 111,
						'y1' => $box14Y - 2 * BOX_HEIGHT,
						'x2' => $box14X + 133,
						'y2' => $box14Y - 2 * BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 143,
						'y1' => $box14Y - 2 * BOX_HEIGHT,
						'x2' => $box14X + 167,
						'y2' => $box14Y - 2 * BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 31,
						'y1' => $box14Y - 2.5 * BOX_HEIGHT,
						'x2' => $box14X + 99,
						'y2' => $box14Y - 2.5 * BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 111,
						'y1' => $box14Y - 2.5 * BOX_HEIGHT,
						'x2' => $box14X + 133,
						'y2' => $box14Y - 2.5 * BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					},
					{
						'x1' => $box14X + 143,
						'y1' => $box14Y - 2.5 * BOX_HEIGHT,
						'x2' => $box14X + 167,
						'y2' => $box14Y - 2.5 * BOX_HEIGHT,
						'blackDash' => 11,
						'whiteDash' => 3
					}
				]
			};
	$report->drawBox($p, $box14X, $box14Y, MAIN_BOX_WIDTH, BOX14_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box15X = $mainBoxX + MAIN_BOX_WIDTH  - 34;
	my $box15Y= $box13Y - BOX13_HEIGHT;
	$report->drawBox($p, $box15X, $box15Y, 34, 20, LEFT_LINE, NO_RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	$report->drawBox($p, $box15X, $box15Y - 20, 34, 11, LEFT_LINE, NO_RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	$report->drawBox($p, $box15X, $box15Y - 31,  34, 11, LEFT_LINE, NO_RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	$report->drawBox($p, $box15X, $box15Y -42, 34, 19, LEFT_LINE, NO_RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box16X = $mainBoxX;
	my $box16Y= $box14Y - BOX14_HEIGHT;

	$properties =
			{
			texts =>
				[
					{
						'text' => "16. ANTICIPATED Dates the Injured employee May :      (Please Complete All Dates)",
						'fontWidth' => 6,
						'x' => $box16X,
						'y' => $box16Y
					},
					{
						'text' => "a) Return to Limited Type of Work:" . SPC x 30 . "b) Achieve Maximum Medical Improvement:" . SPC x 30 . "c) Return to Full-time Work:",
						'fontWidth' => 6,
						'x' => $box16X + 8,
						'y' => $box16Y - 10
					},
				]
			};
	$report->drawBox($p, $box16X, $box16Y, MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	$properties =
	{
		'text' =>"MAY ATTACH TEST RESULTS OR FURTHER WRITTEN INFORMATION",
		'x' => $mainBoxX + 133,
		'y' => $box16Y - BOX_HEIGHT - 10,
		'fontWidth' => 7
	};
	$report->drawText($p,$properties);

#box 17 start
	my $box17X = $mainBoxX;
	my $box17Y= $box16Y - BOX_HEIGHT - 20;

	$properties =
			{
			texts =>
				[
					{
						'text' => "17.  History of Occupational Injury or Illness",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING
					},
					{
						'text' => "18.  Significant Past Medical History",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 2 * BOX17_SPACING
					},
					{
						'text' => "19.  Clinical Assessment Findings",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 4 * BOX17_SPACING
					},
					{
						'text' => "20.  Laboratory, Radiographic, and/or Imaging Tests Ordered and Results",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 6 * BOX17_SPACING
					},
					{
						'text' => "21.  Treatment Plan",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 8 * BOX17_SPACING
					},
					{
						'text' => "22.       Referrals  or       Change of Treating Doctor",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 10 * BOX17_SPACING
					},
					{
						'text' => "23.  Medications or Durable Medical Equipment",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 12 * BOX17_SPACING
					},
					{
						'text' => "24.  Prognosis",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 14 * BOX17_SPACING
					},
					{
						'text' => "25.  Doctor's Name (Printed)",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 16 * BOX17_SPACING
					},
					{
						'text' => "Doctor's Signature",
						'fontWidth' => 6,
						'x' => $box17X + 260,
						'y' => $box17Y - BOX17_PADDING - 16 * BOX17_SPACING
					},

					{
						'text' => "Address",
						'fontWidth' => 6,
						'x' => $box17X + BOX17_LINE_PADDING,
						'y' => $box17Y - BOX17_PADDING - 17 * BOX17_SPACING
					},
					{
						'text' => "Date",
						'fontWidth' => 6,
						'x' => $box17X + 343,
						'y' => $box17Y - BOX17_PADDING - 17 * BOX17_SPACING
					},
					{
						'text' => "26.  Date Report Mailed to Employee",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 18 * BOX17_SPACING
					},
					{
						'text' => "27.  Date Report Mailed to Workers' Compensation Insurance Carrier",
						'fontWidth' => 6,
						'x' => $box17X,
						'y' => $box17Y - BOX17_PADDING - 19 * BOX17_SPACING
					}
				],

			lines =>
				[
					{
						'x1' => $box17X + 120,
						'y1' => $box17Y - BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - BOX17_SPACING,
					},

					{
						'x1' => $box17X + BOX17_LINE_PADDING,
						'y1' => $box17Y - 2 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 2 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 100,
						'y1' => $box17Y - 3 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 3 * BOX17_SPACING,
					},

					{
						'x1' => $box17X + BOX17_LINE_PADDING,
						'y1' => $box17Y - 4 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 4 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 95,
						'y1' => $box17Y - 5 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 5 * BOX17_SPACING,
					},

					{
						'x1' => $box17X + BOX17_LINE_PADDING,
						'y1' => $box17Y - 6 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 6 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 200,
						'y1' => $box17Y - 7 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 7 * BOX17_SPACING,
					},

					{
						'x1' => $box17X + BOX17_LINE_PADDING,
						'y1' => $box17Y - 8 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 8 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 60,
						'y1' => $box17Y - 9 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 9 * BOX17_SPACING,
					},

					{
						'x1' => $box17X + BOX17_LINE_PADDING,
						'y1' => $box17Y - 10 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 10 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 142,
						'y1' => $box17Y - 11 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 11 * BOX17_SPACING,
					},

					{
						'x1' => $box17X + BOX17_LINE_PADDING,
						'y1' => $box17Y - 12 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 12 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 133,
						'y1' => $box17Y - 13 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 13 * BOX17_SPACING,
					},

					{
						'x1' => $box17X + BOX17_LINE_PADDING,
						'y1' => $box17Y - 14 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 14 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 45,
						'y1' => $box17Y - 15 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 15 * BOX17_SPACING,
					},

					{
						'x1' => $box17X + BOX17_LINE_PADDING,
						'y1' => $box17Y - 16 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 16 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 80,
						'y1' => $box17Y - 17 * BOX17_SPACING,
						'x2' => $box17X + 255,
						'y2' => $box17Y - 17 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 315,
						'y1' => $box17Y - 17 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 17 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 40,
						'y1' => $box17Y - 18 * BOX17_SPACING,
						'x2' => $box17X + 343,
						'y2' => $box17Y - 18 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 359,
						'y1' => $box17Y - 18 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 18 * BOX17_SPACING,
					},
					{
						'x1' => $box17X + 110,
						'y1' => $box17Y - 19 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 19 * BOX17_SPACING,
					},

					{
						'x1' => $box17X + 190,
						'y1' => $box17Y - 20 * BOX17_SPACING,
						'x2' => $box17X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box17Y - 20 * BOX17_SPACING,
					}
				],
			checkBoxes =>
				[
					{
						'height' => 7,
						'width' => 7,
						'x' => $box17X + BOX17_LINE_PADDING,
						'y' => $box17Y - BOX17_PADDING - 10 * BOX17_SPACING - 7
					},
					{
						'height' => 7,
						'width' => 7,
						'x' => $box17X + BOX17_LINE_PADDING + 45,
						'y' => $box17Y - BOX17_PADDING - 10 * BOX17_SPACING - 7
					}
				]

			};

	$report->drawBox($p, $box17X, $box17Y, MAIN_BOX_WIDTH, BOX17_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
#box 17 end

#footer
	$properties =
	{
		'text' =>"TWCC 61  (Rev. 7/98)",
		'x' => $box17X,
		'y' => $box17Y - BOX17_HEIGHT -10,
		'fontWidth' => 7
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' =>"Rule 133.101",
		'x' => $box17X + MAIN_BOX_WIDTH - 60 ,
		'y' => $box17Y - BOX17_HEIGHT - 10,
		'fontWidth' => 7
	};
	$report->drawText($p, $properties);

}

sub fillData
{
	my($self, $p, $claim, $report) = @_;

	my $mainBoxX = LEFT_MARGIN;
	my $mainBoxY = TOP_MARGIN - MAIN_BOX_Y;

	$self->boxTopData($p, $claim, LEFT_MARGIN + 333, TOP_MARGIN, $report);
	$self->box1Data($p, $claim, $mainBoxX, $mainBoxY, $report);
	$self->box2Data($p, $claim, $mainBoxX + BOX1_WIDTH, $mainBoxY, $report);
	$self->box3Data($p, $claim, $mainBoxX, $mainBoxY - BOX_HEIGHT, $report);
	$self->box4Data($p, $claim, $mainBoxX, $mainBoxY - 3 * BOX_HEIGHT, $report);
	$self->box5Data($p, $claim, $mainBoxX + BOX2_WIDTH, $mainBoxY - 3 * BOX_HEIGHT, $report);
	$self->box8Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY, $report);
	$self->box6Data($p, $claim, $mainBoxX, $mainBoxY - 4 * BOX_HEIGHT, $report);
	$self->box7Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/4, $mainBoxY - 4 * BOX_HEIGHT, $report);
	$self->box9Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH * 3/4 , $mainBoxY, $report);
	$self->box10Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - BOX_HEIGHT, $report);
	$self->boxEmployeeCityData($p, $claim, $mainBoxX, $mainBoxY - 2 * BOX_HEIGHT, $report);
	$self->boxEmployerCityData($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 3 * BOX_HEIGHT, $report);
	$self->box11Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 2 * BOX_HEIGHT, $report);
	$self->box12Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 4 * BOX_HEIGHT, $report);

	my $box13Y = $mainBoxY - 5 * BOX_HEIGHT - NOTICE_BOX_HEIGHT;
	my $box14Y = $box13Y - BOX13_HEIGHT;
	my $box16Y= $box14Y - BOX14_HEIGHT;
	my $box17Y= $box16Y - BOX_HEIGHT - 20;

	$self->box13Data($p, $claim, $mainBoxX, $box13Y, $report);
	$self->box14Data($p, $claim, $mainBoxX, $box14Y, $report);
	$self->box15Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH - 34,  $box14Y, $report);
	$self->box16Data($p, $claim, $mainBoxX, $box16Y, $report);
	$self->box17Data($p, $claim, $mainBoxX, $box17Y, $report);
}

sub boxTopData
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
				'text' => $claim->{insured}->[$claim->getClaimType]->getPolicyGroupOrFECANo,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 25,
				'y' => $y - 6
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->getId,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 50,
				'y' => $y - 16
			};
	$report->drawText($p, $properties);
}

sub box1Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $patient = $claim->{careReceiver};
	my $employeeName = $patient->getLastName . ", " . $patient->getFirstName . " " . $patient->getMiddleInitial . ".";

	$properties =
			{
				'text' => $employeeName,
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

	$properties =
			{
				'text' => $claim->{careReceiver}->getDateOfBirth(DATEFORMAT_USA),
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

	$properties =
			{
				'text' => $claim->{careReceiver}->getAddress->getAddress1,
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

	my $properties =
			{
				'text' => $claim->{careReceiver}->getVisitDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + DATA_LEFT_PADDING,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);
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

	$properties =
			{
				'text' => $claim->{payToOrganization}->getTaxId,
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
				'text' => $claim->{renderingProvider}->getProfessionalLicenseNo,
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
				'text' => $claim->{payer}->getName,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + DATA_LEFT_PADDING,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);
}

sub box8Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	$properties =
			{
				'text' => $claim->{treatment}->getDateOfIllnessInjuryPregnancy(DATEFORMAT_USA),
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + DATA_LEFT_PADDING,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);
}

sub box9Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	$properties =
			{
				'text' => $claim->{insured}->[$claim->getClaimType]->getSsn,
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

	$properties =
			{
				'text' => $claim->{insured}->[$claim->getClaimType]->getEmployerOrSchoolName,
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

	$properties =
			{
				'text' => $claim->{insured}->[$claim->getClaimType]->{employerAddress}->getAddress1,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + DATA_LEFT_PADDING,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);
}

sub boxEmployeeCityData
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my $address = $claim->{careReceiver}->getAddress;

	$properties =
			{
				'text' => $address->getCity,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $address->getState,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 60,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $address->getZipCode,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 105,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => substr($address->getTelephoneNo,0, 3) . "    " . substr($address->getTelephoneNo,3, 7),
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 160,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);
}

sub boxEmployerCityData
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	my $employerAddress = $claim->{insured}->[$claim->getClaimType]->getEmployerAddress;

	$properties =
			{
				'text' => $employerAddress->getCity,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $employerAddress->getState,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 115,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $employerAddress->getZipCode,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 207,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);
}

#diagnosis
sub box13Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $diagCode0 = $claim->{'diagnosis'}->[0]->getDiagnosis() if ($claim->{'diagnosis'}->[0] ne "");
	$properties =
			{
				'text' => $diagCode0,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 58,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	my $diagCode1 = $claim->{'diagnosis'}->[1]->getDiagnosis() if ($claim->{'diagnosis'}->[1] ne "");
	$properties =
			{
				'text' => $diagCode1,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 165,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	my $diagCode2 = $claim->{'diagnosis'}->[2]->getDiagnosis() if ($claim->{'diagnosis'}->[2] ne "");
	$properties =
			{
				'text' => $diagCode2,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 270,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);
}

sub box14Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	for $i(0..3)
	{
		last if not defined $claim->{'procedures'}->[$i];
		$properties =
			{
				'text' => $claim->{'procedures'}->[$i]->getCPT,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 55,
				'y' => $y - DATA_TOP_PADDING - ( $i * 0.5 * BOX_HEIGHT) - 1
			};
		$report->drawText($p, $properties);

		$properties =
			{
				'text' => $claim->{'procedures'}->[$i]->getModifier,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 112,
				'y' => $y - DATA_TOP_PADDING - ( $i * 0.5 * BOX_HEIGHT) - 1
			};
		$report->drawText($p, $properties);
	}
}

sub box15Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $tmp;
	my $ptr;

	for $i(0..3)
	{
		last if ($claim->{'procedures'}->[$i] eq "");
		my $ptr = $claim->{'procedures'}->[$i]->getDiagnosisCodePointer;
		$tmp = join(' ', @$ptr);
		$tmp =~ s/1/a/;
		$tmp =~ s/2/b/;
		$tmp =~ s/3/c/;

		$properties =
		{
			'text' => $tmp,
			'fontWidth' => DATA_FONT_SIZE,
			'color' => DATA_FONT_COLOR,
			'x' => $x,
			'y' => $y - DATA_TOP_PADDING - (0.5 * $i * BOX_HEIGHT)
		};
		$report->drawText($p, $properties);
	}
}

sub box16Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	$properties =
			{
				'text' => $claim->{treatment}->getReturnToLimitedWorkAnticipatedDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 99,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->{treatment}->getMaximumImprovementAnticipatedDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 266,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->{treatment}->getReturnToFullTimeWorkAnticipatedDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 408,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);
}

sub box17Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my @arrX = (120,100,95,200,60,142,133,45);
	my @arrData;
	$arrData[0] = $claim->{treatment}->getInjuryHistory;
	$arrData[1] = $claim->{treatment}->getPastMedicalHistory;
	$arrData[2] = $claim->{treatment}->getClinicalFindings;
	$arrData[3] = $claim->{treatment}->getLaboratoryTests;
	$arrData[4] = $claim->{treatment}->getTreatmentPlan;
	$arrData[5] = $claim->{treatment}->getReferralInfo61;
	$arrData[6] = $claim->{treatment}->getMedications61;
	$arrData[7] = $claim->{treatment}->getPrognosis;


	for $i(0..7)
	{
		my ($first, $rest) = $report->textSplit($p, $arrData[$i], 520 - $arrX[$i], FONT_NAME, DATA_FONT_SIZE);

		$properties =
			{
				'text' => $first,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + $arrX[$i],
				'y' => $y - BOX17_TOP_PADDING - 2 * $i * BOX17_SPACING
			};
		$report->drawText($p, $properties);

		if ($rest ne "")
		{
			($first, $rest) = $report->textSplit($p, $rest, 500, FONT_NAME, DATA_FONT_SIZE);
			$properties =
				{
					'text' => $first,
					'fontWidth' => DATA_FONT_SIZE,
					'color' => DATA_FONT_COLOR,
					'x' => $x + 10,
					'y' => $y - BOX17_TOP_PADDING - ((2 * $i) + 1)* BOX17_SPACING
				};
			$report->drawText($p, $properties);
		}
	};

	my $arr = [13,58];
	my $t = $claim->{treatment}->getReferralSelection;
	my $textX = "x" if $t ne "";
	$properties =
	{
		'text' => $textX,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arr->[$t - 1],
		'y' => $y - 140
	};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->{renderingProvider}->getFirstName . " " . $claim->{renderingProvider}->getLastName,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 80,
				'y' => $y - 16 * BOX17_SPACING - BOX17_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->getInvoiceDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 359,
				'y' => $y - 17 * BOX17_SPACING - BOX17_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->{renderingProvider}->{address}->getAddress1 . ", " . $claim->{renderingProvider}->{address}->getCity . ", " . $claim->{renderingProvider}->{address}->getState . " " . $claim->{renderingProvider}->{address}->getZipCode,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 40,
				'y' => $y - 17 * BOX17_SPACING - BOX17_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->{treatment}->getDateMailedToEmployee,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 110,
				'y' => $y - 18 * BOX17_SPACING - BOX17_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->{treatment}->getDateMailedToInsurance,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 190,
				'y' => $y - 19 * BOX17_SPACING - BOX17_TOP_PADDING
			};
	$report->drawText($p, $properties);
}

1;
