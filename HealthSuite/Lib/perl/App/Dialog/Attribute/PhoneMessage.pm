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
		new CGI::Dialog::Field(name => 'value_text', caption => 'Phone Message', type => 'memo', options => FLDFLAG_REQUIRED, hints => 'Message to be passed on to the requested person.'),
		new CGI::Dialog::Field(name => 'value_date', caption => 'Date', type => 'date'),
		new App::Dialog::Field::Person::ID(caption =>'Call For', name => 'parent_id', options => FLDFLAG_REQUIRED, hints => 'Person who needs to receive the message.'),	
		new CGI::Dialog::Field(name => 'value_textb', caption => 'Comments', type => 'memo', hints => 'Comments from the user to the caller.'),
	
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
	my $phoneInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

	if($phoneInfo->{value_block} == 1)
	{
		$page->field('value_text', $phoneInfo->{value_text});
		$page->field('value_date', $phoneInfo->{value_date});
		$page->field('parent_id', $phoneInfo->{parent_id});
		$page->field('value_textb', $phoneInfo->{value_textb});
	}
	else
	{
		$page->field('value_text', $phoneInfo->{value_textb});
		$page->field('value_date', $phoneInfo->{value_date});
		$page->field('parent_id', $phoneInfo->{parent_id});
		$page->field('value_textb', $phoneInfo->{value_text});	
	}
	
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;
	
	$page->addDebugStmt("command is $command");
	if($command eq 'add')
	{
		$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('parent_id') || undef,
			item_id => $page->param('item_id') || undef,
			item_name =>'Phone Message',
			value_type => 0,
			value_text => $page->field('value_text') . '(' . $page->param('person_id') . ')' || undef,	
			value_textB => $page->field('value_textb') || undef,	
			value_date => $page->field('value_date') || undef,
			value_block => 1,
			_debug => 1
		);
	}
	else
	{
		$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('parent_id') || undef,
			item_id => $page->param('item_id') || undef,
			item_name =>'Phone Message',
			value_type => 0,
			value_text => $page->field('value_text') || undef,	
			value_textB => $page->field('value_textb') || undef,	
			value_date => $page->field('value_date') || undef,
			value_block => 1,
			_debug => 1
		);	
	}
	
	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id => $page->param('person_id') || undef,
		item_id => $page->param('item_id') || undef,
		item_name =>'Phone Message',
		value_type => 0,
		value_date => $page->field('value_date') || undef,
		value_text => $page->field('value_textb') || undef,	
		value_textB => $page->field('value_text') || undef,	
		value_block => 0,		
		_debug => 0
	);
	
	$self->handlePostExecute($page, $command, $flags);
	
}

use constant PANEDIALOG_ATTENDANCE => 'Dialog/Pane/Phone Message';

@CHANGELOG =
(
);

1;
