##############################################################################
package App::IntelliCode;
##############################################################################

use strict;
use Set::Scalar;
use DBI::StatementManager;
use App::Statements::IntelliCode;
use App::Statements::Catalog;
use Date::Calc qw(:all);
use App::Page::Search;
use App::Data::Manipulate;

use enum qw(BITMASK:INTELLICODEFLAG_ ICDARRAY ICDARRAYINDEX);

use enum qw(BITMASK:AGE_ ADULT MATERNAL NEWBORN PEDIATRIC);
use enum qw(:ICDFLAG_ INVALIDCPTLIST);
use enum qw(:CPTFLAG_ INVALIDCOMPOUNDLIST INVALIDMUTEXCLLIST);
use enum qw(:INTELLICODEERR_
	INVALIDICD
	INVALIDCPT
	PROCNOTALLOWED
	PROCMUTUALEXCLUSIVE
	COMPOUNDPROC
	NODIAGNOSISFORPROC
	INVALIDSEXFORICD
	INVALIDAGEFORICD
	INVALIDSEXFORCPT
	COMORBIDITYICD
	MEDICAREICD
	MANIFESTATIONICD
	QUESTIONABLEICD
	UNACCEPTABLEPRIMARYICD
	UNACCEPTABLEPRINCIPALICD
	UNACCEPTABLEPROCEDUREICD
	NONSPECIFICPROCEDUREICD
	NONCOVEREDPROCEDUREICD
	UNLISTEDCPT
	QUESTIONABLECPT
	ASCCPT
	NONREPCPT
	NONCOVCPT
	ICDNOTREFERENCED
	);

use vars qw(
	%ICD_CACHE
	%CPT_CACHE
	@ERROR_MESSAGES
	%SEX
	%AGE
);

use Devel::ChangeLog;
use vars qw(@CHANGELOG);

@ERROR_MESSAGES =
(
	"ICD '%s' is not a valid ICD",
	"CPT '%s' is not a valid CPT",
	"Procedure '%s' (%s) is not allowed with diagnosis '%s' (%s).",
	"Procedure '%s' (%s) is mutually exclusive with procedure '%s' (%s).",
	"CPT '%s' (%s) is a compound to procedure '%s' (%s).",
	"There is no diagnosis specified for procedure '%s'.",
	"Diagnosis '%s' (%s) is only applicable for '%s' patients.",
	"Diagnosis '%s' (%s) is only applicable for '%s' patients.",
	"Procedure '%s' (%s) is only applicable for '%s' patients.",
	"Diagnosis '%s' (%s) is a Comorbidity/Complication Code.",
	"Diagnosis '%s' (%s) is a Medicare-Secondary-Payer Code.",
	"Diagnosis '%s' (%s) is a Manifestation Code.",
	"Diagnosis '%s' (%s) is a Questionable-Admission Code.",
	"Diagnosis '%s' (%s) is an Unacceptable-Primary-Diagnosis-Without Code.",
	"Diagnosis '%s' (%s) is an Unacceptable-Principal Code.",
	"Diagnosis '%s' (%s) is an Unacceptable-Procedure Code.",
	"Diagnosis '%s' (%s) is an Non-specific-Procedure Code.",
	"Diagnosis '%s' (%s) is an Non-covered-Procedure Code.",
	"Procedure '%s' (%s) is an Unlisted Procedure.",
	"Procedure '%s' (%s) is a Questionable Procedure.",
	"Procedure '%s' (%s) is an ASC Procedure.",
	"Procedure '%s' (%s) is a Non-Rep Procedure.",
	"Procedure '%s' (%s) is a Non-Covered Procedure.",
	"There is no procedure associated with diagnosis '%s' (%s).",
);

undef %ICD_CACHE;
undef %CPT_CACHE;

%SEX = (
	'M' => 'Male',
	'F' => 'Female'
);

