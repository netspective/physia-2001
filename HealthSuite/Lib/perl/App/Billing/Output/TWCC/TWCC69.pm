package App::Billing::Output::TWCC::TWCC69;

use App::Billing::Output::PDF::Report;
use pdflib 2.01;

use constant LEFT_MARGIN => 48;
use constant TOP_MARGIN => 756; # 792 - 36
use constant BOX_HEIGHT => 22;
use constant LINE_SPACING => 9;
use constant MAIN_BOX_Y => 65;
use constant MAIN_BOX_WIDTH => 522;
use constant BOX1_WIDTH => 197;
use constant BOX2_WIDTH => 63;
use constant HEADING_Y => 50;
use constant HEADING_X => 162;
use constant RIGHT_BOX_HEIGHT => 31;
use constant RIGHT_BOX_WIDTH => 210;
use constant RIGHT_BOX_PADDING => 8;
use constant LEFT_LINE => 1;
use constant RIGHT_LINE => 1;
use constant TOP_LINE => 1;
use constant BOTTOM_LINE => 1;
use constant NO_LEFT_LINE => 0;
use constant NO_RIGHT_LINE => 0;
use constant NO_TOP_LINE => 0;
use constant NO_BOTTOM_LINE => 0;
use constant NOTICE_BOX_HEIGHT => 34;
use constant BOX16_HEIGHT => 48;
use constant BOX17_HEIGHT => 68;
use constant SPC => " ";
use constant BOX17_PADDING => 6;
use constant BOX17_SPACING => 13.5;
use constant BOX17_LINE_PADDING => 13;
use constant BOX18_HEIGHT => 73;
use constant BOX19_HEIGHT => 25;
use constant BOX20_HEIGHT => 31;
use constant BOX22_HEIGHT => 156;
use constant DATA_LEFT_PADDING => 6;
use constant DATA_TOP_PADDING => 10;
use constant DATA_FONT_SIZE => 8;
use constant DATA_FONT_COLOR => '0,0,0';
use constant FONT_NAME => 'Helvetica';
use constant BOLD_FONT_NAME => FONT_NAME . '-Bold';
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
	my($self, $p, $claim, $report) = @_;

	
	my $mainBoxX = LEFT_MARGIN;
	my $mainBoxY = TOP_MARGIN - MAIN_BOX_Y;

	$self->header($p, $claim, $mainBoxX, $mainBoxY, $report);
	$self->box1($p, $claim, $mainBoxX, $mainBoxY, $report);
	$self->box2($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY, $report);
	$self->box3($p, $claim, $mainBoxX + MAIN_BOX_WIDTH * 3/4, $mainBoxY, $report);
	$self->box4($p, $claim, $mainBoxX, $mainBoxY - BOX_HEIGHT, $report);
	$self->box5($p, $claim, $mainBoxX + MAIN_BOX_WIDTH * 3/4, $mainBoxY - BOX_HEIGHT, $report);
	$self->box6($p, $claim, $mainBoxX, $mainBoxY - 2 * BOX_HEIGHT, $report);
	$self->box7($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 2 * BOX_HEIGHT, $report);
	$self->box8($p, $claim, $mainBoxX, $mainBoxY - 3 * BOX_HEIGHT, $report);
	$self->box9($p, $claim, $mainBoxX, $mainBoxY - 4 * BOX_HEIGHT, $report);
	$self->box10($p, $claim, $mainBoxX + MAIN_BOX_WIDTH * 3/4, $mainBoxY - 4 * BOX_HEIGHT, $report);
	$self->box11($p, $claim, $mainBoxX, $mainBoxY - 5 * BOX_HEIGHT, $report);
	$self->box12($p, $claim, $mainBoxX + MAIN_BOX_WIDTH * 3/4, $mainBoxY - 5 * BOX_HEIGHT, $report);
	$self->box13($p, $claim, $mainBoxX, $mainBoxY - 6 * BOX_HEIGHT, $report);
	$self->box14($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 6 * BOX_HEIGHT, $report);
	$self->box15($p, $claim, $mainBoxX, $mainBoxY - 7 * BOX_HEIGHT, $report);

	my $box16Y = $mainBoxY - 8 * BOX_HEIGHT;
	
	$self->box16($p, $claim, $mainBoxX, $box16Y, $report);
	$self->box17($p, $claim, $mainBoxX, $box16Y - BOX16_HEIGHT, $report);
	$self->box18($p, $claim, $mainBoxX, $box16Y - BOX16_HEIGHT - BOX17_HEIGHT, $report);
	$self->boxNotice($p, $claim, $mainBoxX, $box16Y - BOX16_HEIGHT - BOX17_HEIGHT - BOX18_HEIGHT, $report);

	my  $box19Y = $box16Y - BOX16_HEIGHT - BOX17_HEIGHT - BOX18_HEIGHT - NOTICE_BOX_HEIGHT;

	$self->box19($p, $claim, $mainBoxX, $box19Y, $report);
	$self->box20($p, $claim, $mainBoxX, $box19Y - BOX19_HEIGHT, $report);
	$self->box22($p, $claim, $mainBoxX, $box19Y - BOX19_HEIGHT - BOX20_HEIGHT, $report);
	$self->footer($p, $claim, $mainBoxX, $box19Y - BOX19_HEIGHT - BOX20_HEIGHT - BOX22_HEIGHT - 23, $report);

}

