##############################################################################
package App::Dialog::Attribute::Credential;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Dialog::Field::Attribute;
use App::Statements::Org;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'credential' => {
		valueType => App::Universal::ATTRTYPE_CREDENTIALS,
		heading => '$Command Credentils',
		_arl => ['org_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_CREDENTIALS()
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'credential', heading => '$Command Credentials');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Attribute::Name(name => 'value_textb',
			caption => 'ID Caption', priKey => 1, type => 'select',
			selOptions => ';Employer#;State#;Medicaid#;Workers Comp#;BCBS#;Medicare#;CLIA#',
			options => FLDFLAG_REQUIRED,
			attrNameFmt => "#field.value_textb#",
			fKeyStmtMgr => $STMTMGR_ORG,
			valueType => $self->{valueType},
			selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'
		),
		new CGI::Dialog::Field(name => 'value_text',
			caption => 'ID Number',
			options => FLDFLAG_REQUIRED
		),
	);

	$self->{activityLog} =
	{
		level => 2,
		scope =>'org_attribute',
		key => "#param.org_id#",
		data => "Credentials '#field.value_textb#' to <a href='/org/#param.org_id#/profile'>#param.org_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons);
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
		item_name => $page->field('value_textb') || undef,
		value_type => App::Universal::ATTRTYPE_CREDENTIALS || undef,
		value_text => $page->field('value_text') || undef,
		value_textB => $page->field('value_textb') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;
