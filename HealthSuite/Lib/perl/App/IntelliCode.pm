##############################################################################
package App::IntelliCode;
##############################################################################

use strict;
use Set::Scalar;
use DBI::StatementManager;
use App::Statements::IntelliCode;
use App::Statements::Search::Code;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Catalog;
use Date::Calc qw(:all);
use Date::Manip;
use App::Page::Search;
use App::Data::Manipulate;
use Exporter ();

use enum qw(BITMASK:INTELLICODEFLAG_ ICDARRAY ICDARRAYINDEX SKIPWARNING 
	NON_FACILITY_PRICING
	FACILITY_PRICING
);

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
	DOBREQUIRED
	SSNREQUIRED
	);

use vars qw(
	%ICD_CACHE
	%CPT_CACHE
	@ERROR_MESSAGES
	%SEX
	%AGE
);

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
	"Date of Birth for %s is required for electronic claim submission.",
	"SSN for %s is required for electronic claim submission."
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
use vars qw(@ISA @EXPORT $INTELLICODE_FS_COST $INTELLICODE_FS_SERV_TYPE $INTELLICODE_FS_CODE_TYPE $INTELLICODE_FS_ID_NUMERIC $INTELLICODE_FS_ID_TEXT
		$INTELLICODE_FS_FFS_CAP $INTELLICODE_FS_COST $INTELLICODE_FS_SERV_CAPTION);

@ISA = qw(Exporter);
@EXPORT = qw($STMTMGR_CATALOG $INTELLICODE_FS_COST $INTELLICODE_FS_SERV_TYPE $INTELLICODE_FS_CODE_TYPE $INTELLICODE_FS_ID_NUMERIC $INTELLICODE_FS_ID_TEXT
		$INTELLICODE_FS_FFS_CAP $INTELLICODE_FS_COST $INTELLICODE_FS_SERV_CAPTION);

$INTELLICODE_FS_ID_NUMERIC = 0;
$INTELLICODE_FS_COST = 1;
$INTELLICODE_FS_SERV_TYPE =2;
$INTELLICODE_FS_SERV_CAPTION = 3;
$INTELLICODE_FS_CODE_TYPE =4;
$INTELLICODE_FS_ID_TEXT =5;
$INTELLICODE_FS_FFS_CAP =6;
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

	#$flags = INTELLICODEFLAG_ICDARRAY unless $flags;

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

	# validate NSF errors
	validateNSF($page, $flags, \@errors, %params) if defined $params{personId};
	#validateNSF($page, $flags, \@errors, %params);

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

sub validateNSF
{
	my ($page, $flags, $errorRef, %params) = @_;
	
	my $personId = $params{personId};
	my $personInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE,	'selRegistry', $personId);
	
	push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_DOBREQUIRED], personLink($personId))) 
		unless $personInfo->{date_of_birth};
		
	push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_SSNREQUIRED], personLink($personId)))
		unless $personInfo->{ssn};
}

sub getNSFerrorCount
{
	my ($page, $invoiceId, $personId) = @_;
	
	my @errors = ();
	validateNSF($page, 0, \@errors, personId => $personId);
	
	return scalar(@errors);
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
	return if $flags & INTELLICODEFLAG_SKIPWARNING;
	
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
			else
			{
				$CPT_CACHE{$cpt} = $STMTMGR_HCPCS_CODE_SEARCH->getRowAsHash
					($page, STMTMGRFLAG_NONE, 'sel_hcpcs_code', $cpt);
			}
		}

		push(@$errorRef, sprintf($ERROR_MESSAGES[INTELLICODEERR_INVALIDCPT], $cpt))
			unless ($CPT_CACHE{$cpt}->{cpt} || $CPT_CACHE{$cpt}->{hcpcs});
		push(@$errorRef, sprintf("Can not check comprehensive compounds CPTs list for CPT $cpt (error loading set)")) if $CPT_CACHE{$cpt}->{flags} & CPTFLAG_INVALIDCOMPOUNDLIST;
		push(@$errorRef, sprintf("Can not check mutually exclusive CPTs list for CPT $cpt (error loading set)")) if $CPT_CACHE{$cpt}->{flags} & CPTFLAG_INVALIDMUTEXCLLIST;
	}
}