%AGE = (
	'N' => {flag => AGE_NEWBORN,   text => 'Newborn'},
	'P' => {flag => AGE_PEDIATRIC, text => 'Pediatric'},
	'M' => {flag => AGE_MATERNAL,  text => 'Maternal'},
	'A' => {flag => AGE_ADULT,     text => 'Adult'},
);

# validateCodes returns an array of Error Messages.  If no error, returns empty array.
sub validateCodes
{
	my ($page, $flags, %params) = @_;

	# The structure of the %params hash is as follows:
	# %params = (
	#   sex => 'M' or 'F'
	#   age => patient's age
	#   dateOfBirth => patient's date of birth ('mm/dd/yyyy').  This is ignored if age is given.
	#   diags => single ICD or reference to an array of ICDs
	#   procs => reference to an array of the following format
	#      [<CPT1 or HCPCS1>, <modifier1>, <diagnosis index(es)>]
	#      [<CPT2 or HCPCS2>, <modifier2>, <diagnosis index(es)>]
	#
	#  See AppSites\practice-management\debug\testIntelliCode.ppl for example.
	# );

	$flags = INTELLICODEFLAG_ICDARRAY unless $flags;

	my @errors = ();

	$page->{db}->{LongReadLen} = 8192;

	my $sex = $params{sex} || push(@errors, "The patient's Sex specification is required.");
	my $ageFlag = getAgeFlag($page, %params) || push(@errors, "The Patient's Age or valid Date of Birth is required");

	my $diags = $params{diags}; # this can be a scalar (one diagnosis) or ref to an array of scalars (multiple)
	unless($diags)
	{
		push(@errors,  "At least one diagnoisis is required");
		return;
	}

	# validate that all ICDs given are valid codes in the database
	validateDiags($page, $flags, \@errors, %params);

	# validate that all CPTs given are valid codes in the database
	validateProcs($page, $flags, \@errors, %params);

	# validate that each ICD is correct for the patient's age and sex
	icdEdits($page, $flags, $ageFlag, \@errors, %params);

	# validate that each CPT is valid for the specified diagnosis
	crossChecks($page, $flags, \@errors, %params);

	# List all mutually exclusive CPTs
	mutualExclusiveEdits($page, $flags, \@errors, %params);

	# List all comprehensive/compound CPTs
	compoundEdits($page, $flags, \@errors, %params);

	# validate that CPT is valid for patient's sex
	cptEdits($page, $flags, $ageFlag, \@errors, %params);

	return @errors;
}

sub getAgeFlag
{
	my ($page, %params) = @_;
	my ($age, $ageFlag) = (undef, undef);

	if (exists $params{age}) {
		$age = $params{age};
	}	elsif (my $dateOfBirth = $params{dateOfBirth}) {
		my ($mm, $dd, $yyyy);
		if($dateOfBirth =~ m/\//)
		{
			($mm, $dd, $yyyy) = split(/\//, $dateOfBirth);
		}
		else
		{
			($yyyy, $mm, $dd) = $dateOfBirth =~ m/^(\d\d\d\d)(\d\d)(\d\d)$/;
		}

		return undef unless check_date($yyyy, $mm, $dd);
		$age = int(Delta_Days($yyyy, $mm, $dd, Today())/365);
	}

	$ageFlag |= AGE_NEWBORN if $age < 1;
	$ageFlag |= AGE_PEDIATRIC if $age <= 17;
	$ageFlag |= AGE_ADULT if $age >= 14;
	$ageFlag |= AGE_MATERNAL if ($age >= 12 && $age <= 55 && $params{sex} eq 'F');

	return $ageFlag;
}

sub validateDiags
{
	my ($page, $flags, $errorRef, %params) = @_;
	my $diagsRef = (ref $params{diags} eq 'ARRAY') ? $params{diags} : [$params{diags}];

	for (@{$diagsRef})
	{
		my $icd = uc($_);
		
		unless ($ICD_CACHE{$icd}->{icd})
		{
			$ICD_CACHE{$icd} = $STMTMGR_INTELLICODE->getRowAsHash($page, STMTMGRFLAG_NONE,
				'selIcdData', $icd);

			if ($ICD_CACHE{$icd}->{icd})
			{
				my $hash = $ICD_CACHE{$icd};

				$hash->{flags} = 0 unless exists $hash->{flags};
				eval
				{
					$hash->{cpts_allowed} = new Set::Scalar(split(',', $hash->{cpts_allowed}));
				};
				if($@)
				{
					push(@$errorRef, "Unable to create cpts_allowed run_list for icd $icd: $@");
					$hash->{cpts_allowed} = new Set::Scalar();
					$hash->{flags} |= ICDFLAG_INVALIDCPTLIST;
				}
			}
		}

		push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_INVALIDICD], $icd)) unless ($ICD_CACHE{$icd}->{icd});
		push(@$errorRef, sprintf("Can not perform crosswalk check for ICD $icd (error loading set)")) if $CPT_CACHE{$icd}->{flags} & ICDFLAG_INVALIDCPTLIST;
	}
}

