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
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'org-main' => {
		heading => '$Command Main Organization',
		orgtype => 'main',
		_arl => ['org_id'],
		_idSynonym => 'Root'
	},
	'org-dept' => {
		heading => '$Command Department Organization',
		orgtype => 'dept',
		_arl => ['org_id'],
		_idSynonym => 'Department'
	},
	'org-provider' => {
		heading => '$Command Associated Provider Organization',
		orgtype => 'provider',
		_arl => ['org_id'],
		_idSynonym => 'Clinic'
	},
	'org-employer' => {
		heading => '$Command Employer Organization',
		orgtype => 'employer',
		_arl => ['org_id'],
		_idSynonym => 'Employer'
	},
	'org-insurance' => {
		heading => '$Command Insurance Organization',
		orgtype => 'insurance',
		_arl => ['org_id'],
		_idSynonym => 'Insurance'
	},
	'org-ipa' => {
		heading => '$Command IPA Organization',
		orgtype => 'ipa',
		_arl => ['org_id'],
		_idSynonym => 'Ipa'
	},
);


sub initialize
{
	my $self = shift;
	my $schema = $self->{schema};
	croak 'schema parameter required' unless $schema;

	#my $orgIdCaption = $self->{orgtype} eq 'dept' ? 'Department ID' : 'Organization ID';
	my $orgIdCaption = 'Organization ID';

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'business_hrs_id'),
		new CGI::Dialog::Subhead(
			heading => 'Profile Information',
			name => 'gen_info_heading'
		),
	);

	if ($self->{orgtype} ne 'main')
	{
		$self->addContent(
			new App::Dialog::Field::Organization::ID(
				caption => 'Parent Organization ID',
				name => 'parent_org_id'
			),
			new App::Dialog::Field::Organization::ID::New(
				caption => $orgIdCaption,
				name => 'org_id',
				options => FLDFLAG_REQUIRED,
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
		);
	}
	else
	{
		$self->addContent(
			new App::Dialog::Field::Organization::ID::Main::New(
				caption => $orgIdCaption,
				name => 'org_id',
				options => FLDFLAG_REQUIRED,
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
		);
	}

	$self->addContent(
		new CGI::Dialog::Field::TableColumn(
			caption => 'Organization Name',
			name => 'name_primary',
			schema => $schema,
			column => 'Org.name_primary'
		),
		new CGI::Dialog::Field::TableColumn(
			caption => 'Doing Business As',
			name => 'name_trade',
			schema => $schema,
			column => 'Org.name_trade'
		),
	);

	$self->addContentOrgType($self->{orgtype});

	$self->addContent(
		new CGI::Dialog::Subhead(
			heading => 'Contact Information',
			name => 'contact_heading',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		),
		new CGI::Dialog::MultiField(
			name => 'hours_and_tzone',
			fields => [
				new CGI::Dialog::Field(
					caption => 'Hours of Operation',
					name => 'business_hours'),
				new CGI::Dialog::Field::TableColumn(
					caption => 'Time Zone',
					type => 'select',
					selOptions => 'EST;CST;MST;PST',
					schema => $schema,
					column => 'Org.time_zone',
					name => 'time_zone'),
			],
		),
	);

	if ($self->{orgtype} eq 'insurance')
	{
		$self->addContent(
			new CGI::Dialog::MultiField(
				name => 'phone_fax',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				fields => [
					new CGI::Dialog::Field(
						caption => 'Phone',
						type=>'phone',
						name => 'phone',
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
					),
					new CGI::Dialog::Field(
						caption => 'Fax',
						type=>'phone',
						name => 'fax',
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
					),
				],
			),
			new App::Dialog::Field::Address(
				caption=>'Mailing Address',
				name => 'address',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
		);
	}

	elsif ($self->{orgtype} ne 'insurance')
	{
		$self->addContent(
			new CGI::Dialog::MultiField(
				name => 'phone_fax',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				fields => [
					new CGI::Dialog::Field(
						caption => 'Phone',
						type=>'phone',
						name => 'phone',
						options => FLDFLAG_REQUIRED,
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
					),
					new CGI::Dialog::Field(
						caption => 'Fax',
						type=>'phone',
						name => 'fax',
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
					),
				],
			),
			new App::Dialog::Field::Address(
				caption=>'Mailing Address',
				name => 'address',
				options => FLDFLAG_REQUIRED,
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
		);
	}

	$self->addContent(
		new CGI::Dialog::Field(
			caption => 'Email',
			type=>'email',
			name => 'email',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		),
		new CGI::Dialog::Field(
			caption => 'Website',
			type=>'url',
			name => 'internet',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		),
		new CGI::Dialog::MultiField(
			name => 'org_contact',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE,
			fields => [
				new CGI::Dialog::Field(
					caption => 'Billing Contact',
					invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE,
					name => 'contact_name'),
				new CGI::Dialog::Field(
					caption => 'Phone',
					type=>'phone',
					name => 'contact_phone',
					invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
			]),
	);

	if ($self->{orgtype} eq 'main' || $self->{orgtype} eq 'provider')
	{
		$self->addContent(
			new CGI::Dialog::Subhead(
				heading => 'ID Numbers',
				name => 'ids_heading'
			),
			new CGI::Dialog::Field::TableColumn(
				caption => 'Tax ID',
				name => 'tax_id',
				schema => $schema,
				column => 'Org.tax_id'
			),
			new CGI::Dialog::Field(
				caption => 'Employer ID',
				name => 'emp_id',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
			new CGI::Dialog::Field(
				caption => 'State ID',
				name => 'state_id',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
			new CGI::Dialog::Field(
				caption => 'Medicaid ID',
				name => 'medicaid_id',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
			new CGI::Dialog::Field(
				caption => "Worker's Comp ID",
				name => 'wc_id',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
			new CGI::Dialog::Field(
				caption => 'Blue Cross-Blue Shield ID',
				name => 'bcbs_id',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
			new CGI::Dialog::Field(
				caption => 'Medicare ID',
				name => 'medicare_id',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
			new CGI::Dialog::Field(
				caption => 'CLIA ID',
				name => 'clia_id',
				invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			),
		);
	}
	if ($self->{orgtype} eq 'provider' || $self->{orgtype} eq 'dept')
	{
		$self->addContent(
			new CGI::Dialog::Subhead(
				heading => 'Service Information',
				name => 'service_heading'),
			new CGI::Dialog::Field(
				caption => 'HCFA Service Place',
				name => 'hcfa_service_place',
				lookup => 'HCFA1500_Service_Place_Code'),
			new CGI::Dialog::Field(
				caption => 'Medicare GPCI Location',
				name => 'medicare_gpci',
				findPopup => '/lookup/gpci/state/*/1',),
			new CGI::Dialog::Field(
				caption => 'Medicare Facility Pricing',
				name => 'medicare_facility_type',
				type => 'select',
				style => 'radio',
				choiceDelim =>',',
				selOptions => 'Non-Facility:0,Facility:1',),
		);
	}

	$self->addContent(
		new CGI::Dialog::Subhead(
			heading => '',
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
			name => ''),
		new CGI::Dialog::Field(
			caption => 'Delete record?',
			type => 'bool',
			name => 'delete_record',
			style => 'check',
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
			readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE),
	);

	$self->{activityLog} = {
		scope =>'org',
		key => "#field.org_id#",
		data => "Organization '#field.org_id#' <a href='/org/#field.org_id#/profile'>#field.name_primary#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_add => [
			['View Org Summary', "/org/%field.org_id%/profile", 1],
			['Add Another Org', "/org/#session.org_id#/dlg-add-org-$self->{orgtype}"],
			['Add Insurance Product', "/org/%field.org_id%/dlg-add-ins-product?_f_ins_org_id=%field.org_id%"],
			['Add Insurance Plan', "/org/%field.org_id%/dlg-add-ins-plan?_f_ins_org_id=%field.org_id%"],
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
		return 1;
	}
	if ($type eq 'main')
	{
		$excludeGroups = "'dept'";
		$self->addContent(
			new CGI::Dialog::Field(name => 'member_name',
					lookup => 'Org_Type',
					style => 'multicheck',
					options => FLDFLAG_REQUIRED,
					caption => 'Organization <nobr>Type(s)</nobr>',
					hints => 'You may choose more than one organization type.',
					fKeyWhere => "group_name not in ($excludeGroups)"),
		);
		return 1;
	}

	if ($type eq 'provider')
	{
		$excludeGroups = "'employer', 'insurance', 'ipa', 'other'";
		$self->addContent(
			new CGI::Dialog::Field(name => 'member_name',
					lookup => 'Org_Type',
					style => 'select',
					options => FLDFLAG_REQUIRED,
					caption => 'Organization Type',
					fKeyWhere => "group_name not in ($excludeGroups)"),
		);
		return 1;
	}
	return 1;
}


sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	my $orgId = $page->param('org_id');
	if($command eq 'remove')
	{
		my $deleteRecord = $self->getField('delete_record');
		$deleteRecord->invalidate($page, "Are you sure you want to delete Organization '$orgId'?");
	}
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
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
		$page->field('parent_org_id', $page->param('org_id'));
	}

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $orgId = $page->param('org_id') ? $page->param('org_id') : $page->session('org_id');
	my $ownerOrg = $page->session('org_internal_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrg, $orgId);

	my $orgData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $orgIntId);
	foreach (keys %$orgData)
	{
		$page->field(lc($_), $orgData->{$_});
	}

	my $parentId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $orgData->{parent_org_id});
	$page->field('parent_org_id', $parentId);

	my $categories = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selCategory', $orgIntId);
	my @categories = split(/\s,\s/, $categories);
	$page->field('member_name', @categories);

	if($command eq 'remove')
	{
		$page->field('delete_record', 1);
	}

	my $attribute = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selAttributeByItemNameAndValueTypeAndParent', $orgIntId, 'HCFA Service Place',
		App::Universal::ATTRTYPE_INTEGER
	);
	$page->field('hcfa_service_place', $attribute->{value_text});

	$attribute = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selAttributeByItemNameAndValueTypeAndParent', $orgIntId, 'Medicare GPCI Location',
		App::Universal::ATTRTYPE_TEXT
	);
	$page->field('medicare_gpci', $attribute->{value_text});
	$page->field('medicare_facility_type', $attribute->{value_int});

	my $businessAttribute = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selAttributeByItemNameAndValueTypeAndParent', $orgIntId, 'Business Hours',
		App::Universal::ATTRTYPE_ORGGENERAL
	);
	$page->field('business_hours', $businessAttribute->{value_text});
	$page->field('business_hrs_id', $businessAttribute->{item_id});
}


sub execute_add
{
	my ($self, $page, $command, $flags) = @_;
	my @members = $page->field('member_name');
	my $ownerOrg = $page->session('org_internal_id');
	my $orgId = $page->field('org_id');
	my $parentId = $page->field('parent_org_id');
	if ($parentId)
	{
		$parentId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrg, $parentId);
	}

	#Group all add transactions together
	$page->beginUnitWork("Unable to add Organization");
	## First create new Org record
	my $orgIntId = $page->schemaAction(
			'Org', $command,
			org_id => $orgId || undef,
			parent_org_id => $parentId || undef,
			owner_org_id => $ownerOrg || undef,
			tax_id => $page->field('tax_id') || undef,
			name_primary => $page->field('name_primary') || undef,
			name_trade => $page->field('name_trade') || undef,
			time_zone => $page->field('time_zone') || undef,
			category => join(',', @members) || undef,
			_debug => 0
		);

	# Retrieve the new Org's internal ID
	#my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrg, $orgId);

	# Special handling of "Main" orgs
	if ($self->{orgtype} eq 'main')
	{
		$page->schemaAction(
			'Org', 'update',
			org_internal_id => $orgIntId,
			owner_org_id => $orgIntId,
			_debug => 0
		);
	}

	##Then add mailing address
	$page->schemaAction(
			'Org_Address', $command,
			parent_id => $orgIntId,
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
			parent_id => $orgIntId,
			item_name => 'HCFA Service Place',
			value_type => App::Universal::ATTRTYPE_INTEGER || undef,
			value_text => $page->field('hcfa_service_place') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_PHONE || undef,
			value_text => $page->field('phone') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_FAX || undef,
			value_text => $page->field('fax') || undef,
			_debug => 0
		) if $page->field('fax') ne'';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_EMAIL || undef,
			value_text => $page->field('email') || undef,
			_debug => 0
		) if $page->field('email') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_URL || undef,
			value_text => $page->field('internet') || undef,
			_debug => 0
		) if $page->field('internet') ne '';

	##Then add property record for Business Hours
	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'Business Hours',
			value_type => defined $generalValueType ? $generalValueType : undef,
			value_text => $page->field('business_hours') || undef,
			_debug => 0
		) if $page->field('business_hours') ne '';

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
			parent_id => $orgIntId,
			item_name => 'Employer#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('emp_id') ne '' ? $page->field('emp_id') : $empId,
			_debug => 0
		)if ($page->field('emp_id') ne '' || $empId ne '');

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'State#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('state_id') ne '' ? $page->field('state_id') : $stateId,
			_debug => 0
		)if ($page->field('state_id') ne '' || $stateId ne '');

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'Medicaid#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('medicaid_id') || undef,
			_debug => 0
		) if $page->field('medicaid_id') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => "Workers Comp#",
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('wc_id') || undef,
			_debug => 0
		) if $page->field('wc_id') ne'';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'BCBS#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('bcbs_id') || undef,
			_debug => 0
		) if $page->field('bcbs_id') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'Medicare#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('medicare_id') || undef,
			_debug => 0
		) if $page->field('medicare_id') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name => 'CLIA#',
			value_type => defined $credentialsValueType ? $credentialsValueType : undef,
			value_text => $page->field('clia_id') || undef,
			_debug => 0
		) if $page->field('clia_id') ne '';

	$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_name =>  'Contact Information',
			value_type => App::Universal::ATTRTYPE_BILLING_PHONE,
			value_text => $page->field('contact_phone') || undef,
			value_textB => $page->field('contact_name') || undef,
			_debug => 0
		)if $page->field('contact_phone') ne '';

	saveAttribute($page, 'Org_Attribute', $orgIntId, 'Medicare GPCI Location', 0,
		value_text => $page->field('medicare_gpci'),
		value_int  => $page->field('medicare_facility_type') || 0,
	);

	$page->param('_dialogreturnurl', "/org/$orgId/profile");

	$page->endUnitWork();

	$self->handlePostExecute($page, $command, $flags);
	return '';
}


