##############################################################################
package App::Data::Obtain::Word;
##############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain;
use vars qw(@ISA $VERSION);
use Win32::OLE;
use Win32::OLE::Const 'Microsoft Word';

@ISA = qw(App::Data::Obtain);
$VERSION = "1.00";

sub process
{
	my ($self, $flags, $collection, $params, $msWord, $document) = @_;
	$self->abstract();
}

sub extractTable
{
	my ($self, $flags, $msWord, $document, $tableId, $saveAsFile, $expectCols, $expectRows) = @_;
	$tableId = 1 unless defined $tableId;
	my $wordDocIsMine = 0;

	unless(ref $document)
	{
		my $srcFile = $document;
		unless(-f $srcFile)
		{
			$self->addError("srcFile '$srcFile' not found");
			return;
		}

		if(my $openDoc = $msWord->Documents($srcFile))
		{
			$self->reportMsg("Closing existing $srcFile.") if $flags & DATAMANIPFLAG_VERBOSE;
			$openDoc->Close(wdDoNotSaveChanges);
		}

		$self->reportMsg("Opening $srcFile.") if $flags & DATAMANIPFLAG_VERBOSE;
		$document = $msWord->Documents->Open({FileName => $srcFile, Revert => 1});
		unless($document)
		{
			$self->addError("Unable to open '$srcFile' in Microsoft Word $@.");
			return;
		}
		$wordDocIsMine = 1;
	}

	$self->reportMsg("Obtaining table $tableId.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $rows = [];
	my $table = $document->Tables($tableId);
	unless($table)
	{
		$self->addError("Couldn't retrieve table '$tableId' in " . $document->Name . ' (there are ' . $document->Tables->Count . ' tables)');
		$document->Close(wdDoNotSaveChanges) if $wordDocIsMine;
		return $rows;
	}

	if(defined $expectCols)
	{
		my $totalCols = $table->Columns->Count;
		unless($totalCols == $expectCols)
		{
			$self->addError("$expectCols columns expected in table '$tableId', instead it has $totalCols");
			$document->Close(wdDoNotSaveChanges) if $wordDocIsMine;
			return $rows;
		}
	}

	my $totalRows = $table->Rows->Count;
	if($totalRows <= 0)
	{
		$document->Close(wdDoNotSaveChanges) if $wordDocIsMine;
		return $rows;
	}
	if(defined $expectRows)
	{
		unless($totalRows == $expectRows)
		{
			$self->addError("$expectRows rows expected in table '$tableId', instead it has $totalRows");
			$document->Close(wdDoNotSaveChanges) if $wordDocIsMine;
			return $rows;
		}
	}

	$self->reportMsg("Converting table $tableId to text.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $range = $table->ConvertToText(wdSeparateByTabs);
	my @rows = split(/[\n\r]/, $range->Text());

	if($saveAsFile)
	{
		$self->reportMsg("Saving table $tableId in $saveAsFile.") if $flags & DATAMANIPFLAG_VERBOSE;
		open(DEST, ">$saveAsFile");
		print DEST join("\n", @rows);
		close(DEST);
	}

	$document->Close(wdDoNotSaveChanges) if $wordDocIsMine;
	return \@rows;
}

sub getTableRowCellsText
{
	my ($self, $row, $selection, @cols) = @_;

	my @text = ();
	foreach (@cols)
	{
		my $text = $row->Cells($_)->Range()->Text();
		$text =~ s/[\0-\32]//g; # for some reason CR is found in $text -- why?
		#chomp($text);
		#print "\rCell $_ is -->'$text'<--\n";
		push(@text, $text);
	};
	return @text;
}

sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	$self->reportMsg("Opening Microsoft Word.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $msWord;
	eval {$msWord = Win32::OLE->GetActiveObject('Word.Application')};
	if($@)
	{
		$self->addError("Microsoft Word does not seem to be installed: $@");
		return;
	}
	unless(defined $msWord)
	{
		$msWord = Win32::OLE->new('Word.Application', sub {$_[0]->Quit;});
		unless($msWord)
		{
			$self->addError("Unable to start Microsoft Word");
			return;
		}
	}

	my $document = undef;
	if($params{srcFile})
	{
		$self->reportMsg("Opening document $params{srcFile}.") if $flags & DATAMANIPFLAG_VERBOSE;
		# open the file
		my $document = $msWord->Documents->Open($params{srcFile});
		unless($document)
		{
			$self->addError("Unable to open Microsoft Word file $params{srcFile}: $!");
			undef $msWord;
			return;
		}
	}
	$self->process($flags, $collection, \%params, $msWord, $document);

	$self->reportMsg("Closing Microsoft Word.") if $flags & DATAMANIPFLAG_VERBOSE;
	undef $document if $document;
	undef $msWord;
}

1;