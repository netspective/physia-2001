##############################################################################
package App::Dialog::Organization;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Insurance;
use App::Dialog::Field::Address;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use App::Universal;


use Date::Manip;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog);

sub initialize
{
	my $self = shift;
	my $schema = $self->{schema};

	croak 'schema parameter required' unless $schema;

	my $orgIdCaption = $self->{orgtype} eq 'dept' ? 'Department ID' : 'Organization ID';

	if ($self->{orgtype} ne 'main')
	{
		$self->addContent(new App::Dialog::Field::Organization::ID(caption => 'Parent Organization ID', name => 'parent_org_id'));
	}

	$self->addContent(
		new App::Dialog::Field::Organization::ID::New(caption => $orgIdCaption,
								name => 'org_id',
								options => FLDFLAG_REQUIRED,
								readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
								postHtml => "<a href=\"javascript:doActionPopup('/lookup/org');\">Lookup organizations</a>"),

		new CGI::Dialog::Field::TableColumn(caption => 'Organization Name', name => 'name_primary',
			schema => $schema, column => 'Org.name_primary'),

		new CGI::Dialog::Field::TableColumn(caption => 'Doing Business As', name => 'name_trade',
			schema => $schema, column => 'Org.name_trade'),

		new CGI::Dialog::Subhead(heading => 'General Information', name => 'gen_info_heading'),
	);

	$self->addContentOrgType($self->{orgtype});

	$self->addContent(
			new CGI::Dialog::MultiField(caption =>'Hours of Operation/Time Zone', name => 'hours_and_tzone',
				fields => [
					new CGI::Dialog::Field(caption => 'Hours of Operation', name => 'business_hours'),
					new CGI::Dialog::Field::TableColumn(type => 'select', selOptions => 'EST;CST;MST;PST',
						schema => $schema, column => 'Org.time_zone', caption => 'Time Zone', name => 'time_zone'),
				]),

			new CGI::Dialog::MultiField(caption =>'Phone/Fax', name => 'phone_fax', invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE,
				fields => [
					new CGI::Dialog::Field(type=>'phone', caption => 'Phone', name => 'phone', options => FLDFLAG_REQUIRED, invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
					new CGI::Dialog::Field(invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE, type=>'phone', caption => 'Fax', name => 'fax'),
				]),

			new App::Dialog::Field::Address(caption=>'Mailing Address', name => 'address',  options => FLDFLAG_REQUIRED, invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),

			new CGI::Dialog::Field(type=>'email', caption => 'Email', name => 'email', invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
			new CGI::Dialog::Field(type=>'url', caption => 'Website', name => 'internet', invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
			new CGI::Dialog::MultiField(caption =>'Org Contact/Phone', name => 'org_contact', invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE,
				fields => [
					new CGI::Dialog::Field(invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE, caption => 'Contact', name => 'contact_name'),
					new CGI::Dialog::Field(type=>'phone', caption => 'Phone', name => 'contact_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),

				]),
	);

	if ($self->{orgtype} ne 'dept')
	{
		$self->addContent(
			new CGI::Dialog::Subhead(heading => 'ID Numbers', name => 'ids_heading'),
				new CGI::Dialog::Field::TableColumn(caption => 'Tax ID', name => 'tax_id',
					schema => $schema, column => 'Org.tax_id'),
				new CGI::Dialog::Field(caption => 'Employer ID', name => 'emp_id'),
				new CGI::Dialog::Field(caption => 'State ID', name => 'state_id'),
				new CGI::Dialog::Field(caption => 'Medicaid ID', name => 'medicaid_id'),
				new CGI::Dialog::Field(caption => "Worker's Comp ID", name => 'wc_id'),
				new CGI::Dialog::Field(caption => 'Blue Cross-Blue Shield ID', name => 'bcbs_id'),
				new CGI::Dialog::Field(caption => 'Medicare ID', name => 'medicare_id'),
				new CGI::Dialog::Field(caption => 'CLIA ID', name => 'clia_id'),
		);
	}
	if ($self->{orgtype} eq 'provider' || $self->{orgtype} eq 'dept')
	{
		$self->addContent(new CGI::Dialog::Field(caption => 'HCFA Service Place', nane => 'hcfa_service_place', lookup => 'HCFA1500_Service_Place_Code'));
	}
	$self->addContent(
		new CGI::Dialog::Field(
						type => 'bool',
						name => 'delete_record',
						caption => 'Delete record?',
						style => 'check',
						invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
						readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE),
	);
	$self->{activityLog} =
	{
		scope =>'org',
		key => "#field.org_id#",
		data => "Organization '#field.org_id#' <a href='/org/#field.org_id#/profile'>#field.name_primary#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(
							nextActions_add => [
								['View Org Summary', "/org/%field.org_id%/profile", 1],
								['Add Another Org', "/org/#session.org_id#/dlg-add-org-$self->{orgtype}"],
								['Add Insurance Policy', "/org/#session.org_id#/dlg-add-ins-newplan"],
								['Go to Directory', "/search/org/id/%field.org_id%"],
								['Return to Home', "/person/#session.user_id#/home"],
								],
							cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub addContentOrgType
{
	my ($self, $type) = @_;
	my $excludeGroups = "''";

	if ($type eq 'dept' || $type eq 'employer' || $type eq 'insurance' || $type eq 'ipa')
	{
		$self->addContent(new CGI::Dialog::Field(type => 'hidden', name => 'member_name',));
		return;
	}
	if ($type eq 'main')
	{
		$excludeGroups = "'dept'";
	}
	if ($type eq 'provider')
	{
		$excludeGroups = "'employer', 'insurance', 'ipa', 'other'";
	}

	$self->addContent(
		new CGI::Dialog::Field(name => 'member_name',
				lookup => 'Org_Type',
				style => 'multicheck',
				options => FLDFLAG_REQUIRED,
				caption => 'Organization <nobr>Type(s)</nobr>',
				hints => 'You may choose more than one organization type.',
				fKeyWhere => "group_name not in ($excludeGroups)"),
	);

}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $orgId = $page->param('org_id');

	if($command eq 'update' || $command eq 'remove')
	{
		$self->updateFieldFlags('phone_fax', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('address', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('email', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('internet', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('ids_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('tax_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('emp_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('state_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('medicaid_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('wc_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('bcbs_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('medicare_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('clia_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('hours_and_tzone', FLDFLAG_INVISIBLE, 1);

	}

	if($orgId && $command eq 'add' && $orgId ne $page->session('org_id'))
	{
		$page->field('org_id', $orgId);
		#$self->setFieldFlags('org_id', FLDFLAG_READONLY);
	}

	if($command eq 'remove')
	{
		my $deleteRecord = $self->getField('delete_record');
		$deleteRecord->invalidate($page, "Are you sure you want to delete Organization '$orgId'?");
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	if($flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL)
	{
	for ($self->{orgtype})
		{
			/dept/		and do { $page->field('member_name','Department'); last };
			/insurance/	and do { $page->field('member_name','Insurance'); last };
			/employer/	and do { $page->field('member_name','Employer'); last };
			/ipa/		and do { $page->field('member_name','IPA'); last };
		}
	$page->field('parent_org_id', $page->{session}{org_id});
	}

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $orgId = $page->param('org_id');

	$STMTMGR_ORG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selRegistry', $orgId);

	my $categories = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selCategory', $orgId);
	my @categories = split(', ', $categories);
	$page->field('member_name', @categories);

	if($command eq 'remove')
	{
		$page->field('delete_record', 1);
	}
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my @members = $page->field('member_name');
	my $taxId = '';
	if ($page->field('tax_id') eq '' && $page->field('parent_org_id') ne '')
	{
		my $parentId = $page->field('parent_org_id');
		my $parentData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $parentId);
		$taxId = $parentData->{'tax_id'};
	}

	## First create new Org record
	$page->schemaAction(
			'Org', $command,
			org_id => $page->field('org_id') || undef,
			parent_org_id => $page->field('parent_org_id') || undef,
			tax_id => $page->field('tax_id') ne '' ?  $page->field('tax_id') : $taxId,
			name_primary => $page->field('name_primary') || undef,
			name_trade => $page->field('name_trade') || undef,
			time_zone => $page->field('time_zone') || undef,
			category => join(', ', @members) || undef,
			_debug => 0
		);

	##Then add mailing address
	$page->schemaAction(
			'Org_Address', $command,
			parent_id => $page->field('org_id'),
			address_name => 'Mailing',
			line1 => $page->field('addr_line1'),
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city'),
			state => $page->field('addr_state'),
			zip => $page->field('addr_zip'),
			_debug => 0
		) if $page->field('addr_line1') ne '';

	##Then add attributes

	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $credentialsValueType = App::Universal::ATTRTYPE_CREDENTIALS;
	my $generalValueType = App::Universal::ATTRTYPE_ORGGENERAL;

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'HCFA Service Place',
			value_type => App::Universal::ATTRTYPE_INTEGER || undef,
			value_text => $page->field('hcfa_service_place') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_PHONE || undef,
			value_text => $page->field('phone') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_FAX || undef,
			value_text => $page->field('fax') || undef,
			_debug => 0
		) if $page->field('fax') ne'';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_EMAIL || undef,
			value_text => $page->field('email') || undef,
			_debug => 0
		) if $page->field('email') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_URL || undef,
			value_text => $page->field('internet') || undef,
			_debug => 0
		) if $page->field('internet') ne '';

	##Then add property record for Business Hours
	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'Business Hours',
			value_type => defined $generalValueType ? $generalValueType : undef,
			value_text => $page->field('business_hours') || undef,
			_debug => 0
		) if $page->field('business_hours') ne '';

		my $parentId = $page->field('parent_org_id');
		my $itemNameEmp = '';
		my $itemName = '';
		my $empId = '';
		my $stateId = '';

		if ($page->field('emp_id') eq '')
		{
			 $itemNameEmp = 'Employer#';
			 my $parentData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $parentId, $itemNameEmp);
			 $empId = $parentData->{'value_text'};
		}

		if ($page->field('state_id') eq  '')
		{
			$itemName = 'State#';
			my $parentData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $parentId, $itemName);
			$stateId = $parentData->{'value_text'};
		}

	# Finally, add records for all ID Numbers
	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'Employer#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('emp_id') ne '' ? $page->field('emp_id') : $empId,
			_debug => 0
		)if ($page->field('emp_id') ne '' || $empId ne '');

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'State#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('state_id') ne '' ? $page->field('state_id') : $stateId,
			_debug => 0
		)if ($page->field('state_id') ne '' || $stateId ne '');

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'Medicaid#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('medicaid_id') || undef,
			_debug => 0
		) if $page->field('medicaid_id') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => "Workers Comp#",
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('wc_id') || undef,
			_debug => 0
		) if $page->field('wc_id') ne'';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'BCBS#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('bcbs_id') || undef,
			_debug => 0
		) if $page->field('bcbs_id') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'Medicare#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('medicare_id') || undef,
			_debug => 0
		) if $page->field('medicare_id') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'CLIA#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('clia_id') || undef,
			_debug => 0
		) if $page->field('clia_id') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $page->field('org_id'),
			item_name => 'Contact Information',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $page->field('contact_name') || undef,
			value_textB => $page->field('contact_phone') || undef,
			_debug => 0
		)if $page->field('contact_phone') ne '';

	$self->handlePostExecute($page, $command, $flags);
	return '';

}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $orgId = $page->field('org_id');

	my @members = $page->field('member_name');

	## First update new Org record
	$page->schemaAction(
			'Org', $command,
			org_id => $orgId,
			parent_org_id => $page->field('parent_org_id') || undef,
			tax_id => $page->field('tax_id') || undef,
			name_primary => $page->field('name_primary') || undef,
			name_trade => $page->field('name_trade') || undef,
			time_zone => $page->field('time_zone') || undef,
			category => join(', ', @members) || undef,
			_debug => 0
		);


	$self->handlePostExecute($page, $command, $flags);
	return '';
}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $orgId = $page->field('org_id');

	$page->schemaAction(
			'Org', $command,
			org_id => $orgId,
			_debug => 0
		);

	$self->handlePostExecute($page, $command, $flags);
	return '';
}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hierarchies
# 4: any text notes about the actual change/action
#
use constant ORG_DIALOG => 'Dialog/Org';
use constant ORG_SESSIONACTIVITY =>'Session/Org';

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/14/1999', 'MAF',
		ORG_DIALOG,
		'Added entry for CLIA ID# in the Org dialog.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/05/2000', 'RK',
		ORG_SESSIONACTIVITY,
		'Added session-activity in execute_add subroutine.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/12/2000', 'RK',
		ORG_SESSIONACTIVITY,
		'Deleted session-activity in execute_add subroutine and added activityLog in the sub new subroutine.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/12/2000', 'RK',
		ORG_SESSIONACTIVITY,
		'Added handlePostExecute in sub execute subroutine'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/20/2000', 'RK',
		ORG_SESSIONACTIVITY,
		'Added a new multifield called OrgContact/Phone.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_REMOVE, '01/26/2000', 'MAF',
		ORG_DIALOG,
		'Removed CLIA# when updating an org.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/26/2000', 'RK',
		ORG_DIALOG,
		'Fixed problem with org attribute Business Hours.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/15/2000', 'MAF',
		ORG_DIALOG,
		'Added checkbox for verifying delete record.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/15/2000', 'MAF',
		ORG_DIALOG,
		'Fixed problem with populating categories.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/17/2000', 'MAF',
		ORG_DIALOG,
		'Fixed problem with org id field.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/07/2000', 'MAF',
		ORG_DIALOG,
		'Fixed attribute types.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '04/03/2000', 'RK',
			ORG_DIALOG,
		'Fixed the code to add the Parent Org Employer# and State# as the default ones to the child org if those fields are left blank'],
);

1;
