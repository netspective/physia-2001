##############################################################################
package App::Page::Person::MailBox::Inbox;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person::MailBox);

use App::Configuration;
use SQL::GenerateQuery;
use CGI::Dialog::DataNavigator;
use CGI::ImageManager;

use vars qw(%RESOURCE_MAP $QDL %PUB_INBOX);
%RESOURCE_MAP = (
	'person/mailbox/inbox' => {
		_idSynonym => ['_default'],
		_tabCaption => 'Inbox',
		},
	);
	

$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'Message.qdl');


########################################################
# Drill Level 0 - Observations
########################################################


%PUB_INBOX = (
	name => 'inbox',
	banner => {
		actionRows => [
			{caption => 'Send Message', url => '/person/#session.person_id#/dlg-send-message',},
			{caption => 'Send Phone Message', url => '/person/#session.person_id#/dlg-send-phone_message',},
			{caption => 'Send Refill Request', url => '/person/#session.person_id#/dlg-send-refill_request',},
		],
	},
	bodyRowAttr => {
		class => 'message_status_#{recipient_status}#',
	},
	columnDefn => [
		{head => '', colIdx => '#{doc_spec_subtype}#', dataFmt => \&iconCallback,},
		{head => 'From', hAlign=> 'left', dataFmt => '#{from_id}#',},
		{head => 'Subject', hAlign=> 'left', dataFmt => '#{subject}#',},
		{head => 'Regarding Patient', hAlign=> 'left', dataFmt => '#{repatient_name}# (#{repatient_id}#)',},
		{head => 'Sent On', hAlign=> 'left', colIdx => '#{date_sent}#', dformat => 'stamp',},
		{
			head => 'Actions', 
			dataFmt => qq{
				<a title="Reply" href="/person/#session.person_id#/dlg-reply_to-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#">$IMAGETAGS{'widgets/mail/reply'}</a>
				<a title="Reply To All" href="/person/#session.person_id#/dlg-reply_to_all-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#">$IMAGETAGS{'widgets/mail/reply_all'}</a>
				<a title="Forward" href="/person/#session.person_id#/dlg-forward-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#">$IMAGETAGS{'widgets/mail/forward'}</a>
				<!-- <a href="/person/#session.person_id#/dlg-trash-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#">Trash</a> -->
			},
		},
	],
	dnSelectRowAction => '/person/#session.person_id#/dlg-read-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#',
	dnQuery => \&inboxQuery,
#	dnAncestorFmt => 'All Lab Results',
);


sub iconCallback
{
	my $value = $_[0]->[$_[1]];
	if ($value eq App::Universal::MSGSUBTYPE_MESSAGE)
	{
		return $IMAGETAGS{'widgets/mail/read'}
	}
	elsif ($value eq App::Universal::MSGSUBTYPE_PHONE_MESSAGE)
	{
		return $IMAGETAGS{'widgets/mail/phone'}
	}
	elsif ($value eq App::Universal::MSGSUBTYPE_REFILL_REQUEST)
	{
		return $IMAGETAGS{'widgets/mail/prescription'}
	}
	else
	{
		return "ERROR: Unknown Message Type: $value";
	}
}


sub inboxQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);
	
	my $cond1 = $sqlGen->WHERE('doc_spec_type', 'is', App::Universal::DOCSPEC_INTERNAL);
	my $cond2 = $sqlGen->WHERE('recipient_id', 'is', $self->session('person_id'));
	my $cond3 = $sqlGen->AND($cond1, $cond2);
	$cond3->outColumns(
		'message_id',
		'doc_spec_subtype',
		'recipient_status',
		'from_id',
		'subject',
		'repatient_id',
		'repatient_name',
		'deliver_record',
		"TO_CHAR({date_sent},'IYYYMMDDHH24MISS')",
	);
	$cond3->orderBy({id => 'date_sent', order => 'Descending'});
	$cond3->distinct(1);
	return $cond3;
}
	

sub prepare_view
{
	my ($self) = @_;

	# Create html file tabs for each document type
	my $tabsHtml = $self->setupTabs();

	# Create the work list dialog
	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUB_INBOX, topHtml => $tabsHtml, page => $self);
	my $dlgHtml = $dlg->getHtml($self, 'add');

	$self->addContent(
		q{
			<STYLE>
				.message_status_ {font-weight: bold;}
				.message_status_0 {font-weight: bold;}
				.message_status_1 {}
			</STYLE>
		},
		$dlgHtml
	);
}

1;