sub fillData
{
	my($self, $p, $claim, $report) = @_;

	my $mainBoxX = LEFT_MARGIN;
	my $mainBoxY = TOP_MARGIN - MAIN_BOX_Y;

	$self->boxTopData($p, $claim, LEFT_MARGIN + 312, TOP_MARGIN, $report);

	$self->box1Data($p, $claim, $mainBoxX, $mainBoxY, $report);
	$self->box2Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY, $report);
	$self->box3Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH * 3/4, $mainBoxY, $report);
	$self->box4Data($p, $claim, $mainBoxX, $mainBoxY - BOX_HEIGHT, $report);
	$self->box5Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH * 3/4, $mainBoxY - BOX_HEIGHT, $report);
	$self->box6Data($p, $claim, $mainBoxX, $mainBoxY - 2 * BOX_HEIGHT, $report);
	$self->box7Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 2 * BOX_HEIGHT, $report);
	$self->box8Data($p, $claim, $mainBoxX, $mainBoxY - 3 * BOX_HEIGHT, $report);
	$self->box9Data($p, $claim, $mainBoxX, $mainBoxY - 4 * BOX_HEIGHT, $report);
	$self->box10Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH * 3/4, $mainBoxY - 4 * BOX_HEIGHT, $report);
	$self->box11Data($p, $claim, $mainBoxX, $mainBoxY - 5 * BOX_HEIGHT, $report);
	$self->box12Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH * 3/4, $mainBoxY - 5 * BOX_HEIGHT, $report);
	$self->box13Data($p, $claim, $mainBoxX, $mainBoxY - 6 * BOX_HEIGHT, $report);
	$self->box14Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 6 * BOX_HEIGHT, $report);
	$self->box15Data($p, $claim, $mainBoxX, $mainBoxY - 7 * BOX_HEIGHT, $report);

	my $box16Y = $mainBoxY - 8 * BOX_HEIGHT;
	
	$self->box17Data($p, $claim, $mainBoxX, $box16Y - BOX16_HEIGHT, $report);
	$self->box18Data($p, $claim, $mainBoxX, $box16Y - BOX16_HEIGHT - BOX17_HEIGHT, $report);

	my  $box19Y = $box16Y - BOX16_HEIGHT - BOX17_HEIGHT - BOX18_HEIGHT - NOTICE_BOX_HEIGHT;

	$self->box19Data($p, $claim, $mainBoxX, $box19Y, $report);
	$self->box20Data($p, $claim, $mainBoxX, $box19Y - BOX19_HEIGHT, $report);
	$self->box22Data($p, $claim, $mainBoxX, $box19Y - BOX19_HEIGHT - BOX20_HEIGHT, $report);
	
}

