##############################################################################
package App::Data::Obtain::TXgulf::FeeSchedules;
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

	unless($params{srcFile})
	{
		$self->addError("srcFile is required");
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

	$self->reportMsg("Opening workbook $params{srcFile}.") if $flags & DATAMANIPFLAG_VERBOSE;
	
	# open the file
	my $book = $excel->Workbooks->Open($params{srcFile});
	
	unless($book)
	{
		$self->addError("Unable to open Excel file $params{srcFile}: $!");		
		undef $excel;
		return;
	}

	$self->process($flags, $collection, \%params, $excel, $book);

	$self->reportMsg("Closing Excel.") if $flags & DATAMANIPFLAG_VERBOSE;
	undef $book;
	undef $excel;
}

sub process
{
	my ($self, $flags, $collection, $params, $excel, $book) = @_;

	# cycle through the rows
	$self->reportMsg("Acquiring worksheet.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $sheetId = exists $params->{worksheet} ? $params->{worksheet} : 1;
	my $sheet = $book->Worksheets($sheetId);
	unless($sheet)
	{
		$self->addError("Unable to acquire worksheet '$sheet' in $params->{srcFile}  $!");
		undef $book;
		undef $excel;
		return;
	}
	
	$self->reportMsg("Loading rows.") if $flags & DATAMANIPFLAG_VERBOSE;
	
	my $data = $collection->{data};		
	
	my %internalCatalogId;
	my @catalogId = ();
	my $offset = $params->{catalog_id_offset};
	
	my $range = $sheet->Range("F3:Y3")->{Value};
	for my $j (0..(@{$range->[0]} -1))
	{
		if ($params->{importAction} eq 'IMPORT_FEE_SCHEDULE')
		{
			push(@$data, [$range->[0][$j], 'Imported FS - ' . $range->[0][$j] ]);
		}
		else
		{
			$internalCatalogId{$range->[0][$j]} = $offset++;
			push(@catalogId, $range->[0][$j]);
		}
	}
	
	return if ($params->{importAction} eq 'IMPORT_FEE_SCHEDULE');

	my $rowIdx = 4; #skip the first 4 rows (the headings)
	my $rowCount=0;
	
	my ($flags, $status, $defaultUnits, $costType, $entryType) = (0, 1, 1, 1, 100);
	
	while(my $range = $sheet->Range("A$rowIdx:Y$rowIdx")->{Value})
	{
		my $code = App::Data::Manipulate::trim($range->[0][0]);
		my $name = App::Data::Manipulate::trim($range->[0][1]);
		
		for my $j (0..(@{$range->[0]} -1))
		{
			my $catalog_id = $catalogId[$j];
			my $internal_catalog_id = $internalCatalogId{$catalog_id};
			my $price = $range->[0][$j+5];
			
			if (exists $internalCatalogId{$catalog_id})
			{
				if ($price > 0)
				{
					$entryType = decodeEntryType($code);
					push(@$data, [$internal_catalog_id, $entryType, $flags, $status, $code, $name,
						$defaultUnits, $costType, $price, $name]);
				}
			}
		}

		last unless $code;
		$rowCount++;
		$rowIdx++;
		
		$self->reportMsg("read $rowIdx rows")
			if ($rowIdx % 500 == 0) && ($flags & DATAMANIPFLAG_SHOWPROGRESS);		
	}	

	$self->reportMsg("$rowCount rows read from $params->{srcFile}") if $flags & DATAMANIPFLAG_SHOWPROGRESS;
}

use constant CPT_ENTRYTYPE => 100;
use constant SERVICE_ENTRYTYPE => 150;
use constant HCPCS_ENTRYTYPE => 210;

sub decodeEntryType
{
	my ($code) = @_;
	
	CASE:
	{
		if ($code =~ /\d\d\d\d\d/) {return CPT_ENTRYTYPE ;last CASE;}
		if ($code =~ /\D\d\d\d\d/) {return HCPCS_ENTRYTYPE ;last CASE;}
		return SERVICE_ENTRYTYPE;
	}
}

1;