##############################################################################
package App::Dialog::InsurancePlan;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Insurance;
use App::Statements::Invoice;

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Insurance;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);
%RESOURCE_MAP = ();

sub initialize
{
	my $self = shift;
	my $schema = $self->{schema};

	$self->addContent(
			#new CGI::Dialog::Field(type => 'hidden', name => 'champus_status_item_id'),
			#new CGI::Dialog::Field(type => 'hidden', name => 'champus_branch_item_id'),
			#new CGI::Dialog::Field(type => 'hidden', name => 'champus_grade_item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'phone_item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'fax_item_id'),
			#new CGI::Dialog::Field(type => 'hidden', name => 'ppo_hmo_indicator_item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'fee_item_id'),
			#new CGI::Dialog::Field(type => 'hidden', name => 'bcbscode_item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'item_id'),

			new App::Dialog::Field::Organization::ID(caption => 'Insurance Organization ID',
							name => 'ins_org_id',
							options => FLDFLAG_REQUIRED),

			new App::Dialog::Field::Insurance::ID::New(caption => 'Insurance Plan ID', name => 'ins_id', options => FLDFLAG_REQUIRED),
			new App::Dialog::Field::Organization::ID(caption => 'IPA', name => 'ipa_org_id'),
			new CGI::Dialog::Field(caption => 'Fee Schedules', name => 'fee_schedules'),

			new App::Dialog::Field::Address(caption=>'Billing Address', name => 'billing_addr',
								options => FLDFLAG_REQUIRED),

			new CGI::Dialog::MultiField(caption =>'Phone/Fax', name => 'phone_fax',
				fields => [
						new CGI::Dialog::Field(type=>'phone',
								caption => 'Phone',
								name => 'phone',
								options => FLDFLAG_REQUIRED,
								invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
						new CGI::Dialog::Field(type=>'phone',
								caption => 'Fax',
								name => 'fax',
								invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
				]),

			new CGI::Dialog::Field::TableColumn(
								caption => 'Insurance Type',
								schema => $schema,
								column => 'Insurance.ins_type',
								typeGroup => ['insurance']),

			new CGI::Dialog::Field(
								caption => 'Insurance Type Code',
								#type => 'foreignKey',
								name => 'insurance_type_code',
								hints=> "(Please ignore this field if 'Insurance Type' is 'Medicare')",
								fKeyStmtMgr => $STMTMGR_INSURANCE,
								fKeyStmt => 'selInsTypeCode',
								fKeyDisplayCol => 0,
								fKeyValueCol => 1,
								options => FLDFLAG_REQUIRED),

			new CGI::Dialog::Field(
								caption => 'PPO-HMO Indicator',
								#type => 'foreignKey',
								name => 'ppo_hmo_indicator',
								fKeyStmtMgr => $STMTMGR_INSURANCE,
								fKeyStmt => 'selPpoHmoIndicator',
								fKeyDisplayCol => 0,
								fKeyValueCol => 1,
								options => FLDFLAG_REQUIRED),

			new CGI::Dialog::MultiField(caption =>'Champus Branch/Status/Grade', name => 'champus_fields', hints=> "(For 'Champus' Insurance Type only)",
				fields => [
						new CGI::Dialog::Field(
								type => 'select',
								selOptions => ';Army;Navy;Air Force;Marines;Coast Guard',
								caption => 'Champus Branch',
								name => 'champus_branch'
								),

						new CGI::Dialog::Field(
								type => 'select',
								selOptions => ';Active;Retired;Reserves',
								caption => 'Champus Status',
								name => 'champus_status'
								),

						new CGI::Dialog::Field(
								caption => 'Champus Grade',
								name => 'champus_grade'
								),

				]),

			new CGI::Dialog::Field(
								caption => 'BCBS Plan Code',
								name => 'bcbs_code',
								hints=> "(For 'BCBS' Insurance Type only)"),
		);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $insType = $page->field('ins_type');

	if($insType != App::Universal::CLAIMTYPE_CHAMPUS && $insType != App::Universal::CLAIMTYPE_PPO && $insType != App::Universal::CLAIMTYPE_HMO)
	{
		$self->updateFieldFlags('ppo_hmo_indicator', FLDFLAG_INVISIBLE, 1);
	}

	#if($insType != App::Universal::CLAIMTYPE_CHAMPUS)
	#{
	#	$self->updateFieldFlags('champus_fields', FLDFLAG_INVISIBLE, 1);
	#}

	if($insType == App::Universal::CLAIMTYPE_MEDICARE)
	{
		$self->updateFieldFlags('insurance_type_code', FLDFLAG_INVISIBLE, 1);
	}

	my $orgId = $page->param('org_id');
	if($orgId && $orgId ne $page->session('org_id'))
	{
		$page->field('ins_org_id', $orgId);
		$self->setFieldFlags('ins_org_id', FLDFLAG_READONLY);
	}
	if(my $insId = $page->param('ins_id'))
	{
		$page->field('ins_id', $insId);
	}

	#turn guarantor id off if patient is 21 or over
	if(my $personId = $page->param('person_id'))
	{
		my $patientAge = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selPatientAge', $personId);
		$self->updateFieldFlags('insured_guarantor_ids', FLDFLAG_INVISIBLE, $patientAge < 21 ? 0 : 1);
		$self->updateFieldFlags('insured_id', FLDFLAG_INVISIBLE, $patientAge < 21 ? 1 : 0);
	}
}

sub customValidate
{
	my ($self, $page) = @_;

	my $command = $self->getActiveCommand($page);

	return () if $command eq 'remove';

	my $insType = $page->field('ins_type');

	if($command eq 'add' && ($insType == App::Universal::CLAIMTYPE_CHAMPUS || $insType == App::Universal::CLAIMTYPE_PPO || $insType == App::Universal::CLAIMTYPE_HMO))
	{
		my $insTypeField = $self->getField('ins_type');
		my $ppoHmoField = $self->getField('ppo_hmo_indicator');
		my $ppoHmoVal = $page->field('ppo_hmo_indicator');

		my $claimTypeCap = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selClaimTypeCaption', $insType);

		if($ppoHmoVal eq '')
		{
			$insTypeField->invalidate($page, "Please select '$ppoHmoField->{caption}' below when selecting '$claimTypeCap'");
			#$insTypeField->invalidate($page, "Please indicate 'Champus Branch/Status/Grade' below when selecting '$claimTypeCap' (not required)");
		}
		elsif($insType == App::Universal::CLAIMTYPE_CHAMPUS && ($ppoHmoVal eq 'N' || $ppoHmoVal eq 'Y'))
		{
			$ppoHmoField->invalidate($page, "Cannot choose this value with '$claimTypeCap'");
		}
		elsif($insType != App::Universal::CLAIMTYPE_CHAMPUS && ($ppoHmoVal ne 'N' && $ppoHmoVal ne 'Y'))
		{
			$ppoHmoField->invalidate($page, "Cannot choose this value with '$claimTypeCap'");
		}
	}

	my $relToInsured = $page->field('rel_to_insured');
	my $relToInsuredField = $self->getField('rel_to_insured');
	my $insuredId = $page->field('insured_id');
	my $insuredIdField = $self->getField('insured_id');

	my $personId = $page->param('person_id');
	if ($relToInsured != 0 && ($insuredId eq $personId || $insuredId eq ''))
	{
		$relToInsuredField->invalidate($page, "Must select 'Self' in '$relToInsuredField->{caption}' if '$insuredIdField->{caption}' is left blank.");
		$insuredIdField->invalidate($page, "Valid insured ID is needed (other than '$personId') if '$relToInsuredField->{caption}' is other than 'Self.'");
	}
	elsif($relToInsured == 0 && ($insuredId ne $personId && $insuredId ne ''))
	{
		$relToInsuredField->invalidate($page, "Must select '$relToInsuredField->{caption}' (other than 'Self') if '$insuredIdField->{caption}' is not '$personId'.");
		$insuredIdField->invalidate($page, "'$insuredIdField->{caption}' must be '$personId' when selecting 'Self' in '$relToInsuredField->{caption}'");
	}
}

sub validateExistingInsSeq
{
	my ($dialogItem, $page, $dialog, $value, $extraData) = @_;
	my $personId = $page->param('person_id');

	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $dialog->id());

	return () if $command ne 'add';

	my $billSeqExists = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByBillSequence', $value, $personId);
	my $billSeqCap = $STMTMGR_INSURANCE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInsuranceBillCaption', $value);

	return $billSeqExists->{ins_internal_id} ne '' ?
			("\u$billSeqCap insurance for '$personId' already exists.") : ();
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $insIntId = $page->param('ins_internal_id');
	if(! $STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId))
	{
		$page->addError("Ins Internal ID '$insIntId' not found.");
	}

	$STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsuranceAddr', $insIntId);

	my $bcbsCode = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'BCBS Plan Code');
	#$page->field('bcbscode_item_id', $bcbsCode->{item_id});
	$page->field('bcbs_code', $bcbsCode->{value_text});

	my $ppoHmo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'HMO-PPO/Indicator');
	#$page->field('ppo_hmo_indicator_item_id', $ppoHmo->{item_id});
	$page->field('ppo_hmo_indicator', $ppoHmo->{value_text});

	my $insPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Contact Method/Telephone/Primary');
	$page->field('phone_item_id', $insPhone->{item_id});
	$page->field('phone', $insPhone->{value_text});

	my $insFax = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Contact Method/Fax/Primary');
	$page->field('fax_item_id', $insFax->{item_id});
	$page->field('fax', $insFax->{value_text});

	my $insFeeSched = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Fee Schedules');
	$page->field('fee_item_id', $insFeeSched->{item_id});
	$page->field('fee_schedules', $insFeeSched->{value_text});

	my $champusStatus = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Champus Status');
	#$page->field('champus_status_item_id', $champusStatus->{item_id});
	$page->field('champus_status', $champusStatus->{value_text});

	my $champusBranch = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Champus Branch');
	#$page->field('champus_branch_item_id', $champusBranch->{item_id});
	$page->field('champus_branch', $champusBranch->{value_text});

	my $champusGrade = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Champus Grade');
	#$page->field('champus_grade_item_id', $champusGrade->{item_id});
	$page->field('champus_grade', $champusGrade->{value_text});

	my $insType = $page->field('ins_type');
	if($insType != App::Universal::CLAIMTYPE_CHAMPUS && $insType != App::Universal::CLAIMTYPE_PPO && $insType != App::Universal::CLAIMTYPE_HMO)
	{
		$self->updateFieldFlags('ppo_hmo_indicator', FLDFLAG_INVISIBLE, 1);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $dialogId = $self->{id};

	my $editInsIntId = $page->param('ins_internal_id');

	my $insType = $page->field('ins_type');
	my $insTypeCode = $insType == App::Universal::CLAIMTYPE_MEDICARE ? 'MP' : $page->field('insurance_type_code');
	my $remitType = $page->field('remit_type');
	my $recordType = $dialogId eq 'ins-unique' ? App::Universal::RECORDTYPE_PERSONALCOVERAGE : App::Universal::RECORDTYPE_INSURANCEPLAN;

	#values for person unique plans
	my $personId = $page->param('person_id');
	my $relToInsured = $page->field('rel_to_insured');
	my $billSeq = $page->field('bill_sequence');
	my $insuredId = $page->field('insured_id') eq '' ? $personId : $page->field('insured_id') ;

	my $orgId = $page->field('ins_org_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId);	

	my $insIntId = $page->schemaAction(
			'Insurance', $command,
			ins_internal_id => $editInsIntId || undef,
			parent_ins_id => $page->field('parent_ins_id') || undef,
			ins_id => $page->field('ins_id') || undef,
			owner_id => $personId || undef,
			ins_org_id => $orgIntId || undef,
			record_type => defined $recordType ? $recordType : undef,
			ins_type => defined $insType ? $insType : undef,
			bill_sequence => defined $billSeq ? $billSeq : undef,
			rel_to_insured => defined $relToInsured ? $relToInsured : undef,
			member_number => $page->field('member_number') || undef,
			plan_name => $page->field('plan_name') || undef,
			policy_number => $page->field('policy_number') || undef,
			group_name => $page->field('group_name') || undef,
			group_number => $page->field('group_number') || undef,
			insured_id => $insuredId || undef,
			guarantor_id => $page->field('guarantor_id') || undef,
			indiv_deductible_amt => $page->field('indiv_deductible_amt') || undef,
			family_deductible_amt  => $page->field('family_deductible_amt') || undef,
			indiv_deduct_remain => $page->field('indiv_deduct_remain') || undef,
			family_deduct_remain => $page->field('family_deduct_remain') || undef,
			remit_type => defined $remitType ? $remitType : undef,
			remit_payer_id => $page->field('remit_payer_id') || undef,
			remit_payer_name => $page->field('remit_payer_name') || undef,
			coverage_begin_date => $page->field('coverage_begin_date') || undef,
			coverage_end_date => $page->field('coverage_end_date') || undef,
			copay_amt => $page->field('copay_amt') || undef,
			percentage_pay => $page->field('percentage_pay') || undef,
			threshold => $page->field('threshold') || undef,
			extra => $insTypeCode || undef,
			_debug => 0
	);

	$insIntId = $command eq 'add' ? $insIntId : $editInsIntId;

	$self->handleAttributes($page, $command, $flags, $insIntId);
}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	$page->schemaAction(
			'Insurance', 'remove',
			ins_internal_id => $page->param('ins_internal_id') || undef,
			_debug => 0
	);

	if(my $addrItemId = $page->field('item_id'))
	{
		$page->schemaAction(
				'Insurance_Address', 'remove',
				item_id => $addrItemId || undef,
				_debug => 0
		);
	}

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "Remove completed.";
}

