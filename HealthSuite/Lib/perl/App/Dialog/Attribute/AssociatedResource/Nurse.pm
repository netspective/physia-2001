##############################################################################
package App::Dialog::Attribute::AssociatedResource::Nurse;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'resource-nurse' => {
		valueType => App::Universal::ATTRTYPE_RESOURCEPERSON,
		heading => '$Command Associated Physician',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-assoc-nurse-' .App::Universal::ATTRTYPE_RESOURCEPERSON()
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'resourcenurse');
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

sub customValidate
{
	my ($self, $page) = @_;

	my $command = $self->getActiveCommand($page);
	return () if $command ne 'add';

	my $physicianName = $self->getField('value_text');
	my $name = $page->field('value_text');
	my $itemName = 'Physician';
	my $parentId = $page->param('person_id');

	my $physicianData = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $parentId, $itemName, App::Universal::ATTRTYPE_RESOURCEPERSON);
	foreach my $physician(@{$physicianData})
	{
		if ($physician->{'value_text'} eq $name)
		{
			$physicianName->invalidate($page, " The $physicianName->{caption} '$name' already exists for $parentId.");
		}
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
	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->param('person_id'),
		item_id => $page->param('item_id') || undef,
		value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
		value_text => $page->field('value_text') || undef,
		parent_org_id => $page->session('org_internal_id') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;
