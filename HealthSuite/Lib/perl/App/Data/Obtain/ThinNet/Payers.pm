##############################################################################
package App::Data::Obtain::ThinNet::Payers;
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


@ISA = qw(Exporter App::Data::Obtain::Word);
$VERSION = "1.00";

sub process
{
	my ($self, $flags, $collection, $params, $msWord, $document) = @_;

	unless($params->{srcThin})
	{
		$self->addError("srcThin parameter is required");
		return;
	}

	$self->{list_payers} = [];
	my $srcThin = "$params->{srcThin}$$.txt";


	$self->reportMsg("Extracting Thin Net Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
	$self->extractTable($flags, $msWord, $params->{srcThin}, 1, $srcThin);

	if($self->haveErrors() == 0)
	{
		$self->reportMsg("Loading Commercial Payers.") if $flags & DATAMANIPFLAG_VERBOSE;
		$self->obtainPayers($flags, $collection, srcFile => $srcThin);
	}

	$self->reportMsg("Deleting temporary files.") if $flags & DATAMANIPFLAG_VERBOSE;
	unlink($srcThin);
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
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_CALL_FOR_ID if $id eq 'call';
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_PILOT_STAGE if $id eq 'pilot';
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_GROUP_POLICY_NUM_REQUIRED if $card eq 'C' || $card eq 'N';
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_GROUP_POLICY_NUM_SUGGESTED if $card eq 'B';
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_CLAIM_OFFICE_NUM_REQUIRED if $card eq 'C';
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_CLAIM_OFFICE_NUM_SUGGESTED if $card eq 'N';
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_ENROLLMENT_REQUIRED if $enroll eq 'yes';
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_CLAIMS_SERVICE if $services eq 'claims';
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_ENCOUNTERS_SERVICE if $services eq 'encounters';

	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_PRIOR_TESTING_REQUIRED if $test && $test eq 'yes';
	$flags |= App::Data::Obtain::Envoy::Payers::ENVOYPAYERFLAG_ADDITIONAL_INSTRUCTIONS if $addl;

	return $flags;
}

sub obtainPayers
{
	my ($self, $flags, $collection, %params) = @_;

	my $list = $self->{list_commercial};
	my $all = $collection->getDataRows();

	my $srcFile = $params{srcFile} || die "srcFile parameter not provided to obtainPayer\n";
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

1;