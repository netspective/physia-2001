##############################################################################
package App::Dialog::InsurancePlan::NewPlan;
##############################################################################
use strict;
use Carp;
use CGI::Validator::Field;
use App::Dialog::InsurancePlan;
use CGI::Dialog;
use App::Universal;
use vars qw(@ISA %RESOURCE_MAP);

%RESOURCE_MAP = (
	'ins-newplan' => {
			heading => '$Command Insurance Plan',
			_arl_add => ['ins_id'],
			_arl_modify => ['ins_internal_id'],
			_idSynonym => 'ins-' . App::Universal::RECORDTYPE_INSURANCEPLAN },
		);

use Date::Manip;

@ISA = qw(App::Dialog::InsurancePlan);

sub initialize
{
	my $self = shift;

	$self->heading('$Command New Insurance Plan');

	$self->SUPER::initialize();

	my $schema = $self->{schema};

	$self->addContent(

		new CGI::Dialog::Subhead(heading => 'General Plan Information', name => 'gen_plan_heading'),


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
			key => "#field.ins_org_id#",
			data => "Insurance '#field.ins_id#' in <a href='/org/#field.ins_org_id#/profile'>#field.ins_org_id#</a>"
		};

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

use constant INSURANCEEXISTS_DIALOG => 'Dialog/New Insurance Plan';


1;