sub validateProcs
{
	my ($page, $flags, $errorRef, %params) = @_;
	my $procsRef = (ref $params{procs} eq 'ARRAY') ? $params{procs} : [[$params{procs}]];

	for (@$procsRef)
	{
		my $cpt = uc($_->[0]);

		unless ($CPT_CACHE{$cpt}->{cpt})
		{
			$CPT_CACHE{$cpt} = $STMTMGR_INTELLICODE->getRowAsHash($page, STMTMGRFLAG_NONE,
				'selCptData', $cpt);

			if ($CPT_CACHE{$cpt})
			{
				my $hash = $CPT_CACHE{$cpt};
				$hash->{flags} = 0 unless exists $hash->{flags};
				eval
				{
					$hash->{comprehensive_compound_cpts} = new Set::Scalar(split(',', $hash->{comprehensive_compound_cpts}));
				};
				if($@)
				{
					push(@$errorRef, "Unable to create comprehensive_compound_cpts run_list for cpt $cpt: $@");
					$hash->{comprehensive_compound_cpts} = new Set::Scalar();
					$hash->{flags} |= CPTFLAG_INVALIDCOMPOUNDLIST;
				}
				eval
				{
					$hash->{mutual_exclusive_cpts} = new Set::Scalar(split(',', $hash->{mutual_exclusive_cpts}));
				};
				if($@)
				{
					push(@$errorRef, "Unable to create mutual_exclusive_cpts run_list for cpt $cpt: $@");
					$hash->{mutual_exclusive_cpts} = new Set::Scalar();
					$hash->{flags} |= CPTFLAG_INVALIDMUTEXCLLIST;
				}
			}
		}

		push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_INVALIDCPT], $cpt)) unless ($CPT_CACHE{$cpt}->{cpt});
		push(@$errorRef, sprintf("Can not check comprehensive compounds CPTs list for CPT $cpt (error loading set)")) if $CPT_CACHE{$cpt}->{flags} & CPTFLAG_INVALIDCOMPOUNDLIST;
		push(@$errorRef, sprintf("Can not check mutually exclusive CPTs list for CPT $cpt (error loading set)")) if $CPT_CACHE{$cpt}->{flags} & CPTFLAG_INVALIDMUTEXCLLIST;
	}
}

