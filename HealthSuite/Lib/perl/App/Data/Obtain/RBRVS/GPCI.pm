##############################################################################
package App::Data::Obtain::RBRVS::GPCI;
############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain::Excel;
use vars qw(@ISA $VERSION);
use Win32::OLE;

@ISA = qw(App::Data::Obtain::Excel);
$VERSION = "1.00";

sub code
{
	return 200;
}


sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	unless($params{srcFileGPCI}&&$params{srcFileLocal})
	{
		$self->addError("srcFileGPCI and srcFileLocal parameters are required");
		return;
	}

	$self->reportMsg("Opening Excel.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $excel;
	eval {$excel = Win32::OLE->GetActiveObject('Excel.Application')};
	if($@)
	{
		$self->addError("Microsoft Excel does not seem to be installed: $@");
		return;
	}
	unless(defined $excel)
	{
		$excel = Win32::OLE->new('Excel.Application', sub {$_[0]->Quit;});
		unless($excel)
		{
			$self->addError("Unable to start Microsoft Excel");
			return;
		}
	}

	$self->reportMsg("Opening workbook $params{srcFileLocal}.") if $flags & DATAMANIPFLAG_VERBOSE;
	$self->reportMsg("Opening workbook $params{srcFileGPCI}.") if $flags & DATAMANIPFLAG_VERBOSE;
	# open the file
	my $bookGPCI = $excel->Workbooks->Open($params{srcFileGPCI});
	my $bookLocal = $excel->Workbooks->Open($params{srcFileLocal});
	unless($bookGPCI)
	{
		$self->addError("Unable to open Excel file $params{srcFileGPCI}: $!");		
		undef $excel;
		return;
	}

	unless($bookLocal)
	{
		$self->addError("Unable to open Excel file $params{srcFileLocal}: $!");		
		undef $excel;
		return;
	}
		
	$self->process($flags, $collection, \%params, $excel, $bookGPCI,$bookLocal);

	$self->reportMsg("Closing Excel.") if $flags & DATAMANIPFLAG_VERBOSE;
	undef $bookGPCI;
	undef $bookLocal;
	undef $excel;
}


sub process
{
	my ($self, $flags, $collection, $params, $excel, $bookGPCI, $bookLocal) = @_;

	# cycle through the rows
	$self->reportMsg("Acquiring worksheet.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $sheetGPCIId = exists $params->{worksheet} ? $params->{worksheet} : 1;
	my $sheetLocalId = exists $params->{worksheet} ? $params->{worksheet} : 1;
	my $sheetGPCI = $bookGPCI->Worksheets($sheetGPCIId );
	unless($sheetGPCI)
	{
				$self->addError("Unable to acquire worksheet '$sheetGPCIId' in $params->{srcFileGPCI}  $!");
				undef $bookGPCI;
				undef $excel;
				return;
	}
	my $sheetLocal = $bookLocal->Worksheets($sheetLocalId);
	unless($sheetLocal)
	{
		$self->addError("Unable to acquire worksheet '$sheetLocalId' in $params->{srcFileLocal}: $!");
		undef $bookLocal;
		undef $excel;
		return;
	}

	$self->reportMsg("Loading rows.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $rowIdx = 4; #skip the first 4 rows (the headings)
	my ($range, $row);
	my $year = '01-Jan-00';	
	my $mergeData={};
	my $gpciData ={};
	my $locData ={};
	my $data = $collection->{data};		
	my $rowCount=0;
	while($range = $sheetGPCI->Range("A$rowIdx:F$rowIdx")->{Value})
	{
		my $row = $range->[0];
		my ($code,$number, $name, $work, $pe,$mp) = ($row->[0],$row->[1], $row->[2], $row->[3], $row->[4], $row->[5]);
		$code=~ s/^\s+//;
		$number=~ s/^\s+//;
		$work=~ s/^\s+//;
		$pe=~ s/^\s+//;
		$mp=~ s/^\s+//;
		last unless $code;
		$rowCount++;
		$rowIdx++;
		$self->updateMsg("read $rowIdx rows")
			if ($rowIdx % 500 == 0) && ($flags & DATAMANIPFLAG_SHOWPROGRESS);		
		$gpciData->{$code . $number} =
		{
			code =>$code,
			number =>$number,
			name => $name,
			work => $work,
			pe => $pe,
			mp =>$mp,			
		};
	}	

	$self->reportMsg("$rowCount rows read from $params->{srcFileGPCI}") if $flags & DATAMANIPFLAG_SHOWPROGRESS;
	
	my $old_state;
	my $rowIdx = 5;	
	$rowCount=0;
	my $valid=0;
	while($range = $sheetLocal->Range("A$rowIdx:E$rowIdx")->{Value})
	{
		my $row = $range->[0];
		my ($code,$number, $state, $area, $county) = ($row->[0],$row->[1], $row->[2], $row->[3], $row->[4]);
		$valid ++;		
		$valid =0 if $code;
		last if $valid>3;
		if ($code)
		{
		$rowCount++;

		$self->updateMsg("read $rowIdx rows")
			if ($rowIdx % 500 == 0) && ($flags & DATAMANIPFLAG_SHOWPROGRESS);	
		$code=~ s/^\s+//;
		$number=~ s/^\s+//;	
		$state=~ s/^\s+//;
		$area=~ s/^\s+//;
		$county=~ s/^\s+//;
		$old_state = $state if ($state && length($state)>0);		
		$locData->{$code . $number} =
		{
			state =>$old_state,
			loc =>$area,
			county =>$county
		};
		}
		$rowIdx++;	
		
	}		
	$self->reportMsg("$rowCount rows read from $params->{srcFileLocal}") if $flags & DATAMANIPFLAG_SHOWPROGRESS;
	
	for  my $key (keys %{$gpciData})
	{
		my $pull=$gpciData->{$key};
		my $pullLoc=$locData->{$key};		
		push(@$data,[$pull->{code}, $pull->{number},$pullLoc->{loc},$pullLoc->{state},
		$pullLoc->{county},$pull->{work}, $pull->{pe},$pull->{mp}]);
	}
	
	#$self->reportMsg("Preparing Data.") if $flags & DATAMANIPFLAG_VERBOSE;

	
	
}

1;