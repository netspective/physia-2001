##############################################################################
package App::Dialog::Attribute::OfficeLocation;
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
	'office-location' => {
		valueType => App::Universal::ATTRTYPE_TEXT,
		heading => '$Command Office Location',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'miscnotes', heading => '$Command Office Location');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Organization::ID(name => 'value_text', caption => 'Location Org ID', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'value_textB', caption => 'Office/Room/Suite#'),
		new CGI::Dialog::Field(type => 'bool', name => 'value_int', caption => 'Default', style => 'check', defaultValue => 1),
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Office location to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
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
		item_name =>'Office Location',
		value_type => 0,
		value_text => $page->field('value_text') || undef,
		value_textB => $page->field('value_textB') || undef,
		value_int => $page->field('value_int') || undef,
		_debug => 0
	);
	return "\u$command completed.";
}

1;
