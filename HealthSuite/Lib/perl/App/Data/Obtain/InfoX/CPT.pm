##############################################################################
package App::Data::Obtain::InfoX::CPT;
##############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain;
use vars qw(@ISA $VERSION);

@ISA = qw(App::Data::Obtain);
$VERSION = "1.00";

use constant CPTFORMAT_LONG  => 'long';
use constant CPTFORMAT_SHORT => 'short';

sub code
{
	return 100;
}

sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	unless($params{srcFileLong} && $params{srcFileShort})
	{
		$self->addError("srcFileLong and srcFileShort parameters are required");
		return;
	}

	my $shortStats =
		{
			lines => 0,
			merged => 0,
			longestText => '',
			longestLen => 0,
			longestLine => 0,
		};

	my $longStats =
		{
			lines => 0,
			merged => 0,
			longestText => '',
			longestLen => 0,
			longestLine => 0,
		};

	my $cptData = {};
	$self->readCPTSource($flags, $cptData, $params{srcFileShort}, CPTFORMAT_SHORT, $shortStats);
	$self->readCPTSource($flags, $cptData, $params{srcFileLong}, CPTFORMAT_LONG, $longStats);

	$self->reportMsg("Combining long and short CPT files.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $data = $collection->{data};
	my $code = $self->code();
	my $count = 0;
	foreach (sort keys %{$cptData})
	{
		my $cpt = $cptData->{$_};
		$self->addError("CPT $_ does not have short text") unless $cpt->{short};
		$self->addError("CPT $_ does not have long text") unless $cpt->{long};

		push(@$data, [$code, $_, $cpt->{short}, $cpt->{long}]);
		$count++;
	}
	$self->reportMsg("$count CPT codes read") if $flags & DATAMANIPFLAG_SHOWPROGRESS;	

	$self->updateStats($collection, $shortStats, CPTFORMAT_SHORT);
	$self->updateStats($collection, $longStats, CPTFORMAT_LONG);
}

sub createCPTRec
{
	my ($self, $cptData, $stats, $which, $code, $text) = @_;

	if(! exists $cptData->{$code})
	{
		$cptData->{$code} =
			{
				code => $code,
				short => '',
				long => '',
			};
	}

	if(length($cptData->{$code}->{$which}) > 0)
	{
		$cptData->{$code}->{$which} .= " $text";
		$stats->{merged}++;
	}
	else
	{
		$cptData->{$code}->{$which} = $text;
	}

	if($stats->{longestLen} < length($cptData->{$code}->{$which}))
	{
		$stats->{longestLen} = length($cptData->{$code}->{$which});
		$stats->{longestText} = $cptData->{$code}->{$which};
		$stats->{longestLine} = $stats->{lines};
	}
}

sub readCPTSource
{
	my ($self, $flags, $cptData, $srcFile, $type, $stats) = @_;

	unless(open(CPTSOURCE, $srcFile))
	{
		$self->addError("unable to open $srcFile: $!");
		return;
	};

	$self->reportMsg("Loading $srcFile.") if $flags & DATAMANIPFLAG_VERBOSE;
	while(<CPTSOURCE>)
	{
		chomp;
		$stats->{lines}++;

		if(! m/^(\d+)\s+(.*)/)
		{
			$self->addError("Error in line (skipped): $_");
			next;
		}
		my ($code, $text) = ($1, $2);

		if($type eq CPTFORMAT_SHORT)
		{
			if($code !~ m/\d\d\d\d\d/)
			{
				$self->addError("Error in short CPT code: $_");
				next;
			}
		}
		else
		{
			# for long text, the text may be wrapped in multiple lines (the last two digits)
			if($code !~ m/(\d\d\d\d\d)(\d\d)/)
			{
				$self->addError("Error in long CPT code: $_");
				next;
			}
			$code = $1;
		}
		$self->createCPTRec($cptData, $stats, $type, $code, $text);
	}
	close(CPTSOURCE);
}

sub updateStats
{
	my ($self, $collection, $stats, $which) = @_;

	$collection->addStatistic("Total lines ($which)", $stats->{lines});
	$collection->addStatistic("Merged lines ($which)", $stats->{merged});
	$collection->addStatistic("CPTs in file ($which)", $stats->{lines}-$stats->{merged});
	$collection->addStatistic("Longest line ($which)", $stats->{longestLine});
	$collection->addStatistic("Longest len ($which)", $stats->{longestLen});
	$collection->addStatistic("Longest text ($which)", $stats->{longestText});
}

1;