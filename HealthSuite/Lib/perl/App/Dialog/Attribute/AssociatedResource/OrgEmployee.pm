##############################################################################
package App::Dialog::Attribute::AssociatedResource::OrgEmployee;
##############################################################################

use DBI::StatementManager;
use App::Statements::Org;
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
	'resource-orgemp' => {
		valueType => App::Universal::ATTRTYPE_RESOURCEOTHER,
		heading => '$Command Associated Employee',
		_arl => ['org_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_RESOURCEOTHER()
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'resourceemployee');
	my $schema = $self->{schema};
	my $sessOrg = $self->{sessionOrg};
	my $orgId = $self->{orgId};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Person::ID(caption => 'Employee ID', name => 'emp_id'),

	);

	$self->{activityLog} =
	{
			level => 1,
			scope =>'person_attribute',
			key => "#param.org_id#",
			data => "Associated Resource '#field.value_text#' to <a href='/org/#param.org_id#/profile'>#param.org_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	my $sessOrg = $page->session('org_id') ;
	my $orgId = $page->param('org_id');
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return () if $command eq 'add';

	my $itemId = $page->param('item_id');
	$STMTMGR_ORG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	$page->schemaAction(
		'Org_Attribute',
		$command,
		parent_id => $page->param('org_id'),
		item_id => $page->param('item_id') || undef,
		item_name => 'Staff',
		value_type => App::Universal::ATTRTYPE_RESOURCEOTHER || undef,
		value_text => $page->field('value_text') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;
