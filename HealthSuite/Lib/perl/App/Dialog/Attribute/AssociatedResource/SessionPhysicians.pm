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

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	
	$self->addContent(
		new CGI::Dialog::Field(caption => 'Physician',
			name => 'physician_list',
			style => 'multicheck',
			fKeyStmtMgr => $STMTMGR_PERSON,
			fKeyStmt => 'selResourceAssociations',
			fKeyStmtBindSession => ['org_internal_id'],
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			size => 5,
		),
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Associated Resource '#field.physician_list#' for <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $orgInternalId = $page->session('org_internal_id');
	my $physicansList = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, 
		STMTMGRFLAG_NONE, 'sel_worklist_resources', $page->param('person_id'), 'WorkList', $orgInternalId);

	my @physicians = ();
	for (@$physicansList)
	{
		push(@physicians, $_->{resource_id});
	}
	
	$page->field('physician_list', @physicians);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $parentId =  $page->param('person_id');
	my $orgInternalId = $page->session('org_internal_id');

	$STMTMGR_COMPONENT_SCHEDULING->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_resources', $parentId, 'WorkList', $orgInternalId);

	my @physicians = $page->field('physician_list');
	for (@physicians)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $parentId,
			parent_org_id => $page->session('org_internal_id') || undef,
			value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
			item_name => 'WorkList',
			value_text => $_,
			parent_org_id => $orgInternalId,
			_debug => 0
		);
	}

	#$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	$self->handlePostExecute($page, $command, $flags);
	#return "\u$command completed.";
}

1;
