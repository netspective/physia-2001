package App::Billing::Output::TWCC::TWCC60;

use App::Billing::Output::PDF::Report;

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
use constant DATA_LEFT_PADDING => 6;
use constant DATA_TOP_PADDING => 10;
use constant DATA_FONT_SIZE => 8;
use constant DATA_FONT_COLOR => '0,0,0';
use constant FONT_NAME => 'Times-Roman';
use constant BOLD_FONT_NAME =>  'Times-Bold';
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
#	$self->fillData($p, $claim, $report);
	$report->endPage($p);
	
	my $properties = {'pageWidth' => PAGE2_WIDTH, 'pageHeight' => PAGE2_HEIGHT};
	$report->newPage($p, $properties);
	$self->drawForm_2($p, $claim, $report);
#	$self->fillData_2($p, $claim, $report);
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
#	$self->box15($p, $claim, $mainBoxX, $box12Y - BOX_HEIGHT, $report);
#	$self->box18($p, $claim, $mainBoxX, $box12Y - 2 * BOX_HEIGHT, $report);
#	$self->box21($p, $claim, $mainBoxX, $box12Y - 3 * BOX_HEIGHT, $report);
#	$self->box24($p, $claim, $mainBoxX, $box12Y - 4 * BOX_HEIGHT, $report);
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
}

sub fillData_2
{
	my($self, $p, $claim, $report) = @_;

	my $mainBoxX = LEFT_MARGIN_2;
	my $mainBoxY = TOP_MARGIN_2 - MAIN_BOX_Y_2;

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
		$properties =
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
		$properties =
		{
			'text' => $arrRight->[$i],
			'x' => LEFT_MARGIN + 446,
			'y' => TOP_MARGIN - $i * LINE_SPACING,
			'fontName' => FONT_NAME,
			'fontWidth' => 7
		};
		$report->drawText($p,$properties);
	}

	$properties =
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

	my $properties =
	{
		'text' => "",
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
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
		$report->drawBox($p,  $x + $i * BOX_WIDTH_2,  $y, BOX_WIDTH_2, BOX_HEAD_HEIGHT_2, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
	}
	
	for $i(0..1)
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
	
	$properties = 
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


1;