sub crossChecks
{
	my ($page, $flags, $errorRef, %params) = @_;
	my $procsRef = (ref $params{procs} eq 'ARRAY') ? $params{procs} : [[$params{procs}]];

	my %diagReferenced = ();

	for (@$procsRef)
	{
		my ($cpt, $modifier) = (uc($_->[0]), $_->[1]);
		next unless ($CPT_CACHE{$cpt}->{cpt});
		
		my $count = scalar(@$_) -1;
		my @diags = @$_[2..$count];

		for my $icd (@diags)
		{
			$icd = App::Data::Manipulate::trim($icd);
			$icd = uc($icd);
			$diagReferenced{$icd} = 'true';

			my $icdHash = $ICD_CACHE{$icd};
			my $cptSet = $icdHash->{cpts_allowed};

			unless($cpt >= 99000 and $cpt <= 99999)
			{
				if (defined $cptSet && (! $cptSet->member($cpt)))
				{
					my $cptName = $CPT_CACHE{$cpt}->{name};
					my $icdName = $ICD_CACHE{$icd}->{name};
					push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_PROCNOTALLOWED],
						detailLink('cpt', $cpt), $cptName, detailLink('icd', $icd), $icdName));
				}
			}
		}
	}

	my $diagsRef = (ref $params{diags} eq 'ARRAY') ? $params{diags} : [$params{diags}];

	for my $icd (@{$diagsRef})
	{
		$icd = uc($icd);
		unless ($diagReferenced{$icd} eq 'true')
		{
			my $icdName = $ICD_CACHE{$icd}->{name};
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_ICDNOTREFERENCED], detailLink('icd', $icd), $icdName));
		}
	}
}

sub __crossChecks
{
	my ($page, $flags, $errorRef, %params) = @_;
	my $procsRef = (ref $params{procs} eq 'ARRAY') ? $params{procs} : [[$params{procs}]];

	my @diagReferenced = ();

	for (@$procsRef)
	{
		my ($cpt, $modifier) = ($_->[0], $_->[1]);
		next unless ($CPT_CACHE{$cpt}->{cpt});

		my $count = scalar(@$_);
		my @diagsIndexes = @$_[2..($count-1)];

		if (! @diagsIndexes)
		{
			my $diagsRef = (ref $params{diags} eq 'ARRAY') ? $params{diags} : [$params{diags}];
			if (scalar(@$diagsRef) > 1)
			{
				push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_NODIAGNOSISFORPROC], $cpt)) ;
			}
			else
			{
				my $icd = $params{diags};
				my $icdHash = $ICD_CACHE{$icd};
				my $cptSet = $icdHash->{cpts_allowed};
				if (defined $cptSet && (! $cptSet->member($cpt)))
				{
					my $cptName = $CPT_CACHE{$cpt}->{name};
					my $icdName = $ICD_CACHE{$icd}->{name};
					push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_PROCNOTALLOWED],
						detailLink('cpt', $cpt), $cptName, detailLink('icd', $icd), $icdName));
				}
			}
		}
		else
		{
			for my $index (@diagsIndexes)
			{
				#my $index_1 = $index -1;
				my $index_1 = $index;

				$diagReferenced[$index_1] = 'true';

				unless(ref $params{diags} eq 'ARRAY')
				{
					push(@$errorRef, "Diags is NOT an array reference.");
					return;
				}
				unless($params{diags}->[$index_1])
				{
					push(@$errorRef, "No diagnoses is provided for index '$index' of the diags array.");
					return;
				}

				my $icd = $params{diags}->[$index_1];
				my $icdHash = $ICD_CACHE{$icd};
				my $cptSet = $icdHash->{cpts_allowed};
				if (defined $cptSet && (! $cptSet->member($cpt)))
				{
					my $cptName = $CPT_CACHE{$cpt}->{name};
					my $icdName = $ICD_CACHE{$icd}->{name};
					push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_PROCNOTALLOWED],
						detailLink('cpt', $cpt), $cptName, detailLink('icd', $icd), $icdName));
				}
			}
		}
	}

	my $diagsRef = (ref $params{diags} eq 'ARRAY') ? $params{diags} : [$params{diags}];
	for my $i (0..(@$diagsRef)-1)
	{
		unless ($diagReferenced[$i])
		{
			my $icd = $diagsRef->[$i];
			my $icdName = $ICD_CACHE{$icd}->{name};
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_ICDNOTREFERENCED], detailLink('icd', $icd), $icdName));
		}
	}
}

