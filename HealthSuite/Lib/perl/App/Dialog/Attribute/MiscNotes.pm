##############################################################################
package App::Dialog::Attribute::MiscNotes;
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
	my ($self, $command) = CGI::Dialog::new(@_, id => 'miscnotes', heading => '$Command Misc Notes');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(name => 'value_text', caption => 'Misc Notes', type => 'memo', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'value_date', caption => 'Date', type => 'date'),
	);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Misc Notes to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
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
		item_name =>'Misc Notes',
		value_type => 0,
		value_text => $page->field('value_text') || undef,	
		value_date => $page->field('value_date') || undef,
		_debug => 0
	);
	return "\u$command completed.";
}

use constant PANEDIALOG_ATTENDANCE => 'Dialog/Pane/Misc Notes';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/08/2000', 'RK',
		PANEDIALOG_ATTENDANCE,
		'Created a new file for attendance.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/14/2000', 'RK',
		PANEDIALOG_ATTENDANCE,
		'Removed Item Path from Item Name'],
);

1;
