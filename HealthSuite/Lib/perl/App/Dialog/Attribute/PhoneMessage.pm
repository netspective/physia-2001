##############################################################################
package App::Dialog::Attribute::PhoneMessage;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;
use App::Universal;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'phonemessage', heading => '$Command Phone Message');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(name => 'value_text', caption => 'Phone Message', type => 'memo', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'value_date', caption => 'Date', type => 'date'),
		new App::Dialog::Field::Person::ID(caption =>'Call For', name => 'value_textb', hints => 'Person who needs to receive the message.'),	
	);
	
	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Phone Message from <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	
	my $itemId = $page->param('item_id');
	my $data = $STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
	
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;
	
	
	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id => $page->param('person_id') || undef,
		item_id => $page->param('item_id') || undef,
		item_name =>'Phone Message',
		value_type => 0,
		value_text => $page->field('value_text') || undef,	
		value_date => $page->field('value_date') || undef,
		value_textB => $page->field('value_textb') || undef,		
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags);
	
}

use constant PANEDIALOG_ATTENDANCE => 'Dialog/Pane/Phone Message';

@CHANGELOG =
(
);

1;
