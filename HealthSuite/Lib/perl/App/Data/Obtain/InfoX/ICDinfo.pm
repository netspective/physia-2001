##############################################################################
package App::Data::Obtain::InfoX::ICDinfo;
##############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain;
use vars qw(@ISA $VERSION);

@ISA = qw(App::Data::Obtain);
$VERSION = "1.00";

sub BOOL
{
	uc($_[0]) eq 'Y' ? 1 : 0;
}

sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	my $icdEditFile = $params{icdEditFile};
	my $icd_cptFile = $params{icdCptCrosswalkFile};
	my $icdDescrFile = $params{icdDescrFile};

	unless($params{icdEditFile} && $params{icdCptCrosswalkFile} && $params{icdDescrFile})
	{
		$self->addError("icdEditFile, icdCptCrosswalkFile, and icdDescrFile parameters are required");
		return;
	}

	unless(open(ICDEDIT, $icdEditFile)) {
		$self->addError("unable to open ICD Edit file '$icdEditFile': $!");
		return;
	}

	unless(open(ICDCPT, $icd_cptFile)) {
		$self->addError("unable to open ICD-CPT crosswalk file '$icd_cptFile': $!");
		return;
	}

	unless(open(ICDDESCR, $icdDescrFile)) {
		$self->addError("unable to open ICD Description file '$icdDescrFile': $!");
		return;
	}

	my $data = $collection->{data};
	my @cols = ();
	my $count = 0;

	# First, load the entire crosswalk into hash
	$self->reportMsg("Loading CrossWalk $icd_cptFile into memory...") if $flags & DATAMANIPFLAG_VERBOSE;
	my %crosswalk = {};
	while (<ICDCPT>)
	{
		chomp;
		my ($icd, $cpt) = split(/,/);
		push(@{$crosswalk{$icd}}, $cpt);
		print "\rReading line $. => $icd" if $. % 2000 == 0;
		$count++;
	}
	$self->reportMsg("$count lines read from $icd_cptFile") if $flags & DATAMANIPFLAG_VERBOSE;

	# Next, Read Long ICD descriptions
	$self->reportMsg("Loading Description $icdDescrFile ...") if $flags & DATAMANIPFLAG_VERBOSE;
	my %icdDescr = {};
	$count = 0;
	while (<ICDDESCR>)
	{
		chomp;
		my ($icd, $nothing, $descr) = split(/\t/);
		$icdDescr{$icd} = $descr;
		print "\rReading line $. => $icd" if $. % 2000 == 0;
		$count++;
	}
	$self->reportMsg("$count lines read from $icdDescrFile") if $flags & DATAMANIPFLAG_VERBOSE;

	# Now, process each ICD code
	$self->reportMsg("Loading $params{icdEditFile}.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $maxCptsInOneICD = 0;
	my $maxCptsColumnLength = 0;

	$count = 0;
	while(<ICDEDIT>)
	{
		chomp;
		my $line = $_;
		$line =~ s/\,([A-Z])/\-$1/g;
		$line =~ s/\"//g;
		$line =~ s/\, / - /g;
		@cols = split(/,/, $line);

		my $cpts_allowed = undef;
		my $icd = $cols[0];
		if(exists $crosswalk{$icd})
		{
			my $cptsList = $crosswalk{$icd};
			$cpts_allowed = join(',', @$cptsList);
			$maxCptsInOneICD = scalar(@$cptsList) if scalar(@$cptsList) > $maxCptsInOneICD;
			$maxCptsColumnLength = length($cpts_allowed) if length($cpts_allowed) > $maxCptsColumnLength;
		}
		my $description;
		if(exists $icdDescr{$icd})
		{
			$description = $icdDescr{$icd};
		}
		push(@$data, [
			$icd,
			$cols[1],  # name
			$description || $cols[1],  # description
			BOOL($cols[2]),  # non_specific_code
			$cols[3],  # sex
			$cols[4],  # age
			$cols[5],  # major_diag_category
			BOOL($cols[6]),  # comorbidity_complication
			BOOL($cols[7]),  # medicare_secondary_payer
			BOOL($cols[8]),  # manifestation_code
			BOOL($cols[9]),  # questionable_admission
			BOOL($cols[10]), # unacceptable_primary_wo
			BOOL($cols[11]), # unacceptable_principal
			BOOL($cols[12]), # unacceptable_procedure
			BOOL($cols[13]), # non_specific_procedure
			BOOL($cols[14]), # non_covered_procedure
			$cpts_allowed,
			]);
		$count++;
		print "\rWrote information for $icd ($.)" if ($. % 2000) == 0;
	}
	$self->reportMsg("$count lines read from $icdEditFile") if $flags & DATAMANIPFLAG_SHOWPROGRESS;
	$self->reportMsg("Maximum CPTs in a single ICD: $maxCptsInOneICD (max length $maxCptsColumnLength)") if $flags & DATAMANIPFLAG_SHOWPROGRESS;

	close(ICDCPT);
	close(ICDEDIT);
}
