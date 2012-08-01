##############################################################################
package App::Dialog::Attribute::Attendance;
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
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'attendance' => {
		valueType => App::Universal::ATTRTYPE_EMPLOYEEATTENDANCE,
		heading => '$Command Attendance',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_EMPLOYEEATTENDANCE()
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'attendance', heading => '$Command Attendance');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(name => 'value_textb', caption => 'Property Name', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'value_text',caption => 'Property Value', options => FLDFLAG_REQUIRED),
	);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Attendance '#field.value_textb#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
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
		parent_id => $page->param('person_id'),
		item_id => $page->param('item_id') || undef,
		item_name => $page->field('value_textb') || undef,
		value_type => App::Universal::ATTRTYPE_EMPLOYEEATTENDANCE || undef,
		value_text => $page->field('value_text') || undef,
		value_textB => $page->field('value_textb') || undef,
		_debug => 0
	);

	return "\u$command completed.";
}

1;
