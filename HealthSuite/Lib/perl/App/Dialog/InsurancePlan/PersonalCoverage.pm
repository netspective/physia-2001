##############################################################################
package App::Dialog::InsurancePlan::PersonalCoverage;
##############################################################################
use strict;
use Carp;
use Date::Manip;
use DBI::StatementManager;
use CGI::Validator::Field;
use App::Dialog::InsurancePlan;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Insurance;
use App::Dialog::Field::Insurance;
use CGI::Dialog;
use App::Universal;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'ins-coverage' => {
		heading => '$Command Personal Insurance Coverage',
		_arl_add => ['plan_name'],
		_arl_modify => ['ins_internal_id'],
	   	_idSynonym => 'ins-' . App::Universal::RECORDTYPE_PERSONALCOVERAGE,
	   	},
	);


sub new
{
	my $self = CGI::Dialog::new(@_);

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Person::ID(
			caption => 'Patient ID',
			types => ['Patient'],
			options => FLDFLAG_REQUIRED,
			name => 'person_id'
			),
		new App::Dialog::Field::Insurance::Product(
			caption => 'Insurance Product',
			name => 'product_name',
			findPopup => '/lookup/insproduct/insorgid',
			),
		new App::Dialog::Field::Insurance::Plan(
			caption => 'Insurance Plan',
			name => 'plan_name',
			findPopup => '/lookup/insplan/product/itemValue',
			findPopupControlField => '_f_product_name',
			),
		new CGI::Dialog::Field::TableColumn(
			caption => 'Insurance Sequence',
			schema => $schema,
			column => 'Insurance.bill_sequence',
			onValidate => \&App::Dialog::InsurancePlan::validateExistingInsSeq,
			onValidateData => $self,
			defaultValue => 1,
			options => FLDFLAG_REQUIRED,
			),
		new CGI::Dialog::Field(
			caption => 'Confirm?',
			type => 'bool',
			name => 'do_anyway',
			style => 'check',
			options => FLDFLAG_INVISIBLE,
			),

		# General Plan Information
		new CGI::Dialog::Subhead(
			heading => 'General Plan Information',
			name => 'gen_plan_heading',
			),
		new CGI::Dialog::Field(
			caption => "Patient's Relationship to Insured",
			name => 'rel_to_insured',
			fKeyStmtMgr => $STMTMGR_INSURANCE,
			fKeyStmt => 'selInsuredRelation',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			options => FLDFLAG_REQUIRED | FLDFLAG_PREPENDBLANK,
			onChangeJS => qq{showFieldsNotValues(event, [@{[App::Universal::INSURED_SELF]}], ['insured_id']); showFieldsOnValues(event, [@{[App::Universal::INSURED_OTHER]}], ['extra']);},
			),
		new CGI::Dialog::Field(
			caption => 'Other Relationship',
			name => 'extra',
			),
		new App::Dialog::Field::Person::ID(
			caption => 'Insured Person ID',
			name => 'insured_id',
			),
		new App::Dialog::Field::Organization::ID(
			caption => "Insured Person's Employer",
			name => "employer_org_id",
			),
		new CGI::Dialog::MultiField(
			name => 'group_info',
			fields => [
				new CGI::Dialog::Field::TableColumn(
					caption => "Group Name",
					schema => $schema,
					column => 'Insurance.group_name',
					),
				new CGI::Dialog::Field::TableColumn(
					caption => "Number",
					schema => $schema,
					column => 'Insurance.group_number',
					),
				],
			),
		new CGI::Dialog::Field::TableColumn(
			caption => 'Member Number',
			schema => $schema,
			column => 'Insurance.member_number',
			options => FLDFLAG_REQUIRED
			),

		# Coverage Information
		new CGI::Dialog::Subhead(
			heading => 'Coverage Information',
			name => 'coverage_heading',
			),
		new CGI::Dialog::MultiField (
			name => 'dates',
			fields => [
				new CGI::Dialog::Field(
					caption => 'Coverage Begin Date',
					name => 'coverage_begin_date',
					type => 'date',
					options => FLDFLAG_REQUIRED,
					pastOnly => 1,
					defaultValue => '',
					),
				new CGI::Dialog::Field(
					caption => 'End Date',
					name => 'coverage_end_date',
					type => 'date',
					defaultValue => '',
					),
				],
			),
		new CGI::Dialog::MultiField(
			name => 'deduct_amts',
			fields => [
				new CGI::Dialog::Field::TableColumn(
					caption => 'Individual',
					schema => $schema,
					column => 'Insurance.indiv_deductible_amt',
					),
				new CGI::Dialog::Field::TableColumn(
					caption => 'Family Deductible Amounts',
					schema => $schema,
					column => 'Insurance.family_deductible_amt',
					),
				],
			),
		new CGI::Dialog::MultiField(
			name => 'deduct_remain',
			fields => [
				new CGI::Dialog::Field::TableColumn(
					caption => 'Individual',
					schema => $schema,
					column => 'Insurance.indiv_deduct_remain'),
				new CGI::Dialog::Field::TableColumn(
					caption => 'Family Deductible Remaining',
					schema => $schema,
				column => 'Insurance.family_deduct_remain'),
				],
			),
		new CGI::Dialog::MultiField(name => 'percentage_threshold',
			fields => [
				new CGI::Dialog::Field::TableColumn(
					caption => 'Percentage Pay',
					schema => $schema,
					column => 'Insurance.percentage_pay'),
				new CGI::Dialog::Field::TableColumn(
					caption => 'Threshold',
					schema => $schema,
					column => 'Insurance.threshold'),
				],
			),
		new CGI::Dialog::Field::TableColumn(
			caption => 'Office Visit Co-pay',
			schema => $schema,
			column => 'Insurance.copay_amt',
			),
		);

	$self->{activityLog} =
	{
		scope =>'insurance',
		key => "#field.product_name#",
		data => "#field.product_name# Insurance coverage added for <a href='/person/#field.person_id#/profile'>#field.person_id#</a>"
	};

	$self->addFooter(
		new CGI::Dialog::Buttons(
			nextActions_add => [
				['Add Another Insurance Coverage', "/person/%field.person_id%/dlg-add-ins-coverage", 1],
				['Go to Person Profile', "/person/%field.person_id%/profile"],
				],
			cancelUrl => $self->{cancelUrl} || undef,
			),
		);

