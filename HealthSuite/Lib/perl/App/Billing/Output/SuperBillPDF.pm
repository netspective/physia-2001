package App::Billing::Output::SuperBillPDF;


use App::Billing::SuperBill::SuperBills;
use App::Billing::SuperBill::SuperBill;
use App::Billing::SuperBill::SuperBillComponent;

use App::Billing::Output::PDF::Report;
use pdflib 2.01;

use strict;

use constant HX => 30;
use constant HY => 756; # 792 - 36
use constant HEAD_HEIGHT => 46;
use constant MAIN_WIDTH => 550;
use constant ROW_HEIGHT => 9;
use constant BOX_HEIGHT => 22;
use constant BOX1_WIDTH => 295;
use constant BOX7_WIDTH => 50;
use constant BOX11_WIDTH => 205;
use constant LINE_SPACING => 9;
use constant TALL_BOX_HEIGHT => 32;
use constant BOX6_HEIGHT => 60;
use constant BOX10_HEIGHT => BOX6_HEIGHT + BOX_HEIGHT ;
use constant BOX9_HEIGHT => 34;
use constant BOX13_HEIGHT => 18;
use constant BOX14_HEIGHT => BOX10_HEIGHT - BOX13_HEIGHT;
use constant LEFT_LINE => 1;
use constant RIGHT_LINE => 1;
use constant TOP_LINE => 1;
use constant BOTTOM_LINE => 1;
use constant NO_LEFT_LINE => 0;
use constant NO_RIGHT_LINE => 0;
use constant NO_TOP_LINE => 0;
use constant NO_BOTTOM_LINE => 0;
use constant FONT_NAME => 'Helvetica';
use constant BOLD_FONT_NAME => FONT_NAME . '-Bold';
use constant SPC => " ";
use constant DATA_LEFT_PADDING => 3;
use constant DATA_TOP_PADDING => 10;
use constant DATA_TOP_PADDING2 => 4;
use constant DATA_FONT_COLOR => '0,0,0';
use constant REPORT_COLOR => '0,0,0';
use constant REPORT_FILL_COLOR => '0.9,0.9,0.9';
use constant DATA_FONT_SIZE => 7;
use constant THRESHOLD => 4;

sub new
{
	my ($type) = shift;
	my $self = {};
	return bless $self, $type;
}

