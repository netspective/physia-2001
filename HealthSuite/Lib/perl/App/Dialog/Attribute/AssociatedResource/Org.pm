##############################################################################
package App::Dialog::Attribute::AssociatedResource::Org;
##############################################################################

use DBI::StatementManager;
use App::Statements::Org;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'resource-org' => {
		valueType => App::Universal::ATTRTYPE_RESOURCEORG,
		heading => '$Command Associated Organization',
		_arl => ['org_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_RESOURCEORG()
		},
);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'resourceorg');
	my $schema = $self->{schema};
	my $sessOrg = $self->{sessionOrg};
	my $orgId = $self->{orgId};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(	new CGI::Dialog::Field(type => 'hidden', name => 'attr_path')  );

	$self->addContent(
				new App::Dialog::Field::Organization::ID(caption => 'Org ID', name => 'value_text', options => FLDFLAG_REQUIRED)
			);

	$self->{activityLog} =
	{
		level => 2,
		scope =>'org_attribute',
		key => "#param.org_id#",
		data => "Associated Org '#field.value_text#' to <a href='/org/#param.org_id#/profile'>#param.org_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');
	$STMTMGR_ORG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	#my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', 
	#$page->session('org_internal_id'), $page->param('org_id');
	my $orgId = $page->param('org_id') ? $page->param('org_id') : $page->session('org_id');
	my $orgIntId = $page->session('org_internal_id');
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $orgIntId, $orgId) if $page->param('org_id');
	$page->schemaAction(
		'Org_Attribute', $command,
		parent_id => $orgIntId || undef,
		item_id => $page->param('item_id') || undef,
		item_name => 'Organization',
		value_type => App::Universal::ATTRTYPE_RESOURCEORG || undef,
		value_text => $page->field('value_text') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);

	return "\u$command completed.";
}

1;
