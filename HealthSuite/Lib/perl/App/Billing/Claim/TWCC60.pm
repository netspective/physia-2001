##############################################################################
package App::Billing::Claim::TWCC60;
##############################################################################

use strict;

sub new
{
	my ($type, %params) = @_;

	$params{requestorType} = undef;
	$params{disputeType} = undef;

	$params{requestorName} = undef;
	$params{requestorContactName} = undef;
	$params{requestorAddress} = undef;
	$params{requestorFEIN} = undef;
	$params{requestorLicenseNo} = undef;

	$params{noticeOfDenial} = undef;
	$params{noticeOfDispute} = undef;

	$params{respondentType} = undef;
	$params{respondentName} = undef;
	$params{respondentContactName} = undef;
	$params{respondentAddress} = undef;
	$params{respondentFEIN} = undef;
	$params{respondentLicenseNo} = undef;

	$params{issueResolved} = undef;
	$params{issueResolvedDesc} = undef;

	$params{first4Fields} = [];
	$params{second4Fields} = [];

	return bless \%params, $type;
}

sub setRequestorType
{
	my ($self, $value) = @_;
	$self->{requestorType} = $value;
}

sub getRequestorType
{
	my $self = shift;
	return $self->{requestorType};
}

sub setDisputeType
{
	my ($self, $value) = @_;
	$self->{disputeType} = $value;
}

sub getDisputeType
{
	my $self = shift;
	return $self->{disputeType};
}

sub setRequestorName
{
	my ($self, $value) = @_;
	$self->{requestorName} = $value;
}

sub getRequestorName
{
	my $self = shift;
	return $self->{requestorName};
}

sub setRequestorContactName
{
	my ($self, $value) = @_;
	$self->{requestorContactName} = $value;
}

sub getRequestorContactName
{
	my $self = shift;
	return $self->{requestorContactName};
}

sub setRequestorAddress
{
	my ($self, $value) = @_;
	$self->{requestorAddress} = $value;
}

sub getRequestorAddress
{
	my $self = shift;
	return $self->{requestorAddress};
}

sub setRequestorFEIN
{
	my ($self, $value) = @_;
	$self->{requestorFEIN} = $value;
}

sub getRequestorFEIN
{
	my $self = shift;
	return $self->{requestorFEIN};
}

sub setRequestorLicenseNo
{
	my ($self, $value) = @_;
	$self->{requestorLicenseNo} = $value;
}

sub getRequestorLicenseNo
{
	my $self = shift;
	return $self->{requestorLicenseNo};
}

sub setNoticeOfDenial
{
	my ($self, $value) = @_;
	$self->{noticeOfDenial} = $value;
}

sub getNoticeOfDenial
{
	my $self = shift;
	return $self->{noticeOfDenial};
}

sub setNoticeOfDispute
{
	my ($self, $value) = @_;
	$self->{noticeOfDispute} = $value;
}

sub getNoticeOfDispute
{
	my $self = shift;
	return $self->{noticeOfDispute};
}

sub setRespondentType
{
	my ($self, $value) = @_;
	$self->{respondentType} = $value;
}

sub getRespondentType
{
	my $self = shift;
	return $self->{respondentType};
}

sub setRespondentName
{
	my ($self, $value) = @_;
	$self->{respondentName} = $value;
}

sub getRespondentName
{
	my $self = shift;
	return $self->{respondentName};
}

sub setRespondentContactName
{
	my ($self, $value) = @_;
	$self->{respondentContactName} = $value;
}

sub getRespondentContactName
{
	my $self = shift;
	return $self->{respondentContactName};
}

sub setRespondentAddress
{
	my ($self, $value) = @_;
	$self->{respondentAddress} = $value;
}

sub getRespondentAddress
{
	my $self = shift;
	return $self->{respondentAddress};
}

sub setRespondentFEIN
{
	my ($self, $value) = @_;
	$self->{respondentFEIN} = $value;
}

sub getRespondentFEIN
{
	my $self = shift;
	return $self->{respondentFEIN};
}

sub setRespondentLicenseNo
{
	my ($self, $value) = @_;
	$self->{respondentLicenseNo} = $value;
}

sub getRespondentLicenseNo
{
	my $self = shift;
	return $self->{respondentLicenseNo};
}

sub setIssueResolved
{
	my ($self, $value) = @_;
	$self->{issueResolved} = $value;
}

sub getIssueResolved
{
	my $self = shift;
	return $self->{issueResolved};
}

sub setIssueResolvedDesc
{
	my ($self, $value) = @_;
	$self->{issueResolvedDesc} = $value;
}

sub getIssueResolvedDesc
{
	my $self = shift;
	return $self->{issueResolvedDesc};
}

sub addFirst4Fields
{
	my $self = shift;
	my $listRef = $self->{first4Fields};
	foreach (@_)
	{
		push(@{$listRef}, $_);
	}
}

sub addSecond4Fields
{
	my $self = shift;
	my $listRef = $self->{second4Fields};
	foreach (@_)
	{
		push(@{$listRef}, $_);
	}
}

sub getDisputedDOS
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return '' if ($no < 0 || $no > 15);
	my @result = split('//', $self->{first4Fields}->[$no]);
	return $result[0];
}

sub getCPTCode
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return '' if ($no < 0 || $no > 15);
	my @result = split('//', $self->{first4Fields}->[$no]);
	return $result[1];
}

sub getAmountBilled
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return '' if ($no < 0 || $no > 15);
	my @result = split('//', $self->{first4Fields}->[$no]);
	return $result[2];
}

sub getMedicalFee
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return '' if ($no < 0 || $no > 15);
	my @result = split('//', $self->{first4Fields}->[$no]);
	return $result[3];
}

sub getTotalAmountPaid
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return '' if ($no < 0 || $no > 15);
	my @result = split('//', $self->{second4Fields}->[$no]);
	return $result[0];
}

sub getAmountInDispute
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return '' if ($no < 0 || $no > 15);
	my @result = split('//', $self->{second4Fields}->[$no]);
	return $result[1];
}

sub getIncreasedReimburse
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return '' if ($no < 0 || $no > 15);
	my @result = split('//', $self->{second4Fields}->[$no]);
	return $result[2];
}

sub getMaintainingReduction
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return '' if ($no < 0 || $no > 15);
	my @result = split('//', $self->{second4Fields}->[$no]);
	return $result[3];
}

1;