##############################################################################
package App::Dialog::Message::Phone;
##############################################################################

use strict;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Message;
use base qw(App::Dialog::Message);

use CGI::Carp qw(fatalsToBrowser);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'phone_message' => {
			_arl => ['message_id'],
			_modes => ['send', 'trash', 'read', 'forward', 'reply_to', 'reply_to_all',],
			_idSynonym => 'message_' . App::Universal::MSGSUBTYPE_PHONE_MESSAGE,
		},
);


sub new
{
	my $self = App::Dialog::Message::new(@_);
	
	$self->{id} = 'phone_message';
	$self->{heading} = '$Command Phone Message';
	
	return $self;
}


sub addExtraFields
{
	my $self = shift;
	
	my @fields = (
		new CGI::Dialog::Field(
			name => 'return_phone',
			caption => 'Return Phone #',
			type => 'phone',
		),
	);
	
	return @fields;
}


sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
	$self->setFieldFlags('patient_id', FLDFLAG_REQUIRED);	
}


sub populateData
{
	my $self = shift;
	my ($page, $command, $activeExecMode, $flags) = @_;
	
	$self->SUPER::populateData(@_);
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	
	my $existingMsg = $self->{existing_message};
	
	if ($command eq 'send')
	{
		# We're creating an entirely new message
	}
	elsif (grep {$_ eq $command} ('trash', 'read'))
	{
		# We're displaying an existing message
		$page->field('return_phone', $existingMsg->{'return_phone'}) if defined $existingMsg->{'return_phone'};
	}
	elsif (grep {$_ eq $command} ('reply_to', 'reply_to_all', 'forward'))
	{
		$page->field('return_phone', $existingMsg->{'return_phone'}) if defined $existingMsg->{'return_phone'};
	}
}


sub saveMessage
{
	my $self = shift;
	my $page = shift;
	my %data = @_;
	
	$data{doc_spec_subtype} = App::Universal::MSGSUBTYPE_PHONE_MESSAGE;
	return $self->SUPER::saveMessage($page, %data);
}

sub saveRegardingPatient
{
	my $self = shift;
	my $page = shift;
	my %data = @_;

	if (my $phone = $page->field('return_phone'))
	{
		$data{'value_textB'} = $phone;
	}
	
	return $self->SUPER::saveRegardingPatient($page, %data);
}


1;
