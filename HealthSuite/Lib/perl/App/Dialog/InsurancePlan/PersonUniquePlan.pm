##############################################################################
package App::Dialog::InsurancePlan::PersonUniquePlan;
##############################################################################
use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Universal;
use App::Dialog::InsurancePlan;
use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Insurance;
use Date::Manip;
use vars qw(@ISA);
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

@ISA = qw(App::Dialog::InsurancePlan);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Unique Plan');

	$self->SUPER::initialize();

	my $schema = $self->{schema};

	$self->addContent(

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
			new CGI::Dialog::MultiField(caption =>'Policy Name/Number', name => 'policy_name_number',
				fields => [
						new CGI::Dialog::Field::TableColumn(
							caption => 'Policy Name',
							schema => $schema,
							column => 'Insurance.plan_name'),
						new CGI::Dialog::Field::TableColumn(
							caption => 'Policy Number',
							schema => $schema,
							column => 'Insurance.policy_number')
					]),


			new CGI::Dialog::MultiField(caption =>'Group Name/Number', name => 'group_name_number',
				fields => [
						new CGI::Dialog::Field::TableColumn(
							caption => 'Group Name',
							name => 'group_name',
							schema => $schema,
							column => 'Insurance.group_name'),
						new CGI::Dialog::Field::TableColumn(
							caption => 'Group Number',
							name => 'group_number',
							schema => $schema,
							column => 'Insurance.group_number'),
					]),

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
							type => 'foreignKey',
							name => 'rel_to_insured',
							fKeyStmtMgr => $STMTMGR_INSURANCE,
							fKeyStmt => 'selInsuredRelation',
							fKeyDisplayCol => 1,
							fKeyValueCol => 0),

			new CGI::Dialog::MultiField(caption =>'Indiv/Family Deductible Remaining', name => 'deduct_remain',
				fields => [
						new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Insurance.indiv_deduct_remain'),
						new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Insurance.family_deduct_remain'),
					]),
			new CGI::Dialog::Field::TableColumn(caption => 'Remittance Type',
							name => 'remit_type',
							schema => $schema,
							column => 'Insurance.Remit_Type'),
			new CGI::Dialog::Field(caption => 'E-Remittance Payer ID',
							hints=> '(Only for non-Paper types)',
							name => 'remit_payer_id',
							findPopup => '/lookup/envoypayer/id'),

		new CGI::Dialog::Subhead(heading => 'Coverage Information', name => 'coverage_heading'),
			new CGI::Dialog::MultiField (caption => 'Coverage Begin/End Dates',	name => 'dates',
					fields => [
								new CGI::Dialog::Field(caption => 'Begin Date', name => 'coverage_begin_date', type => 'date'),
								new CGI::Dialog::Field(caption => 'End Date', name => 'coverage_end_date', type => 'date'),
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


use constant INSURANCEUNIQUE_DIALOG => 'Dialog/Unique Insurance';

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/27/1999', 'RK',
		INSURANCEUNIQUE_DIALOG,
		'Updated the code to add the PatientId as InsuredId by default and added the customValidate subroutine to check that if the field rel_to_insured is other than Self, a valid insured_id must be entered. '],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/10/2000', 'RK',
		INSURANCEUNIQUE_DIALOG,
		"Added session-activity to the unique insurance plan."],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/26/2000', 'MAF',
		INSURANCEUNIQUE_DIALOG,
		'Fixed problem with handleAttribute not working properly.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '02/22/2000', 'RK',
		INSURANCEUNIQUE_DIALOG,
		"Changed the Date field names in the dialog and in schema actions in order to display the dates while updating and deleting"],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/22/2000', 'MAF',
		INSURANCEUNIQUE_DIALOG,
		'Cleaned up dialog fields and makeStateChanges.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/23/2000', 'MAF',
		INSURANCEUNIQUE_DIALOG,
		'Removed sub execute. Modularized code.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/28/2000', 'RK',
		INSURANCEUNIQUE_DIALOG,
		'Replaced fkeyxxx select in the dialogs with Sql statement from Statement Manager'],


);

1;