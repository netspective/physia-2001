##############################################################################
package Data::TextPublish;
##############################################################################

use strict;
use Exporter;
use Number::Format;
use CGI::Layout;
use Data::Reporter;
use Data::Reporter::RepFormat;
use Data::Reporter::Arraysource;
use App::Configuration;
use Storable qw(dclone);

use vars qw(@ISA @EXPORT);

@ISA    = qw(Exporter);
@EXPORT = qw(
	createTextFromData
	createTextRowsFromData
);

use constant FORMATTER => new Number::Format(INT_CURR_SYMBOL => '$');

# This sub is used to place fields in arbitrary locations in a monospaced grid of specified size.
# Its functionality is still considerably limited.
# $publishDefn has the same structure as $publDefn in prepare_HtmlBlockFmtTemplate with columnDefn
# replaced by fieldDefn.  The structure of fieldDefn is given below...
#
#	fieldDefn => [
#		{ col => '10', row => '10', width => '15', colIdx => '1', align => 'RIGHT' },
#		{ col => '15', row => '11', width => '10', colIdx => '2', align => 'CENTER' },
#		{ col => '30', row => '10', width => '5', colIdx => '3', align => 'LEFT' },
#		{ col => '30', row => '11', width => '10', colIdx => '4', align => 'RIGHT' }
#	],
#
# The four arguments that it accepts are:
#   $maxCols, $maxRows
#	a string in "x,y" form which specifies the maximum number of columns and rows available to
#	lay fields out in
#   $publDefn
#   $mtbDebug
#	a number which, when nonzero, causes all debug information to be suppressed.  Otherwise, it
#	spits out some stuff to STDOUT.  Used mainly when testing this function with a standalone
#	driver stub

# This is just a stub...
sub createTextFromStatement {
	return createTextFromData (@_);
}

