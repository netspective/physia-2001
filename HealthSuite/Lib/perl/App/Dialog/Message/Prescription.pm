##############################################################################
package App::Dialog::Message::Prescription;
##############################################################################

use strict;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Message;
use base qw(App::Dialog::Message);

use CGI::Carp qw(fatalsToBrowser);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'message_prescription' => {
			_arl => ['message_id'],
			_modes => ['trash', 'read', 'forward', 'reply_to', 'reply_to_all',],
			_idSynonym => 'message_' . App::Universal::MSGSUBTYPE_PRESCRIPTION,
		},
);


sub new
{
	my $self = App::Dialog::Message::new(@_);

	$self->{id} = 'prescription';
	$self->{heading} = '$Command Prescription Request';

	return $self;
}


sub addExtraFields
{
	my $self = shift;

	return (
		new CGI::Dialog::Field(
			name => 'permed_id',
			type => 'hidden',
		),
		new CGI::Dialog::Field(
			caption => 'Prescription Request',
			name => 'prescription',
			options => FLDFLAG_READONLY,
		),
	);
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

	my $permedId = $existingMsg->{'permed_id'};
	my $personId = $page->field('patient_id');
	$page->field('permed_id', $permedId);
	my $preField = $self->getField('prescription');
	#$preField->{preHtml} = qq{<a href="/person-p/$personId/dlg-approve-medication/$permedId" target="approve_med">Edit & Approve Prescription</a>};
	$preField->{preHtml} = qq{
		<a href="javascript:doActionPopup('/person-p/$personId/dlg-approve-medication/$permedId', null,'location, status, width=620,height=550,scrollbars,resizable')">
		<b style='font-family:Tahoma'>View/Edit/Approve Prescription</b></a>
	};
}

sub execute
{
	my $self = shift;
	my ($page, $command, $flags, $messageData) = @_;
	$messageData = {} unless defined $messageData;

	$messageData->{'permedId'} = $page->field('permed_id');
	return $self->SUPER::execute($page, $command, $flags, $messageData);
}


sub saveMessage
{
	my $self = shift;
	my $page = shift;
	my $messageData = shift;
	my %schemaActionData = @_;

	$schemaActionData{doc_spec_subtype} = App::Universal::MSGSUBTYPE_PRESCRIPTION;
	$schemaActionData{doc_data_a} = $messageData->{'permedId'};
	return $self->SUPER::saveMessage($page, $messageData, %schemaActionData);
}


1;
