##############################################################################
package App::Page::Person::MailBox::SentItems;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person::MailBox);

use App::Configuration;
use SQL::GenerateQuery;
use CGI::Dialog::DataNavigator;
use CGI::ImageManager;

use vars qw(%RESOURCE_MAP $QDL %PUB_SENT);
%RESOURCE_MAP = (
	'person/mailbox/sentitems' => {
		_tabCaption => 'Sent Items',
		},
	);
	

$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'Message.qdl');


########################################################
# Drill Level 0 - Observations
########################################################


%PUB_SENT = (
	name => 'sentitems',
	banner => {
		actionRows => [
			{caption => 'Send Message', url => '/person/#session.person_id#/dlg-send-message',},
			{caption => 'Send Phone Message', url => '/person/#session.person_id#/dlg-send-phone_message',},
		],
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
				<a title="Reply To All" href="/person/#session.person_id#/dlg-reply_to_all-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#">$IMAGETAGS{'widgets/mail/reply_all'}</a>
				<a title="Forward" href="/person/#session.person_id#/dlg-forward-message_#{doc_spec_subtype}#/#{message_id}#?home=#homeArl#">$IMAGETAGS{'widgets/mail/forward'}</a>
			},
		},
	],
	dnQuery => \&sentItemsQuery,
	dnSelectRowAction => '/person/#session.person_id#/dlg-read-message/#{message_id}#?home=#homeArl#',
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


sub sentItemsQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('from_id', 'is', $self->session('person_id'));
	$cond1->outColumns(
		'message_id',
		'doc_spec_subtype',
		'from_id',
		'subject',
		'repatient_id',
		'repatient_name',
		'deliver_record',
		"TO_CHAR({date_sent},'IYYYMMDDHH24MISS')",
	);
	$cond1->orderBy({id => 'date_sent', order => 'Descending'});
	$cond1->distinct(1);
	return $cond1;
}
	

sub prepare_view
{
	my ($self) = @_;

	# Create html file tabs for each document type
	my $tabsHtml = $self->setupTabs();

	# Create the work list dialog
	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUB_SENT, topHtml => $tabsHtml, page => $self);
	my $dlgHtml = $dlg->getHtml($self, 'add');

	$self->addContent($dlgHtml);
}

1;
