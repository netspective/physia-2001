##############################################################################
package App::Dialog::Message;
##############################################################################

use strict;
use SDE::CVS ('$Id: Message.pm,v 1.11 2001-01-10 18:27:27 thai_nguyen Exp $', '$Name:  $');
use CGI::Validator::Field;
use CGI::Dialog;
use base qw(CGI::Dialog);

use CGI::Carp qw(fatalsToBrowser);

use App::Dialog::Field::Person;
use DBI::StatementManager;
use App::Statements::Document;
use Date::Manip;
use Text::Autoformat;
use CGI::ImageManager;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'message' => {
			_arl => ['message_id', 'doc_spec_subtype'],
			_modes => ['send', 'trash', 'read', 'forward', 'reply_to', 'reply_to_all',],
			_idSynonym => 'message_' . App::Universal::MSGSUBTYPE_MESSAGE,
		},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'message', heading => '$Command Message');

	my $toField = new App::Dialog::Field::Person::ID(
			name => 'to',
			caption => 'To',
			size => 40,
			maxLength => 255,
			findPopupAppendValue => ',',
			options => FLDFLAG_REQUIRED,
			type => 'not_an_identifier',
			addPopup => 'NONE',
	);
	$toField->clearFlag(FLDFLAG_IDENTIFIER);

	my $ccField = new App::Dialog::Field::Person::ID(
			name => 'cc',
			caption => 'CC',
			size => 40,
			maxLength => 255,
			findPopupAppendValue => ',',
			type => 'not_an_identifier',
			addPopup => 'NONE',
	);
	$ccField->clearFlag(FLDFLAG_IDENTIFIER);


	$self->addContent(
		new CGI::Dialog::Subhead(heading => 'Message',
			name => 'message_subhead',
			options => FLDFLAG_INVISIBLE,
		),
		new CGI::Dialog::Field(
			name => 'message_id',
			type => 'hidden',
		),
		new CGI::Dialog::MultiField (caption => 'From',
			name => 'from_senton',
			fields => [
				new CGI::Dialog::Field(caption => 'From',
					name => 'from',
				),
				new CGI::Dialog::Field(
					name => 'send_on',
				),
			],
			options => FLDFLAG_READONLY,
		),

		$toField,
		$ccField,
		new App::Dialog::Field::Person::ID(caption => 'Regarding Patient',
			name => 'patient_id',
			types => ['Patient'],
			incSimpleName => 1,
		),
		new CGI::Dialog::Field(
			name => 'patient_name',
			type => 'hidden',
		),
		new CGI::Dialog::Field(
			name => 'saved_patient_id',
			type => 'hidden',
		),

		new CGI::Dialog::Field(caption => 'Caller if Other than Patient',
			name => 'doc_source_system',
			size => 40,
		),

		$self->addExtraFields(),
		#new CGI::Dialog::Field(
		#	name => 'deliver_records',
		#	caption => 'Deliver with medical record?',
		#	type => 'bool',
		#	style => 'check',
		#),

		new CGI::Dialog::MultiField (name => 'return_phones',
			fields => [
				new CGI::Dialog::Field(caption => 'Return Call To:  Home',
					name => 'return_phone1',
					type => 'phone',
				),
				new CGI::Dialog::Field(caption => 'Office',
					name => 'return_phone2',
					type => 'phone',
				),
				new CGI::Dialog::Field(caption => 'Cell',
					name => 'return_phone3',
					type => 'phone',
				),
			],
		),

		new CGI::Dialog::MultiField (name => 'pager_other',
			fields => [
				new CGI::Dialog::Field(caption => 'Pager',
					name => 'return_phone4',
					size => 13,
				),
				new CGI::Dialog::Field(caption => 'Other',
					name => 'return_phone5',
					size => 13,
				),
			],
		),

		new CGI::Dialog::Field(caption => 'Priority',
			name => 'priority',
			selOptions => 'Normal;ASAP;Emergency',
			type => 'select',
		),
		new CGI::Dialog::Field(caption => 'Subject',
			name => 'subject',
			size => 70,
			maxLength => 255,
			options => FLDFLAG_REQUIRED,
		),

		new CGI::Dialog::Field(caption => 'Message',
			name => 'common_message',
			type => 'select',
			selOptions => qq{;
				Medication Question : medication_question;
				Medication Problem  : medication_problem;
				Wants Lab Results   : want_lab_results;
				Has Question About Lab Results : has_question_about_lab_results;
				Doesn't Feel Well   : does_not_feel_well;
				Complains Of        : complains_of;
				Continue Same Treatment : continue_same_treatment;
				Schedule Appointment : schedule_appointment;
				Follow Up in : follow_up_in;
				Stop Medication : stop_medication;
				Start New Medication : start_new_medication;
				Change Medication Dose : change_medication_dose;
				Refill Medication : refill_medication;
				Call
			},
		),

		new CGI::Dialog::Field(caption => '',
			name => 'message',
			type => 'memo',
			cols => 70,
			rows => 5,
		),
		new CGI::Dialog::Subhead(heading => 'Notes',
			name => 'notes_subhead',
			options => FLDFLAG_INVISIBLE,
		),
		new App::Dialog::Message::Notes(caption => '',
			name => 'existing_notes',
		),
		new CGI::Dialog::Field(caption => 'Add Notes',
			name => 'notes',
			type => 'memo',
			cols => 70,
			rows => 5,
			options => FLDFLAG_INVISIBLE,
		),
		new CGI::Dialog::Field(caption => 'Keep notes private?',
			name => 'notes_private',
			type => 'bool',
			style => 'check',
			options => FLDFLAG_INVISIBLE,
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons());

	return $self;
}