sub printReport
{
	my ($self, $superBills, %params) = @_;

	my $filename = $params{file} ne "" ? $params{file} : "SuperBill.pdf";
	my $columns = $params{columns} ne "" ? $params{columns} : 4;
	my $rows = $params{rows} ne "" ? $params{rows} : 51;
	my $startX = $params{startX} ne "" ? HX + $params{startX} : HX;
	my $startY = $params{startY} ne "" ? HY - $params{startY} : HY;
	my $reportColor = $params{reportColor} ne "" ? $params{reportColor} : REPORT_COLOR;

	$columns = 4 if($columns > 4);
	$rows = 55 if($rows > 55);

	my $p = pdflib::PDF_new();
	die "Couldn't open PDF file"  if (pdflib::PDF_open_file($p, $filename) == -1);
	my $report = new App::Billing::Output::PDF::Report(color => $reportColor);

	my $allSuperBills = $superBills->getSuperBill();

	for my $i (0 .. $#$allSuperBills) # it depends on the number of patients
	{

		my $superBill = $allSuperBills->[$i];

		$report->newPage($p);

		pdflib::PDF_setlinewidth($p, 0.7);
		$self->printHeader($p, $startX, $startY, $report, $superBill);

		my $x = $startX;
		my $y = $startY - HEAD_HEIGHT;
		my ($rowNo, $columnNo);

		my $columnWidth = MAIN_WIDTH / $columns;
		my $column1Width = 0.18 * $columnWidth;
		my $column2Width = 0.10 * $columnWidth;
		my $column3Width = 0.45 * $columnWidth;
		my $column4Width = 0.27 * $columnWidth;

		$self->printHeading($p, $x, $y, $report, [$column1Width, $column2Width, $column3Width, $column4Width], ["CPT","","DESCRIPTION","FEE"], $columns - 1, $columnWidth);

		for my $i (0..$#{$superBill->{superBillComponents}})
		{
			my $heading = $superBill->{superBillComponents}->[$i]->{header};
			if (($rows - $rowNo) <= THRESHOLD)
			{
				while ($rowNo < $rows)
				{
					$rowNo++;
					$self->printRow($p, $x + $columnNo * $columnWidth, $y - $rowNo * ROW_HEIGHT, $report, [$column1Width, $column2Width, $column3Width, $column4Width], ['']);
				}
				$columnNo++;$rowNo=0;
				last if($columnNo >= $columns);
			}

			$rowNo++;
			$self->printRowMain($p, $x + $columnNo * $columnWidth, $y - $rowNo * ROW_HEIGHT, $report, [$columnWidth], $heading);

			for my $j (0..$superBill->{superBillComponents}->[$i]->getCount - 1)
			{
				$rowNo++;
				$self->printRow($p, $x + $columnNo * $columnWidth, $y - $rowNo * ROW_HEIGHT, $report, [$column1Width, $column2Width, $column3Width, $column4Width],
						[$superBill->{superBillComponents}->[$i]->getCpt($j),"",$superBill->{superBillComponents}->[$i]->getDescription($j),""]);

				if ($rowNo == $rows)
				{
					$columnNo++;$rowNo=1;
					last if($columnNo >= $columns);

					my $contHeading = $heading . " (contd.)";
					$self->printRowMain($p, $x + $columnNo * $columnWidth, $y - $rowNo * ROW_HEIGHT, $report, [$columnWidth], $contHeading);
				}
			}
			last if($columnNo >= $columns);

			#blank row after each component
			$rowNo++;
			$self->printRow($p, $x + $columnNo * $columnWidth, $y - $rowNo * ROW_HEIGHT, $report, [$column1Width, $column2Width, $column3Width, $column4Width], ['']);
			if ($rowNo == $rows)
			{
				$columnNo++;$rowNo=0;
				last if($columnNo >= $columns);
			}


		}

		#print remaining blank rows
		while($columnNo <= $columns -1 || $rowNo == $rows)
		{
			$rowNo++;
			$self->printRow($p, $x + $columnNo * $columnWidth, $y - $rowNo * ROW_HEIGHT, $report, [$column1Width, $column2Width, $column3Width, $column4Width], ['']);
			if ($rowNo == $rows){$columnNo++;$rowNo=0;}
		}

		pdflib::PDF_setlinewidth($p, 0.9);

		$x = $startX;
		$y = $startY - HEAD_HEIGHT - $rows * ROW_HEIGHT - 20;
		$self->box1f($p, $x, $y, $report, $superBill);
		$self->box2f($p, $x, $y - TALL_BOX_HEIGHT, $report, $superBill);
		$self->box3f($p, $x, $y - TALL_BOX_HEIGHT - BOX_HEIGHT, $report, $superBill);
		$self->box4f($p, $x, $y - TALL_BOX_HEIGHT - 2 * BOX_HEIGHT, $report, $superBill);
		$self->box5f($p, $x, $y - TALL_BOX_HEIGHT - 3 * BOX_HEIGHT, $report, $superBill);
		$self->box6f($p, $x, $y - TALL_BOX_HEIGHT - 4 * BOX_HEIGHT, $report, $superBill);
		$self->box7f($p, $x + BOX1_WIDTH, $y, $report, $superBill);
		$self->box8f($p, $x + BOX1_WIDTH, $y - TALL_BOX_HEIGHT, $report, $superBill);
		$self->box9f($p, $x + BOX1_WIDTH, $y - 2 * TALL_BOX_HEIGHT, $report, $superBill);
		$self->box10f($p, $x + BOX1_WIDTH, $y - 2 * TALL_BOX_HEIGHT - BOX9_HEIGHT, $report, $superBill);
		$self->box11f($p, $x + BOX1_WIDTH + BOX7_WIDTH, $y, $report, $superBill);
		$self->box12f($p, $x + BOX1_WIDTH + BOX7_WIDTH, $y  - 2 * TALL_BOX_HEIGHT, $report, $superBill);
		$self->box13f($p, $x + BOX1_WIDTH + BOX7_WIDTH, $y  - 2 * TALL_BOX_HEIGHT - BOX9_HEIGHT, $report, $superBill);
		$self->box14f($p, $x + BOX1_WIDTH + BOX7_WIDTH, $y  - 2 * TALL_BOX_HEIGHT - BOX9_HEIGHT - BOX13_HEIGHT, $report, $superBill);

		$report->endPage($p);
	}

	pdflib::PDF_close($p);
	pdflib::PDF_delete($p);

}

sub box1f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' => "DATE" . SPC x 20 . "TIME"  . SPC x 8 . "PATIENT"  . SPC x 80 .  "REASON",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				]
			};
	$report->drawBox($p, $x, $y, BOX1_WIDTH, TALL_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	$self->boxData($p, $x, $y, $report, $superBill->getDate, 0, 10);
	$self->boxData($p, $x, $y, $report, $superBill->getTime, 45, 10);
	$self->boxData($p, $x, $y, $report, $superBill->{patient}->getName, 76, 10);

}

sub box2f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' => "  CKET" . SPC x 15 . "DR.#"  . SPC x 8 . "DOCTOR" . SPC x 15 . "LOCATION"  . SPC x 60 . "DOB"  ,
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX1_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
#	$self->boxData($p, $x, $y, $report, $superBill->{doctor}->getId, 45, 10);
	$self->boxData($p, $x, $y, $report, $superBill->{doctor}->getName, 45, 10);
	$self->boxData($p, $x, $y, $report, $superBill->{location}->getName, 120, 10);
	$self->boxData($p, $x, $y, $report, $superBill->{patient}->getDateOfBirth(1), 250, 10);

}