sub crossChecks
{
	my ($page, $flags, $errorRef, %params) = @_;
	return if $flags & INTELLICODEFLAG_SKIPWARNING;

	my $procsRef = (ref $params{procs} eq 'ARRAY') ? $params{procs} : [[$params{procs}]];

	my %diagReferenced = ();

	for (@$procsRef)
	{
		my ($cpt, $modifier) = (uc($_->[0]), $_->[1]);
		next unless ($CPT_CACHE{$cpt}->{cpt} || $CPT_CACHE{$cpt}->{hcpcs});

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

	return if $flags & INTELLICODEFLAG_SKIPWARNING;

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

sub mutualExclusiveEdits
{
	my ($page, $flags, $errorRef, %params) = @_;
	return if $flags & INTELLICODEFLAG_SKIPWARNING;

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
	return if $flags & INTELLICODEFLAG_SKIPWARNING;

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

		return if $flags & INTELLICODEFLAG_SKIPWARNING;

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

		return if $flags & INTELLICODEFLAG_SKIPWARNING;

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

sub personLink
{
	my ($personId) = @_;

	return qq{
		<a HREF='/person/$personId/profile' STYLE="text-decoration:none">$personId</a>
	};
}

sub detailLink
{
	my ($type, $code) = @_;

	return qq{
		<a HREF="javascript:chooseItem2('/lookup/$type/detail/$code', '$code', true)"
			STYLE="text-decoration:none"> $code </a>
	};
}

sub incrementUsage
{
	my ($page, $type, $codesRef, $person_id, $org_internal_id) = @_;
	return;
}

sub __incrementUsage
{
	my ($page, $type, $codesRef, $person_id, $org_internal_id) = @_;

	my $selName1 = "sel" . ucfirst(lc($type)) . "Usage1";
	my $selName2 = "sel" . ucfirst(lc($type)) . "Usage2";

	my $updName1 = "upd" . ucfirst(lc($type)) . "Usage1";
	my $updName2 = "upd" . ucfirst(lc($type)) . "Usage2";

	my $insName = "ins" . ucfirst(lc($type)) . "Usage";

	for my $code (@$codesRef)
	{
		if ($type eq 'Icd')
		{
			next unless $ICD_CACHE{$code}->{icd};
		}
		elsif ($type eq 'Cpt')
		{
			next unless $CPT_CACHE{$code}->{cpt};
		}

		if ($STMTMGR_INTELLICODE->recordExists($page, STMTMGRFLAG_NONE, $selName1, $code, $person_id, $org_internal_id))
		{
			$STMTMGR_INTELLICODE->execute($page, STMTMGRFLAG_NONE, $updName1, $code, $person_id, $org_internal_id);
		}
		else
		{
			$STMTMGR_INTELLICODE->execute($page, STMTMGRFLAG_NONE, $insName, $code, $person_id, $org_internal_id);
		}

		if ($STMTMGR_INTELLICODE->recordExists($page, STMTMGRFLAG_NONE, $selName2, $code, $org_internal_id))
		{
			$STMTMGR_INTELLICODE->execute($page, STMTMGRFLAG_NONE, $updName2, $code, $org_internal_id);
		}
		else
		{
			$STMTMGR_INTELLICODE->execute($page, STMTMGRFLAG_NONE, $insName, $code, undef, $org_internal_id);
		}
	}
}

sub isLabProc
{
	my ($page, $codes) = @_;

	return '';
}


#pulls information from assoicated Fee Schedules about the proceudre
#Info includes: Price, Service Type (Lab,X-Ray,etc), Code Type (EPSDT,CPT,etc), flag (cap, ffs),Fee used
sub getFSEntry
{
	my ($page, $cpt, $modifier,$serviceDate, $fsRef, $flags) = @_;

	my @buffer = ();
	
	#fsRef holds hierarchal list of FS, could be multiple FS on each level
	foreach my $fsList (@$fsRef)
	{
		#if procedure is found in a FS then do not check for hit at lower level in the hierarchy
		next if scalar(@buffer);

		#split list in case we have multiple FS at the same level in hierarchy
		my @fsArray = split(/\s*,\s*/,$fsList);		
		foreach my $fs (@fsArray)							
		{			
			getEntry($page, $cpt, $modifier,$serviceDate, \@buffer, $fs);		
		}	
	}
	#Try FFS FS if procedure is not found
	getFFS($page, $cpt, $modifier,$serviceDate, \@buffer) unless scalar(@buffer);
	return \@buffer;	
}

#Attempts to find procedure in  default FS 'FFS'
sub getFFS
{
	my ($page, $cpt, $modifier, $serviceDate,$bufferRef) = @_;
	my $orgId = $page->session('org_internal_id');
	my $ffs = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_catalog_by_id_orgId', 'FFS', $orgId);
	getEntry($page, $cpt, $modifier, $serviceDate,$bufferRef, $ffs->{internal_catalog_id} , 1) if $ffs->{internal_catalog_id};
}

#Attempts to find procedure information in Fee Schedule
sub getEntry
{
	my ($page, $cpt, $modifier,$serviceDate, $bufferRef, $fs,$ffsFlag) = @_;	
	my $orgId = $page->session('org_internal_id');

	my $entry = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,'selProcedureInfoByCodeModDate', $cpt, $modifier, $fs,$serviceDate);	
	push(@{$bufferRef}, [$fs, sprintf("%.2f", $entry->{unit_cost}), $entry->{data_text},$entry->{caption} ,$entry->{entry_type},
			     $entry->{catalog_id},$ffsFlag || $entry->{flags} ]) if exists $entry->{internal_catalog_id};
}




sub getItemCost
{
	my ($page, $cpt, $modifier, $fsRef, $flags) = @_;

	$flags |= INTELLICODEFLAG_NON_FACILITY_PRICING 
		unless $flags & INTELLICODEFLAG_FACILITY_PRICING;

	my @buffer = ();

	for my $i (0..(@$fsRef -1))
	{
		my $fs = $fsRef->[$i];
		getItemPrice($page, $cpt, $modifier, \@buffer, $fs);
	}

	calcRVRBS($page, $cpt, $modifier, $fsRef, \@buffer, $flags) unless scalar(@buffer);
	defaultToFFS($page, $cpt, $modifier, \@buffer) unless scalar(@buffer);
		
	return \@buffer;
}

sub getSvcType
{
	my ($page, $cpt, $modifier, $fsRef, $flags) = @_;
	
	my @buffer = ();
	for my $i (0..(@$fsRef -1))
		{
			my $fs = $fsRef->[$i];
			getType($page, $cpt, $modifier, \@buffer, $fs);
	}
	useFFSvcType($page, $cpt, $modifier, \@buffer) unless scalar(@buffer);
	return \@buffer;
}

sub getType
{
	my ($page, $cpt, $modifier, $bufferRef, $fs, $ffsFlag) = @_;		
	my $entry;
	if ($modifier)
	{
		$entry = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_catalogEntry_svcType_by_code_modifier_catalog', $cpt, $modifier, $fs
		);
	}
	else
	{
		$entry = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_catalogEntry_svcType_by_catalog', $cpt, $fs);
	}
	push(@{$bufferRef}, [$fs,$entry->{data_text},$entry->{caption} ,$entry->{entry_type},$entry->{catalog_id}]) if exists $entry->{data_text};	
}


sub getItemPrice
{
	my ($page, $cpt, $modifier, $bufferRef, $fs, $ffsFlag) = @_;
	
	my $orgId = $page->session('org_internal_id');

	my $entry;
	if ($modifier)
	{
		$entry = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_catalogEntry_by_code_modifier_catalog', $cpt, $modifier, $fs
		);
	}
	else
	{
		$entry = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_catalogEntry_by_code_catalog', $cpt, $fs);
	}

	push(@{$bufferRef}, [$fs, sprintf("%.2f", $entry->{unit_cost}), 
		$ffsFlag || $entry->{flags} ]) if exists $entry->{unit_cost};
}