sub addExtraFields
{
	my $self = shift;

	my @fields = ();
	return @fields;
}


sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);

	if ($command eq 'read' || $command eq 'trash')
	{
		foreach (sort keys %{$self->{fieldMap}})
		{
			next if $_ eq 'notes';
			next if $_ eq 'notes_private';

			$self->setFieldFlags($_, FLDFLAG_READONLY);
		}

		unless ($command eq 'trash')
		{
			$self->clearFieldFlags('message_subhead', FLDFLAG_INVISIBLE);
			$self->clearFieldFlags('notes_subhead', FLDFLAG_INVISIBLE);
			$self->clearFieldFlags('notes', FLDFLAG_INVISIBLE);
			$self->clearFieldFlags('notes_private', FLDFLAG_INVISIBLE);
		}
	}
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $commonMessageField = $self->getField('common_message');

	my $existingMsg = {};
	if ($command ne 'send')
	{
		# Load existing message data
		my $messageId = $page->param('message_id');
		die "Message ID Required" unless $messageId;

		$self->{preHtml} = [qq
			{	<a title="Reply" href="/person/#session.person_id#/dlg-reply_to-message_#param.doc_spec_subtype#/#param.message_id#/#param.doc_spec_subtype#?home=#homeArl#">$IMAGETAGS{'widgets/mail/reply'}</a> &nbsp;
				<a title="Reply To All" href="/person/#session.person_id#/dlg-reply_to_all-message_#param.doc_spec_subtype#/#param.message_id#/#param.doc_spec_subtype#?home=#homeArl#">$IMAGETAGS{'widgets/mail/reply_all'}</a> &nbsp;
				<a title="Forward" href="/person/#session.person_id#/dlg-forward-message_#param.doc_spec_subtype#/#param.message_id#/#param.doc_spec_subtype#?home=#homeArl#">$IMAGETAGS{'widgets/mail/forward'}</a> &nbsp;
				<a title="Trash" href="/person/#session.person_id#/dlg-trash-message_#param.doc_spec_subtype#/#param.message_id#/#param.doc_spec_subtype#?home=#homeArl#">$IMAGETAGS{'icons/action-edit-remove-x'}</a> &nbsp;
			},
		] if $command eq 'read';

		$existingMsg = $STMTMGR_DOCUMENT->getRowAsHash($page, STMTMGRFLAG_NONE, 'selMessage',
			$messageId, $page->session('GMT_DAYOFFSET'));
		$existingMsg->{to} = $STMTMGR_DOCUMENT->getSingleValueList($page, STMTMGRFLAG_NONE, 'selMessageToList', $messageId);
		$existingMsg->{cc} = $STMTMGR_DOCUMENT->getSingleValueList($page, STMTMGRFLAG_NONE, 'selMessageCCList', $messageId);
		$existingMsg->{cc} = [] unless defined $existingMsg->{cc};
	}
	$self->{existing_message} = $existingMsg;

	if ($command eq 'send')
	{
		# We're creating an entirely new message
		$page->field('from', $page->session('person_id'));

		$commonMessageField->{selOptions} = qq{;
			Medication Question : medication_question;
			Medication Problem  : medication_problem;
			Wants Lab Results   : want_lab_results;
			Has Question About Lab Results : has_question_about_lab_results;
			Doesn't Feel Well   : does_not_feel_well;
			Complains Of        : complains_of
		};
	}
	elsif (grep {$_ eq $command} ('trash', 'read'))
	{
		# We're displaying an existing message
		$page->field('from', $existingMsg->{'from_id'});
		$page->field('to', join(',', @{$existingMsg->{'to'}}));
		$page->field('cc', join(',', @{$existingMsg->{'cc'}}));

		my $patientId = defined $existingMsg->{'repatient_id'} ? $existingMsg->{'repatient_id'} : '';
		my $patientName = defined $existingMsg->{'repatient_name'} ? $existingMsg->{'repatient_name'} : '';

		if ($patientId)
		{
			my $patient = qq{<a href="javascript:doActionPopup('/person/$patientId/chart')" title="View $patientId Chart">$patientName ($patientId)</a>};
			my $field = $self->getField('patient_id');
			$field->{preHtml} = qq{<a href="javascript:doActionPopup('/person/$patientId/chart')" title="View $patientId Chart">$patientName</a> &nbsp;};
			$page->field('patient_id', "($patientId)");
			$page->field('saved_patient_id', $patientId);
		}

		$page->field('patient_name', $existingMsg->{'repatient_name'}) if defined $existingMsg->{'repatient_name'};

		$page->field('deliver_records', $existingMsg->{'deliver_records'}) if defined $existingMsg->{'deliver_records'};
		$page->field('priority', $existingMsg->{'priority'} || 'Normal');
		$page->field('subject', $existingMsg->{'subject'});
		$page->field('message', $existingMsg->{'message'}) if defined $existingMsg->{'message'};

		my @return_phones = split(/\s*,\s*/, $existingMsg->{return_phones});
		for my $i (1..5)
		{
			$page->field("return_phone$i", $return_phones[$i -1]);
		}

		$page->field('send_on', qq{&nbsp; &nbsp; &nbsp; &nbsp; Sent on $existingMsg->{'send_on'}});

		$page->field('common_message', $existingMsg->{common_message});
		$page->field('doc_source_system', $existingMsg->{'doc_source_system'});
	}
	elsif (grep {$_ eq $command} ('reply_to', 'reply_to_all', 'forward'))
	{
		# We're creating a new message based on the existing message
		$page->field('from', $page->session('person_id'));

		if ($command eq 'reply_to' || $command eq 'reply_to_all')
		{
			$page->field('to', $existingMsg->{'from_id'});
		}

		if ($command eq 'reply_to_all')
		{
			$page->field('cc', join(',', @{$existingMsg->{'to'}}, @{$existingMsg->{'cc'}}));
		}

		# We should be safe to assume that it's still regarding the same patient
		$page->field('patient_id', $existingMsg->{'repatient_id'});

		# Create an appropriate new subject
		my $prefix = $command eq 'forward' ? 'FW: ' : 'RE: ';
		$page->field('subject', $prefix . $existingMsg->{subject});

		# Quote the existing message
		my $quotedMsg = autoformat $self->quoteMsg($existingMsg->{'message'}, $existingMsg->{'from_id'});
		$page->field('message', $quotedMsg);

		my @return_phones = split(/\s*,\s*/, $existingMsg->{return_phones});
		for my $i (1..5)
		{
			$page->field("return_phone$i", $return_phones[$i -1]);
		}

		$commonMessageField->{selOptions} = qq{;
			Continue Same Treatment : continue_same_treatment;
			Schedule Appointment : schedule_appointment;
			Follow Up in : follow_up_in;
			Stop Medication : stop_medication;
			Start New Medication : start_new_medication;
			Change Medication Dose : change_medication_dose;
			Refill Medication : refill_medication;
			Call
		};

		$page->field('doc_source_system', $existingMsg->{'doc_source_system'});
	}
}