sub header
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties = 
	{	
		'text' =>"Send To TWCC OFFICE Handling Claim, If known, or",
		'x' => LEFT_MARGIN,
		'y' => TOP_MARGIN, 
		'fontWidth' => 8
	};
	$report->drawText($p, $properties);
	$properties = 
	{	
		'text' =>"TEXAS WORKERS\' COMPENSATION COMMISSION",
		'x' => LEFT_MARGIN,
		'y' => TOP_MARGIN - LINE_SPACING,
		'fontWidth' => 7
	};
	$report->drawText($p, $properties);
	
	$properties =
	{
		'text' =>"4000 South IH-35, Southfield Building",
		'x' => LEFT_MARGIN,
		'y' => TOP_MARGIN - 2 * LINE_SPACING,
		'fontWidth' => 7
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' =>"Austin, Texas 78704",
		'x' => LEFT_MARGIN,
		'y' => TOP_MARGIN - 3 * LINE_SPACING,
		'fontWidth' => 7
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' =>"REPORT OF MEDICAL EVALUATION",
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 10, 
		'x' => LEFT_MARGIN + HEADING_X,
		'y' => TOP_MARGIN - HEADING_Y
	};
	$report->drawText($p,$properties);

	my $rightBoxX = LEFT_MARGIN + 312;
	my $rightBoxY = TOP_MARGIN;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' =>"TWCC#",
						'fontWidth' => 7,
						'x' => $rightBoxX,
						'y' => $rightBoxY - RIGHT_BOX_PADDING
					},
					{
						'text' =>"Carrier\'s Claim #",
						'fontWidth' => 7,
						'x' => $rightBoxX,
						'y' => $rightBoxY - LINE_SPACING - RIGHT_BOX_PADDING
					}
				],

			lines =>
				[
					{	
						'x1' => $rightBoxX + 30,
						'y1' => $rightBoxY - 15,
						'x2' => $rightBoxX + 30 + 165,
						'y2' => $rightBoxY - 15
					},

					{
						'x1' => $rightBoxX + 55,
						'y1' => $rightBoxY - 25,
						'x2' => $rightBoxX + 55 + 140,
						'y2' => $rightBoxY - 25
					}
				]					
			};
					
	$report->drawBox($p, $rightBoxX, $rightBoxY, RIGHT_BOX_WIDTH, RIGHT_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
	
}
	