sub useFFSvcType
{
	my ($page, $cpt, $modifier, $bufferRef) = @_;
	my $orgId = $page->session('org_internal_id');
	my $ffs = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_catalog_by_id_orgId', 'FFS', $orgId);
	if (my $fs = $ffs->{internal_catalog_id})
	{
		getType($page, $cpt, $modifier, $bufferRef, $fs, 1);
	}
}

sub defaultToFFS
{
	my ($page, $cpt, $modifier, $bufferRef) = @_;
	
	my $orgId = $page->session('org_internal_id');
	my $ffs = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_catalog_by_id_orgId', 'FFS', $orgId);
		
	if (my $fs = $ffs->{internal_catalog_id})
	{
		getItemPrice($page, $cpt, $modifier, $bufferRef, $fs, 1);
	}
}

sub calcRVRBS
{
	my ($page, $cpt, $modifier, $fsRef, $bufferRef, $flags) = @_;
	
	my $orgId = $page->param('org_internal_id') || $page->session('org_internal_id');
	my $today = UnixDate('today', '%m/%d/%Y');
	my $gpciItemName = 'Medicare GPCI Location';
	
	my $org = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute',	$orgId, $gpciItemName);
	my $gpciId = $org->{value_text};
	$flags |= INTELLICODEFLAG_FACILITY_PRICING if $org->{value_int};
	
	my $gpci = $STMTMGR_INTELLICODE->getRowAsHash($page, STMTMGRFLAG_NONE, 'sel_gpci', $gpciId);
	
	my $pfs;
	if ($modifier)
	{
		$pfs = $STMTMGR_INTELLICODE->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_pfs_rvu_by_code_modifier', $cpt, $modifier, $today);
	}
	else
	{
		$pfs = $STMTMGR_INTELLICODE->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_pfs_rvu_by_code', $cpt, $today);
	}

	my $rvrbsPrice;
	if ($flags & INTELLICODEFLAG_NON_FACILITY_PRICING)
	{
		$rvrbsPrice = (
			($pfs->{work_rvu} * $gpci->{work}) + 
			($pfs->{trans_non_fac_pe_rvu} * $gpci->{practice_expense}) + 
			($pfs->{mal_practice_rvu} * $gpci->{mal_practice}) 
		) * $pfs->{conversion_fact};
	}
	else
	{
		$rvrbsPrice = (
			($pfs->{work_rvu} * $gpci->{work}) + 
			($pfs->{trans_fac_pe_rvu} * $gpci->{practice_expense}) + 
			($pfs->{mal_practice_rvu} * $gpci->{mal_practice}) 
		) * $pfs->{conversion_fact};
	}
	
	if ($rvrbsPrice > 0)
	{
		for my $fs (@{$fsRef})
		{
			my $fsHash = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selCatalogById', $fs);
			push(@{$bufferRef}, ['RVRBS', sprintf("%.2f", $rvrbsPrice * $fsHash->{rvrbs_multiplier})]) 
				if defined $fsHash->{rvrbs_multiplier};
		}
	}
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

1;