sub quoteMsg
{
	my $self = shift;
	my ($message, $from_id) = @_;

	$message =~ s/\n/\n\> /g;
	$message = "> " . $message;

	return $message;
}


sub execute
{
	my ($self, $page, $command, $flags, $messageData) = @_;
	$messageData = {} unless defined $messageData;

	unless ($command eq 'send')
	{
		$self->updateRecipientFlags($page, $command, $flags);
	}

	unless ($command eq 'trash' || $command eq 'read')
	{
		$messageData->{'priority'} = $page->field('priority') unless defined $messageData->{'priority'};
		$messageData->{'subject'} = $page->field('subject') unless defined $messageData->{'subject'};
		$messageData->{'message'} = $page->field('message') unless defined $messageData->{'message'};
		$messageData->{'to'} = $page->field('to') unless defined $messageData->{'to'};
		$messageData->{'cc'} = $page->field('cc') unless defined $messageData->{'cc'};
		$messageData->{'rePatient'} = $page->field('patient_id') unless defined $messageData->{'rePatient'};
		$messageData->{'deliverRecords'} = $page->field('deliver_records') ? 1 : 0 unless defined $messageData->{'deliverRecords'};
		$messageData->{'doc_source_system'} = $page->field('doc_source_system') unless defined $messageData->{'doc_source_system'};
		$messageData->{'doc_data_c'} = $page->field('common_message') unless defined $messageData->{'doc_data_c'};

		for my $i (1..5)
		{
			push(@{$messageData->{'return_phones'}}, $page->field("return_phone$i") || undef);
		}

		$self->sendMessage($page, %$messageData);
	}
	else
	{
		if (my $notes = $page->field('notes'))
		{
			$self->saveMessageAttribute($page, $messageData,
				parent_id => $page->param('message_id'),
				value_type => App::Universal::ATTRTYPE_TEXT,
				item_name => 'Notes',
				person_id => $page->session('person_id'),
				value_int => $page->field('notes_private') ? 1 : 0,
				value_text => $notes,
			);
		}
	}

	#$self->handlePostExecute($page, $command, $flags, "/person/@{[$page->session('user_id')]}/mailbox");
	$self->handlePostExecute($page, $command, $flags, $page->param('home'));
}

