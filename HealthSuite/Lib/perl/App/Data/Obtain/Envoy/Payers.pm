##############################################################################
package App::Data::Obtain::Envoy::Payers;
##############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain::Word;
use Exporter;
use vars qw(@ISA @EXPORT $VERSION);

use constant ENVOYPAYERTYPE_COMMERCIAL => 100;
use constant ENVOYPAYERTYPE_BCBS       => 200;
use constant ENVOYPAYERTYPE_MEDICARE   => 300;
use constant ENVOYPAYERTYPE_MEDICAID   => 400;

use enum qw(BITMASK:ENVOYPAYERFLAG_
	CLAIMS_SERVICE
	ENCOUNTERS_SERVICE
	GROUP_POLICY_NUM_REQUIRED
	CLAIM_OFFICE_NUM_REQUIRED
	GROUP_POLICY_NUM_SUGGESTED
	CLAIM_OFFICE_NUM_SUGGESTED
	PRIOR_TESTING_REQUIRED
	ENROLLMENT_REQUIRED
	ADDITIONAL_INSTRUCTIONS
	CALL_FOR_ID
	PILOT_STAGE
	);

@EXPORT = qw(
	ENVOYPAYERFLAG_CLAIMS_SERVICE
	ENVOYPAYERFLAG_ENCOUNTERS_SERVICE
	ENVOYPAYERFLAG_GROUP_POLICY_NUM_REQUIRED
	ENVOYPAYERFLAG_CLAIM_OFFICE_NUM_REQUIRED
	ENVOYPAYERFLAG_GROUP_POLICY_NUM_SUGGESTED
	ENVOYPAYERFLAG_CLAIM_OFFICE_NUM_SUGGESTED
	ENVOYPAYERFLAG_PRIOR_TESTING_REQUIRED
	ENVOYPAYERFLAG_ENROLLMENT_REQUIRED
	ENVOYPAYERFLAG_ADDITIONAL_INSTRUCTIONS
	ENVOYPAYERFLAG_CALL_FOR_ID
	ENVOYPAYERFLAG_PILOT_STAGE
	);

@ISA = qw(Exporter App::Data::Obtain::Word);
$VERSION = "1.00";

