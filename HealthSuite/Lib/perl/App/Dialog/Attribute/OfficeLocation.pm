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
		new CGI::Dialog::Field(name => 'value_textb', caption => 'Office/Room/Suite#', size => 7),
		new CGI::Dialog::Field(type => 'bool', name => 'value_int', caption => 'Default', style => 'check'),
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

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $personId = $page->param('person_id');
	$STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selOfficeLocationData', $personId) ? $self->updateFieldFlags('value_int', FLDFLAG_INVISIBLE, 0) : $self->updateFieldFlags('value_int', FLDFLAG_INVISIBLE, 1);
	my $itemId = $page->param('item_id');
	my $data = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

	if ($command eq 'update' && $data->{'value_int'} ne '')
	{
		$page->field('value_int',1);
		$self->updateFieldFlags('value_int', FLDFLAG_INVISIBLE, 1);
	}
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');
	my $data = $STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
}

sub customValidate
{
	my ($self, $page) = @_;

	my $oId = $self->getField('value_text');
	my $personId = $page->param('person_id');
	my $orgId = $page->field('value_text');
	my $itemId = $page->param('item_id');
	my $orgExists = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selOfficeLocationOrg', $personId,$orgId);
	if (($orgExists->{'value_text'} eq $orgId) && ($itemId ne $orgExists->{'item_id'}))
	{
		$oId->invalidate($page, "This $oId->{caption} already exists for the Person '$personId'");
	}
}


sub execute
{
	my ($self, $page, $command,$flags) = @_;

	my $personId = $page->param('person_id');
	my $officeRecord = $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selOfficeLocationData', $personId);
	my $defaultField = $officeRecord eq 1 ? $page->field('value_int') : 1;

	if ($page->field('value_int') ne '')
	{

		my $defaultOrgData = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selOfficeLocationData', $personId);
		foreach my $defaultOrg(@{$defaultOrgData})
		{
			if ($defaultOrg->{'value_int'} ne '')
			{
				my $itemId = $defaultOrg->{'item_id'};
				$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selupdClearDefaultOrg', $itemId);
			}
		}
	}

	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id => $personId || undef,
		item_id => $page->param('item_id') || undef,
		item_name =>'Office Location',
		value_type => 0,
		value_text => $page->field('value_text') || undef,
		value_textB => $page->field('value_textb') || undef,
		value_int => $defaultField || undef,
		_debug => 0
	);

	return "\u$command completed.";
}

1;
