package App::Billing::Output::TWCC::TWCC64;
use App::Billing::Output::PDF::Report;
use pdflib 2.01;

use constant LEFT_MARGIN => 48;
use constant TOP_MARGIN => 756; # 792 - 36
use constant BOX_HEIGHT => 22;
use constant LINE_SPACING => 9;
use constant MAIN_BOX_Y => 52;
use constant MAIN_BOX_WIDTH => 520;
use constant BOX1_WIDTH => 197;
use constant BOX2_WIDTH => 63;
use constant HEADING_Y => 40;
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
use constant BOX13_HEIGHT => 50;
use constant BOX14_HEIGHT => 61;
use constant BOX14_PADDING => 4;
use constant BOX17_HEIGHT => 107;
use constant FONT_NAME => 'Helvetica';
use constant BOLD_FONT_NAME => FONT_NAME . '-Bold';
use constant SPC => " ";
use constant BOX17_PADDING => 6;
use constant BOX17_SPACING => 13.5;
use constant BOX17_LINE_PADDING => 13;
use constant BOX18_HEIGHT => 40;
use constant BOX19_HEIGHT => 52;
use constant BOX20_HEIGHT => 16;
use constant BOX21_HEIGHT => 26;
use constant BOX22_HEIGHT => 16;
use constant BOX23_HEIGHT => 40;
use constant BOX24_HEIGHT => 42;
use constant DATA_LEFT_PADDING => 3;
use constant DATA_TOP_PADDING => 10;
use constant DATA_TOP_PADDING2 => 4;
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
		'text' =>"TEXAS WORKERS' COMPENSATION COMMISSION",
		'x' => LEFT_MARGIN,
		'y' => TOP_MARGIN, 
		'fontWidth' => 7
	};
	$report->drawText($p, $properties);
	
	$properties = 
	{
		'text' =>"Mail this form to the WORKERS' COMPENSATION INSURANCE CARRIER",
		'x' => LEFT_MARGIN,
		'y' => TOP_MARGIN - 2 * LINE_SPACING,
		'fontWidth' => 7
	};
	$report->drawText($p,$properties);

	$properties = 
	{
		'text' =>"SPECIFIC AND SUBSEQUENT MEDICAL REPORT",
		'fontName' => BOLD_FONT_NAME,
		'fontWidth' => 10, 
		'x' => LEFT_MARGIN + 130,
		'y' => TOP_MARGIN - HEADING_Y
	};
	$report->drawText($p, $properties);

	my $rightBoxX=LEFT_MARGIN + 333;
	my $rightBoxY=TOP_MARGIN - 0;
	
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
						'text' =>"Carrier's Claim #",
						'fontWidth' => 7,
						'x' => $rightBoxX,
						'y' => $rightBoxY - LINE_SPACING - RIGHT_BOX_PADDING
					}
				],

			lines =>
				[
					{	
						'x1' => $rightBoxX + 28,
						'y1' => $rightBoxY - 15,
						'x2' => $rightBoxX + 28 + 118,
						'y2' => $rightBoxY - 15
					},

					{
						'x1' => $rightBoxX + 54,
						'y1' => $rightBoxY - 24,
						'x2' => $rightBoxX + 54 + 110,
						'y2' => $rightBoxY - 24
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
						'fontWidth' => 7,
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
						'fontWidth' => 7,
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
						'fontWidth' => 7,
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
						'fontWidth' => 7,
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
						'fontWidth' => 7,
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
						'fontWidth' => 7,
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
						'text' =>"City                                   State             Zip Code                 Phone No.",
						'fontWidth' => 7,
						'x' => $mainBoxX,
						'y' => $mainBoxY - 2 * BOX_HEIGHT
					},
					{
						'text' => "(           )",
						'fontWidth' => 7,
						'x' => $mainBoxX + 182,
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
						'fontWidth' => 7,
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
						'fontWidth' => 7,
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
						'fontWidth' => 7,
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
					'text' =>"City                                                    State                                          Zip Code",
					'fontWidth' => 7,
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
					'fontWidth' => 7,
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
					'fontWidth' => 7,
					'x' => $mainBoxX + MAIN_BOX_WIDTH/4,
					'y' => $mainBoxY - 4 * BOX_HEIGHT
				}
			]
	};
	$report->drawBox($p, $mainBoxX + MAIN_BOX_WIDTH/4, $mainBoxY - 4 * BOX_HEIGHT, MAIN_BOX_WIDTH/4, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
# function end

	$properties =
	{
		texts =>
			[	
				{
					'text' =>"12. Insurance Carrier",
					'fontWidth' => 7,
					'x' => $mainBoxX + MAIN_BOX_WIDTH/2,
					'y' => $mainBoxY - 4 * BOX_HEIGHT
				}
			]
	};
	$report->drawBox($p, $mainBoxX + MAIN_BOX_WIDTH/2, $mainBoxY - 4 * BOX_HEIGHT, MAIN_BOX_WIDTH/2, BOX_HEIGHT, NO_LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	
#diagnosis
	
	my $box13X = $mainBoxX;
	my $box13Y= $mainBoxY - 5 * BOX_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "13. Diagnosis (ICD-9 Codes and Descriptions)       Relate Diagnosis to Procedure by Reference to Letters a, b, c)",
						'fontWidth' => 7,
						'x' => $box13X,
						'y' => $box13Y
					},
					{	
						'text' => "a)  ____  ____  ____  .  ____  ____ " ,
						'fontWidth' => 7,
						'x' => $box13X + 18,
						'y' => $box13Y - LINE_SPACING * 1 - 3
					},
					{	
						'text' => "b)  ____  ____  ____  .  ____  ____ " ,
						'fontWidth' => 7,
						'x' => $box13X + 18,
						'y' => $box13Y - LINE_SPACING * 2 - 3
					},
					{	
						'text' => "c)  ____  ____  ____  .  ____  ____ ",
						'fontWidth' => 7,
						'x' => $box13X + 18,
						'y' => $box13Y - LINE_SPACING * 3 - 3 
					}
				],

			lines =>
				[
					{	
						'x1' => $box13X + 360,
						'y1' => $box13Y - LINE_SPACING * .8,
						'x2' => $box13X + MAIN_BOX_WIDTH - 15,
						'y2' => $box13Y - LINE_SPACING * .8
					},

					{
						'x1' => $box13X + MAIN_BOX_WIDTH - 15,
						'y1' => $box13Y -  LINE_SPACING * .8,
						'x2' => $box13X + MAIN_BOX_WIDTH - 15,
						'y2' => $box13Y - LINE_SPACING * 4.5
					}
				]
			};
	$report->drawBox($p, $box13X, $box13Y, MAIN_BOX_WIDTH, BOX13_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	$properties =
			{
				'x1' => $box13X + MAIN_BOX_WIDTH - 17,
				'y1' => $box13Y - 40,
				'x2' => $box13X + MAIN_BOX_WIDTH - 13,
				'y2' => $box13Y - 40,
				'x3' => $box13X + MAIN_BOX_WIDTH - 15,
				'y3' => $box13Y - 43,
			};
	$report->drawArrow($p, $properties);

	my $box14X = $mainBoxX;
	my $box14Y= $box13Y - BOX13_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "14.      Treatment at this Visit  or       Procedure Performed in Hospital      (CPT Code and Modifiers, If Necessary, and Description)" . SPC x 32 . "15.",
						'fontWidth' => 7,
						'x' => $box14X,
						'y' => $box14Y - 1
					},
					{	
						'text' => "DO NOT INCLUDE OFFICE VISIT",
						'fontWidth' => 7,
						'x' => $box14X + 206,
						'y' => $box14Y - LINE_SPACING - 1
					},
					{	
						'text' => "____  ____  ____  ____  ____  .  ____  ____  .  ____  ____" ,
						'fontWidth' => 7,
						'x' => $box14X + 33,
						'y' => $box14Y - LINE_SPACING * 2 - BOX14_PADDING
					},
					{	
						'text' => "____  ____  ____  ____  ____  .  ____  ____  .  ____  ____" ,
						'fontWidth' => 7,
						'x' => $box14X + 33,
						'y' => $box14Y - LINE_SPACING * 3 - BOX14_PADDING
					},
					{	
						'text' => "____  ____  ____  ____  ____  .  ____  ____  .  ____  ____" ,
						'fontWidth' => 7,
						'x' => $box14X + 33,
						'y' => $box14Y - LINE_SPACING * 4 - BOX14_PADDING
					},
					{	
						'text' => "____  ____  ____  ____  ____  .  ____  ____  .  ____  ____" ,
						'fontWidth' => 7,
						'x' => $box14X + 33,
						'y' => $box14Y - LINE_SPACING * 5 - BOX14_PADDING
					}
				],
			checkBoxes =>
				[
					{
						'height' => 7,
						'width' => 7,
						'x' => $box14X + 15,
						'y' => $box14Y - 9 
					},
					{
						'height' => 7,
						'width' => 7,
						'x' => $box14X + 105,
						'y' => $box14Y - 9 
					}
				]				
			};
	$report->drawBox($p, $box14X, $box14Y, MAIN_BOX_WIDTH, BOX14_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box15X = $mainBoxX + MAIN_BOX_WIDTH  - 34;
	my $box15Y= $box13Y - BOX13_HEIGHT;
	$report->drawBox($p, $box15X, $box15Y, 34, 24, LEFT_LINE, NO_RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	$report->drawBox($p, $box15X, $box15Y - 24, 34, 11, LEFT_LINE, NO_RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	$report->drawBox($p, $box15X, $box15Y - 35,  34, 11, LEFT_LINE, NO_RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);
	$report->drawBox($p, $box15X, $box15Y -46, 34, 11, LEFT_LINE, NO_RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box16X = $mainBoxX;
	my $box16Y= $box14Y - BOX14_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "16. ANTICIPATED Dates the Injured employee May :      (Please Complete All Dates)",
						'fontWidth' => 7,
						'x' => $box16X,
						'y' => $box16Y
					},
					{	
						'text' => "a) Return to Limited Type of Work:" . SPC x 30 . "b) Achieve Maximum Medical Improvement:" . SPC x 30 . "c) Return to Full-time Work:",
						'fontWidth' => 7,
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
		'y' => $mainBoxY - 610, 
		'fontWidth' => 7
	};
	$report->drawText($p, $properties);

#box 17 start
	my $box17X = $mainBoxX;
	my $box17Y= $box16Y - BOX_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "17.  Reason for Report:",
						'fontWidth' => 7,
						'x' => $box17X,
						'y' => $box17Y
					},
					
					{
						'text' => "Subsequent Medical Report (due every 60 days after initial report)",
						'fontWidth' => 7,
						'x' => $box17X + 21,
						'y' => $box17Y - BOX17_SPACING
					},
					
					{
						'text' => "Released to Return to Work:" . SPC x 21 . "Limited Activity" . SPC x 28 . "Normal Activity" . SPC x 7 . "Date",
						'fontWidth' => 7,
						'x' => $box17X + 21,
						'y' => $box17Y - 2 * BOX17_SPACING
					},
					{
						'text' => "Changing Treating Doctors:" . SPC x 10 . "Name of New Doctor",
						'fontWidth' => 7,
						'x' => $box17X + 21,
						'y' => $box17Y - 3 * BOX17_SPACING
					},
					{
						'text' => "Address" . SPC x 115 . "Date:",
						'fontWidth' => 7,
						'x' => $box17X + 162,
						'y' => $box17Y - 4 * BOX17_SPACING
					},
					{
						'text' => "Professional License No.",
						'fontWidth' => 7,
						'x' => $box17X + 114,
						'y' => $box17Y - 6 * BOX17_SPACING
					},
					
					{
						'text' => "Discharge from:" . SPC x 34 . "Name of Hospital:" . SPC x 96 . "Discharge Date:",
						'fontWidth' => 7,
						'x' => $box17X + 21,
						'y' => $box17Y - 7 * BOX17_SPACING
					}
				],

			lines =>
				[
					{	
						'x1' => $box17X + 329,
						'y1' => $box17Y - 34,
						'x2' => $box17X + 414,
						'y2' => $box17Y - 34,
					},
					{	
						'x1' => $box17X + 195,
						'y1' => $box17Y - 102,
						'x2' => $box17X + 195 + 173,
						'y2' => $box17Y - 102,
					},
					{	
						'x1' => $box17X + 431,
						'y1' => $box17Y - 60,
						'x2' => $box17X + 516,
						'y2' => $box17Y - 60,
					},
					{	
						'x1' => $box17X + 431,
						'y1' => $box17Y - 102,
						'x2' => $box17X + 516,
						'y2' => $box17Y - 102,
					}
				],
			checkBoxes =>
				[
					{
						'height' => 7,
						'width' => 7,
						'x' => $box17X + BOX17_LINE_PADDING,
						'y' => $box17Y - BOX17_PADDING - BOX17_SPACING 
					},
					{
						'height' => 7,
						'width' => 7,
						'x' => $box17X + BOX17_LINE_PADDING ,
						'y' => $box17Y - BOX17_PADDING - 2 * BOX17_SPACING
					},
					{
						'height' => 7,
						'width' => 7,
						'x' => $box17X + BOX17_LINE_PADDING ,
						'y' => $box17Y - BOX17_PADDING - 3 * BOX17_SPACING
					},
					{
						'height' => 7,
						'width' => 7,
						'x' => $box17X + BOX17_LINE_PADDING ,
						'y' => $box17Y - BOX17_PADDING - 7 * BOX17_SPACING
					},
					{
						'height' => 7,
						'width' => 7,
						'x' => $box17X + 142 ,
						'y' => $box17Y - BOX17_PADDING - 2 * BOX17_SPACING
					},
					{
						'height' => 7,
						'width' => 7,
						'x' => $box17X + 244,
						'y' => $box17Y - BOX17_PADDING - 2 * BOX17_SPACING
					}
				]
									
			};
					
	$report->drawBox($p, $box17X, $box17Y, MAIN_BOX_WIDTH, BOX17_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	$report->drawBox($p, $box17X + 195, $box17Y - 38, 173, BOX17_SPACING, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE);
	$report->drawBox($p, $box17X + 195, $box17Y - 38 - BOX17_SPACING, 173, BOX17_SPACING, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE);
	$report->drawBox($p, $box17X + 195, $box17Y - 38 - 2 * BOX17_SPACING, 173, BOX17_SPACING, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE);
	$report->drawBox($p, $box17X + 195, $box17Y - 38 - 3 * BOX17_SPACING, 173, BOX17_SPACING, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE);
	
#box 17 end

	my $box18X = $mainBoxX;
	my $box18Y= $box17Y - BOX17_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "18.  Changes in Injured Employee's Condition, including Clinical Assessment and Test Results",
						'fontWidth' => 7,
						'x' => $box18X,
						'y' => $box18Y - BOX17_PADDING
					}
				],

			lines =>
				[
					{	
						'x1' => $box18X + 298,
						'y1' => $box18Y - BOX17_SPACING,
						'x2' => $box18X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box18Y - BOX17_SPACING,
					},

					{
						'x1' => $box18X + BOX17_LINE_PADDING,
						'y1' => $box18Y - 2 * BOX17_SPACING,
						'x2' => $box18X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box18Y - 2 * BOX17_SPACING,
					}
				]
									
			};
					
	$report->drawBox($p, $box18X, $box18Y, MAIN_BOX_WIDTH, BOX18_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box19X = $mainBoxX;
	my $box19Y= $box18Y - BOX18_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "19.  Treatment Plan *",
						'fontWidth' => 7,
						'x' => $box19X,
						'y' => $box19Y - BOX17_PADDING
					}
				],

			lines =>
				[
					{	
						'x1' => $box19X + 74,
						'y1' => $box19Y - BOX17_SPACING,
						'x2' => $box19X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box19Y - BOX17_SPACING,
					},

					{
						'x1' => $box19X + BOX17_LINE_PADDING,
						'y1' => $box19Y - 2 * BOX17_SPACING,
						'x2' => $box19X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box19Y - 2 * BOX17_SPACING,
					},

					{
						'x1' => $box19X + BOX17_LINE_PADDING,
						'y1' => $box19Y - 3 * BOX17_SPACING,
						'x2' => $box19X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box19Y - 3 * BOX17_SPACING,
					}
				]
									
			};
					
	$report->drawBox($p, $box19X, $box19Y, MAIN_BOX_WIDTH, BOX19_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box20X = $mainBoxX;
	my $box20Y= $box19Y - BOX19_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "20.  Referrals",
						'fontWidth' => 7,
						'x' => $box20X,
						'y' => $box20Y - BOX17_PADDING
					}
				]								
			};
	$report->drawBox($p, $box20X, $box20Y, MAIN_BOX_WIDTH, BOX20_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box21X = $mainBoxX;
	my $box21Y= $box20Y - BOX20_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "21.  Medications or Durable Medical Equipment",
						'fontWidth' => 7,
						'x' => $box21X,
						'y' => $box21Y - BOX17_PADDING
					}
				],

			lines =>
				[
					{	
						'x1' => $box21X + 156,
						'y1' => $box21Y - BOX17_SPACING,
						'x2' => $box21X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box21Y - BOX17_SPACING,
					}
				]				
			};
	$report->drawBox($p, $box21X, $box21Y, MAIN_BOX_WIDTH, BOX21_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box22X = $mainBoxX;
	my $box22Y= $box21Y - BOX21_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "22.  Prognosis",
						'fontWidth' => 7,
						'x' => $box22X,
						'y' => $box22Y - BOX17_PADDING
					}
				]								
			};
	$report->drawBox($p, $box22X, $box22Y, MAIN_BOX_WIDTH, BOX22_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box23X = $mainBoxX;
	my $box23Y= $box22Y - BOX22_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "23.  Compliance by Injured Employee with Recommended Treatment",
						'fontWidth' => 7,
						'x' => $box23X,
						'y' => $box23Y - BOX17_PADDING
					}
				],

			lines =>
				[
					{	
						'x1' => $box23X + 222,
						'y1' => $box23Y - BOX17_SPACING,
						'x2' => $box23X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box23Y - BOX17_SPACING,
					},
					{	
						'x1' => $box23X + BOX17_LINE_PADDING,
						'y1' => $box23Y - 2 * BOX17_SPACING,
						'x2' => $box23X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box23Y - 2 * BOX17_SPACING,
					}
				]				
			};
	$report->drawBox($p, $box23X, $box23Y, MAIN_BOX_WIDTH, BOX23_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

	my $box24X = $mainBoxX;
	my $box24Y= $box23Y - BOX23_HEIGHT;
	
	$properties =
			{
			texts =>
				[
					{	
						'text' => "24.  Signature of Doctor",
						'fontWidth' => 7,
						'x' => $box24X,
						'y' => $box24Y - BOX17_PADDING
					},
					{	
						'text' => "Date",
						'fontWidth' => 7,
						'x' => $box24X + 405,
						'y' => $box24Y - BOX17_PADDING
					},
					{	
						'text' => "Address",
						'fontWidth' => 7,
						'x' => $box24X + BOX17_LINE_PADDING,
						'y' => $box24Y - BOX17_PADDING - BOX17_SPACING
					}
				],
			lines =>
				[
					{	
						'x1' => $box24X + 78,
						'y1' => $box24Y - BOX17_SPACING,
						'x2' => $box24X + MAIN_BOX_WIDTH - 116,
						'y2' => $box24Y - BOX17_SPACING,
					},
					{	
						'x1' => $box24X + MAIN_BOX_WIDTH - 95 ,
						'y1' => $box24Y - BOX17_SPACING,
						'x2' => $box24X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box24Y - BOX17_SPACING,
					},
					{	
						'x1' => $box24X + 43,
						'y1' => $box24Y - 2 * BOX17_SPACING,
						'x2' => $box24X + MAIN_BOX_WIDTH - BOX17_LINE_PADDING,
						'y2' => $box24Y - 2 * BOX17_SPACING,
					}
				]				
			};
	$report->drawBox($p, $box24X, $box24Y, MAIN_BOX_WIDTH, BOX24_HEIGHT, LEFT_LINE, RIGHT_LINE, NO_TOP_LINE, BOTTOM_LINE, $properties);

#footer
	$properties =
	{
		'text' =>"TWCC 64  (Rev. 4/92)",
		'x' => $mainBoxX,
		'y' => $mainBoxY - 638, 
		'fontWidth' => 7
	};
	$report->drawText($p, $properties);
	
	$properties =
	{
		'text' =>"Rule 133.102 and 133.103",
		'x' => $mainBoxX + MAIN_BOX_WIDTH - 85 ,
		'y' => $mainBoxY - 638, 
		'fontWidth' => 7
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' =>"*Note If no additional treatment is necessary, physical therapy orders must be included in specific treatments to be performed, the frequency of",
		'x' => $mainBoxX,
		'y' => $mainBoxY - 584, 
		'fontWidth' => 8
	};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' =>"treatments: and if necessary for continued therapy past 30 days, a re-evaluation by the treating doctor.",
		'x' => $mainBoxX,
		'y' => $mainBoxY - 584 - LINE_SPACING, 
		'fontWidth' => 8
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
	$self->box13Data($p, $claim, $mainBoxX, $mainBoxY - 5 * BOX_HEIGHT, $report);

	my $box14Y= $mainBoxY - 5 * BOX_HEIGHT - BOX13_HEIGHT;
	my $box16Y= $box14Y - BOX14_HEIGHT;
	my $box17Y= $box16Y - BOX_HEIGHT;
	my $box18Y= $box17Y - BOX17_HEIGHT;
	my $box19Y= $box18Y - BOX18_HEIGHT;
	my $box20Y= $box19Y - BOX19_HEIGHT;
	my $box21Y= $box20Y - BOX20_HEIGHT;
	my $box22Y= $box21Y - BOX21_HEIGHT;
	my $box23Y= $box22Y - BOX22_HEIGHT;
	my $box24Y= $box23Y - BOX23_HEIGHT;

	$self->box14Data($p, $claim, $mainBoxX, $box14Y, $report);
	$self->box15Data($p, $claim, $mainBoxX + MAIN_BOX_WIDTH - 34,  $box14Y, $report);
	$self->box16Data($p, $claim, $mainBoxX, $box16Y, $report);
	$self->box17Data($p, $claim, $mainBoxX, $box17Y, $report);
	$self->box18Data($p, $claim, $mainBoxX, $box18Y, $report);
	$self->box19Data($p, $claim, $mainBoxX, $box19Y, $report);
	$self->box20Data($p, $claim, $mainBoxX, $box20Y, $report);
	$self->box21Data($p, $claim, $mainBoxX, $box21Y, $report);
	$self->box22Data($p, $claim, $mainBoxX, $box22Y, $report);
	$self->box23Data($p, $claim, $mainBoxX, $box23Y, $report);
	$self->box24Data($p, $claim, $mainBoxX, $box24Y, $report);

}

