##############################################################################
package App::Data::Obtain::HCFA::HCPCS;
##############################################################################

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

sub process
{
	my ($self, $flags, $collection, $params, $excel, $book) = @_;

	# cycle through the rows (HCPCS codes)
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
	my $rowIdx = 2; #skip the first row (the headings)
	my ($range, $row);
	my $allCodes = {};

	while($range = $sheet->Range("A$rowIdx:E$rowIdx")->{Value})
	{
		my $row = $range->[0];
		my ($code, $name, $descr) = ($row->[0], $row->[4], $row->[3]);
		last unless $descr;

		if(my $codeData = $allCodes->{$code})
		{
			$codeData->[1] .= ' ' . $name if $name;
			$codeData->[2] .= ' ' . $descr if $descr;
		}
		else
		{
			$allCodes->{$code} = [$code, $name, $descr];
		}

		$rowIdx++;
		$self->updateMsg("read $rowIdx rows")
			if ($rowIdx % 500 == 0) && ($flags & DATAMANIPFLAG_SHOWPROGRESS);
	}
	my $rowCount = $rowIdx-1; # since we started at 2
	$self->reportMsg("$rowCount rows read from $params->{srcFile}") if $flags & DATAMANIPFLAG_SHOWPROGRESS;

	$self->reportMsg("Preparing Data.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $data = $collection->{data};
	my $code = $self->code();
	foreach (sort keys %{$allCodes})
	{
		push(@$data, [@{$allCodes->{$_}}]);
	}

	undef $allCodes;
}

1;