sub mutualExclusiveEdits
{
	my ($page, $flags, $errorRef, %params) = @_;
	my $procsRef = (ref $params{procs} eq 'ARRAY') ? $params{procs} : [[$params{procs}]];

	for my $i (0..(@$procsRef)-1)
	{
		my ($cpt, $modifier) = ($procsRef->[$i]->[0], $procsRef->[$i]->[1]);

		for my $j (0..(@$procsRef -1))
		{
			my $cpt2 = $procsRef->[$j]->[0];
			my $cptSet = $CPT_CACHE{$cpt}->{mutual_exclusive_cpts};
			if (defined $cptSet && $cptSet->member($cpt2))
			{
				my $cptName = $CPT_CACHE{$cpt}->{name};
				my $cpt2Name = $CPT_CACHE{$cpt2}->{name};
				push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_PROCMUTUALEXCLUSIVE], detailLink('cpt',$cpt), $cptName,
					detailLink('cpt', $cpt2), $cpt2Name));
			}
		}
	}
}

sub compoundEdits
{
	my ($page, $flags, $errorRef, %params) = @_;
	my $procsRef = (ref $params{procs} eq 'ARRAY') ? $params{procs} : [[$params{procs}]];

	for my $i (0..(@$procsRef)-1)
	{
		my ($cpt, $modifier) = ($procsRef->[$i]->[0], $procsRef->[$i]->[1]);

		for my $j (0..(@$procsRef -1))
		{
			my $cpt2 = $procsRef->[$j]->[0];
			my $cptSet = $CPT_CACHE{$cpt}->{comprehensive_compound_cpts};
			if (defined $cptSet &&  $cptSet->member($cpt2))
			{
				my $cptName = $CPT_CACHE{$cpt}->{name};
				my $cpt2Name = $CPT_CACHE{$cpt2}->{name};
				push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_COMPOUNDPROC], detailLink('cpt', $cpt2), $cpt2Name,
					detailLink('cpt', $cpt), $cptName));
			}
		}
	}
}

sub icdEdits
{
	my ($page, $flags, $ageFlag, $errorRef, %params) = @_;
	my $diagsRef = (ref $params{diags} eq 'ARRAY') ? $params{diags} : [$params{diags}];

	for (@{$diagsRef})
	{
		my $icd = $_;
		my $icdSex = $ICD_CACHE{$icd}->{sex};
		my $icdAge = $ICD_CACHE{$icd}->{age};

		my $icdAgeFlag = $icdAge ? $AGE{$icdAge}->{flag} : $ageFlag;
		my $icdAgeText = $icdAge ? $AGE{$icdAge}->{text} : '';

		my $icdName = $ICD_CACHE{$icd}->{name};

		unless ($params{sex} =~ /$icdSex/i || (! $icdSex)) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_INVALIDSEXFORICD], detailLink('icd', $icd), $icdName, $SEX{$icdSex}));
		}
		unless ($icdAgeFlag & $ageFlag) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_INVALIDAGEFORICD], detailLink('icd', $icd), $icdName, $icdAgeText));
		}

		if ($ICD_CACHE{$icd}->{comorbidity_complication}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_COMORBIDITYICD], detailLink('icd', $icd), $icdName));
		}
		if ($ICD_CACHE{$icd}->{medicare_secondary_payer}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_MEDICAREICD], detailLink('icd', $icd), $icdName));
		}
		if ($ICD_CACHE{$icd}->{manifestation_code}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_MANIFESTATIONICD], detailLink('icd', $icd), $icdName));
		}
		if ($ICD_CACHE{$icd}->{questionable_admission}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_QUESTIONABLEICD], detailLink('icd', $icd), $icdName));
		}
		if ($ICD_CACHE{$icd}->{unacceptable_primary_wo}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_UNACCEPTABLEPRIMARYICD], detailLink('icd', $icd), $icdName));
		}
		if ($ICD_CACHE{$icd}->{unacceptable_principal}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_UNACCEPTABLEPRINCIPALICD], detailLink('icd', $icd), $icdName));
		}
		if ($ICD_CACHE{$icd}->{unacceptable_procedure}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_UNACCEPTABLEPROCEDUREICD], detailLink('icd', $icd), $icdName));
		}
		if ($ICD_CACHE{$icd}->{non_specific_procedure}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_NONSPECIFICPROCEDUREICD], detailLink('icd', $icd), $icdName));
		}
		if ($ICD_CACHE{$icd}->{non_covered_procedure}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_NONCOVEREDPROCEDUREICD], detailLink('icd', $icd), $icdName));
		}
	}
}