sub sendMessage
{
	my $self = shift;
	my $page = shift;
	my %messageData = @_;

	my $docDestIds = join(', ', split(/\s*,\s*/, $messageData{'to'} . ', ' . $messageData{'cc'}));

	my $messageId = $self->saveMessage($page, \%messageData,
		doc_mime_type => 'text/plain',
		doc_orig_stamp => $page->getTimeStamp(),
		doc_spec_type => App::Universal::DOCSPEC_INTERNAL,
		doc_spec_subtype => $messageData{'type'} || App::Universal::MSGSUBTYPE_MESSAGE,
		doc_source_id => $page->session('person_id'),
		doc_source_type => App::Universal::DOCSRCTYPE_PERSON,
		doc_data_b => $messageData{'priority'},
		doc_name => $messageData{'subject'},
		doc_content_small => $messageData{'message'},
		doc_dest_ids => $docDestIds,
		doc_source_system => $messageData{'doc_source_system'} || undef,
		doc_data_c => $messageData{'doc_data_c'} || undef,
	);

	# Add the To recipients
	my @toRecipients = split /\,\s*/, $messageData{'to'};
	foreach my $toRecipient (@toRecipients)
	{
		$self->saveMessageAttribute($page, \%messageData,
			parent_id => $messageId,
			item_name => 'To',
			value_type => App::Universal::ATTRTYPE_PERSON_ID,
			value_int => 0,
			value_text => uc($toRecipient),
		);
	}

	# Add the CC recipients
	my @ccRecipients = split /\,\s*/, $messageData{'cc'};
	foreach my $ccRecipient (@ccRecipients)
	{
		$self->saveMessageAttribute($page,\%messageData,
		parent_id => $messageId,
		item_name => 'CC',
		value_type => App::Universal::ATTRTYPE_PERSON_ID,
		value_int => 0,
		value_text => uc($ccRecipient),
		);
	}

	$self->saveMessageAttribute($page, \%messageData,
		parent_id => $messageId,
		item_name => 'Regarding Patient',
		value_type => App::Universal::ATTRTYPE_PATIENT_ID,
		value_text => $messageData{'rePatient'},
		value_int => $messageData{'deliverRecords'} ? 1 : 0,
	);

	$self->saveMessageAttribute($page, \%messageData,
		parent_id => $messageId,
		item_name => 'Return Phones',
		value_type => App::Universal::ATTRTYPE_PHONE,
		value_text => join(',', @{$messageData{'return_phones'}}),
	) if defined $messageData{'return_phones'};
}