sub createTextFromData {
	my ($page, $flags, $data, $publDefn, $publParams) = @_;

	my $mtbDebug = lc($publDefn->{mtbDebug}) || "";
	my ($maxCols, $maxRows) = ($publDefn->{maxCols} || 80, $publDefn->{maxRows} || 66);

	my ($rowIndex, $colIndex) = (0, 0);
	my $format;
	my $output;
	
	my $fillerChar = ($mtbDebug eq 'full' ? "x" : ($mtbDebug eq 'less' ? "." : " "));
	my $fillerLine = ($mtbDebug eq 'full' ? "X\n" : ($mtbDebug eq 'less' ? ".\n" : "\n"));

	# Reformat incoming arguments for optimized processing...
	my @fieldDefn =  @{$publDefn->{fieldDefn}};
	my %newFieldDefn;
	my %startIndex;

	foreach my $thisFieldDefn (@fieldDefn) {
		$newFieldDefn{$thisFieldDefn->{row}}{$thisFieldDefn->{col}} = {
			width => $thisFieldDefn->{width},
			colIdx => $thisFieldDefn->{colIdx},
			align => $thisFieldDefn->{align} || 'LEFT',
			type => lc($thisFieldDefn->{type}) || 'simple',
			data => $thisFieldDefn->{data} || "",
#			startIdx => 0,
		};
	
		$startIndex{$thisFieldDefn->{row}}{$thisFieldDefn->{col}} = 0;
	}

	# Process all data items one by one...
	my $dataIndex = 0;
	foreach my $dataItem (@{$data}) {
		($rowIndex, $colIndex) = (1, 1);
		# Process all non-empty rows...
		foreach my $currentRow (sort {$a <=> $b} keys %newFieldDefn) {
			$output .= "RowIndex: $rowIndex... Current Row: $currentRow..." if ($mtbDebug eq 'full');
			$output .= "(padding with ".($currentRow - $rowIndex)." rows...\n" if ($mtbDebug eq 'full');
			# If the rowIndex hasnt caught up to the next non-empty row due to intervening blank
			# lines, help it along...
			if ($rowIndex != $currentRow) {
				$output .= $fillerLine x ($currentRow - $rowIndex);
				$rowIndex = $currentRow;
			}

			# These variables need to be reinitialized to process each row...
			$colIndex = 1;
			my @theFields = ();
			$format = "";
			foreach my $currentCol (sort {$a <=> $b} keys %{$newFieldDefn{$currentRow}}) {
				$output .= "ColIndex: $colIndex... Current Col: $currentCol..." if ($mtbDebug eq 'full');
				$output .= "(padding with ".($currentCol - $colIndex)." cols...\n" if ($mtbDebug eq 'full');
				# If the colIndex hasnt caught up to the next non-empty column due to intervening blank
				# columns, help it along...
				$format .= $fillerChar x ($currentCol - $colIndex);
				$colIndex = $currentCol;
				
				# Fetch current field as a hash...
				my $currentField = $newFieldDefn {$currentRow}{$currentCol};
#				$output .= "newFieldDefn ref = ".ref ($newFieldDefn {$currentRow}{$currentCol})."\n";
#				$output .= "currentField ref = ".ref ($currentField)."\n";

				my $formatChar;
#				my $formatTestChar = uc($newFieldDefn{$currentRow}{$currentCol}{align});
				my $formatTestChar = uc($currentField->{align});
			
				if ($formatTestChar eq 'LEFT') {
					$formatChar = '<';
				} elsif ($formatTestChar eq 'RIGHT') {
					$formatChar = '>';
				} else {
					$formatChar = '|';
				}
		
				$output .= "Format Char: $formatChar ($formatTestChar)\n" if ($mtbDebug eq 'full');
				# Prepare the format string...
				my $formatLength = $currentField->{width} - 1;
#				$format .= '@'.($formatChar x $formatLength);
				$format .= '^'.($formatChar x $formatLength);

				# Check for a conditional element...
				if ($currentField->{type} eq 'conditional') {
					push @theFields, $currentField->{data}->{$dataItem->[$currentField->{colIdx}]};
				} else {
					push @theFields, $dataItem->[$currentField->{colIdx}];
#					if ($currentField->{startIdx} < length $dataItem->[$currentField->{colIdx}]) {
#						my $theField = $currentField->{startIdx} . '*' . length $dataItem->[$currentField->{colIdx}];
#						push @theFields, $currentField->{startIdx} . " " . substr ($dataItem->[$currentField->{colIdx}], $currentField->{startIdx});
#						$currentField->{startIdx} += $formatLength;
#						$theField .= '*'.$currentField->{startIdx};
#						push @theFields, $theField;
#						$newFieldDefn {$currentRow}{$currentCol} = $currentField;
						
#						substr ($dataItem->[$currentField->{colIdx}], 0, $formatLength = "";
#					} else {
#						push @theFields, "";
#					}
				}
	
				# Update column index...
				$colIndex = $colIndex + $formatLength;
			}

			$output .= "ColIndex: $colIndex... Current Col: $maxCols..." if ($mtbDebug eq 'full');
			$output .= "(padding with ".($maxCols - $colIndex)." cols...\n" if ($mtbDebug eq 'full');
			$format .= $fillerChar x ($maxCols - $colIndex);
			$format .= "\n";

			$output .= "---Printing format---\n" if ($mtbDebug eq 'full');
			$output .= $format if ($mtbDebug eq 'full');
			$output .= "---End  of  format---\n" if ($mtbDebug eq 'full');

			formline $format, @theFields;
			$output .= $^A;
			$^A = "";
			$rowIndex ++;
		}
		$output .= "RowIndex: $rowIndex... Current Row: $maxRows..." if ($mtbDebug eq 'full');
		$output .= "(padding with ".($maxRows - $rowIndex)." rows...\n" if ($mtbDebug eq 'full');
		$output .= $fillerLine x ($maxRows - $rowIndex + 1);
		$rowIndex = $maxRows;
		$dataIndex ++;
	}
	
	$output .= $fillerLine x ($maxRows - $rowIndex + 1);
	$rowIndex = $maxRows;
	
#	print $output if ($mtbDebug);
	return $output;
}


