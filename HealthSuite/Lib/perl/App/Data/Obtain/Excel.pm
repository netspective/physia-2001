##############################################################################
package App::Data::Obtain::Excel;
##############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain;
use vars qw(@ISA $VERSION);
use Win32::OLE;

@ISA = qw(App::Data::Obtain);
$VERSION = "1.00";

sub process
{
	my ($self, $flags, $collection, $params, $excel, $book) = @_;
	$self->abstract();
}

sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	unless($params{srcFile})
	{
		$self->addError("srcFile parameters is required");
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

	my ($sheetId, $sheet) = (undef, undef);
	if($sheetId = $params{worksheet})
	{
		$self->reportMsg("Acquiring worksheet '$sheetId'.") if $flags & DATAMANIPFLAG_VERBOSE;
		$sheet = $book->Worksheets($sheetId);
		unless($sheet)
		{
			$self->addError("Unable to acquire worksheet '$sheetId' in $params{srcFile}: $!");
			undef $book;
			undef $excel;
			return;
		}
	}

	$self->process($flags, $collection, \%params, $excel, $book, $sheet, $sheetId);

	$self->reportMsg("Closing Excel.") if $flags & DATAMANIPFLAG_VERBOSE;
	undef $book;
	undef $excel;
}

1;