sub boxTopData
{

	my($self, $p, $claim, $x, $y, $report) = @_;

	my $properties =
			{
				'text' => $claim->{insured}->[$claim->getClaimType]->getPolicyGroupOrFECANo,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 30,
				'y' => $y - 6
			};
	$report->drawText($p, $properties);
	
	$properties =
			{
				'text' => $claim->getId,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 55,
				'y' => $y - 15
			};
	$report->drawText($p, $properties);

}

sub box1Data
{

	my($self, $p, $claim, $x, $y, $report) = @_;

	my $patient = $claim->{careReceiver};
	my $employeeName = $patient->getLastName . ", " . $patient->getFirstName . " " . $patient->getMiddleInitial . "."; 
		
	my $properties =
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
				'text' => $claim->{payToOrganization}->getFederalTaxId,
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
				'x' => $x + 83,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $address->getZipCode,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 120,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => substr($address->getTelephoneNo,0, 3) . "      " . substr($address->getTelephoneNo,3, 7),
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 187,
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
				'x' => $x + 210,
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

sub box13Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	for $i(0..2)
	{
		last if ($claim->{'diagnosis'}->[$i] eq "");
		$properties =
			{
				'text' => $claim->{'diagnosis'}->[$i]->getDiagnosis,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 60,
				'y' => $y - 11 - ($i * LINE_SPACING)
			};
		$report->drawText($p, $properties);
	}
}