# This sub is used to place fields in arbitrary locations in a monospaced grid of specified size.
# Its functionality is still considerably limited.
# $publishDefn has the same structure as $publDefn in prepare_HtmlBlockFmtTemplate with columnDefn
# replaced by fieldDefn.  The structure of fieldDefn is given below...
#
#	fieldDefn => [
#		{ col => '10', width => '15', colIdx => '1', align => 'RIGHT' },
#		{ col => '15', width => '10', colIdx => '2', align => 'CENTER' },
#		{ width => '5', colIdx => '3', align => 'LEFT' },
#		{ col => '30', width => '10', colIdx => '4', align => 'RIGHT' }
#	],
#
#	header => [
#		'This is a sample header line 1',
#		'This is line 2',
#		'This is line three',
#	]
#
#	footer => [
#		'This is a sample footer line 1',
#		'This is line 2',
#		'This is line three',
#	]
#
# The four arguments that it accepts are:
#   $maxCols, $maxRows
#	a string in "x,y" form which specifies the maximum number of columns and rows available to
#	lay fields out in
#   $publDefn
#   $mtbDebug
#	a number which, when nonzero, causes all debug information to be suppressed.  Otherwise, it
#	spits out some stuff to STDOUT.  Used mainly when testing this function with a standalone
#	driver stub

my @columnTotals = ();
my @totalRows = ();
my @columnSubTotals = ();
my @subTotalRows = ();
my @groupColumnValues = ();
my $numRowsInGroup = 0;
my $logSpaces = 0;

sub createTextRowsFromStatement {
	my ($page, $flags, $stmtHdl, $publDefn, $publParams) = @_;

#	my ($page, $flags, $data, $publDefn, $publParams) = @_;

	my ($theData, $textOutput);
#	$theData = $STMTMGR_REPORT_ACCOUNTING->getRowsAsArray($page, STMTMGRFLAG_NONE, $stmtHdl, @{$publParams});
#	$textOutput = createTextRowsFromData($page, STMTMGRFLAG_NONE, $theData, $STMTMGR_REPORT_ACCOUNTING->{"_dpd_sel_patient_superbill_info"});
}

sub createTextRowsFromData {
	my ($page, $flags, $data, $publDefn, $publParams) = @_;

	my $mtbDebug = lc($publDefn->{mtbDebug}) || "";
	$mtbDebug = 'full';
	my ($maxCols, $maxRows) = ($publDefn->{maxCols} || 132, $publDefn->{maxRows} || 60);
	my @header = (defined $publDefn->{header}) ? @{$publDefn->{header}} : ();
	my @footer = @header;

	my ($rowIndex, $colIndex) = (0, 0);
	my $tempDir = $CONFDATA_SERVER->path_temp();
	my $theFilename = "/" . $page->session ('org_id') . (rand time()) . $page->session ('user_id') . (rand time() + 1) . ".txt";
	while (-e $tempDir.$theFilename) {
		$theFilename = "/" . $page->session ('org_id') . (rand time()) . $page->session ('user_id') . (rand time() + 1) . ".txt";
	}

	# Reformat incoming arguments for optimized processing...
	my @fieldDefn =  @{$publDefn->{columnDefn}};
	my $reportTitle = (defined $publDefn->{reportTitle} ? $publDefn->{reportTitle} : undef);

	# Initialize report variables...
	@columnTotals = ();
	@totalRows = ();
	@columnSubTotals = ();
	@subTotalRows = ();
	@groupColumnValues = ();
	$numRowsInGroup = 0;
	$logSpaces = 0;


	# Massage the public definition to appear the way we want it to.
	my ($newFieldDefn, $origFieldOrder) = massageFieldDefn (\@fieldDefn);
	my ($rowFormat, $headingOrder, $fieldOrder) = generateFormat ($newFieldDefn, $origFieldOrder, $maxCols);
	my ($groupCols, $sumCols) = getReportOrganization ($newFieldDefn, $origFieldOrder);
	my $detailCallback = generateDetailCallback ($rowFormat, $origFieldOrder, $newFieldDefn, $groupCols, $sumCols);
	my $breaksCallback = generateBreaksCallback ($rowFormat, $origFieldOrder, $newFieldDefn, $groupCols, $sumCols);
	my $finalCallback = generateFinalCallback ($rowFormat, $origFieldOrder, $newFieldDefn, $groupCols, $sumCols);
	my $headerCallback = generateHeaderCallback (\@header, $rowFormat, $headingOrder, $reportTitle);
	my $footerCallback = generateFooterCallback (\@footer, $rowFormat, $headingOrder);
	my $titleCallback = generateTitleCallback ();

	my $source = new Data::Reporter::Arraysource(Array => $data);
	my $report = new Data::Reporter();
	$report->configure(
		Width		=> $maxCols,
		Height		=> $maxRows,
#		Footer_size 	=> 2,
		SubFinal 	=> $finalCallback,
		Breaks		=> $breaksCallback,
		SubHeader	=> $headerCallback,
#		SubFooter	=> $footerCallback,
		SubTitle	=> $titleCallback,
		SubDetail	=> $detailCallback,
		Source		=> $source,
		File_name	=> $tempDir.$theFilename
	);
	$report->generate();
	
	return $theFilename;
}