sub box1
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
			{
			texts => 
				[
					{
						'text' =>"1. Injured Employee's Name (Last, First, M.I.)",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					}
				]
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/2, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box2
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	

	my $properties =
			{
			texts => 
				[
					{
						'text' =>"2. Social Security Number",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/4, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box3
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	
	my $properties =
			{
			texts => 
				[
					{
						'text' =>"3. Date of Injury",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					}
				]
			};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/4, BOX_HEIGHT , NO_LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

}
	
sub box4
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[	
					{
						'text' =>"4. Injured Employee's Mailing Address (Street or P.O. Box)",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>"City",
						'fontWidth' => 7,
						'x' => $x + 216,
						'y' => $y
					},
					{
						'text' =>"State",
						'fontWidth' => 7,
						'x' => $x + 300,
						'y' => $y
					},
					{
						'text' =>"Zip Code",
						'fontWidth' => 7,
						'x' => $x + 354,
						'y' => $y
					}
				]
		};

	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH * 3/4, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub box5
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[	
					{
						'text' =>"5. Phone Number",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>"(         )",
						'fontWidth' => 7,
						'x' => $x + 10,
						'y' => $y - DATA_TOP_PADDING
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/4, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub box6
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[	
					{
						'text' =>"6. Employer's Business Name",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/2, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box7
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		texts =>
			[	
				{
					'text' =>"7. Workers' Compensation Insurance Carrier",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/2, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box8
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[	
					{
						'text' =>"8. Employer's Mailing Address (Street or P.O. Box)",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>"City",
						'fontWidth' => 7,
						'x' => $x + 216,
						'y' => $y
					},
					{
						'text' =>"State",
						'fontWidth' => 7,
						'x' => $x + 300,
						'y' => $y
					},
					{
						'text' =>"Zip Code",
						'fontWidth' => 7,
						'x' => $x + 354,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box9
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[	
					{
						'text' =>"9. Doctor's Name, Title and Speciality",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH * 3/4, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box10
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
		{
			texts =>
				[	
					{
						'text' =>"10. Date of Visit",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y 
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/4, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box11
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[	
					{
						'text' =>"11. Doctor's Mailing Address (Street or P.O. Box)",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>"City",
						'fontWidth' => 7,
						'x' => $x + 216,
						'y' => $y
					},
					{
						'text' =>"State",
						'fontWidth' => 7,
						'x' => $x + 300,
						'y' => $y
					},
					{
						'text' =>"Zip Code",
						'fontWidth' => 7,
						'x' => $x + 354,
						'y' => $y
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH * 3/4, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box12
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
		{
			texts =>
				[	
					{
						'text' =>"12. Phone Number",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>"(         )",
						'fontWidth' => 7,
						'x' => $x + 12,
						'y' => $y - DATA_TOP_PADDING
					}
				]
		};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/4, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box13
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' =>"13. Professional License Number",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/2, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box14
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' =>"14. Diagnosis (ICD-9 Codes)",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
				{
					'text' =>"(1)  ____  ____  ____  .  ____  ____        (2)  ____  ____  ____  .  ____  ____ ",
					'fontWidth' => 7,
					'x' => $x + 10,
					'y' => $y - 15
				},
				{
					'text' =>"(3)  ____  ____  ____  .  ____  ____        (4)  ____  ____  ____  .  ____  ____ ",
					'fontWidth' => 7,
					'x' => $x + 10,
					'y' => $y - 30
				}
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/2, BOX_HEIGHT * 2 , LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

}

sub box15
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' =>"15. Federal Tax Identification No.",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				}
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH/2, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box16
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' => "16.  Please attach a narrative history of the employee's medical condition(s) including but not limited to:",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
				{
					'text' => "a)  onset and course of employee's medical condition(s): and",
					'fontWidth' => 7,
					'x' => $x + 43,
					'y' => $y - LINE_SPACING - 2
				},
				{
					'text' => "b)  findings of previous examinations, treatments and responses to treatments",
					'fontWidth' => 7,
					'x' => $x + 43,
					'y' => $y - 2 * LINE_SPACING - 2 
				},
				{
					'text' => "    not previously reported to the insurance carrier and the Commission by the doctor making this report.",
					'fontWidth' => 7,
					'x' => $x + 43,
					'y' => $y - 3 * LINE_SPACING - 2 
				},
				{
					'text' => "c)  a description of the results of the most recent clinical evaluation of the employee.",
					'fontWidth' => 7,
					'x' => $x + 43,
					'y' => $y - 4 * LINE_SPACING - 2 
				}
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, BOX16_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box17
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' => "MAXIMUM MEDICAL IMPROVEMENT",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y
				},
				{
					'text' => "17.  Has employee reached maximum medical improvement as defined on the reverse side? Please check the appropriate box and complete the remainder of the form.",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - LINE_SPACING
				},
				{
					'text' => "No, the employee has not reached maximum medical improvement. Give the estimated date on which the employee is expected to reach maximum medical",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 3 * LINE_SPACING
				},
				{
					'text' => "improvement. ___________________________",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 4 * LINE_SPACING
				},
				{
					'text' => "Yes, I certify the above named employee has reached maximum medical improvement on __________________________. This date may not be prospective.",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 6 * LINE_SPACING
				}
			],
		checkBoxes =>
			[
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 7,
					'y' => $y - 35
				},
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 7,
					'y' => $y - 62
				}
			]

	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, BOX17_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub box18
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' => "IMPAIRMENT RATING",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 3
				},
				{
					'text' => "18.  I certify the above-named employee has a whole body impairment rating of ______%. (Please attach worksheets used to determine the whole body impairment.)",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - LINE_SPACING - 3
				},
				{
					'text' => "Objective clinical or laboratory finding means a medical finding of impairment resulting from a compensable injury, based on competent objective medical evidence",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 2 * LINE_SPACING - 6
				},
				{
					'text' => "that is independently confirmable by a doctor, including a designated doctor, without reliance on the subjective symptoms perceived by the employee. The",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 3 * LINE_SPACING - 6
				},
				{
					'text' => "impairment rating whall be based on the compensable injury alone.",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 4 * LINE_SPACING - 6
				},
				{
					'text' => "To determine the existence and degree of the employee's impairment, a doctor must use the \"Guides to the Evaluation of Permanent Impairment,\" third edition,",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 5 * LINE_SPACING - 8
				},
				{
					'text' => "second printing, February 1989, published by the American Medical Association.",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 6 * LINE_SPACING - 8
				}
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, BOX18_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub boxNotice
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' => "IMPROTANT NOTICE TO THE INJURED EMPLOYEE AND THE INSURANCE CARRIER:  THE FIRST IMPAIRMENT RATING",
					'fontWidth' => 9,
					'x' => $x,
					'y' => $y - 2
				},
				{
					'text' => "ASSIGNED BY A DOCTOR IS CONSIDERED FINAL IF THE RATING IS NOT DISPUTED WITHIN 90 DAYS FROM RECEIVING",
					'fontWidth' => 9,
					'x' => $x,
					'y' => $y - LINE_SPACING - 3
				},
				{
					'text' => "NOTICE OF THE RATING. CONTACT THE FIELD OFFICE HANDLING THE CLAIM FOR FURTHER INFORMATION.",
					'fontWidth' => 9,
					'x' => $x,
					'y' => $y - 2 * LINE_SPACING - 4
				},
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, NOTICE_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub box19
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' => "19. Doctor Type: (check appropriate block)" . SPC x 100 . "Required Medical Examination Doctor",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y
				},
				{
					'text' => "Treating" . SPC x 27 . "Other" . SPC x 22 . "Designated" . SPC x 50 . "Carrier Selected" . SPC x 18 . "Commission Selected",
					'fontWidth' => 7,
					'x' => $x + 30,
					'y' => $y - 15
				}
			],
		checkBoxes =>
			[
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 23,
					'y' => $y - 2 * LINE_SPACING - 4
				},
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 102,
					'y' => $y - 2 * LINE_SPACING - 4
				},
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 162,
					'y' => $y - 2 * LINE_SPACING - 4
				},
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 295,
					'y' => $y - 2 * LINE_SPACING - 4
				},
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 380,
					'y' => $y - 2 * LINE_SPACING - 4
				}
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, BOX19_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub box20
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' => "20.  Signature of Doctor __________________________________________________________________      21.  Date of this Report ____________________",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - 19
				}
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, BOX20_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}

sub box22
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		texts =>
			[	
				{
					'text' =>  "22. A doctor, other than the treating doctor or designated doctor, who certifies maximum medical improvement must send this Report of Medical Evaluation (TWCC-89) to",
					'fontWidth' => 6.8,
					'x' => $x,
					'y' => $y - 5
				},
				{
					'text' =>  "      the treating doctor no later than 7 days after the examination. The  treating doctor, in turn, must mail this Report of Medical Evaluation to the commision field office",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - LINE_SPACING - 5
				},
				{
					'text' =>  "      handling the employee's claim within 7 days. This will serve as the treating doctor's agreement or disagreement with certification of maximum medical improvement",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - 2 * LINE_SPACING - 5
				},
				{
					'text' =>  "      and/or with the assigned impairing rating.",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - 3 * LINE_SPACING - 5
				},
				{
					'text' =>  "      Treating Doctor's Review of Certification of Maximum Medical Improvement and Assigned Impairment Rating (see reverse side for instructions).",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - 5 * LINE_SPACING - 5
				},
				{
					'text' =>  "I AGREE with the above doctor's certification of maximum medical improvement.",
					'fontWidth' => 7,
					'x' => $x + 23,
					'y' => $y - 7 * LINE_SPACING - 5
				},
				{
					'text' =>  "I DISAGREE with the above doctor's certification of maximum medical",
					'fontWidth' => 7,
					'x' => $x + 290,
					'y' => $y - 7 * LINE_SPACING - 5
				},
				{
					'text' =>  "improvement.",
					'fontWidth' => 7,
					'x' => $x + 290,
					'y' => $y - 8 * LINE_SPACING - 5
				},
				{
					'text' =>  "I AGREE with the above doctor's assigned impairment rating.",
					'fontWidth' => 7,
					'x' => $x + 23,
					'y' => $y - 10 * LINE_SPACING - 4
				},
				{
					'text' =>  "I DISAGREE with the above doctor's assigned impairment rating.",
					'fontWidth' => 7,
					'x' => $x + 290,
					'y' => $y - 10 * LINE_SPACING - 4
				},
				{
					'text' =>  "23.  Signature of Treating Doctor______________________________________________________________",
					'fontWidth' => 7,
					'x' => $x,
					'y' => $y - 12 * LINE_SPACING - 8
				},
				{
					'text' =>  "Printed Name of Treating Doctor______________________________________________________________        24.  Date Signed ____________________",
					'fontWidth' => 7,
					'x' => $x + 15,
					'y' => $y - 14 * LINE_SPACING - 15
				},
			],
		checkBoxes =>
			[
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 15,
					'y' => $y - 8 * LINE_SPACING - 4
				},
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 280,
					'y' => $y - 8 * LINE_SPACING - 4
				},
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 15,
					'y' => $y - 10 * LINE_SPACING - 10
				},
				{
					'height' => 7,
					'width' => 7,
					'x' => $x + 280,
					'y' => $y - 10 * LINE_SPACING - 10
				},
			]
	};
	$report->drawBox($p, $x, $y, MAIN_BOX_WIDTH, BOX22_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
}


