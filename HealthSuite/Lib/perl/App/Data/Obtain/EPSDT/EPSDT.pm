##############################################################################
package App::Data::Obtain::EPSDT::EPSDT;
##############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain::Excel;
use vars qw(@ISA $VERSION);
use Win32::OLE;

@ISA = qw(App::Data::Obtain::Excel);
$VERSION = "1.00";


sub process
{
	my ($self, $flags, $collection, $params, $excel, $book) = @_;

	# cycle through the rows (CPT/HPCS codes)
	$self->reportMsg("Acquiring worksheet.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $sheetId = exists $params->{worksheet} ? $params->{worksheet} : 1;
	my $sheet = $book->Worksheets($sheetId );
	unless($sheet)
	{
		$self->addError("Unable to acquire worksheet $sheetId  in $params->{srcFile}: $!");
		undef $book;
		undef $excel;
		return;
	}

	$self->reportMsg("Loading rows.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $rowIdx = 2; #skip the first 10 rows (the headings)
	my ($range, $row);
	my $rowCount=0;
	my $data = $collection->{data};	
	eval
	{
	while($range = $sheet->Range("A$rowIdx:C$rowIdx")->{Value})
	{
		my $row = $range->[0];
		last unless $row->[0];	
	
		$rowCount++;		
		$self->updateMsg("read $rowIdx rows")
			if ($rowIdx % 500 == 0) && ($flags & DATAMANIPFLAG_SHOWPROGRESS);					
		my ($code,$desc) = ($row->[0],$row->[2]);
		App::Data::Manipulate::trim($code);
		App::Data::Manipulate::trim($desc);	
		push(@$data,[$code,$desc,$desc]);
		$rowIdx++;		
	}
	};
	if(@$)
	{
		print $range, $rowIdx, "ERROR\n";
	};	
	$self->reportMsg("$rowCount rows read from $params->{srcFile}") if $flags & DATAMANIPFLAG_SHOWPROGRESS;

	#$self->reportMsg("Preparing Data.") if $flags & DATAMANIPFLAG_VERBOSE;

	
	
}