sub massageFieldDefn {
	my ($fieldDefn) = @_;
	my %newFieldDefn;
	my @originalFieldOrder;
	
	my $tempDir = $CONFDATA_SERVER->path_temp();
	my $theFilename .= "/publish.debug.log";
	
#	open (LOGFILE, ">>$tempDir$theFilename");
#	print LOGFILE "sub getReportOrganization\n";
	$logSpaces += 2;
	my $logPrepend = (scalar localtime)." " x $logSpaces;

	# Go ahead and massage the data to appear the way we want it to
	my $colCount = 0;
	foreach my $thisFieldDefn (@{$fieldDefn}) {
		$logSpaces += 2;
		$logPrepend = (scalar localtime)." " x $logSpaces;
		# If this field doesnt have a column field, set it to a sane value
		# Obtained by adding the widths of all the fields before this one.
#		my $tempCol = $thisFieldDefn->{col} || $colCount;
#		print LOGFILE $logPrepend."tempCol: $tempCol\n";

		my $thisHashOutput = "{";
		while (my ($key, $value) = each %{$thisFieldDefn}) {
			$thisHashOutput .= "$key=$value|";
		}
		chop $thisHashOutput;
		$thisHashOutput .= "}\n";
		
#		print LOGFILE $logPrepend."thisHash => ".$thisHashOutput;

		# Set other sane default values...
		my $tempDataType = ($thisFieldDefn->{dformat} ? lc($thisFieldDefn->{dformat}) : 'raw' );
		my $tempSummarize = ($thisFieldDefn->{summarize} ? lc($thisFieldDefn->{summarize}) : 'none' );
		my $tempGroupBy = ($thisFieldDefn->{groupBy} ? lc($thisFieldDefn->{groupBy}) : 'none' );
		my $tempAlign = uc($thisFieldDefn->{dAlign}) || 'LEFT';
		$tempAlign = 'RIGHT' if ((defined $thisFieldDefn->{summarize}) or ($tempDataType ne 'raw'));
		my $tempType = lc($thisFieldDefn->{type}) || 'simple';
		my $tempData = $thisFieldDefn->{data} || "";
		my $tempDataFmt = (defined $thisFieldDefn->{dataFmt}) ? $thisFieldDefn->{dataFmt} : '#'.((defined $thisFieldDefn->{colIdx}) ? $thisFieldDefn->{colIdx} : $colCount).'#';
		
		unless ($tempDataType eq 'raw' and $tempSummarize eq 'none') {
			$tempDataFmt = '#'.((defined $thisFieldDefn->{colIdx}) ? $thisFieldDefn->{colIdx} : $colCount).'#';
		}
		
		if ($tempDataFmt =~ /<a\s+href\s*=.*?>(.*?)<\s*\/a>/i) {
			$tempDataFmt = $1;
		}

		# Calculate the number of fields in the dataFmt
		my $dataFmt = $tempDataFmt;
		my $numFields = 0;
		while ($dataFmt =~ /#[0-9]+?#/) {
			$numFields ++;
			$dataFmt = $';
		}

		# Default width = 10.  *shrug*
		my $tempWidth = $thisFieldDefn->{width} || (10 * $numFields);
		my $tempHead = $thisFieldDefn->{head} || " " x $tempWidth;
		my $tempCol = (defined $thisFieldDefn->{colIdx}) ? $thisFieldDefn->{colIdx} : $colCount;
		
		$newFieldDefn{$tempCol} = {
			width => $tempWidth,
			colIdx => $thisFieldDefn->{colIdx},
			dataFmt => $tempDataFmt,
			align => $tempAlign,
			type => $tempType,
			data => $tempData,
			head => $tempHead,
			groupBy => $tempGroupBy,
			summarize => $tempSummarize,
			dataType => $tempDataType,
		};
		push @originalFieldOrder, $tempCol;

		my $massagedHashOutput = "{";
		while (my ($key, $value) = each %{$newFieldDefn{$tempCol}}) {
			$massagedHashOutput .= "$key=$value|";
		}
		chop $massagedHashOutput;
		$massagedHashOutput .= "}\n";
		
#		print LOGFILE $logPrepend."$tempCol => ".$massagedHashOutput;
		
		$colCount ++;
		$logSpaces -= 2;
	}
	
	$logSpaces -= 2;
	return (\%newFieldDefn, \@originalFieldOrder);
}

