##############################################################################
package App::Dialog::Organization::Department;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(App::Dialog::Organization);

sub initialize
{
	my $self = shift;

	$self->SUPER::initialize();
	$self->{id} = '$Command Department';

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'phone_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'fax_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'email_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'contact_item_id'),

		new App::Dialog::Field::Organization::ID::New(caption => 'Dept ID',
								name => 'dept_id',
								options => FLDFLAG_REQUIRED,
								postHtml => "<a href=\"javascript:doActionPopup('/lookup/org');\">Lookup organizations</a>"),

		new CGI::Dialog::Field(caption => 'Department Name', name => 'name_primary', options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Subhead(heading => 'General Information', name => 'gen_info_heading'),

		new App::Dialog::Field::Organization::ID(caption => 'Parent Organization ID', name => 'parent_org_id'),

		new CGI::Dialog::MultiField(caption =>'Phone/Fax', name => 'phone_fax',
			fields => [
				new CGI::Dialog::Field(type=>'phone', caption => 'Phone', name => 'phone', options => FLDFLAG_REQUIRED),
				new CGI::Dialog::Field(type=>'phone', caption => 'Fax', name => 'fax'),
			]),

		new CGI::Dialog::Field(type=>'email', caption => 'Email', name => 'email'),

		new CGI::Dialog::MultiField(caption =>'Org Contact/Phone', name => 'org_contact',
			fields => [
				new CGI::Dialog::Field(caption => 'Contact', name => 'contact_name'),
				new CGI::Dialog::Field(type=>'phone', caption => 'Phone', name => 'contact_phone'),

			]),

	);
	$self->{activityLog} =
	{
		scope =>'org',
		key => "#field.org_id#",
		data => "Organization '#field.org_id#' <a href='/org/#field.org_id#/profile'>#field.name_primary#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	my $deptId = $page->param('dept_id');
	$page->field('dept_id', $deptId);

	my $orgId = $page->param('org_id');
	if($orgId)
	{
		$page->field('parent_org_id', $orgId);
		$self->setFieldFlags('parent_org_id', FLDFLAG_READONLY);
	}

	if($command ne 'add')
	{
		$self->setFieldFlags('dept_id', FLDFLAG_READONLY);
	}

	if($command eq 'remove')
	{
		$self->setFieldFlags('name_primary', FLDFLAG_READONLY);
		$self->updateFieldFlags('gen_info_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('parent_org_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('phone_fax', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('email', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('org_contact', FLDFLAG_INVISIBLE, 1);
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $deptId = $page->param('dept_id');

	my $deptInfo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $deptId);
	$page->field('name_primary', $deptInfo->{name_primary});

	my $deptPhone = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $deptId, 'Primary', App::Universal::ATTRTYPE_PHONE);
	$page->field('phone', $deptPhone->{value_text});
	$page->field('phone_item_id', $deptPhone->{item_id});

	my $deptFax = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $deptId, 'Primary', App::Universal::ATTRTYPE_FAX);
	$page->field('fax', $deptFax->{value_text});
	$page->field('fax_item_id', $deptFax->{item_id});

	my $deptEmail = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $deptId, 'Primary', App::Universal::ATTRTYPE_EMAIL);
	$page->field('email', $deptEmail->{value_text});
	$page->field('email_item_id', $deptEmail->{item_id});

	my $deptContact = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $deptId, 'Contact Information');
	$page->field('contact_name', $deptContact->{value_text});
	$page->field('contact_phone', $deptContact->{value_textb});
	$page->field('contact_item_id', $deptContact->{item_id});
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $parentOrgId = $page->param('org_id') || $page->field('parent_org_id');

	## First create new Org record
	$page->schemaAction(
			'Org', $command,
			org_id => $page->field('dept_id') || undef,
			parent_org_id => $parentOrgId || undef,
			name_primary => $page->field('name_primary') || undef,
			category => 'Department',
			_debug => 0
		);


	##Then add property records for all contact methods

	my $phoneAttrType = App::Universal::ATTRTYPE_PHONE;
	my $textAttrType = App::Universal::ATTRTYPE_TEXT;
	$page->schemaAction(
			'Org_Attribute', $command,
			item_id => $page->field('phone_item_id') || undef,
			parent_id => $page->field('dept_id'),
			item_name => 'Primary',
			value_type => $phoneAttrType,
			value_text => $page->field('phone') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Org_Attribute', $command,
			item_id => $page->field('fax_item_id') || undef,
			parent_id => $page->field('dept_id'),
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_FAX || undef,
			value_text => $page->field('fax') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Org_Attribute', $command,
			item_id => $page->field('email_item_id') || undef,
			parent_id => $page->field('dept_id'),
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_EMAIL || undef,
			value_text => $page->field('email') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Org_Attribute', $command,
			item_id => $page->field('contact_item_id') || undef,
			parent_id => $page->field('dept_id'),
			item_name => 'Contact Information',
			value_type => defined $textAttrType ? $textAttrType : undef,
			value_text => $page->field('contact_name') || undef,
			value_textB => $page->field('contact_phone') || undef,
			_debug => 0
		);

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";

}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $orgId = $page->field('dept_id');

	$page->schemaAction(
			'Org', $command,
			org_id => $orgId,
			_debug => 0
		);

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hierarchies
# 4: any text notes about the actual change/action
#
use constant DIALOG_DEPT => 'Dialog/Department';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/09/2000', 'MAF',
		DIALOG_DEPT,
		'Create new module for department orgs.'],
);

1;