sub cptEdits
{
	my ($page, $flags, $ageFlag, $errorRef, %params) = @_;
	my $procsRef = (ref $params{procs} eq 'ARRAY') ? $params{procs} : [[$params{procs}]];

	for (@$procsRef)
	{
		my ($cpt, $modifier) = ($_->[0], $_->[1]);
		my $cptSex = $CPT_CACHE{$cpt}->{sex};
		my $cptName = $CPT_CACHE{$cpt}->{name};

		unless ($params{sex} =~ /$cptSex/i || (! $cptSex)) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_INVALIDSEXFORCPT], detailLink('cpt', $cpt), $cptName, $SEX{$cptSex}));
		}
		if ($CPT_CACHE{$cpt}->{unlisted}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_UNLISTEDCPT], detailLink('cpt', $cpt), $cptName));
		}
		if ($CPT_CACHE{$cpt}->{questionable}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_QUESTIONABLECPT], detailLink('cpt', $cpt), $cptName));
		}
		if ($CPT_CACHE{$cpt}->{asc_}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_ASCCPT], detailLink('cpt', $cpt), $cptName));
		}
		if ($CPT_CACHE{$cpt}->{non_rep}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_NONREPCPT], detailLink('cpt', $cpt), $cptName));
		}
		if ($CPT_CACHE{$cpt}->{non_cov}) {
			push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_NONCOVCPT], detailLink('cpt', $cpt), $cptName));
		}
	}
}

sub detailLink
{
	my ($type, $code) = @_;

	return qq{
		<a HREF="javascript:chooseItem2('/lookup/$type/detail/$code', $code, true)"
			STYLE="text-decoration:none"> $code </a>
	};
}

sub incrementUsage
{
	my ($page, $type, $codesRef, $person_id, $org_id) = @_;

	my $selName1 = "sel" . ucfirst(lc($type)) . "Usage1";
	my $selName2 = "sel" . ucfirst(lc($type)) . "Usage2";

	my $updName1 = "upd" . ucfirst(lc($type)) . "Usage1";
	my $updName2 = "upd" . ucfirst(lc($type)) . "Usage2";

	my $insName = "ins" . ucfirst(lc($type)) . "Usage";

	for my $code (@$codesRef)
	{
		if ($STMTMGR_INTELLICODE->recordExists($page, STMTMGRFLAG_NONE, $selName1, $code, $person_id, $org_id))
		{
			$STMTMGR_INTELLICODE->execute($page, STMTMGRFLAG_NONE, $updName1, $code, $person_id, $org_id);
		}
		else
		{
			$STMTMGR_INTELLICODE->execute($page, STMTMGRFLAG_NONE, $insName, $code, $person_id, $org_id);
		}

		if ($STMTMGR_INTELLICODE->recordExists($page, STMTMGRFLAG_NONE, $selName2, $code, $org_id))
		{
			$STMTMGR_INTELLICODE->execute($page, STMTMGRFLAG_NONE, $updName2, $code, $org_id);
		}
		else
		{
			$STMTMGR_INTELLICODE->execute($page, STMTMGRFLAG_NONE, $insName, $code, undef, $org_id);
		}
	}
}