sub box14Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	for $i(0..3)
	{
		last if ($claim->{'procedures'}->[$i] eq "");
		$properties =
			{
				'text' => $claim->{'procedures'}->[$i]->getCPT,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 40,
				'y' => $y - 21 - ($i * LINE_SPACING) 
			};
		$report->drawText($p, $properties);

		$properties =
			{
				'text' => $claim->{'procedures'}->[$i]->getModifier,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 112,
				'y' => $y - 21 - ($i * LINE_SPACING) 
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
				'x' => $x + DATA_LEFT_PADDING,
				'y' => $y - 16 - ((LINE_SPACING+1)  * $i)
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
				'x' => $x + 120,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->{treatment}->getMaximumImprovementAnticipatedDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 313,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->{treatment}->getReturnToFullTimeWorkAnticipatedDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 460,
				'y' => $y - DATA_TOP_PADDING
			};
	$report->drawText($p, $properties);
}

sub box17Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $arr1 = [12,25,38,92]; 		# reason for report check boxes
	my $arr2 = [142,244];			# activity type check boxes
	
	my $reason = $claim->{treatment}->getReasonForReport;
	my $textX = "x" if $reason > 0;
	$properties =
			{
				'text' => $textX,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 13,
				'y' => $y - $arr1->[$reason - 1]
			};
	$report->drawText($p, $properties);
	
	if ($reason == 2) 
	{
		$properties =
			{
				'text' => "x",
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + $arr2->[$claim->{treatment}->getActivityType - 1],
				'y' => $y - 25
			};
		$report->drawText($p, $properties);

		$properties =
			{
				'text' => $claim->{treatment}->getActivityDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 329,
				'y' => $y - 25
			};
		$report->drawText($p, $properties);
	}

	if ($reason == 3) 
	{
		$properties =
			{
				'text' => $claim->{changedTreatingDoctor}->getName,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 195,
				'y' => $y - 40
			};
		$report->drawText($p, $properties);
		$properties =
			{
				'text' => $claim->{changedTreatingDoctor}->{address}->getAddress1,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 195,
				'y' => $y - 40 - BOX17_SPACING
			};
		$report->drawText($p, $properties);

		$properties =
			{
				'text' => $claim->{changedTreatingDoctor}->{address}->getCity . " " . $claim->{changedTreatingDoctor}->{address}->getState . " " . $claim->{changedTreatingDoctor}->{address}->getZipCode,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 195,
				'y' => $y - 40 - 2 * BOX17_SPACING
			};
		$report->drawText($p, $properties);

		$properties =
			{
				'text' => $claim->{changedTreatingDoctor}->getProfessionalLicenseNo,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 195,
				'y' => $y - 40 - 3 * BOX17_SPACING
			};
		$report->drawText($p, $properties);

		$properties =
			{
				'text' => $claim->{treatment}->getActivityDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 431,
				'y' => $y - 50
			};
		$report->drawText($p, $properties);
	}

	if ($reason == 4) 
	{
		$properties =
			{
				'text' => $claim->{treatment}->getActivityType,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 195,
				'y' => $y - 93
			};
		$report->drawText($p, $properties);

		$properties =
			{
				'text' => $claim->{treatment}->getActivityDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 431,
				'y' => $y - 93
			};
		$report->drawText($p, $properties);
	}
}


