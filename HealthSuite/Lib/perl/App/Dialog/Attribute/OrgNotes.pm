##############################################################################
package App::Dialog::Attribute::OrgNotes;
##############################################################################

use DBI::StatementManager;
use App::Statements::Org;
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
	'org-notes' => {
		valueType => App::Universal::ATTRTYPE_TEXT,
		heading => '$Command Org Notes',
		_arl => ['org_id'] ,
		_arl_modify => ['item_id'],
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'org-notes', heading => '$Command Org Notes');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(name => 'value_text', caption => 'caption', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'value_textb', caption => 'Detail', type => 'memo'),
		new CGI::Dialog::Field(name => 'value_date', caption => 'Begin Date', type => 'date', futureOnly => 0),
		new CGI::Dialog::Field(name => 'value_dateb', caption => 'End Date', type => 'date', defaultValue => ''),
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'org_attribute',
		key => "#param.org_id#",
		data => "Org Notes to <a href='/org/#param.org_id#/profile'>#param.org_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');
	my $data = $STMTMGR_ORG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	my $orgId = $page->param('org_id') ? $page->param('org_id') : $page->session('org_id');
	my $orgIntId = $page->session('org_internal_id');
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $orgIntId, $orgId) if $page->param('org_id');
	$page->schemaAction(
		'Org_Attribute', $command,
		parent_id => $orgIntId || undef,
		item_id => $page->param('item_id') || undef,
		item_name =>'Org Notes',
		value_type => 0,
		value_text => $page->field('value_text') || undef,
		value_textB => $page->field('value_textb') || undef,
		value_date => $page->field('value_date') || undef,
		value_dateB => $page->field('value_dateb') || undef,
		_debug => 0
	);
	return "\u$command completed.";
}

1;