sub isLabProc
{
	my ($page, $codes) = @_;

	return '';
}

sub getItemCost
{
	my ($page, $cpt, $modifier, $fsRef) = @_;
	my @buffer = ();

	for my $i (0..(@$fsRef -1))
	{
		my $fs = $fsRef->[$i];
		
		my $entries = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'sel_catalogEntryByCpt_Catalog', $cpt, $modifier, $fs);
	
		for my $entry (@{$entries})
		{
			push(@buffer, [$fs, $entry]);
		}
	}
	
	return \@buffer;
}

sub _getItemCost
{
	my ($page, $cpt, $modifier, $fsRef) = @_;
	my @buffer = ();

	for my $i (0..(@$fsRef -1))
	{
		my $fs = $fsRef->[$i];
		
		my $entries = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'sel_catalogEntryByCpt_Catalog', $cpt, $modifier, $fs);
	
		for my $entry (@{$entries})
		{
			push(@buffer, [$fs, $entry->{unit_cost}]);
		}
	}
	
	if (scalar @buffer == 0)
	{
		return (2, "No price found for this Code/Modifier/Fee_Schedule combination.");		
	}
	elsif (scalar @buffer == 1)
	{
		return (0, $buffer[0]->[1]);
	}
	else 
	{
		return (1, \@buffer);
	}
}

sub __getItemCost
{
	my ($page, $codesRef, $orgId, $insId) = @_;

	my $itemGrpType = App::Universal::CATALOGENTRYTYPE_ITEMGRP;
	my $cptType = App::Universal::CATALOGENTRYTYPE_CPT;

	my @return = ();

	foreach my $code (@$codesRef)
	{
		$page->addDebugStmt("Code: $code");
		if(my $foundCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'selCatalogItemsByCodeAndType', $code, $cptType))
		{
			my $idx = 0;
			my @price = ();
			foreach my $foundCode (@{$foundCodes})
			{
				my $parentCatalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
					'selCatalogById', $foundCode->{catalog_id});
				if($parentCatalog->{org_id} eq $orgId || $parentCatalog->{org_id} eq '')
				{
					$page->addDebugStmt("Orgs are the same");
					$idx += 1;
					if($idx > 1)
					{
						$page->addDebugStmt("Error: Code $code was found more than once for $orgId.");
					}
					else
					{
						@price = ($foundCode->{catalog_id}, $foundCode->{unit_cost});
						push(@return, \@price);
					}
				}
			}
		}

		if(my $foundExplCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'selCatalogItemsByCodeAndType', $code, $itemGrpType))
		{
			my $idx = 0;
			foreach my $foundExplCode (@{$foundExplCodes})
			{
				my $parentCatalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
					'selCatalogById', $foundExplCode->{catalog_id});
				if($parentCatalog->{org_id} eq $orgId || $parentCatalog->{org_id} eq '')
				{
					$idx += 1;
					if($idx > 1)
					{
						$page->addDebugStmt("Error: There are $idx explosion codes for $orgId.");
					}
					else
					{
						my $explCodeEntries = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selCatalogItemsByParentItem', $foundExplCode->{entry_id});
						push(@return, $explCodeEntries);
					}
				}
			}
		}
	}

	return \@return;

	#foreach my $code (@$codesRef)
	#{
	#	#parent catalog
	#	my $catalogs = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selParentCatalogByOrgId', $org_id);
	#	foreach my $catalog(@{$catalogs})
	#	{
	#		#parent catalog entries
	#		my $parentCatalogEntries = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selCPTCatalogItems', $catalog->{catalog_id}, $itemGrpType, $cptType);
	#		foreach my $parentCatalogEntry (@{$parentCatalogEntries})
	#		{
	#			if($parentCatalogEntry->{entry_type} == $cptType)
	#			{
	#				if($parentCatalogEntry->{code} eq $code)
	#				{
	#					#push();
	#				}
	#			}
	#			elsif($parentCatalogEntry->{entry_type} == $itemGrpType)
	#			{
	#				my $parentCatalogEntrysEntries = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selCatalogItemsByParent', $parentCatalogEntry->{entry_id}, $itemGrpType, $cptType);
	#				foreach my $parentCatalogEntrysEntry (@{$parentCatalogEntrysEntries})
	#				{
	#					if($parentCatalogEntry->{code} eq $code)
	#					{
	#						#push();
	#					}
	#				}
	#			}
	#		}
	#
	#		#parent catalog's child catalogs
	#		my $childCatalogs = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selChildrenCatalogs', $catalog->{catalog_id});
	#		foreach my $childCatalog (@{$childCatalogs})
	#		{
	#			#child catalog's entries
	#			my $catItems = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selCPTCatalogItems', $childCatalog->{catalog_id}, $itemGrpType, $cptType);
	#			foreach my $item(@{$catItems})
	#			{
	#				#child catalog's entries's entries
	#				my $childCatItems = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selCatalogItemsByParent', $item->{parent_entry_id}, $itemGrpType, $cptType);
	#			}
	#		}
	#	}
	#}
}

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/25/2000', 'TVN',
		'IntelliCode',
		'Receive array of ICD codes for each procedure.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/21/2000', 'TVN',
		'IntelliCode',
		'Added check for unreferenced ICD.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/20/2000', 'TVN',
		'IntelliCode',
		'Optimized for maximum performance when incrementUsage.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/06/2000', 'TVN',
			'IntelliCode',
		'Completed Hyper-Link Codes to Detailed Search.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/07/2000', 'TVN',
			'IntelliCode',
		'Implement additional CPT and ICD edits.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/08/2000', 'TVN',
			'IntelliCode',
		'Completed CPT and ICD edits.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/14/2000', 'TVN',
		'IntelliCode',
		'Added sub incrementUsage to increment read_counts of the Ref_xxx_Usage tables.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '03/30/2000', 'MAF',
		'IntelliCode',
		'Added sub getItemCost to return cost of cpt code or all explosion code entries.'],

);


