##############################################################################
package App::Data::Obtain::Ntis::CPTinfo;
##############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain;
use App::Data::Obtain::InfoX::ICDinfo;
use vars qw(@ISA $VERSION);

@ISA = qw(App::Data::Obtain);
$VERSION = "1.00";

use constant CPTFORMAT_LONG  => 'long';
use constant CPTFORMAT_SHORT => 'short';

sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	my $cptShortFile  = $params{cptShortFile};
	my $cptLongFile   = $params{cptLongFile};
	my $cpEditFile    = $params{cpEditFile};
	my $meEditFile    = $params{meEditFile};
	my $crosswalkFile = $params{crosswalkFile};
	my $cptOceFile    = $params{cptOceFile};

	unless($cptShortFile && $cptLongFile && $cpEditFile && $meEditFile && $crosswalkFile && $cptOceFile)
	{
		$self->addError
			("All 6 cptShortFile, cptLongFile, cpEdit, meEdit, crosswalk, and cptOce are required");
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

	# Read Oce File
	$self->readOceFile($flags, $cptData, $cptOceFile);

	# Read Crosswalk File
	#$self->readCrossWalkFile($flags, $cptData, $crosswalkFile);

	# Read Long and Short Description Files
	$self->readCPTSource($flags, $cptData, $cptShortFile, CPTFORMAT_SHORT, $shortStats);
	$self->readCPTSource($flags, $cptData, $cptLongFile, CPTFORMAT_LONG, $longStats);

	# Read Edit Files
	$self->readCPTEdit($flags, $cptData, $cpEditFile, "cpEdit", "cpFlag");
	$self->readCPTEdit($flags, $cptData, $meEditFile, "meEdit", "meFlag");

	$self->reportMsg("Combining CPT files.") if $flags & DATAMANIPFLAG_VERBOSE;

	my $data = $collection->{data};
	my $count = 0;

	my $maxCPLength = 0;
	my $maxMELength = 0;
	#my $maxICDsLength = 0;

	foreach (sort keys %{$cptData})
	{
		my $cpt = $cptData->{$_};
		#$self->addError("CPT $_ does not have short text") unless $cpt->{short};
		#$self->addError("CPT $_ does not have long text") unless $cpt->{long};

		my $cpEdits  = join(',', @{$cpt->{cpEdit}}) if exists $cpt->{cpEdit};
		my $cpFlags  = join(',', @{$cpt->{cpFlag}}) if exists $cpt->{cpFlag};
		my $meEdits  = join(',', @{$cpt->{meEdit}}) if exists $cpt->{meEdit};
		my $meFlags  = join(',', @{$cpt->{meFlag}}) if exists $cpt->{meFlag};
		#my $icdsList = join(',', @{$cpt->{crosswalk}}) if exists $cpt->{crosswalk};

		push(@$data, [$_, $cpt->{short}, $cpt->{long}, $cpEdits, $cpFlags, $meEdits, $meFlags,
			$cpt->{sex}, $cpt->{unlisted}, $cpt->{questionable}, $cpt->{asc}, $cpt->{nonRep},
			$cpt->{nonCov}
			]
		);

		$maxCPLength = length($cpEdits) if length($cpEdits) > $maxCPLength;
		$maxMELength = length($meEdits) if length($meEdits) > $maxMELength;
		#$maxICDsLength = length($icdsList) if length($icdsList) > $maxICDsLength;

		$count++;
	}

	$self->reportMsg("$count CPT codes read") if $flags & DATAMANIPFLAG_SHOWPROGRESS;

	$self->reportMsg("Max CP Length= $maxCPLength") if $flags & DATAMANIPFLAG_SHOWPROGRESS;
	$self->reportMsg("Max ME Length= $maxMELength") if $flags & DATAMANIPFLAG_SHOWPROGRESS;
	#$self->reportMsg("Max ICDs Length= $maxICDsLength") if $flags & DATAMANIPFLAG_SHOWPROGRESS;

	$self->updateStats($collection, $shortStats, CPTFORMAT_SHORT);
	$self->updateStats($collection, $longStats, CPTFORMAT_LONG);
}

sub readOceFile
{
	my ($self, $flags, $cptData, $cptOceFile) = @_;

	unless(open(CPTOCE, $cptOceFile)) {
		$self->addError("unable to open CPTOCE file '$cptOceFile': $!");
		return;
	}

	my $count = 0;
	while (<CPTOCE>)
	{
		chomp;

		next if /^Code/;
		next if /^$/;

		my $line = $_;
		$line =~ s/\"//g;
		$line =~ s/\, / - /g;
		my @cols = split(/,/, $line);

		my $cpt = $cols[0];
		#$cptData->{$cpt}->{modifier}     = $cols[1];
		#$cptData->{$cpt}->{descr}        = $cols[2];
		$cptData->{$cpt}->{sex}          = $cols[3];
		$cptData->{$cpt}->{unlisted}     = App::Data::Obtain::InfoX::ICDinfo::BOOL($cols[4]);
		$cptData->{$cpt}->{questionable} = App::Data::Obtain::InfoX::ICDinfo::BOOL($cols[5]);
		$cptData->{$cpt}->{asc}          = App::Data::Obtain::InfoX::ICDinfo::BOOL($cols[6]);
		$cptData->{$cpt}->{nonRep}       = App::Data::Obtain::InfoX::ICDinfo::BOOL($cols[7]);
		$cptData->{$cpt}->{nonCov}       = App::Data::Obtain::InfoX::ICDinfo::BOOL($cols[8]);

		$count++;
	}
	$self->reportMsg("$count lines read from $cptOceFile") if $flags & DATAMANIPFLAG_VERBOSE;

	close(CPTOCE);
}

sub readCrossWalkFile
{
	my ($self, $flags, $cptData, $crosswalkFile) = @_;

	$self->reportMsg("Loading CrossWalk $crosswalkFile ...") if $flags & DATAMANIPFLAG_VERBOSE;
		unless(open(CROSSWALK, $crosswalkFile)) {
			$self->addError("unable to open Crosswalk file '$crosswalkFile': $!");
			return;
		}

		my $count = 0;
		while (<CROSSWALK>)
		{
			chomp;
			my ($cpt, $icd) = split(/,/);
			push(@{$cptData->{$cpt}->{crosswalk}}, $icd);
			print "\rReading line $. => $cpt" if $. % 2000 == 0;
			$count++;
		}
		$self->reportMsg("$count lines read from $crosswalkFile") if $flags & DATAMANIPFLAG_VERBOSE;

		close(CROSSWALK);
}

sub readCPTEdit
{
	my ($self, $flags, $cptData, $editFile, $editType, $flagType) = @_;

	unless (open(EDITFILE, $editFile)) {
		$self->addError("unable to open CPT Edit file '$editFile': $!");
		return;
	}

	$self->reportMsg("Loading $editFile.") if $flags & DATAMANIPFLAG_VERBOSE;

	$/ = sprintf ("%c", 0xD);
	while (<EDITFILE>)
	{
		chomp;
		my @cols = split(/\t/);
		my $cpt1 = $cols[0];
		my $cpt2 = $cols[1];
		my $gbFlag = $cols[6];

		push(@{$cptData->{$cpt1}->{$editType}}, $cpt2);
		push(@{$cptData->{$cpt1}->{$flagType}}, $gbFlag);
	}

	close(EDITFILE);
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

	unless (open(CPTSOURCE, $srcFile))
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
