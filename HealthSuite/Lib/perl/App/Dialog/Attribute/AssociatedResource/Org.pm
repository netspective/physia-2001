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
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

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

	$page->schemaAction(
		'Org_Attribute', $command,
		parent_id => $page->param('org_id') || undef,
		item_id => $page->param('item_id') || undef,
		item_name => 'Organization',
		value_type => App::Universal::ATTRTYPE_RESOURCEORG || undef,
		value_text => $page->field('value_text') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);

	return "\u$command completed.";
}

use constant PANEDIALOG_ASSOCRSRC => 'Dialog/Associated Resource';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/01/2000', 'RK',
		PANEDIALOG_ASSOCRSRC,
		'Added a new dialog for Associated Resource pane in Org profile.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/14/2000', 'RK',
		PANEDIALOG_ASSOCRSRC,
		'Removed Item Path from Item Name'],
);

1;