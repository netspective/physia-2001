##############################################################################
package App::Dialog::Attribute::AssociatedResource::SessionPhysicians;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Scheduling;
use App::Statements::Component::Scheduling;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'resource-session-physicians' => {
		valueType => App::Universal::ATTRTYPE_RESOURCEPERSON,
		heading => '$Command Session Set Of Physicians',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_RESOURCEPERSON()
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'sessionphysicians');
	my $schema = $self->{schema};
	my $sessOrg = $self->{sessionOrg};
	my $orgId = $self->{orgId};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(	new CGI::Dialog::Field(type => 'hidden', name => 'attr_path')  );
	$self->addContent(
			new CGI::Dialog::Field(caption => 'Physician Name',
										#type => 'foreignKey',
										name => 'value_text',
										style => 'multicheck',
										hints => 'You may choose more than one Physician.',
										fKeyStmtMgr => $STMTMGR_PERSON,
										fKeyStmt => 'selResourceAssociations',
										#fKeyTable => 'person p, person_org_category pcat',
										#fKeySelCols => "distinct p.person_id, p.complete_name",
										fKeyDisplayCol => 1,
										fKeyValueCol => 0,
										#fKeyWhere => "p.person_id=pcat.person_id and pcat.org_id='$sessOrg' and category='Physician'",
										options => FLDFLAG_REQUIRED,
										readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE)
			);

		$self->{activityLog} =
		{
				level => 1,
				scope =>'person_attribute',
				key => "#param.person_id#",
				data => "Associated Resource '#field.value_text#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
		};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub _customValidate
{
	my ($self, $page) = @_;

	my $command = $self->getActiveCommand($page);
	return () if $command ne 'add';
	my $itemId = $page->param('item_id');
	my $physicianName = $self->getField('value_text');
	my $sessOrg = $self->{sessionOrg};
	my $itemName = 'Physician';
	my $parentId = $page->param('person_id');

	my $physicianList = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);


		if ($physicianList->{'value_int'} eq 1)
		{
			$physicianName->invalidate($page, " A list of Physicians allready exists. Modify the existing record to change the list.");
		}

}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	my $sessOrgId = $page->session('org_internal_id');
	$self->getField('value_text')->{fKeyStmtBindPageParams} = $sessOrgId;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	my $itemId = $page->param('item_id');
	my $physicansList = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

	my @physicians = split(/,/, $physicansList->{value_text});
	$page->field('value_text', @physicians);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $parentId =  $page->param('person_id');
	my $physiciansString = join(',', $page->field('value_text'));
	my $physicansList = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selSessionPhysicians', $parentId);
	my $itemId = $physicansList->{'item_id'};

	if ($itemId ne '' && $command eq 'add')
	{
		$command = 'update';
	}

	$page->schemaAction(
		'Person_Attribute',	$command,
		item_id => $command eq 'add' ? undef : $itemId,
		parent_id => $page->param('person_id'),
		parent_org_id => $page->session('org_internal_id') || undef,
		value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
		item_name => 'SessionPhysicians',
		value_text => $physiciansString,
		value_int =>  1,
		_debug => 0
	);

	my $userId = $page->session('user_id');

	$STMTMGR_COMPONENT_SCHEDULING->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_resources', $userId, 'Physician');

	my @physicians = $page->field('value_text');
	for (@physicians)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_internal_id') || undef,
			value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
			item_name => 'Physician',
			value_text => $_,
			value_int =>  1,
			_debug => 0
		);
	}

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;