sub box18Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $data = $claim->{treatment}->getChangeInCondition;
	$self->printMultiLine($p, $x, $y, $report, $data, 300, 3);
	
}

sub box19Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $data = $claim->{treatment}->getTreatmentPlan;
	$self->printMultiLine($p, $x, $y, $report, $data, 75, 4);
}

sub box20Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $data = $claim->{treatment}->getReferralInfo;
	$self->printMultiLine($p, $x, $y, $report, $data, 50, 1);
}

sub box21Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $data = $claim->{treatment}->getMedications;
	$self->printMultiLine($p, $x, $y, $report, $data, 156, 2);
}

sub box22Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $data = $claim->{treatment}->getPrognosis;
	$self->printMultiLine($p, $x, $y, $report, $data, 50, 1);

}

sub box23Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	my $data = $claim->{treatment}->getComplianceByEmployee;
	$self->printMultiLine($p, $x, $y, $report, $data, 222, 3);
}

sub box24Data
{
	my($self, $p, $claim, $x, $y, $report) = @_;

	$properties =
			{
				'text' => $claim->getInvoiceDate,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 440,
				'y' => $y - DATA_TOP_PADDING2
			};
	$report->drawText($p, $properties);

	$properties =
			{
				'text' => $claim->{renderingProvider}->{address}->getAddress1 . ", " . $claim->{renderingProvider}->{address}->getCity . ", " . $claim->{renderingProvider}->{address}->getState . " " . $claim->{renderingProvider}->{address}->getZipCode,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + 45,
				'y' => $y - 16
			};
	$report->drawText($p, $properties);
}

sub printMultiLine
{
	my($self, $p, $x, $y, $report, $data, $firstXPos, $numLines) = @_;

	my $first;
	my $last;	
	my $i=0;
	$rest = $data;
	
	while ($rest ne "" and $i < $numLines)
	{
		if ($i==0)
		{
			($first, $rest) = $report->textSplit($p, $rest, 500 - $firstXPos, FONT_NAME, DATA_FONT_SIZE);
			$properties =
			{
				'text' => $first,
				'fontWidth' => DATA_FONT_SIZE,
				'color' => DATA_FONT_COLOR,
				'x' => $x + $firstXPos,
				'y' => $y - DATA_TOP_PADDING2
			};
			$report->drawText($p, $properties);
		}
		else
		{
			($first, $rest) = $report->textSplit($p, $rest, 490, FONT_NAME, DATA_FONT_SIZE);
			$properties =
				{
					'text' => $first,
					'fontWidth' => DATA_FONT_SIZE,
					'color' => DATA_FONT_COLOR,
					'x' => $x + 10,
					'y' => $y - DATA_TOP_PADDING2 - 13 * $i
				};
			$report->drawText($p, $properties);
		}
		$i++;
	};

}

1;