sub execute_update
{
	my ($self, $page, $command, $flags) = @_;
	my @members = $page->field('member_name');
	my $orgId = $page->field('org_id');
	my $ownerOrg = $page->session('org_internal_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrg, $orgId);
	my $parentId = $page->field('parent_org_id');
	if ($parentId)
	{
		$parentId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrg, $parentId);
	}

	#Group all update transactions together
	$page->beginUnitWork("Unable to update Organization");
	## First update new Org record
	$page->schemaAction(
			'Org', $command,
			org_internal_id => $orgIntId,
			parent_org_id => $parentId || undef,
			tax_id => $page->field('tax_id') || undef,
			name_primary => $page->field('name_primary') || undef,
			name_trade => $page->field('name_trade') || undef,
			time_zone => $page->field('time_zone') || undef,
			category => join(',', @members) || undef,
			_debug => 0
		);

	my $busHrsCommand = $page->field('business_hrs_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Org_Attribute', $busHrsCommand,
			parent_id => $orgIntId,
			item_id => $page->field('business_hrs_id') || undef,
			item_name => 'Business Hours',
			value_type => App::Universal::ATTRTYPE_ORGGENERAL,
			value_text => $page->field('business_hours') || undef,
			_debug => 0
		) if $page->field('business_hours') ne '';

	saveAttribute($page, 'Org_Attribute', $orgIntId, 'HCFA Service Place', App::Universal::ATTRTYPE_INTEGER,
		value_text => $page->field('hcfa_service_place'),
	);

	saveAttribute($page, 'Org_Attribute', $orgIntId, 'Medicare GPCI Location', 0,
		value_text => $page->field('medicare_gpci') || undef,
		value_int  => $page->field('medicare_facility_type') || 0,
	);

	$page->param('_dialogreturnurl', "/org/$orgId/profile");
	$page->endUnitWork();
	$self->handlePostExecute($page, $command, $flags);
	return '';
}


sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;
	my $orgId = $page->field('org_id');
	my $ownerOrg = $page->session('org_internal_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrg, $orgId);

	#Group all delete transactions together
	$page->beginUnitWork("Unable to delete Organization");
	$page->schemaAction(
			'Org', $command,
			org_internal_id => $orgIntId,
			_debug => 0
		);
	$page->endUnitWork();
	$self->handlePostExecute($page, $command, $flags);
	return '';
}


sub saveAttribute
{
	my ($page, $table, $parentId, $itemName, $valueType, %data) = @_;

	my $recExist = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selAttributeByItemNameAndValueTypeAndParent', $parentId, $itemName, $valueType);

	my $itemId = $recExist->{item_id};
	my $command = $itemId ? 'update' : 'add';

	my $newItemId = $page->schemaAction(
		$table, $command,
		item_id    => $command eq 'add' ? undef : $itemId,
		parent_id  => $parentId,
		item_name  => $itemName,
		value_type => $valueType,
		%data
	);

	return $newItemId;
}

1;