sub box3f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' => "PATIENT NO." . SPC x 5 . "RESPONSIBLE PARTY"  . SPC x 30 . "PH#" . SPC x 30 . "REFERRING DR.",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX1_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	$self->boxData($p, $x, $y, $report, $superBill->{patient}->getId, 2, 10);
	$self->boxData($p, $x, $y, $report, $superBill->{patient}->{address}->getTelephoneNo(1), 160, 10);

}

sub box4f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' => "M" . SPC x 5 . "F"  . SPC x 8 . "ADDRESS" . SPC x 40 . "CITY/STATE" . SPC x 40 . "ZIPCODE",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX1_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	my $xpos = ($superBill->{patient}->getSex eq 'M') ? 0 : 12 ;
	$self->boxData($p, $x, $y, $report, "X", $xpos, 12);

	$self->boxData($p, $x, $y, $report, $superBill->{patient}->{address}->getAddress1, 30, 10);
	$self->boxData($p, $x, $y, $report, $superBill->{patient}->{address}->getCity, 150, 10);
	$self->boxData($p, $x, $y, $report, $superBill->{patient}->{address}->getState, 180, 10);
	$self->boxData($p, $x, $y, $report, $superBill->{patient}->{address}->getZipCode, 260, 10);

}

sub box5f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>  SPC x 8 . "OVER 90" . SPC x 8 . "OVER 60" . SPC x 8 . "OVER 30" . SPC x 7 . "CURRENT" . SPC x 6 . "TOTAL DUE   PT   BC  CS  PAY CHOICE",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX1_WIDTH, BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box6f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>  "INSURANCE COMPANY" . SPC x 15 . "BA   SCT  POLICY I.D." . SPC x 45 . "RELATIONSHIP",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX1_WIDTH, BOX6_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
#	$self->boxData($p, $x, $y, $report, $superBill->{insurance}->getName, 0, 10);
}