sub updateRecipientFlags
{
	my $self = shift;
	my ($page, $command, $flags) = @_;

	my $messageId = $page->param('message_id');
	my $personId = $page->session('person_id');
	my $item_id = $STMTMGR_DOCUMENT->getSingleValue($page, STMTMGRFLAG_NONE, 'selMessageRecipientAttrId',
		$messageId, $personId);
	if ($item_id) #otherwise we're reading someone else's mail
	{
		$page->schemaAction('Document_Attribute', 'update',
			item_id => $item_id,
			value_int => $command eq 'trash' ? 2 : 1,
			_debug => 0,
		);
	}
}

sub saveMessage
{
	my $self = shift;
	my $page = shift;
	my $messageData = shift;

	return $page->schemaAction('Document', 'add', @_, _debug => 0);
}

sub saveMessageAttribute
{
	my $self = shift;
	my $page = shift;
	my $messageData = shift;
	my %schemaActionData = @_;

	if ($schemaActionData{value_text})
	{
		return $page->schemaAction('Document_Attribute', 'add', %schemaActionData, _debug => 0);
	}
}

##############################################################################
package App::Dialog::Message::Notes;
##############################################################################

use strict;
use SDE::CVS ('$Id: Message.pm,v 1.11 2001-01-10 18:27:27 thai_nguyen Exp $', '$Name:  $');
use CGI::Dialog;
use base qw(CGI::Dialog::ContentItem);

use DBI::StatementManager;
use App::Statements::Document;
use Data::Publish;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP=();


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags, $mainData) = @_;

	return '' unless $command eq 'read';

	my $noteRows = $STMTMGR_DOCUMENT->getRowsAsArray($page, STMTMGRFLAG_NONE, 'selMessageNotes',
		$page->param('message_id'), $page->session('person_id'), $page->session('STANDARD_TIME_OFFSET'));
	my $html = '';
	foreach my $note (@$noteRows)
	{
		my $date = Data::Publish::fmt_stamp($page, $note->[0]);
		my $private = $note->[3] ? '<b>(privately)</b>' : '';

		$html .= "<p><b>$note->[1]</b> on $date wrote: $private<br>$note->[2]</p>";
	}

	return qq{<tr><td colspan="2">&nbsp;</td><td style="font-size: 10pt; font-family: Tahoma, Ariel, Helvetica;">$html<br></td><td>&nbsp;</td></tr>};
}


1;