sub generateFormat {
	my ($fieldDefn, $originalFieldOrder, $maxCols) = @_;
	
	my $rowFormat;
	my $fmtColIndex = 1;
	my @fieldOrder;
	my @headingOrder;
	# Generate a format for each row...
#	foreach my $field (sort {$a <=> $b} keys %{$fieldDefn}) {	
	foreach my $field (@{$originalFieldOrder}) {
		# If the current column Index is less than the field indicates,
		# i.e. either the first field in the row does NOT start at 1 or
		# there is a >1 space gap between two fields,
		# then go ahead and add the appropriate number of spaces...
#		$rowFormat .= (' ' x ($field - $fmtColIndex)) if ($fmtColIndex < $field);
		$rowFormat .= '@';
		$fmtColIndex += $field - $fmtColIndex + 1;
		
		my $formatChar;
		if ($fieldDefn->{$field}->{align} eq 'LEFT') {
			$formatChar = '<';
		} elsif ($fieldDefn->{$field}->{align} eq 'RIGHT') {
			$formatChar = '>';
		} else {
			$formatChar = '|';
		}
		
		$rowFormat .= ($formatChar x ($fieldDefn->{$field}->{width} - 1));
		$rowFormat .= " ";
		$fmtColIndex += $fieldDefn->{$field}->{width} - 1;
		
		# Push the colIndex that this field refers to onto the fieldOrder array...
		push @fieldOrder, $fieldDefn->{$field}->{dataFmt};
		# Push the heading of this column on the headingOrder array...
		push @headingOrder, $fieldDefn->{$field}->{head};
	}
	$rowFormat .= ' ' x ($maxCols - length ($rowFormat));
	
	return ($rowFormat, \@headingOrder, \@fieldOrder);
}

sub getReportOrganization {
	my ($newFieldDefn, $fieldOrder) = @_;
	
	my @groupCols = ();
	my @sumCols = ();
	
	my $tempDir = $CONFDATA_SERVER->path_temp();
	my $theFilename .= "/publish.debug.log";
	
#	open (LOGFILE, ">>$tempDir$theFilename");
#	print LOGFILE "sub getReportOrganization\n";
	$logSpaces += 2;
	my $logPrepend = (scalar localtime)." " x $logSpaces;

#	foreach my $field (sort {$a <=> $b} keys %{$newFieldDefn}) {
	foreach my $field (@{$fieldOrder}) {
		my $theField = \%{$newFieldDefn->{$field}};
		if (defined $theField->{groupBy}) {
			if ($theField->{groupBy} =~ /#([0-9]+)#/) {
				my $groupByCol = $1;
				push @groupCols, $groupByCol;
#				print LOGFILE $logPrepend."groupBy: $groupByCol [".$theField->{groupBy}."]\n";
			}
		}
		
		if (defined $theField->{summarize}) {
			if (lc($theField->{summarize}) eq "sum") {
				my $sumCol = $theField->{dataFmt};
				if ($sumCol =~ /#([0-9]+)#/) {
					$sumCol = $1;
				}
				push @sumCols, $sumCol;
#				print LOGFILE $logPrepend."summarize: $sumCol [".$theField->{summarize}."]\n";
			}
		}
	}
	
#	print LOGFILE $logPrepend."groupCols: (".(join '|', @groupCols).")\n";
#	print LOGFILE $logPrepend."sumCols: (".(join '|', @sumCols).")\n";
	
#	close LOGFILE;
	$logSpaces -= 2;
	return (\@groupCols, \@sumCols);
}