1;

#1. create tables to store crosswalk data (CD-ROM:/CPTICD1/CPT-ICD1)
#2. create tables to store ICD edits (CD-ROM:/ICDEDITS/Icd1Edit.txt)
#3. create tables to store CPT edits
#   a. Comprehensive and Compound Procedures Data (Floppy:/A_CPEDIT.TXT)
#   b. Mutually Exclusive CPTs (Floppy:/C_MEEDIT.TXT)
#(4. in the future, well add the RBRVS data tables)
#5. create App::Data::Obtain::XXXX for each of the new tables/files
#6. add the new App::Data::Obtain::XXXX to p:\database\refdata\transform.pl

#7. implement minimal set of features in sub validateCodes
#8. work with munir to "wire-up" the claims front-end with the new tables, functions

# this can be a scalar (if it is, then $diags must be a scalar) or a reference to an array of the following format
# [<CPT1 or HCPCS1>, <modifier1>, <diagnosis index(es)>]
# [<CPT2 or HCPCS2>, <modifier2>, <diagnosis index(es)>]

# check for:
# * valid ICD-9 code (from REF_ICD)
# * valid CPT code (from REF_ICD)
# * valid ICD-9 edits (based on sex, dateofbirth/age, etc)
# * valid ICD-9 primary diagnosis (based on ICD Edits)
# * valid ICD-9 modifiers (do we have the data?)
# * valid CPT edits (based on sex, dateofbirth/age, etc) -- NTIS
# * ICD/ICD exclusions (does one ICD exclude another?)
# * CPT/CPT exclusions (does one CPT exclude another?)
# * CPT/ICD exclusions (crosswalk) [diagnosis codes must support procedure codes]
# + RBRVS data (can the dollar amount be charged for given state/procedure)