sub footer
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' =>"TXCC 69  (Rev. 5/94)",
		'fontWidth' => 7,
		'x' => $x,
		'y' => $y 
	};
	$report->drawText($p, $properties);
	
	$properties =
	{
		'text' =>"Rule 134",
		'fontWidth' => 7,
		'x' => $x + MAIN_BOX_WIDTH - 28,
		'y' => $y
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' =>"ADDITIONAL INFORMATION ON REVERSE SIDE",
		'fontWidth' => 9,
		'x' => $x + 162,
		'y' => $y + 10
	};
	$report->drawText($p, $properties);
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
		'text' => $claim->{careReceiver}->getLastName . ", " . $claim->{careReceiver}->getFirstName . " " . $claim->{careReceiver}->getMiddleInitial . ".",
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
		'text' => $claim->{careReceiver}->getSsn,
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
		'text' => $claim->{treatment}->getDateOfIllnessInjuryPregnancy(DATEFORMAT_USA),
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
		'text' => $claim->{careReceiver}->{address}->getAddress1,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
	
	$properties =
	{
		'text' => $claim->{careReceiver}->{address}->getCity,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 216,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $claim->{careReceiver}->{address}->getState,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 300,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

	my $pZip = length($claim->{careReceiver}->{address}->getZipCode) > 5 ? 338 : 353;
	$properties =
	{
		'text' => $claim->{careReceiver}->{address}->getZipCode,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $pZip,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

}


sub box5Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => substr($claim->{careReceiver}->{address}->getTelephoneNo, 0, 3) . "      " . substr($claim->{careReceiver}->{address}->getTelephoneNo, 3, 7),
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 7 + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}