sub generateBreaksCallback {
	my ($rowFormat, $fieldOrder, $newFieldDefn, $groupCols, $sumCols) = @_;
	
	my %breakSubs = ();

	foreach my $breakPoint (@{$groupCols}) {
		$breakSubs {$breakPoint} = sub {
			my ($report, $sheet, $rep_actline, $rep_lastline) = @_;
			
			my @_groupCols = @{$groupCols};
			my @_sumCols = @{$sumCols};
			
			my @thisRowFields;
			
			foreach my $field (@{$fieldOrder}) {
				my $tempField = $newFieldDefn->{$field}->{dataFmt};
				while ($tempField =~ /#([0-9]+)#/) {
					my $fieldNum = $1;
					my $tempFieldValue;
					
					if (lc($newFieldDefn->{$field}->{summarize}) ne 'none') {
						# A column that needed to be subtotalled...
						$tempFieldValue = $columnSubTotals[$fieldNum];
						if (lc ($newFieldDefn->{$fieldNum}->{dataType}) eq 'currency') {
							$tempFieldValue = FORMATTER->format_price($tempFieldValue, 2);
						}
					} elsif (lc($newFieldDefn->{$field}->{groupBy}) ne 'none') {
						# A column that was grouped on
						$tempFieldValue = $newFieldDefn->{$field}->{groupBy};
						$tempFieldValue = $rep_actline->[$fieldNum] if ($newFieldDefn->{$field}->{groupBy} =~ /#([0-9]+)#/);
					} else {
						# A column that wasnt subtotalled or grouped upon...
						$tempFieldValue = " ";
					}

					$tempField =~ s/#$fieldNum#/$tempFieldValue/;
				}
				push @thisRowFields, $tempField;
			}

			foreach my $summedCol (@_sumCols) {
			    $columnSubTotals [$summedCol] = 0.0;
			}
			
			foreach my $groupedCol (@_groupCols) {
				$groupColumnValues [$groupedCol] = "";
			}
			
			formline $rowFormat, @thisRowFields;
			my $tempData = $^A;
			$^A = "";
	
			my $line = $rowFormat;
			$line =~ s/[@<>|]/\-/g;
			if ($numRowsInGroup > 1) {
				$sheet->MVPrint (0, 0, $line);
				$sheet->MVPrint (0, 1, $tempData);
				$sheet->MVPrint (0, 2, " ");
			} elsif ($numRowsInGroup == 1) {
				$sheet->MVPrint (0, 0, " ");
			}
			$numRowsInGroup = 0;
		};
	}
	
	return \%breakSubs;
}

sub generateFinalCallback {
	my ($rowFormat, $fieldOrder, $newFieldDefn, $groupCols, $sumCols) = @_;
	
	return sub {
		my ($report, $sheet, $rep_actline, $rep_lastline) = @_;
		
		my @_groupCols = @{$groupCols};
		my @_sumCols = @{$sumCols};
			
		my @thisRowFields;
		my @totalRowFields;
		
		foreach my $field (@{$fieldOrder}) {
			my $tempField = $newFieldDefn->{$field}->{dataFmt};
			my $totalField = $field;
			while ($tempField =~ /#([0-9]+)#/) {
				my $fieldNum = $1;
				my $tempFieldValue;

				if (lc($newFieldDefn->{$field}->{summarize}) ne 'none') {
					# A column that needed to be subtotalled...
				       	$tempFieldValue = $columnTotals[$fieldNum];
				} elsif (lc($newFieldDefn->{$field}->{groupBy}) ne 'none') {
					# A column that was grouped on
					$tempFieldValue = " ";
#					if (lc($newFieldDefn->{$field}->{groupBy}) !~ /#([0-9]+)#/) {
#						$tempFieldValue = $rep_actline->[$fieldNum];
#					} else {
#						$tempFieldValue = $newFieldDefn->{$field}->{groupBy};
#					}
				} else {
					# A column that wasnt subtotalled or grouped upon...
					$tempFieldValue = " ";
				}

				if (lc ($newFieldDefn->{$fieldNum}->{dataType}) eq 'currency') {
					$tempFieldValue = FORMATTER->format_price($tempFieldValue, 2);
				}
				
				$tempField =~ s/#$fieldNum#/$tempFieldValue/e;
			}
			push @totalRowFields, $tempField;
		}

		foreach my $summedCol (@_sumCols) {
		    $columnSubTotals [$summedCol] = 0;
		    $columnTotals [$summedCol] = 0;
		}
			
		foreach my $groupedCol (@_groupCols) {
			$groupColumnValues [$groupedCol] = "";
		}
			
		formline $rowFormat, @totalRowFields;
		my $totalData = $^A;
		$^A = "";
	
		my $line = $rowFormat;
		$line =~ s/[@<>|]/=/g;
		$sheet->MVPrint (0, 0, $line);
		$sheet->MVPrint (0, 1, $totalData);
	};
}

sub generateHeaderCallback {
	my ($header, $rowFormat, $headingOrder, $reportTitle) = @_;

	my @tempHeader;

	# Create the header automagically from headings...
	formline $rowFormat, @{$headingOrder};
	my $tempHead = $^A;
	push @tempHeader, $tempHead;
	$^A = "";

	return sub {
		my ($report, $sheet, $rep_actline, $rep_lastline) = @_;

		my @theHeader = @tempHeader;
		my $row = 0;
		my $headerLength = 0;
		my $headerLine = $rowFormat;
		$headerLine =~ s/[@<>|]/\-/g;

		my $tempDir = $CONFDATA_SERVER->path_temp();
		my $theFilename .= "/publish.debug.log";
	
#		open (LOGFILE, ">>$tempDir$theFilename");
#		print LOGFILE "sub headerCallback\n";
		$logSpaces += 2;
		my $logPrepend = (scalar localtime)." " x $logSpaces;
	
		if (defined $reportTitle) {
			my $titleFormat = "@".("|" x ($report->width() - 1));
			formline $titleFormat, $reportTitle;
			my $formattedReportTitle = $^A;
			$^A = "";
	
			$sheet->MVPrint (0, $row, $formattedReportTitle);
			
			$row ++;
		}

		$sheet->MVPrint (0, $row, $report->date(2)." ".$report->time(1));
		$sheet->MVPrint ($report->width() - 10, $row, "Page ".$report->page());
		$row ++;
		$sheet->MVPrint (0, $row, " ");

		$row = 3;

		foreach my $headerLine (@theHeader) {
			$sheet->MVPrint (0, $row, $headerLine);
			$headerLength = length ($headerLine) if ((length ($headerLine)) > $headerLength);
			$row ++;
		}
		
		$sheet->MVPrint (0, $row, $headerLine);
		
		$logSpaces -= 2;
		close LOGFILE;
	};

}

sub generateFooterCallback {
	my ($footer, $rowFormat, $headingOrder) = @_;

	my @tempFooter;

	# Create the header automagically from headings...
	formline $rowFormat, @{$headingOrder};
	my $tempFoot = $^A;
	push @tempFooter, $tempFoot;
	$^A = "";

	return sub {
		my ($report, $sheet, $rep_actline, $rep_lastline) = @_;

		my @theFooter = @tempFooter;
		my $footerLength = 0;
		
		foreach my $footerLine (@theFooter) {
			$footerLength = length ($footerLine) if ((length ($footerLine)) > $footerLength);
		}
		$sheet->MVPrint (0, 0, '-' x $footerLength);
		$sheet->MVPrint (0, 1, $report->date(2)." ".$report->time(1));
		$sheet->MVPrint ($report->width() - 10, 1, "Page ".$report->page());
	};

}

sub generateDetailCallback {
	my ($rowFormat, $fieldOrder, $newFieldDefn, $groupCols, $sumCols) = @_;
	my $debug = 0;
	
	return sub {
		my ($report, $sheet, $rep_actline, $rep_lastline) = @_;

		my $tempDir = $CONFDATA_SERVER->path_temp();
		my $theFilename .= "/publish.debug.log";
	
#		open (LOGFILE, ">>$tempDir$theFilename");
#		print LOGFILE "sub detailCallback\n";
		$logSpaces += 2;
		my $logPrepend = (scalar localtime)." " x $logSpaces;

	
		my @thisRowFields;
		my @_sumCols = @{$sumCols};
		my @_groupCols = @{$groupCols};
#		my %fieldDefn = %{$newFieldDefn};
		my @summedFields = ();

		foreach my $field (@{$fieldOrder}) {
			$logSpaces += 2;
			$logPrepend = (scalar localtime)." " x $logSpaces;
#			print LOGFILE $logPrepend."field: $field\n";

			my $tempField = $newFieldDefn->{$field}->{dataFmt};
			my $tempFieldValue;
			while ($tempField =~ /#([0-9]+)#/) {
				my $fieldNum = $1;
#				my %thisFieldDefn = $fieldDefn{$fieldNum};
#				my %thisFieldDefn = $newFieldDefn->{$fieldNum};
				$tempFieldValue = $rep_actline->[$fieldNum];

				my $fieldDefnHashOutput = "{";
				while (my ($key, $value) = each %{$newFieldDefn->{$fieldNum}}) {
					$fieldDefnHashOutput .= "$key=$value|";
				}
				chop $fieldDefnHashOutput;
				$fieldDefnHashOutput .= "}\n";

				$logSpaces += 2;
				$logPrepend = (scalar localtime)." " x $logSpaces;
#				print LOGFILE $logPrepend."fieldNum: $field\n";
				$groupColumnValues [$fieldNum] = $rep_actline->[$fieldNum] if (grep $fieldNum, @_groupCols);

				if (grep $fieldNum, @_sumCols) {
					$logSpaces += 2;
					$logPrepend = (scalar localtime)." " x $logSpaces;
#					print LOGFILE $logPrepend."Subtotal: $columnSubTotals[$fieldNum] -> ";
			
					# A column that needed to be subtotalled...
					# Make sure it hasnt already been summed up earlier...
					unless ($summedFields [$fieldNum]) {
						$columnSubTotals [$fieldNum] += $rep_actline->[$fieldNum];
						$columnTotals [$fieldNum] += $rep_actline->[$fieldNum];
						$summedFields [$fieldNum] = 1;
#						print LOGFILE "$columnSubTotals[$fieldNum]\n";
					}
					$logSpaces -= 2;
			       	}
				my $attribHashOutput = "{";
				while (my ($key, $value) = each %{$newFieldDefn->{$fieldNum}}) {
					$attribHashOutput .= "$key=$value|";
				}
				chop $attribHashOutput;
				$attribHashOutput .= "}\n";
				
#				print LOGFILE $logPrepend."$field attribs: $attribHashOutput\n";
				if (lc ($newFieldDefn->{$fieldNum}->{dataType}) eq 'currency') {
					$tempFieldValue = FORMATTER->format_price($rep_actline->[$fieldNum], 2);
				}
				
			       	$tempField =~ s/#$fieldNum#/$tempFieldValue/e;
				$logSpaces -= 2;
			}
			push @thisRowFields, $tempField;
			$logSpaces -= 2;
		}
		
		my $rawData = "(".(join '|', @{$rep_actline}).")";
		my $thisRowData = "(".(join '|', @thisRowFields).")";
#		print LOGFILE $logPrepend."data: $rawData\n";
#		print LOGFILE $logPrepend."thisRowFields: $thisRowData\n";

		formline $rowFormat, @thisRowFields;
		my $tempData = $^A;
		$^A = "";
		formline $rowFormat, @columnSubTotals;
		my $subTotals = $^A;
		$^A = "";
		
		if ($debug) {
			$sheet->MVPrint (0, 0, "-"x128);
			$sheet->MVPrint (0, 1, $tempData);
			$sheet->MVPrint (0, 2, " "x128);
			$sheet->MVPrint (0, 3, $rawData);
			$sheet->MVPrint (0, 4, $thisRowData);
			$sheet->MVPrint (0, 0, "-"x128);
#			$sheet->MVPrint (0, 2, $subTotals);
		} else {
			$sheet->MVPrint (0, 0, $tempData) unless ($tempData =~ /^\s*$/);
		}
		$numRowsInGroup ++ unless ($tempData =~ /^\s*$/);

		$logSpaces -= 2;
		close LOGFILE;
	};
}

sub generateTitleCallback {
	my ($reportTitle) = @_;
	
	$reportTitle = "Insert Report Title Here";
	
	return sub {
		my ($report, $sheet, $rep_actline, $rep_lastline) = @_;

#		my $titleFormat = "@".("|" x ($report->width() - 1));
#		formline $titleFormat, $reportTitle;
#		my $reportTitle = $^A;
#		$^A = "";
#		
#		$sheet->MVPrint (0, 0, $reportTitle);
#		$sheet->MVPrint (0, 1, $report->date(2));
#		$sheet->MVPrint ($report->width() - 10, 1, $report->page());
#		$sheet->MVPrint (0, 2, " ");
	};
}

1;