sub box7f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>  "PRIOR BALANCE",
						'fontWidth' => 5,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX7_WIDTH, TALL_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box8f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>  "TODAY'S CHARGE",
						'fontWidth' => 5,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX7_WIDTH, TALL_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box9f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>  "ADJUSTMENTS",
						'fontWidth' => 5,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX7_WIDTH, BOX9_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box10f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
	{
		'width' =>  BOX7_WIDTH,
		'height' => 15,
		'x' => $x,
		'y' => $y - 30,
	};
	$report->drawFilledRectangle($p, $properties);

	$properties =
			{
			texts =>
				[
					{
						'text' =>  "TODAY's PAYMENT",
						'fontWidth' => 5,
						'x' => $x,
						'y' => $y
					},
					{
						'text' =>  "BALANCE",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 7,
						'x' => $x + 8,
						'y' => $y - 30,
						'color' => '1,1,1'
					},
					{
						'text' =>  "DUE",
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 7,
						'x' => $x + 15,
						'y' => $y - 37,
						'color' => '1,1,1'
					},
				],
			};
	$report->drawBox($p, $x, $y, BOX7_WIDTH, BOX10_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub box11f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>  "DIAGNOSIS:",
						'fontWidth' => 6,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX11_WIDTH, 2 * TALL_BOX_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = 	[
					"1. _______________________________________________",
					"2. _______________________________________________",
					"3. _______________________________________________",
					"4. _______________________________________________",
				];

	for my $i(0..3)
	{
		my $properties =
		{
			'text' =>$arr->[$i],
			'x' => $x,
			'y' => $y - $i * 13 - 13,
			'fontWidth' => 7
		};
		$report->drawText($p, $properties);
	}
}

sub box12f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>  "IF OTHER, PLEASE EXPLAIN",
						'fontWidth' => 7,
						'x' => $x + 50,
						'y' => $y - 17
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX11_WIDTH, BOX9_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = ["CASH", "CHECK", "VISA", "MASTER CARD", "OTHER" ];
	my $arrX = [5,44,88,132,5];
	my $arrY = [5,5,5,5,17];

	for my $i(0..4)
	{
		my $properties =
		{
			'text' =>$arr->[$i],
			'x' => $x + $arrX->[$i] + 8,
			'y' => $y - $arrY->[$i],
			'fontWidth' => 7
		};
		$report->drawText($p, $properties);

		$properties =
		{
			'height' => 8,
			'width' => 8,
			'x' => $x + $arrX->[$i],
			'y' => $y - $arrY->[$i] - 8,
		};
		$report->drawCheckBox($p, $properties);
	}

}

sub box13f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
			{
			texts =>
				[
					{
						'text' =>  "",
						'fontWidth' => 7,
						'x' => $x,
						'y' => $y
					}
				],
			};
	$report->drawBox($p, $x, $y, BOX11_WIDTH, BOX13_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = ["Patient to file insurance", "Clinic to file insurance" ];
	my $arrX = [5,112];
	my $arrY = [5,5];

	for my $i(0..1)
	{
		my $properties =
		{
			'text' =>$arr->[$i],
			'x' => $x + $arrX->[$i] + 8,
			'y' => $y - $arrY->[$i],
			'fontWidth' => 7
		};
		$report->drawText($p, $properties);

		$properties =
		{
			'height' => 8,
			'width' => 8,
			'x' => $x  + $arrX->[$i],
			'y' => $y - $arrY->[$i] - 8,
		};
		$report->drawCheckBox($p, $properties);
	}

}