sub process
{
	my ($self, $flags, $collection, $params, $msWord, $document) = @_;

	unless($params->{srcCommercial} && $params->{srcBCBS} && $params->{srcMedicare} && $params->{srcMedicaid})
	{
		$self->addError("srcCommercial, srcBCBS, srcMedicare, and srcMedicaid parameters are required");
		return;
	}

	$self->{list_commercial} = [];
	$self->{list_bcbs} = [];
	$self->{list_medicare} = [];
	$self->{list_medicaid} = [];

	my $srcCommercial = "$params->{srcCommercial}$$.txt";
	my $srcBCBS = "$params->{srcBCBS}$$.txt";
	my $srcMedicare = "$params->{srcMedicare}$$.txt";
	my $srcMedicaid = "$params->{srcMedicaid}$$.txt";

	$self->reportMsg("Extracting Commercial Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
	$self->extractTable($flags, $msWord, $params->{srcCommercial}, 1, $srcCommercial);
	$self->reportMsg("Extracting BCBS Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
	$self->extractTable($flags, $msWord, $params->{srcBCBS}, 1, $srcBCBS);
	$self->reportMsg("Extracting Medicare Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
	$self->extractTable($flags, $msWord, $params->{srcMedicare}, 1, $srcMedicare);
	$self->reportMsg("Extracting Medicaid Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
	$self->extractTable($flags, $msWord, $params->{srcMedicaid}, 1, $srcMedicaid);

	if($self->haveErrors() == 0)
	{
		$self->reportMsg("Loading Commercial Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
		$self->obtainCommercial($flags, $collection, srcFile => $srcCommercial);
		$self->reportMsg("Loading BCBS Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
		$self->obtainBCBS($flags, $collection, srcFile => $srcBCBS);
		$self->reportMsg("Loading Medicare Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
		$self->obtainMedicare($flags, $collection, srcFile => $srcMedicare);
		$self->reportMsg("Loading Medicaid Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
		$self->obtainMedicaid($flags, $collection, srcFile => $srcMedicaid);
	}

	$self->reportMsg("Deleting temporary files.") if $flags & DATAMANIPFLAG_VERBOSE;
	unlink($srcCommercial);
	unlink($srcBCBS);
	unlink($srcMedicare);
	unlink($srcMedicaid);
}

sub getFlags
{
	my ($self, $id, $card, $enroll, $test, $services, $addl) = @_;

	$id = lc($id);
	$card = uc(App::Data::Manipulate::trim($card));
	$enroll = lc(App::Data::Manipulate::trim($enroll));
	$test = lc($test) if $test;
	$services = lc(App::Data::Manipulate::trim($services));

	my $flags = 0;
	$flags |= ENVOYPAYERFLAG_CALL_FOR_ID if $id eq 'call';
	$flags |= ENVOYPAYERFLAG_PILOT_STAGE if $id eq 'pilot';
	$flags |= ENVOYPAYERFLAG_GROUP_POLICY_NUM_REQUIRED if $card eq 'C' || $card eq 'N';
	$flags |= ENVOYPAYERFLAG_GROUP_POLICY_NUM_SUGGESTED if $card eq 'B';
	$flags |= ENVOYPAYERFLAG_CLAIM_OFFICE_NUM_REQUIRED if $card eq 'C';
	$flags |= ENVOYPAYERFLAG_CLAIM_OFFICE_NUM_SUGGESTED if $card eq 'N';
	$flags |= ENVOYPAYERFLAG_ENROLLMENT_REQUIRED if $enroll eq 'yes';
	$flags |= ENVOYPAYERFLAG_CLAIMS_SERVICE if $services eq 'claims';
	$flags |= ENVOYPAYERFLAG_ENCOUNTERS_SERVICE if $services eq 'encounters';
	$flags |= ENVOYPAYERFLAG_PRIOR_TESTING_REQUIRED if $test && $test eq 'yes';
	$flags |= ENVOYPAYERFLAG_ADDITIONAL_INSTRUCTIONS if $addl;

	return $flags;
}

sub obtainCommercial
{
	my ($self, $flags, $collection, %params) = @_;

	my $list = $self->{list_commercial};
	my $all = $collection->getDataRows();

	my $srcFile = $params{srcFile} || die "srcFile parameter not provided to obtainCommercial\n";
	my $delim = $params{colDelim} || "\t";

	open(SRCFILE, $srcFile) || die "[obtainCommercial] srcFile '$srcFile' not found\n";

	$self->reportMsg("Loading $params{srcFile}.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $header = <SRCFILE>;
	while(<SRCFILE>)
	{
		my ($reserved, $payer, $id, $card, $enroll, $services, $addl) = split(/$delim/);

		$payer = App::Data::Manipulate::trim($payer);
		next unless $payer;

		$id = App::Data::Manipulate::trim($id);
		$addl = App::Data::Manipulate::trim($addl);

		my $flags = $self->getFlags($id, $card, $enroll, undef, $services, $addl);
		my $row = [
			$id =~ /^(call|pilot)$/i ? '' : $id,
			$payer,
			ENVOYPAYERTYPE_COMMERCIAL,
			'',  # 'state' not used here
			$flags,
			$addl,
			];
		push(@$list, $row);
		push(@$all, $row);
	}
	close(SRCFILE);
}

sub obtainGovernment
{
	my ($self, $flags, $collection, $listName, $payType, %params) = @_;
	my $list = $self->{"list_$listName"};
	my $all = $collection->getDataRows();

	my $srcFile = $params{srcFile} || die "srcFile parameter not provided to obtainCommercial\n";
	my $delim = $params{colDelim} || "\t";

	open(SRCFILE, $srcFile) || die "[obtainGovernment] srcFile '$srcFile' not found\n";

	$self->reportMsg("Loading $params{srcFile}") if $flags & DATAMANIPFLAG_VERBOSE;
	my $header = <SRCFILE>;
	while(<SRCFILE>)
	{
		my ($state, $reserved, $payer, $id, $card, $enroll, $test, $services, $addl) = split(/$delim/);

		$payer = App::Data::Manipulate::trim($payer);
		next unless $payer;

		$state = uc($state);
		$id = App::Data::Manipulate::trim($id);
		$addl = App::Data::Manipulate::trim($addl);

		my $flags = $self->getFlags($id, $card, $enroll, undef, $services, $addl);
		my $row = [
			$id =~ /^(call|pilot)$/i ? '' : $id,
			$payer,
			$payType,
			$state,
			$flags,
			$addl,
			];
		push(@$list, $row);
		push(@$all, $row);
	}
	close(SRCFILE);
}

sub obtainBCBS
{
	my ($self, $flags, $collection, %params) = @_;
	return $self->obtainGovernment($flags, $collection, 'bcbs', ENVOYPAYERTYPE_BCBS, %params);
}

sub obtainMedicare
{
	my ($self, $flags, $collection, %params) = @_;
	return $self->obtainGovernment($flags, $collection, 'medicare', ENVOYPAYERTYPE_MEDICARE, %params);
}

sub obtainMedicaid
{
	my ($self, $flags, $collection, %params) = @_;
	return $self->obtainGovernment($flags, $collection, 'medicaid', ENVOYPAYERTYPE_MEDICAID, %params);
}

1;