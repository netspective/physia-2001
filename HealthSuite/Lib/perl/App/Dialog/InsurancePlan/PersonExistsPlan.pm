##############################################################################
package App::Dialog::InsurancePlan::PersonExistsPlan;
##############################################################################
use strict;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Insurance;
use App::Dialog::InsurancePlan;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Universal;
use vars qw(@ISA %RESOURCE_MAP);

%RESOURCE_MAP = (
	'ins-exists' => {
			_arl_add => ['ins_id'],
			_arl_modify => ['ins_internal_id'],
			},
		);

@ISA = qw(App::Dialog::InsurancePlan);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Insurance Plan');

	my $schema = $self->{schema};
	$self->addContent(
			new CGI::Dialog::MultiField(caption => 'Insurance Plan ID/Employer Plan ID', name => 'ins_plan',
				fields => [
					new App::Dialog::Field::Insurance::ID(caption => 'Insurance Plan ID', name => 'ins_id'),
					new CGI::Dialog::Field(caption => 'Employee Plans',
								name => 'emp_plan',
								fKeyStmtMgr => $STMTMGR_INSURANCE,
								#fKeyStmtFlags => STMTMGRFLAG_DEBUG,
								fKeyStmt => 'selEmpExistPlan',
								#fKeyStmtBindPageParams => 'RHACKETT',
								fKeyDisplayCol => 0,
								fKeyValueCol => 0,
								defaultValue => ''
							)
						]),

			new CGI::Dialog::Field::TableColumn(
					caption => 'Insurance Sequence',
					schema => $schema,
					column => 'Insurance.bill_sequence',
					onValidate => \&App::Dialog::InsurancePlan::validateExistingInsSeq,
					onValidateData => $self),


		new CGI::Dialog::Subhead(heading => 'General Plan Information', name => 'gen_plan_heading'),

			new CGI::Dialog::Field::TableColumn(
							caption => 'Member Number',
							schema => $schema,
							column => 'Insurance.member_number'),

			new CGI::Dialog::Field::TableColumn(
							caption => 'Policy Number',
							schema => $schema,
							column => 'Insurance.policy_number'),


			new CGI::Dialog::MultiField(caption =>'Insured/Guarantor ID', name => 'insured_guarantor_ids',
				fields => [
						new App::Dialog::Field::Person::ID(caption => 'Insured ID',
							types => ['Patient'],
							name => 'insured_id',options => FLDFLAG_REQUIRED),

						new App::Dialog::Field::Person::ID(caption => 'Guarantor ID',
							types => ['Patient'],
							name => 'guarantor_id',
							options => FLDFLAG_REQUIRED)
					]),

						new App::Dialog::Field::Person::ID(caption => 'Insured ID',
							types => ['Patient'],
							name => 'insured_id'
							),

			new CGI::Dialog::Field(caption => 'Relationship to Insured',
							name => 'rel_to_insured',
							fKeyStmtMgr => $STMTMGR_INSURANCE,
							fKeyStmt => 'selInsuredRelation',
							fKeyDisplayCol => 1,
							fKeyValueCol => 0
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
								new CGI::Dialog::Field(caption => 'End Date', name => 'coverage_end_date', type => 'date', options => FLDFLAG_REQUIRED, futureOnly => 1),
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
						caption => 'Co-pay Amount',
						schema => $schema,
						column => 'Insurance.copay_amt'),
	);

		$self->{activityLog} =
		{
			scope =>'insurance',
			key => "#param.person_id#",
			data => "Insurance '#field.ins_id#' in <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
		};

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;

}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	my $personId = $page->param('person_id');
	#$self->getField('ins_plan')->{fields}->[1]->{fKeyWhere} = "patt.parent_id = '@{[ $page->param('person_id') ]}' and patt.item_name like 'Association/Employment/%' and patt.value_text = ins.ins_org_id and ins.record_type = 6 ";
	#my $data =  $STMTMGR_INSURANCE->getSingleValueList($page, STMTMGRFLAG_CACHE, 'selEmpExistPlan', $personId);
	#my $existPlan = join('; ', @{$data});
	$self->getField('ins_plan')->{fields}->[1]->{fKeyStmtBindPageParams} = $personId;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $editInsIntId = $page->param('ins_internal_id');
	my $personId = $page->param('person_id');
	my $recordType = App::Universal::RECORDTYPE_PERSONALCOVERAGE;
	#Use constants for sql statement
 	my $categoryRecType = App::Universal::RECORDTYPE_CATEGORY;
	my $glbGrpRecType = App::Universal::RECORDTYPE_INSURANCEPLAN;
	my $orgGrpInhRecType = App::Universal::RECORDTYPE_INSURANCEPLAN;
	my $orgGrpUnqRecType = App::Universal::RECORDTYPE_INSURANCEPLAN;
	my $insId = $page->field('ins_id') ne '' ? $page->field('ins_id') : $page->field('emp_plan');

	my $planData = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsurancePlanData', $insId,
							$categoryRecType, $glbGrpRecType, $orgGrpInhRecType, $orgGrpUnqRecType);

	#Values that can be zero
	my $insType = $planData->{ins_type};
	my $remitType = $planData->{remit_type};
	my $relToInsured = $page->field('rel_to_insured');
	my $billSeq = $page->field('bill_sequence');
	my $insuredId = $page->field('insured_id') eq '' ? $personId : $page->field('insured_id') ;
	$page->schemaAction(
			'Insurance', $command,
			ins_internal_id => $editInsIntId || undef,
			ins_id => $insId,
			parent_ins_id => $planData->{ins_internal_id} || undef,
			owner_id => $personId || undef,
			owner_org_id => $page->session('org_id'),
			ins_org_id => $planData->{ins_org_id} || undef,
			record_type => defined $recordType ? $recordType : undef,
			ins_type => defined $insType ? $insType : undef,
			bill_sequence => defined $billSeq ? $billSeq : undef,
			rel_to_insured => defined $relToInsured ? $relToInsured : undef,
			member_number => $page->field('member_number') || undef,
			plan_name => $planData->{plan_name} || undef,
			policy_number => $page->field('policy_number') || undef,
			group_name => $planData->{group_name} || undef,
			group_number => $planData->{group_number} || undef,
			insured_id => $insuredId || undef,
			guarantor_id => $page->field('guarantor_id') || undef,
			indiv_deductible_amt => $page->field('indiv_deductible_amt') || undef,
			family_deductible_amt  => $page->field('family_deductible_amt') || undef,
			indiv_deduct_remain => $page->field('indiv_deduct_remain') || undef,
			family_deduct_remain => $page->field('indiv_deduct_remain') || undef,
			remit_type => defined $remitType ? $remitType : undef,
			remit_payer_id => $planData->{remit_payer_id} || undef,
			remit_payer_name => $planData->{remit_payer_name} || undef,
			coverage_begin_date => $page->field('coverage_begin_date') || undef,
			coverage_end_date => $page->field('coverage_end_date') || undef,
			copay_amt => $page->field('copay_amt') || undef,
			percentage_pay => $page->field('percentage_pay') || undef,
			threshold => $page->field('threshold') || undef,
			extra => $planData->{extra} || undef,
			_debug => 0
		);

	$personId = uc($personId);
	$self->handlePostExecute($page, $command, $flags);
}

use constant INSURANCEEXISTS_DIALOG => 'Dialog/Existing Insurance';


1;