sub box6Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{careReceiver}->getEmployerOrSchoolName,
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

	my $properties =
	{
		'text' => $claim->{careReceiver}->{employerAddress}->getAddress1,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $claim->{careReceiver}->{employerAddress}->getCity,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 216,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $claim->{careReceiver}->{employerAddress}->getState,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 300,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $claim->{careReceiver}->{employerAddress}->getZipCode,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 353,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box9Data
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

sub box10Data
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

sub box11Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => $claim->{renderingProvider}->{address}->getAddress1,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
	
	$properties =
	{
		'text' => $claim->{renderingProvider}->{address}->getCity,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 216,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $claim->{renderingProvider}->{address}->getState,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 300,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

	my $pZip = length($claim->{renderingProvider}->{address}->getZipCode) > 5 ? 338 : 353;
	$properties =
	{
		'text' => $claim->{renderingProvider}->{address}->getZipCode,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $pZip,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);

}

sub box12Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
	{
		'text' => substr($claim->{renderingProvider}->{address}->getTelephoneNo, 0, 3) . "      " . substr($claim->{renderingProvider}->{address}->getTelephoneNo, 3, 7),
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 9 + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box13Data
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

sub box14Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $diagCode0 = $claim->{'diagnosis'}->[0]->getDiagnosis if ($claim->{'diagnosis'}->[0] ne "");
	my $properties =
	{
		'text' => $diagCode0,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 55,
		'y' => $y - 12 
	};
	$report->drawText($p, $properties);
	
	my $diagCode1 = $claim->{'diagnosis'}->[1]->getDiagnosis if ($claim->{'diagnosis'}->[1] ne "");
	$properties =
	{
		'text' => $diagCode1,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 170,
		'y' => $y - 12 
	};
	$report->drawText($p, $properties);
	
	my $diagCode2 = $claim->{'diagnosis'}->[2]->getDiagnosis if ($claim->{'diagnosis'}->[2] ne "");
	$properties =
	{
		'text' => $diagCode2,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 55,
		'y' => $y - 28
	};
	$report->drawText($p, $properties);

	my $diagCode3 = $claim->{'diagnosis'}->[3]->getDiagnosis if ($claim->{'diagnosis'}->[3] ne "");
	$properties =
	{
		'text' => $diagCode3,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 170,
		'y' => $y - 28
	};
	$report->drawText($p, $properties);
}

sub box15Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		'text' => $claim->{payToOrganization}->getFederalTaxId,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + DATA_LEFT_PADDING,
		'y' => $y - DATA_TOP_PADDING
	};
	$report->drawText($p, $properties);
}

