##############################################################################
package App::Dialog::InsurancePlan::PersonalCoverage;
##############################################################################
use strict;
use Carp;
use DBI::StatementManager;
use CGI::Validator::Field;
use App::Dialog::InsurancePlan;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Insurance;
use CGI::Dialog;
use App::Universal;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
use Date::Manip;

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'coverage', heading => '$Command Personal Insurance Coverage');

	#my $id = $self->{'id'}; 	# id = 'insur_pay' | 'personal_pay'

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
			new CGI::Dialog::Field(type => 'hidden', name => 'phone_item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'fax_item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'bill_seq_hidden'),
			new App::Dialog::Field::Person::ID(caption => 'Person/Patient ID',types => ['Patient'],	name => 'person_id'),
			new App::Dialog::Field::Organization::ID(caption => 'Insurance Company ID', name => 'ins_org_id', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(caption => 'Product Name', name => 'product_name', options => FLDFLAG_REQUIRED, findPopup => '/lookup/insurance/product_name'),
			new CGI::Dialog::Field(caption => 'Plan Name', name => 'plan_name', findPopup => '/lookup/insurance/plan_name'),
			#new CGI::Dialog::Field::TableColumn(
			#					caption => 'Insurance Type',
			#					schema => $schema,
			#					column => 'Insurance.ins_type',
			#					typeGroup => ['insurance', 'workers compensation']),

			#new CGI::Dialog::Field(lookup => 'Bill_Sequence', caption => 'Insurance Sequence', name => 'bill_sequence', options => FLDFLAG_REQUIRED),

			new CGI::Dialog::Field::TableColumn(
								caption => 'Insurance Sequence',
								schema => $schema,
								column => 'Insurance.bill_sequence',
								onValidate => \&App::Dialog::InsurancePlan::validateExistingInsSeq,
								onValidateData => $self,
								defaultValue => 1,
								options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(type => 'bool', name => 'create_record', caption => 'Inactivate Coverage?',style => 'check'),
			#new CGI::Dialog::Field(caption => 'Fee Schedules', name => 'fee_schedules'),
			new CGI::Dialog::Subhead(heading => 'General Plan Information', name => 'gen_plan_heading'),
			new CGI::Dialog::MultiField(caption =>'Group Name/Group Number', name => 'group',
				fields => [
						new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Insurance.group_name'),
						new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Insurance.group_number'),
					]),

			new CGI::Dialog::Field::TableColumn(
							caption => 'Member Number',
							schema => $schema,
							column => 'Insurance.member_number',
							options => FLDFLAG_REQUIRED),

			new CGI::Dialog::Field::TableColumn(
							caption => 'Policy Number',
							schema => $schema,
							column => 'Insurance.policy_number'),


			#new CGI::Dialog::MultiField(caption =>'Insured/Guarantor ID', name => 'insured_guarantor_ids',
			#	fields => [
			#			new App::Dialog::Field::Person::ID(caption => 'Insured ID',
			#				types => ['Patient'],
			#				name => 'insured_id',options => FLDFLAG_REQUIRED),

			#			new App::Dialog::Field::Person::ID(caption => 'Guarantor ID',
			#				types => ['Patient'],
			#				name => 'guarantor_id',
			#				options => FLDFLAG_REQUIRED)
			#		]),

						new App::Dialog::Field::Person::ID(caption => 'Insured ID',
							types => ['Patient'],
							name => 'insured_id', options => FLDFLAG_REQUIRED
							),

			new CGI::Dialog::Field(caption => "Patient's Relationship to Insured",
							name => 'rel_to_insured',
							fKeyStmtMgr => $STMTMGR_INSURANCE,
							fKeyStmt => 'selInsuredRelation',
							fKeyDisplayCol => 1,
							fKeyValueCol => 0,
							options => FLDFLAG_REQUIRED
							),

			new CGI::Dialog::MultiField(caption =>'Indiv/Family Deductible Remaining', name => 'deduct_remain',
				fields => [
						new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Insurance.indiv_deduct_remain'),
						new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Insurance.family_deduct_remain'),
					]),

			new CGI::Dialog::Subhead(heading => 'Coverage Information', name => 'coverage_heading'),
			new CGI::Dialog::MultiField (caption => 'Coverage Begin/End Dates',	name => 'dates',
					fields => [
								new CGI::Dialog::Field(caption => 'Begin Date', name => 'coverage_begin_date', type => 'date', options => FLDFLAG_REQUIRED, pastOnly => 1),
								new CGI::Dialog::Field(caption => 'End Date', name => 'coverage_end_date', type => 'date', futureOnly => 1),
							]),

			new CGI::Dialog::MultiField(caption =>'Deductible Amounts', hints => 'Individual/Family', name => 'deduct_amts',
					fields => [
								new CGI::Dialog::Field::TableColumn(caption => 'Individual Deductible Amount',
									schema => $schema, column => 'Insurance.indiv_deductible_amt'),
								new CGI::Dialog::Field::TableColumn(caption => 'Family Deductible Amount',
									schema => $schema, column => 'Insurance.family_deductible_amt'),
					]),

			new CGI::Dialog::MultiField(caption =>'Percentage Pay/Threshold', name => 'percentage_threshold',
				fields => [
					new CGI::Dialog::Field::TableColumn(
						schema => $schema,
						column => 'Insurance.percentage_pay'),
					new CGI::Dialog::Field::TableColumn(
						schema => $schema,
						column => 'Insurance.threshold'),
				]),

			new CGI::Dialog::Field::TableColumn(
						caption => 'Office Visit Co-pay',
						schema => $schema,
					column => 'Insurance.copay_amt'),

			new CGI::Dialog::Subhead(heading => 'Remittance Information', name => 'remittance_heading'),
			new CGI::Dialog::Field::TableColumn(caption => 'Remittance Type',
						name => 'remit_type',
						schema => $schema,
						column => 'Insurance.Remit_Type'),

			new CGI::Dialog::Field(caption => 'E-Remittance Payer ID',
						hints=> '(Only for non-Paper types)',
						name => 'remit_payer_id',
						findPopup => '/lookup/envoypayer/id'),

			new CGI::Dialog::Field(caption => 'Remit Payer Name', name => 'remit_payer_name'),

			new CGI::Dialog::Subhead(heading => 'Add Another Personal Insurance Coverage', name => 'insur_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			new CGI::Dialog::Field(
								type => 'bool',
								name => 'add_insurance',
								caption => 'Add Additional Personal Insurance Coverage?',
								style => 'check',
								invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

			new CGI::Dialog::MultiField(caption =>'InsCompanyID/ProductName/PlanName', name => 'insplan',invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				fields => [
							new App::Dialog::Field::Organization::ID(caption => 'Ins Company ID', name => 'ins_comp',invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
							new CGI::Dialog::Field(caption => 'Product Name', name => 'product', findPopup => '/lookup/insurance/product_name', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
							new CGI::Dialog::Field(caption => 'Plan Name', name => 'plan', findPopup => '/lookup/insurance/plan_name', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
						])

			);

			$self->{activityLog} =
			{
				scope =>'insurance',
				key => "#field.ins_org_id#",
				data => "Insurance '#field.product_name#' in <a href='/org/#param.ins_org_id#/profile'>#param.ins_org_id#</a>"
			};

			$self->addFooter(new CGI::Dialog::Buttons(
							nextActions_add => [
								['Add Another Insurance Coverage', "/person/%param.person_id%/dlg-add-ins-coverage?_f_product_name=%field.product%&_f_ins_org_id=%field.ins_comp%&_f_plan_name=%field.plan%&_f_bill_sequence=%field.bill_sequence%", 1],
								['Go to Person Profile', "/person/%param.person_id%/profile"],
							],
								cancelUrl => $self->{cancelUrl} || undef
						)
					);

			return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	$self->updateFieldFlags('person_id', FLDFLAG_INVISIBLE, 1) if ($page->param('person_id') ne '');
	#turn guarantor id off if patient is 21 or over
	if(my $personId = $page->param('person_id'))
	{
		my $patientAge = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selPatientAge', $personId);
		#$self->updateFieldFlags('insured_guarantor_ids', FLDFLAG_INVISIBLE, $patientAge < 21 ? 0 : 1);
		#$self->updateFieldFlags('insured_id', FLDFLAG_INVISIBLE, $patientAge < 21 ? 1 : 0);
		my $insuredId = $patientAge >= 21 ? $personId : undef;
		$page->field('insured_id', $insuredId);
	}

	$self->updateFieldFlags('create_record', FLDFLAG_INVISIBLE, 1);

	if($page->param('_lcm_ispopup'))
	{
		$self->updateFieldFlags('insur_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('insplan', FLDFLAG_INVISIBLE, 1);
	}
}

sub customValidate
{
	my ($self, $page) = @_;

	my $command = $self->getActiveCommand($page);

	return () if $command eq 'remove';

	my $relToInsured = $page->field('rel_to_insured');
	my $relToInsuredField = $self->getField('rel_to_insured');
	my $insuredId = $page->field('insured_id');
	my $insuredIdField = $self->getField('insured_id');
	my $billSeq = $self->getField('bill_sequence');

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

	my $insOrg = $self->getField('insplan')->{fields}->[0];
	my $productName = $self->getField('insplan')->{fields}->[1];
	my $PlanName = $self->getField('insplan')->{fields}->[2];
	my $addIns = $page->field('add_insurance');
	if($addIns ==1 &&
		($page->field('ins_comp') eq '' || $page->field('product') eq '' || $page->field('plan') eq ''))
	{
		$insOrg->invalidate($page, " 'Ins Org ID', 'ProductName' and 'PlanName' cannot be blank if the Insurance Coverage is checked.");
	}

	my $previousSequence = $page->field('bill_seq_hidden');

	my $billCaption = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selInsuranceBillCaption',$previousSequence);
	my $sequence = $page->field('bill_sequence');

	if ($sequence == App::Universal::INSURANCE_INACTIVE)
	{
		do
		{
			$previousSequence ++;
			$self->updateFieldFlags('create_record', FLDFLAG_INVISIBLE, 0);

			if($STMTMGR_INSURANCE->recordExists($page,STMTMGRFLAG_NONE, 'selDoesInsSequenceExists', $personId, $previousSequence))
			{


				my $createInsCoverageHref = "javascript:doActionPopup('/person-p/#param.person_id#/dlg-add-ins-coverage/?_f_bill_sequence=#field.bill_seq_hidden#');";
				$billSeq->invalidate($page, "Do u want to Create a New <a href=$createInsCoverageHref>'$billCaption Personal Insurance Coverage'</a>.<br> Or Click The Check Box To Inactivate this Coverage");
				return $STMTMGR_INSURANCE->getRowsAsHashList($page,STMTMGRFLAG_NONE, 'selUpdateAndAddInsSeq', $personId, $previousSequence) if $page->field('create_record', 0);
			}
			elsif($page->field('create_record', 1))
			{
				return $STMTMGR_INSURANCE->getRowsAsHashList($page,STMTMGRFLAG_NONE, 'selUpdateInsSequence', $personId, $previousSequence);
			}
			#if($page->field('create_record') eq '')
			#{
			#	return $STMTMGR_INSURANCE->getRowsAsHashList($page,STMTMGRFLAG_NONE, 'selUpdateAndAddInsSeq', $personId, $previousSequence);
			#}
		}until $STMTMGR_INSURANCE->recordExists($page,STMTMGRFLAG_NONE, 'selDoesInsSequenceExists', $personId, $previousSequence) && $previousSequence <=3;
	}

}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

		return unless ($flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL);

		my $personId = $page->param('person_id');
		my $seq = 0;
		my $hiddenBillSeq = $page->field('bill_sequence');
		if($hiddenBillSeq ne  '')
		{
			$page->field('bill_sequence', $hiddenBillSeq);
		}
		else
		{
			do
			{
				$seq++;

			}until ((!$STMTMGR_INSURANCE->recordExists($page,STMTMGRFLAG_NONE, 'selDoesInsSequenceExists', $personId, $seq)) && $seq < 4);

			if ($seq > 4)
			{
				$page->field('bill_sequence', App::Universal::INSURANCE_INACTIVE);
			}
			else
			{
				$page->field('bill_sequence', $seq);
			}
		}


		#my $billSequence = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInsSequence', $personId);
		#foreach my $existSequence(@{$billSequence})
		#{

		#	my $sequence = $existSequence->{'bill_sequence'};
		#	if ($sequence < 4)
		#	{
		#		my $newSequence = $sequence + 1;
		#		$page->field('bill_sequence', $newSequence);
		#	}
		#	else
		#	{
		#		$page->field('bill_sequence', App::Universal::INSURANCE_INACTIVE);
		#	}
		#}

		my $productName = $page->field('product_name');
		my $planName = $page->field('plan_name');
		my $planType = App::Universal::RECORDTYPE_INSURANCEPLAN;
		my $planData = $STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsPlan', $productName, $planName);
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	# Populating the fields while updating the dialog
	return unless ($flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL);

	my $insIntId = $page->param('ins_internal_id');
	if(! $STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId))
	{
		$page->addError("Ins Internal ID '$insIntId' not found.");
	}
	my $prevBillSeq = $page->field('bill_sequence');
	$page->field('bill_seq_hidden', $prevBillSeq);
}

sub populateData_remove
{
	populateData_update(@_);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $productName = $page->field('product_name');
	my $planName = $page->field('plan_name');
	my $recordType = App::Universal::RECORDTYPE_INSURANCEPLAN;
	my $recordTypeProduct = App::Universal::RECORDTYPE_INSURANCEPRODUCT;
	my $planData = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsPlan', $productName, $planName);
	my $recordData = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPlanByInsIdAndRecordType', $productName, $recordTypeProduct);
	my $parentInsId = $planData->{'ins_internal_id'} ne '' ? $planData->{'ins_internal_id'} : $recordData->{'ins_internal_id'};
	my $insType = $planData->{'ins_type'} ne '' ? $planData->{'ins_type'} : $recordData->{'ins_type'};
	my $editInsIntId = $page->param('ins_internal_id');
	my $personId = $page->param('person_id') ne '' ? $page->param('person_id') : $page->field('person_id');

	my $insIntId = $page->schemaAction(
				'Insurance', $command,
				ins_internal_id => $editInsIntId || undef,
				parent_ins_id => $parentInsId || undef,
				product_name => $page->field('product_name') || undef,
				plan_name => $page->field('plan_name') || undef,
				record_type => App::Universal::RECORDTYPE_PERSONALCOVERAGE || undef,
				owner_person_id => $personId || undef,
				ins_org_id => $page->field('ins_org_id') || undef,
				bill_sequence => $page->field('bill_sequence') || undef,
				ins_type => $insType || undef,
				fee_schedule => $page->field('fee_schedule') || undef,
				group_name => $page->field('group_name') || undef,
				group_number => $page->field('group_number') || undef,
				member_number => $page->field('member_number') || undef,
				policy_number => $page->field('policy_number') || undef,
				insured_id => $page->field('insured_id') || undef,
				guarantor_id => $page->field('guarantor_id') || undef,
				rel_to_insured => $page->field('rel_to_insured') || undef,
				indiv_deduct_remain => $page->field('indiv_deduct_remain') || undef,
				family_deduct_remain => $page->field('family_deduct_remain') || undef,
				copay_amt => $page->field('copay_amt') || undef,
				coverage_begin_date => $page->field('coverage_begin_date') || undef,
				coverage_end_date => $page->field('coverage_end_date') || undef,
				indiv_deductible_amt => $page->field('indiv_deductible_amt') || undef,
				family_deductible_amt => $page->field('family_deductible_amt') || undef,
				percentage_pay => $page->field('percentage_pay') || undef,
				threshold => $page->field('threshold') || undef,
				remit_type => $page->field('remit_type') || undef,
				remit_payer_id => $page->field('remit_payer_id') || undef,
				remit_payer_name => $page->field('remit_payer_name') || undef,
				_debug => 0
			);

	#$insIntId = $command eq 'add' ? $insIntId : $editInsIntId;

	#$self->handleAttributes($page, $command, $flags, $insIntId);
	$self->handlePostExecute($page, $command, $flags);
	return '';
}



sub _handleAttributes
{
	my ($self, $page, $command, $flags, $insIntId) = @_;

	$page->schemaAction(
			'Insurance_Address', $command,
			item_id => $page->field('item_id') || undef,
			parent_id => $insIntId || undef,
			address_name => 'Billing' || undef,
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

	$self->handlePostExecute($page, $command, $flags);
	return '';
}


use constant INSURANCEEXISTS_DIALOG => 'Dialog/New Insurance Plan';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '04/05/2000', 'RK',
		INSURANCEEXISTS_DIALOG,
		'Cleaned up dialog fields and removed makeStateChanges.'],
);

1;