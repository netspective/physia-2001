##############################################################################
package App::Page::Person::MailBox::PhoneMessage;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person::MailBox);

use App::Configuration;
use SQL::GenerateQuery;
use CGI::Dialog::DataNavigator;
use CGI::ImageManager;
use Data::Publish;

use vars qw(%RESOURCE_MAP $QDL %PUBDEFN);
%RESOURCE_MAP = (
	'person/mailbox/phoneMessages' => {
		_tabCaption => 'Phone Messages',
		},
	);

$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'Message.qdl');

%PUBDEFN = (
	name => 'phoneMessages',
	banner => {
		actionRows => [
			{caption => 'Send Message', url => '/person/#session.person_id#/dlg-send-message',},
			{caption => 'Send Phone Message', url => '/person/#session.person_id#/dlg-send-phone_message',},
		],
	},
	columnDefn => [
		{head => '', colIdx => '#{priority}#', dataFmt => sub {return $IMAGETAGS{'widgets/mail/pri_' . $_[0]->[$_[1]]}},},
		{head => '', colIdx => '#{doc_spec_subtype}#', dataFmt => \&iconCallback,},
		{head => 'To', dataFmt => '#{to_ids}#',},
		{head => 'Subject', hAlign=> 'left', dataFmt => '#{subject}#',},
		{head => 'Regarding Patient', hAlign=> 'left', dataFmt => '#{repatient_name}# (#{repatient_id}#)',},
		{head => 'Sent On', hAlign=> 'left', colIdx => '#{date_sent}#', dformat => 'stamp',},
		{
			head => 'Actions',
			dataFmt => qq{
				<a title="Reply To All" href="/person/#session.person_id#/dlg-reply_to_all-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#">$IMAGETAGS{'widgets/mail/reply_all'}</a>
				<a title="Forward" href="/person/#session.person_id#/dlg-forward-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#">$IMAGETAGS{'widgets/mail/forward'}</a>
				<a title="Trash" href="/person/#session.person_id#/dlg-trash-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#">$IMAGETAGS{'icons/action-edit-remove-x'}</a>
			},
			options => PUBLCOLFLAG_DONTWRAP,
		},
	],
	bodyRowAttr => {
		class => 'message_status_#{recipient_status}#',
	},

	dnQuery => \&dnQuery,
	dnSelectRowAction => '/person/#session.person_id#/dlg-read-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#',
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
	elsif ($value eq App::Universal::MSGSUBTYPE_PRESCRIPTION)
	{
		return $IMAGETAGS{'widgets/mail/prescription'}
	}
	else
	{
		return "ERROR: Unknown Message Type: $value";
	}
}

sub dnQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('doc_spec_type', 'is', App::Universal::DOCSPEC_INTERNAL);
	my $cond2 = $sqlGen->WHERE('recipient_id', 'is', $self->session('person_id'));
	my $cond3 = $sqlGen->WHERE('doc_spec_subtype', 'is', App::Universal::MSGSUBTYPE_PHONE_MESSAGE);
	my $cond4 = $sqlGen->WHERE('recipient_status', 'isnot', 2);

	my $finalCond = $sqlGen->AND($cond1, $cond2, $cond3, $cond4);
	$finalCond->outColumns(
		'priority',
		'message_id',
		'doc_spec_subtype',
		'from_id',
		'subject',
		'repatient_id',
		'repatient_name',
		'deliver_record',
		"TO_CHAR({date_sent},'IYYYMMDDHH24MISS')",
		'to_ids',
		'recipient_status',
	);
	$finalCond->orderBy({id => 'date_sent', order => 'Descending'});
	$finalCond->distinct(1);
	return $finalCond;
}

sub prepare_view
{
	my ($self) = @_;

	# Create html file tabs for each document type
	my $tabsHtml = $self->setupTabs();

	# Create the work list dialog
	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUBDEFN, topHtml => $tabsHtml, page => $self);
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