sub box17Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	my $tmp = $claim->{treatment}->getMaximumImprovement();
	my $textX = "x"; # if ($tmp == 0 or $tmp == 1); 
	my $arrTmp = [27,54];
	my $arrDateX = [80,310];
	my $arrDateY = [34,53];
	
	my $properties =
	{
		'text' => $textX, 
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 7,
		'y' => $y - $arrTmp->[$tmp]
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $claim->{treatment}->getMaximumImprovementDate,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arrDateX->[$tmp],
		'y' => $y - $arrDateY->[$tmp]
	};
	$report->drawText($p, $properties);
}

sub box18Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $properties =
	{
		'text' => $claim->{treatment}->getImpairmentRating,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 250,
		'y' => $y - 10
	};
	$report->drawText($p, $properties);
}

sub box19Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	my $arr1 = [23,102,162];
	my $arr2 = [295,380];
	
	my $t1 = $claim->{treatment}->getDoctorType;
	my $textX = "x" if $t1 ne "";
	my $properties =
	{
		'text' => $textX,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arr1->[$t1 - 1],
		'y' => $y - 14
	};
	$report->drawText($p, $properties);
	
	my $t2 = $claim->{treatment}->getExaminingDoctorType;
	my $textX2 = "x" if $t2 ne "";
	$properties =
	{
		'text' => $textX2,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arr2->[$t2 - 1],
		'y' => $y - 14
	};
	$report->drawText($p, $properties);

}

sub box20Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;

	$properties =
	{
		'text' => $self->getDate,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 435,
		'y' => $y - 16
	};
	$report->drawText($p, $properties);

}

sub box22Data
{	
	my($self, $p, $claim, $x, $y, $report) = @_;
	
	my $arrtmp = [280,15];
	my $t1 = $claim->{treatment}->getMaximumImprovementAgreement;
	my $textX = "x"; # if ($t1 == 0 or $t1 == 1);
	my $properties =
	{
		'text' => $textX,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arrtmp->[$t1],
		'y' => $y - 68
	};
	$report->drawText($p, $properties);

	my $t2 = $claim->{treatment}->getImpairmentRatingAgreement;
	my $textX2 = "x";  # if ($t2 == 0 or $t2 == 1);

	$properties =
	{
		'text' => $textX2,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + $arrtmp->[$t2],
		'y' => $y - 92
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => $claim->{renderingProvider}->getFirstName . " " . $claim->{renderingProvider}->getLastName,
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 128,
		'y' => $y - 140
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => "",					#date signed
		'fontWidth' => DATA_FONT_SIZE,
		'color' => DATA_FONT_COLOR,
		'x' => $x + 435,
		'y' => $y - 140
	};
	$report->drawText($p, $properties);

}

sub getDate
{
	my($self) = @_;
	
	my $monthSequence = {JAN => '01', FEB => '02', MAR => '03', APR => '04',
				   		 MAY => '05', JUN => '06', JUL => '07', AUG => '08',
				 		 SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
						};
	
	my $date = localtime();
	my $month = $monthSequence->{uc(substr(localtime(),4,3))};
	my @dateStr = ($month, substr(localtime(),8,2), substr(localtime(),20,4));

	@dateStr = reverse(@dateStr);

	$dateStr[1] =~ s/ /0/;

	return $dateStr[2] . "/" . $dateStr[1] . "/" . $dateStr[0];	
}

1;