sub box14f
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
	{
		texts =>
			[
				{
					'text' =>  "Patient Signature",
					'fontWidth' => 6,
					'x' => $x + 75,
					'y' => $y - 55
				}
			],
		lines =>
			[
				{
					'x1' => $x + 4,
					'y1' => $y - 55,
					'x2' => $x + BOX11_WIDTH - 4,
					'y2' => $y - 55
				}
			]
	};
	$report->drawBox($p, $x, $y, BOX11_WIDTH, BOX14_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);

	my $arr = 	[
					"I hereby authorize my insurance benefits to be paid direct",
					"to the above signed physician, realizing I am responsible to",
					"pay non-covered services and I hereby authorize the release",
					"of pertinent medical information to insurance carriers."
				];
	for my $i(0..3)
	{
		my $properties =
		{
			'text' =>$arr->[$i],
			'x' => $x,
			'y' => $y - $i * 9,
			'fontWidth' => 7.5
		};
		$report->drawText($p, $properties);
	}

}

sub printHeader
{
	my($self, $p, $x, $y, $report, $superBill) = @_;

	my $properties =
	{
		'text' => $superBill->{orgName},
		'fontWidth' => 11,
		'x' => $x + 200,
		'y' => $y
	};
	$report->drawText($p, $properties);

	$properties =
		{
			'text' => $superBill->{taxId},
			'fontWidth' => 11,
			'x' => $x + 250,
			'y' => $y - 15
		};
	$report->drawText($p, $properties);

	$properties =
	{
		'text' => "CKIN | EXAM | CK OUT | LAB IN | LAB OUT",
		'x' => $x + 20,
		'y' => $y - 20,
		'fontWidth' => 8
	};
	$report->drawText($p, $properties);

	my $arrX = [20,49,80,115,147];

	for my $i(0..4)
	{

		$properties =
		{
			'height' => 10,
			'width' => 22,
			'x' => $x + $arrX->[$i],
			'y' => $y - 40,
		};
		$report->drawCheckBox($p, $properties);
	}
}

sub printHeading
{
	my($self, $p, $x, $y, $report, $columnWidths, $data, $noOfColumns, $columnWidth) = @_;

	for my $h(0..$noOfColumns)
	{
		my $xpos;
		for my $i(0..3)
		{
			$xpos += $columnWidths->[$i-1] if ($i != 0);
			my $properties =
			{
				texts =>
				[
					{
						'text' =>  $data->[$i],
						'fontWidth' => 6,
						'x' => $x + $xpos + $h * $columnWidth,
						'y' => $y
					}
				],
			};
			$report->drawBox($p, $x + $xpos + $h * $columnWidth, $y, $columnWidths->[$i], ROW_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
		}
	}
}

sub printRowMain
{
	my($self, $p, $x, $y, $report, $columnWidths, $data) = @_;

	my $length = pdflib::PDF_stringwidth($p, $data, BOLD_FONT_NAME, 7);

	my $properties =
	{
		'width' =>  $columnWidths->[0],
		'height' => ROW_HEIGHT,
		'x' => $x,
		'y' => $y,
		'fillColor' => REPORT_FILL_COLOR,
	};
	$report->drawFilledRectangle($p, $properties);

	$properties =
			{
			texts =>
				[
					{
						'text' =>  $data,
						'fontName' => BOLD_FONT_NAME,
						'fontWidth' => 7,
						'x' => $x + $columnWidths->[0]/2 - $length/2 ,
						'y' => $y,
					}
				],
			};

	$report->drawBox($p, $x, $y, $columnWidths->[0], ROW_HEIGHT, LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
}

sub printRow
{
	my($self, $p, $x, $y, $report, $columnWidths, $data) = @_;
	my $xpos;
	for my $i(0..3)
	{
		$xpos += $columnWidths->[$i-1] if ($i != 0);
		my $properties =
		{
			texts =>
			[
				{
					'text' =>  $data->[$i],
					'fontWidth' => 5,
					'x' => $x + $xpos,
					'y' => $y
				}
			],
		};
		$report->drawBox($p, $x + $xpos, $y, $columnWidths->[$i], ROW_HEIGHT,LEFT_LINE, RIGHT_LINE, TOP_LINE, BOTTOM_LINE, $properties);
	}
}

sub boxData
{
	my($self, $p, $x, $y, $report, $data, $xPadding, $yPadding) = @_;

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