sub handleAttributes
{
	my ($self, $page, $command, $flags, $insIntId) = @_;

	$page->schemaAction(
			'Insurance_Address', $command,
			item_id => $page->field('item_id') || undef,
			parent_id => $insIntId || undef,
			address_name => 'Billing',
			line1 => $page->field('addr_line1') || undef,
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city') || undef,
			state => $page->field('addr_state') || undef,
			zip => $page->field('addr_zip') || undef,
			_debug => 0
		);

	my $textAttrType = App::Universal::ATTRTYPE_TEXT;
	my $phoneAttrType = App::Universal::ATTRTYPE_PHONE;
	my $faxAttrType = App::Universal::ATTRTYPE_FAX;

	my @feeSchedules = $page->field('fee_schedules');
	$page->schemaAction(
			'Insurance_Attribute', $command,
			item_id => $page->field('fee_item_id') || undef,
			parent_id => $insIntId || undef,
			item_name => 'Fee Schedules',
			value_type => defined $textAttrType ? $textAttrType : undef,
			value_text => join(',', @feeSchedules) || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Insurance_Attribute', $command,
			item_id => $page->field('phone_item_id') || undef,
			parent_id => $insIntId || undef,
			item_name => 'Contact Method/Telephone/Primary',
			value_type => defined $phoneAttrType ? $phoneAttrType : undef,
			value_text => $page->field('phone') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Insurance_Attribute', $command,
			item_id => $page->field('fax_item_id') || undef,
			parent_id => $insIntId || undef,
			item_name => 'Contact Method/Fax/Primary',
			value_type => defined $faxAttrType ? $faxAttrType : undef,
			value_text => $page->field('fax') || undef,
			_debug => 0
		);

	my $bcbsCode = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'BCBS Plan Code');
	my $bcbsItemId = $bcbsCode->{item_id};
	my $bcbsCommand = $bcbsItemId eq '' ? 'add' : 'update';
	$bcbsCommand = $command eq 'remove' ? 'remove' : $bcbsCommand;
	my $bcbsField = $page->field('bcbs_code');
	$page->schemaAction(
			'Insurance_Attribute', $bcbsCommand,
			item_id => $bcbsItemId || undef,
			parent_id => $insIntId || undef,
			item_name => 'BCBS Plan Code',
			value_type => defined $textAttrType ? $textAttrType : undef,
			value_text => $bcbsField || undef,
			_debug => 0
		) if $bcbsField;

	my $hmoPpo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'HMO-PPO/Indicator');
	my $hmoPpoItemId = $hmoPpo->{item_id};
	my $hmoPpoCommand = $hmoPpoItemId eq '' ? 'add' : 'update';
	$hmoPpoCommand = $command eq 'remove' ? 'remove' : $hmoPpoCommand;
	my $hmoPpoField = $page->field('ppo_hmo_indicator');
	$page->schemaAction(
			'Insurance_Attribute', $hmoPpoCommand,
			item_id => $hmoPpoItemId || undef,
			parent_id => $insIntId || undef,
			item_name => 'HMO-PPO/Indicator',
			value_type => defined $textAttrType ? $textAttrType : undef,
			value_text => $hmoPpoField || undef,
			_debug => 0
		) if $hmoPpoField;

	my $champusStatus = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Champus Status');
	my $statusItemId = $champusStatus->{item_id};
	my $statusCommand = $statusItemId eq '' ? 'add' : 'update';
	$statusCommand = $command eq 'remove' ? 'remove' : $statusCommand;
	my $status = $page->field('champus_status');
	$page->schemaAction(
			'Insurance_Attribute', $statusCommand,
			item_id => $statusItemId || undef,
			parent_id => $insIntId || undef,
			item_name => 'Champus Status',
			value_type => defined $textAttrType ? $textAttrType : undef,
			value_text => $status || undef,
			_debug => 0
		) if $status;

	my $champusBranch = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Champus Branch');
	my $branchItemId = $champusBranch->{item_id};
	my $branchCommand = $branchItemId eq '' ? 'add' : 'update';
	$branchCommand = $command eq 'remove' ? 'remove' : $branchCommand;
	my $branch = $page->field('champus_branch');
	$page->schemaAction(
			'Insurance_Attribute', $branchCommand,
			item_id => $branchItemId || undef,
			parent_id => $insIntId || undef,
			item_name => 'Champus Branch',
			value_type => defined $textAttrType ? $textAttrType : undef,
			value_text => $branch || undef,
			_debug => 0
		) if $branch;

	my $champusGrade = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Champus Grade');
	my $gradeItemId = $champusGrade->{item_id};
	my $gradeCommand = $gradeItemId eq '' ? 'add' : 'update';
	$gradeCommand = $command eq 'remove' ? 'remove' : $gradeCommand;
	my $grade = $page->field('champus_grade');
	$page->schemaAction(
			'Insurance_Attribute', $gradeCommand,
			item_id => $gradeItemId || undef,
			parent_id => $insIntId || undef,
			item_name => 'Champus Grade',
			value_type => defined $textAttrType ? $textAttrType : undef,
			value_text => $grade || undef,
			_debug => 0
		) if $grade;



	if($command eq 'update' && $self->{id} ne 'ins-unique')
	{
		$self->updateChildrenPlans($page, $flags, $insIntId);
	}
	else
	{
		$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
		return "\u$command completed.";
	}
}

sub updateChildrenPlans
{
	my ($self, $page, $flags, $insIntId) = @_;

	my $insData = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId);
	my $childPlans = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selChildrenPlans', $insIntId);

	my $remitType = $insData->{remit_type};
	my $insType = $insData->{ins_type};
	
	my $orgId = $insData->{ins_org_id};
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId);	
	
	foreach (@{$childPlans})
	{
		$page->schemaAction(
				'Insurance', 'update',
				ins_internal_id => $_->{ins_internal_id} || undef,
				ins_id => $insData->{ins_id} || undef,
				ins_org_id => $orgIntId || undef,
				ins_type => defined $insType ? $insType : undef,
				plan_name => $insData->{plan_name} || undef,
				group_name => $insData->{group_name} || undef,
				group_number => $insData->{group_number} || undef,
				remit_type => defined $remitType ? $remitType : undef,
				remit_payer_id => $insData->{remit_payer_id} || undef,
				remit_payer_name => $insData->{remit_payer_name} || undef,
				extra => $insData->{extra} || undef,
				_debug => 0
			);
	}

	$self->handlePostExecute($page, 'update', $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "Update completed.";
}

1;