package App::Billing::Validate::HCFA::HCFA1500;
#####################################################################
#####################################################################
use strict;
use Carp;
use App::Billing::Driver;
use App::Billing::Validator;

use constant VALITEMIDX_NAME => 0;
use constant VALITEMIDX_INSTANCE => 1;
use constant VALITEMIDX_ERRCODE => 2;
use constant VALITEMIDX_MESSAGE => 3;
use constant CONTAINS => 0;
use constant NOT_CONTAINS => 1;

use vars qw(@ISA);
@ISA = qw(App::Billing::Validator);


use constant VALIDATORFLAGS_DEFAULT => 0;

sub new
{
	my ($type) = @_;
	my $self = new App::Billing::Validator(@_);

	return bless $self, $type;
}

sub getId
{

	return 'VC07';
}

sub getName
{
	return 'Generic Validator Class';
}

sub getCallSequences
{
	return 'Claim_1500';
}


# read/write a generic property for this class
#

sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub validate
{
	my ($self, $parent, $callSeq, $vFlags, $claim) = @_;
	$self->checkValidProcedureDiagnosis($parent, $vFlags, $claim);


}

sub checkValidProcedureDiagnosis
{
	my($self, $parent, $vFlags, $claim) = @_;
	my @diag;
	my $diagnoses = $claim->{diagnosis};
	my $procedures = $claim->{procedures};
	my $diagnosis;
	foreach  $diagnosis(@$diagnoses)
	{
		if ($diagnosis ne "")
		{
			push @diag, $diagnosis->getDiagnosis;
		}
	}
	my $dg = join(' ',sort(@diag));
	foreach my $procedure (@$procedures)
	{
		if ($procedures ne "")
		{
			my $sd  ='(.*)((' . join(')+)(.*)((',sort(split(/,/,$procedure->getDiagnosis))) . ')+)(.*)';
			$dg =~ $sd ? 1 : $claim->addError($self, $self->getId(), "A procedure contains invalid diagnosis");
		}
	}


}


1;