# Need to find a better way to do this...
#	$self->addPostHtml(q{<script>
#		<!--
#		setIdDisplay('insured_id','none');
#		setIdDisplay('extra','none');
#		// -->
#	</script>});

	return $self;
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	# Populating the fields while updating the dialog
	return unless ($flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL);

	my $insIntId = $page->param('ins_internal_id');
	if(! $STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId))
	{
		$page->addError("Insurance Internal ID '$insIntId' not found.");
	}
	unless ($page->field('prev_sequence'))
	{
		$page->param('prev_sequence', $page->field('bill_sequence'));
	}
	if($page->field('employer_org_id'))
	{
		my $empOrgId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $page->field('employer_org_id'));
		$page->field('employer_org_id', $empOrgId);
	}
}


sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	if ($page->param('person_id') ne '')
	{
		$page->field('person_id', $page->param('person_id'));
		$self->updateFieldFlags('person_id', FLDFLAG_READONLY, 1);
	}

	if ($page->field('rel_to_insured') == App::Universal::INSURED_SELF)
	{
		$page->field('insured_id', $page->field('person_id'));
	}
}


sub customValidate
{
	my ($self, $page) = @_;

	# Return if we're in remove mode
	my $command = $self->getActiveCommand($page);
	return () if $command eq 'remove';

	my $ownerOrgId = $page->session('org_internal_id');

	# Validate Relationship To Insured
	my $relToInsured = $page->field('rel_to_insured');
	my $relToInsuredField = $self->getField('rel_to_insured');
	my $insuredId = $page->field('insured_id');
	my $insuredIdField = $self->getField('insured_id');
	my $personId = $page->field('person_id');
	# If the relationship is not 'SELF' and Insured Person ID is blank or same as Patient ID
	if ($relToInsured != App::Universal::INSURED_SELF && ($insuredId eq $personId || $insuredId eq ''))
	{
		if($insuredId ne '')
		{
			$relToInsuredField->invalidate($page, "Must select 'Self' in '$relToInsuredField->{caption}' if '$insuredIdField->{caption}' is '$personId'");
			$insuredIdField->invalidate($page, "Valid insured ID is needed (other than '$personId') if '$relToInsuredField->{caption}' is other than 'Self.'");
		}
		else
		{
			my $createPersonHref = qq{javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-patient ',null,null,['_f_person_id'],['_f_insured_id']);};
			my $invMsg = qq{$insuredIdField->{caption} is required when Relationship is not 'Self'.  <a href="$createPersonHref">Create A New Person ID?</a> };
			$insuredIdField->invalidate($page, $invMsg)
		}
	}
	elsif($relToInsured == $App::Universal::INSURED_SELF && ($insuredId ne $personId && $insuredId ne ''))
	{
		$relToInsuredField->invalidate($page, "Must select '$relToInsuredField->{caption}' (other than 'Self') if '$insuredIdField->{caption}' is not '$personId'.");
		$insuredIdField->invalidate($page, "'$insuredIdField->{caption}' must be '$personId' when selecting 'Self' in '$relToInsuredField->{caption}'");
	}
	# If the relationship is other, the "Other Relationship" field becomes required
	if ($relToInsured == App::Universal::INSURED_OTHER)
	{
		my $otherField = $self->getField('extra');
		unless ($page->field('extra'))
		{
			$otherField->invalidate($page, "$otherField->{caption} is required when Relationship is 'Other'.");
		}
	}

	# Validate that Insurance Product exists (if entered)
	my $productRecord;
	if ($page->field('product_name'))
	{
		$productRecord = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selProductRecord', $ownerOrgId, $page->field('product_name'));
		if ($productRecord)
		{
			$page->property('productRecord', $productRecord) if defined $productRecord;
		}
		else
		{
			my $productField = $self->getField('product_name');
			my $newProductHref = "javascript:doActionPopup('/org-p/" . $page->session('org_id') . "/dlg-add-ins-product?_f_product_name=" . $page->field('product_name') . "')";
			$productField->invalidate($page, "Insurance Product '" . $page->field('product_name') . qq{' does not exist. <a href="$newProductHref">Create it now?</a>});
		}
	}

	# Validate that Insurance Plan exists (if entered) and is a child of Insurance Product
	my $planRecord;
	if ($page->field('plan_name'))
	{
		my $planField = $self->getField('plan_name');
		$planRecord = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPlanRecord', $ownerOrgId, $page->field('plan_name'));
		if ($planRecord)
		{
			$page->property('planRecord', $planRecord);
			if ($productRecord && $planRecord->{'parent_ins_id'} != $productRecord->{'ins_internal_id'})
			{
				$planField->invalidate($page, "'@{[$page->field('plan_name')]}' is not a not a Plan of the '@{[$page->field('product_name')]}' Product");
			}
		}
		else
		{
			my $newPlanHref = "javascript:doActionPopup('/org-p/" . $page->session('org_id') . "/dlg-add-ins-plan?_f_plan_name=" . $page->field('plan_name') . "')";
			$planField->invalidate($page, "Insurance Plan '" . $page->field('plan_name') . qq{' does not exist. <a href="$newPlanHref">Create it now?</a>});
		}
	}

	# Validate that they entered either a product or a plan
	unless($productRecord || $planRecord)
	{
		$self->getField('product_name')->invalidate($page, "You must enter an Insurance Product or a Plan");
		$self->getField('plan_name')->invalidate($page, "You must enter an Insurance Product or a Plan");
	}
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $ownerOrgIntId = $page->session('org_internal_id');
	# Since Ins Plan is not required, the parent record could be a Plan or Product record
	my $parentRecord;
	if ($page->field('plan_name'))
	{
		$parentRecord = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPlanRecord', $ownerOrgIntId, $page->field('plan_name'));
	}
	else
	{
		$parentRecord = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selProductRecord', $ownerOrgIntId, $page->field('product_name'));
	}
	my $empOrgIntId = $page->field('employer_org_id') ? $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrgIntId, $page->field('employer_org_id')) : undef;
	my $insIntId = $page->schemaAction(
		'Insurance', $command,
		ins_internal_id			=> $page->param('ins_internal_id') || undef,
		parent_ins_id			=> $parentRecord->{'ins_internal_id'} || undef,
		product_name			=> $parentRecord->{'product_name'} || undef,
		plan_name				=> $page->field('plan_name') || undef,
		record_type				=> App::Universal::RECORDTYPE_PERSONALCOVERAGE,
		owner_person_id			=> $page->param('person_id') || $page->field('person_id') || undef,
		ins_org_id				=> $parentRecord->{'ins_org_id'} || undef,
		owner_org_id			=> $ownerOrgIntId,
		bill_sequence			=> $page->field('bill_sequence'),
		ins_type				=> $parentRecord->{'ins_type'} || undef,
		employer_org_id			=> $empOrgIntId || undef,
		group_name				=> $page->field('group_name') || undef,
		group_number			=> $page->field('group_number') || undef,
		member_number			=> $page->field('member_number') || undef,
		insured_id				=> $page->field('insured_id') || undef,
		guarantor_id			=> $page->field('guarantor_id') || undef,
		rel_to_insured			=> $page->field('rel_to_insured') || undef,
		extra					=> $page->field('extra') || undef,
		indiv_deduct_remain		=> $page->field('indiv_deduct_remain') || undef,
		family_deduct_remain	=> $page->field('family_deduct_remain') || undef,
		copay_amt				=> $page->field('copay_amt') || undef,
		coverage_begin_date		=> $page->field('coverage_begin_date') || undef,
		coverage_end_date		=> $page->field('coverage_end_date') || undef,
		indiv_deductible_amt	=> $page->field('indiv_deductible_amt') || undef,
		family_deductible_amt	=> $page->field('family_deductible_amt') || undef,
		percentage_pay			=> $page->field('percentage_pay') || undef,
		threshold				=> $page->field('threshold') || undef,
		_debug => 0
		);

	$self->handlePostExecute($page, $command, $flags);
	return '';
}

1;
