##############################################################################
package App::Dialog::TWCC73;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Invoice;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'twcc73' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'twcc73', heading => 'TWCC Form 73');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(		
		new CGI::Dialog::Field(type => 'hidden', name => 'field4_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field13_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field14a_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field14b_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field14c_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field14d_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field14e_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field14f_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field14g_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field15_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field16_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field17a_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field17b_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field17c_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field17d_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field17e_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field17f_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field17g_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field17h_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field18_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19a_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19b_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19c_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19d_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19e_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19f_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19g_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19h_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19i_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19j_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19k_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field20_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field21_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field22a_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field22b_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field22c_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field22d_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field22e_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field23_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field24_item_id'),
		

		#4
		new CGI::Dialog::Field(type => 'memo', caption => "Employee's Description of Injury/Accident", name => 'employee_descr'),

		#13
		new CGI::Dialog::Subhead(heading => 'Work Status Information', name => 'workstatus_heading'),
		new CGI::Dialog::Field(type => 'select',  name => 'return_to_work', 
				selOptions => 'Return to work (w/o restrictions):1;Return to work (w/ restrictions):2;Prevents employee from returning to work:3', 
				caption => "Injured employee's medical condition resulting from work comp injury",
				options => FLDFLAG_REQUIRED | FLDFLAG_PREPENDBLANK,
				onChangeJS => qq{showFieldsOnValues(event, [1], ['return_date_no_restrict']); showFieldsOnValues(event, [2], ['return_date_restrict_fields']); showFieldsOnValues(event, [3], ['prevent_return_date_fields']);},),

			#13a
			new CGI::Dialog::Field(type => 'date', caption => 'Allow employee to return to work as of', name => 'return_date_no_restrict', defaultValue => ''),
			#13b
			new CGI::Dialog::MultiField(caption => 'Allow employee to return to work as of and through', name => 'return_date_restrict_fields',
				fields => [
					new CGI::Dialog::Field(type => 'date', caption => 'Allow employee to return to work as of', name => 'return_date_restrict_from', defaultValue => ''),
					new CGI::Dialog::Field(type => 'date', caption => 'Allow employee to return to work through', name => 'return_date_restrict_to', defaultValue => ''),
				]),
			#13c
			new CGI::Dialog::MultiField(caption => 'Prevents employee from returning to work as of and through', name => 'prevent_return_date_fields',
				fields => [
					new CGI::Dialog::Field(type => 'date', caption => 'Prevents employee from returning to work as of', name => 'prevent_return_date_from', defaultValue => ''),
					new CGI::Dialog::Field(type => 'date', caption => 'Prevents employee from returning to work through', name => 'prevent_return_date_to', defaultValue => ''),
				]),



		#14
		new CGI::Dialog::Subhead(heading => "Activity Restrictions (Only complete if 'Return to work (w/ restrictions)' was selected)", name => 'restrictions_heading'),

		new CGI::Dialog::MultiField(caption => 'Posture Restrictions (if any):', name => 'posture_column_heads', options => FLDFLAG_READONLY,
			fields => [
				new CGI::Dialog::Field(	caption => 'max hrs', name => 'max_hrs', value => 'Max Hrs /'),
				new CGI::Dialog::Field(caption => 'other hrs', name => 'other_hrs', value => 'Other'),
			]),

		new CGI::Dialog::MultiField(caption => 'Standing', name => 'standing_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Standing max hours', name => 'standing_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Standing other hours', name => 'standing_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Sitting', name => 'sitting_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Sitting max hours', name => 'sitting_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Sitting other hours', name => 'sitting_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Kneeling/Squatting', name => 'kneeling_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Kneeling/Squatting max hours', name => 'kneeling_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Kneeling/Squatting other hours', name => 'kneeling_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Bending/Stooping', name => 'bending_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Bending/Stooping max hours', name => 'bending_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Bending/Stooping other hours', name => 'bending_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Pushing/Pulling', name => 'pushing_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Pushing/Pulling max hours', name => 'pushing_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Pushing/Pulling other hours', name => 'pushing_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Twisting', name => 'twisting_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Twisting max hours', name => 'twisting_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Twisting other hours', name => 'twisting_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Other Posture', name => 'other_posture_fields',
			fields => [
				new CGI::Dialog::Field(caption => 'Other Posture', name => 'other_posture'),
				new CGI::Dialog::Field(	type => 'select', caption => 'Other max hours', name => 'other_posture_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Other other hours', name => 'other_posture_other_hours'),
			]),


		#15
		new CGI::Dialog::Subhead(heading => '', name => 'divider1'),
		new CGI::Dialog::Field(name => 'specific_restrictions',
				type => 'select',
				style => 'multicheck',
				caption => 'Restrictions specific to (if applicable):',
				selOptions => 'L Hand/Wrist:LH;L Arm:LA;L Leg:LL;L Foot/Ankle:LF;R Hand/Wrist:RH;R Arm:RA;R Leg:RL;R Foot/Ankle:RF;Neck:N;Back:B',
				),
		new CGI::Dialog::Field(caption => 'Other', name => 'other_specific_restriction'),


		#16
		new CGI::Dialog::Subhead(heading => '', name => 'divider2'),
		new CGI::Dialog::Field(type => 'memo', caption => 'Other restrictions (if any):', name => 'other_restrictions_notes'),


		#17		
		new CGI::Dialog::Subhead(heading => '', name => 'divider3'),
		new CGI::Dialog::MultiField(caption => 'Motion Restrictions (if any):', name => 'motion_column_heads', options => FLDFLAG_READONLY,
			fields => [
				new CGI::Dialog::Field(	caption => 'max hrs', name => 'max_hrs', value => 'Max Hrs /'),
				new CGI::Dialog::Field(caption => 'other hrs', name => 'other_hrs', value => 'Other'),
			]),

		new CGI::Dialog::MultiField(caption => 'Walking', name => 'walking_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Walking max hours', name => 'walking_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Walking other hours', name => 'walking_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Climbing stairs/ladders', name => 'climbing_stairs_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Climbing stairs/ladders max hours', name => 'climbing_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Climbing stairs/ladders other hours', name => 'climbing_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Grasping/Squeezing', name => 'grasping_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Grasping/Squeezing max hours', name => 'grasping_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Grasping/Squeezing other hours', name => 'grasping_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Wrist flexion/extension', name => 'wrist_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Wrist flexion/extension max hours', name => 'wrist_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Wrist flexion/extension other hours', name => 'wrist_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Reaching', name => 'reaching_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Reaching max hours', name => 'reaching_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Reaching other hours', name => 'reaching_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Overhead Reaching', name => 'overhead_reaching_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Overhead Reaching max hours', name => 'overhead_reaching_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Overhead Reaching other hours', name => 'overhead_reaching_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Keyboarding', name => 'keyboarding_fields',
			fields => [
				new CGI::Dialog::Field(	type => 'select', caption => 'Keyboarding max hours', name => 'keyboarding_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Keyboarding other hours', name => 'keyboarding_other_hours'),
			]),
		new CGI::Dialog::MultiField(caption => 'Other Motion', name => 'other_motion_fields',
			fields => [
				new CGI::Dialog::Field(caption => 'Other motion', name => 'other_motion'),
				new CGI::Dialog::Field(	type => 'select', caption => 'Other max hours', name => 'other_motion_hours', selOptions => '0;2;4;6;8', options => FLDFLAG_PREPENDBLANK),
				new CGI::Dialog::Field(type => 'integer', caption => 'Other other hours', name => 'other_motion_other_hours'),
			]),



		#18
		new CGI::Dialog::Subhead(heading => '', name => 'divider4'),
		new CGI::Dialog::Field(type => 'select',  name => 'lift_carry_instructions', 
				selOptions => 'May not lift/carry objects (conditional):1;May not perform any lifting/carrying:2;Other:3', 
				caption => 'Lift/Carry Restrictions (if any):',
				options => FLDFLAG_PREPENDBLANK,
				onChangeJS => qq{showFieldsOnValues(event, [1], ['pounds_hours_fields']); showFieldsOnValues(event, [3], ['other_carry_restrictions']);},),

			new CGI::Dialog::MultiField(caption => 'Pounds (lbs) per hour(s)', name => 'pounds_hours_fields',
				fields => [
					new CGI::Dialog::Field(type => 'integer', caption => 'Max Pounds', name => 'carry_lbs'),
					new CGI::Dialog::Field(type => 'integer', caption => 'Hours per day', name => 'carry_hours'),
				]),
			new CGI::Dialog::Field(caption => 'Other Lift/Carry Restrictions', name => 'other_carry_restrictions'),



		#19
		new CGI::Dialog::Subhead(heading => '', name => 'divider5'),
		new CGI::Dialog::Field(caption => 'Misc Restrictions (if any):', name => 'misc_restrict_heading', options => FLDFLAG_READONLY),
		new CGI::Dialog::Field(type => 'integer', caption => 'Max hours per day of work', name => 'max_hours_of_work'),
		new CGI::Dialog::MultiField(caption => 'Sit/Stretch breaks (number per unit of time)', name => 'sit_stretch_breaks_fields',
			fields => [
				new CGI::Dialog::Field(type => 'integer', caption => 'Sit/Stretch breaks (number)', name => 'num_of_sit_stretch_breaks'),
				new CGI::Dialog::Field(caption => 'Sit/Stretch breaks (per unit of time)', name => 'sit_stretch_breaks_per'),
			]),
		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Yes:1;No:2', caption => 'Must wear splint/cast at work', name => 'wear_splint_cast', defaultValue => 2),
		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Yes:1;No:2', caption => 'Must use crutches at all times', name => 'crutches', defaultValue => 2),
		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Yes:1;No:2', caption => 'No driving/operating heavy equipment', name => 'no_driving', defaultValue => 2),
		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Yes:1;No:2', caption => 'Can only drive automatic transmission', name => 'auto_transmission_only', defaultValue => 2),

		new CGI::Dialog::Field(type => 'select',  name => 'work_limitations', 
				selOptions => 'No work:1;Limited work hours:2', 
				caption => 'Work schedule limitations',
				options => FLDFLAG_PREPENDBLANK,
				onChangeJS => qq{showFieldsOnValues(event, [2], ['work_hours_per_day',]);},),

		new CGI::Dialog::Field(type => 'integer', caption => 'Hours per day', name => 'work_hours_per_day'),
		#new CGI::Dialog::MultiField(caption => 'Work Conditions', name => 'work_conditions',
		#	fields => [
				new CGI::Dialog::Field(type => 'bool', style => 'check', caption => 'In extreme hot/cold environments', name => 'work_temp_environment'),
				new CGI::Dialog::Field(type => 'bool', style => 'check', caption => 'At heights or on scaffolding', name => 'work_height_environment'),
		#	]),
		new CGI::Dialog::MultiField(caption => 'Must keep (provide body part)', name => 'must_keep_fields',
			fields => [
				new CGI::Dialog::Field(caption => 'Must keep info', name => 'must_keep_text'),
				new CGI::Dialog::Field(type => 'bool', style => 'check', caption => 'Elevated', name => 'elevated'),
				new CGI::Dialog::Field(type => 'bool', style => 'check', caption => 'Clean & Dry', name => 'clean_dry'),
			]),

		new CGI::Dialog::Field(caption => 'No skin contact with', name => 'no_skin_contact_with'),
		new CGI::Dialog::Field(type => 'bool', style => 'check', caption => 'Dressing changes necessary at work', name => 'dress_changes'),
		new CGI::Dialog::Field(type => 'bool', style => 'check', caption => 'No Running', name => 'no_running'),


		#20
		new CGI::Dialog::Subhead(heading => '', name => 'divider6'),
		new CGI::Dialog::Field(caption => 'Medications Restrictions (if any):', name => 'med_restrict_heading', options => FLDFLAG_READONLY),
		new CGI::Dialog::Field(type => 'bool', style => 'check', caption => 'Must take prescription medication(s)', name => 'prescription_meds'),
		new CGI::Dialog::Field(type => 'bool', style => 'check', caption => 'Advised to take over-the-counter meds', name => 'otc_meds'),
		new CGI::Dialog::Field(type => 'bool', style => 'check', caption => 'Medication may take drowsy (possible safety/driving issues)', name => 'drowsy_meds'),

		#21
		new CGI::Dialog::Subhead(heading => 'Treatment/Follow-up Appointment Information', name => 'divider7'),
		new CGI::Dialog::Field(type => 'memo', caption => 'Work Injury Diagnosis Information', name => 'injury_diag_info'),

		#22
		new CGI::Dialog::Field(caption => 'Expected Follow-up Services include:', name => 'follow_up_services_heading', options => FLDFLAG_READONLY),
		new CGI::Dialog::MultiField(caption => 'Evaluation by the treating doctor (date/time)', name => 'eval_by_doc_fields',
			fields => [
				new CGI::Dialog::Field(type => 'date', caption => 'Evaluation Date', name => 'eval_date', defaultValue => ''),
				new CGI::Dialog::Field(type => 'time', caption => 'Evaluation Time', name => 'eval_time'),
			]),
		new CGI::Dialog::MultiField(caption => 'Referral to/Consult with (name/date/time)', name => 'ref_consult_fields',
			fields => [
				new CGI::Dialog::Field(caption => 'Referral to/Consult with', name => 'ref_consult_with'),
				new CGI::Dialog::Field(type => 'date', caption => 'Referral to/Consult Date', name => 'ref_consult_date', defaultValue => ''),
				new CGI::Dialog::Field(type => 'time', caption => 'Referral to/Consult Time', name => 'ref_consult_time'),
			]),
		new CGI::Dialog::MultiField(caption => 'Physical medicine (# per week/# of weeks/start date/start time)', name => 'phys_med_fields',
			fields => [
				new CGI::Dialog::Field(type => 'integer', caption => 'Physical medicine (per week)', name => 'phys_med_per_week'),
				new CGI::Dialog::Field(type => 'integer', caption => 'Physical medicine (# of weeks)', name => 'phys_med_weeks'),
				new CGI::Dialog::Field(type => 'date', caption => 'Physical medicine (start date)', name => 'phys_med_start_date', defaultValue => ''),
				new CGI::Dialog::Field(type => 'time', caption => 'Physical medicine (start time)', name => 'phys_med_start_time'),
			]),
		new CGI::Dialog::MultiField(caption => 'Special studies (list/date/time)', name => 'special_studies_fields',
			fields => [
				new CGI::Dialog::Field(caption => 'Special studies list', name => 'special_list'),
				new CGI::Dialog::Field(type => 'date', caption => 'Special studies date', name => 'special_studies_date', defaultValue => ''),
				new CGI::Dialog::Field(type => 'time', caption => 'Special studies time', name => 'special_studies_time'),
			]),
		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'True:1;False:2', caption => 'None. This is the last scheduled visit for this problem. At this time, no further medical care is anticipated.', name => 'no_services_anticipated', defaultValue => 2),

		#visit type - no number on form so we'll refer to it as 23
		new CGI::Dialog::Field(type => 'select',  name => 'visit_type', selOptions => 'Initial:1;Follow-up:2', caption => 'Visit Type'),

		#role of doctor - no number on form so we'll refer to it as 24
		new CGI::Dialog::Field(type => 'select',  name => 'doctor_role', caption => 'Role of Doctor',
			selOptions => 'Designated doctor:1;Carrier-selected RME:2;TWCC-selected RME:3;Treating doctor:4;Referral doctor:5;Consulting doctor:6;Other doctor:7'),

	);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $invoiceId = $page->param('invoice_id');


	#populate field 4
	my $field4 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/4');
	$page->field('field4_item_id', $field4->{item_id});
	$page->field('employee_descr', $field4->{value_text});


	#populate field 13
	my $field13 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/13');
	$page->field('field13_item_id', $field13->{item_id});
	$page->field('return_date_no_restrict', $field13->{value_date});
	my $returnToWork = $field13->{value_int};
	$page->field('return_to_work', $returnToWork);
	if($returnToWork == 2)
	{
		$page->field('return_date_restrict_from', $field13->{value_datea});
		$page->field('return_date_restrict_to', $field13->{value_dateb});	
	}
	elsif($returnToWork == 3)
	{
		$page->field('prevent_return_date_from', $field13->{value_datea});
		$page->field('prevent_return_date_to', $field13->{value_dateb});	
	}


	#populate field 14
	my $field14a = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/14a');
	$page->field('field14a_item_id', $field14a->{item_id});
	$page->field('standing_hours', $field14a->{value_int});
	$page->field('standing_other_hours', $field14a->{value_intb});

	my $field14b = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/14b');
	$page->field('field14b_item_id', $field14b->{item_id});
	$page->field('sitting_hours', $field14b->{value_int});
	$page->field('sitting_other_hours', $field14b->{value_intb});

	my $field14c = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/14c');
	$page->field('field14c_item_id', $field14c->{item_id});
	$page->field('kneeling_hours', $field14c->{value_int});
	$page->field('kneeling_other_hours', $field14c->{value_intb});

	my $field14d = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/14d');
	$page->field('field14d_item_id', $field14d->{item_id});
	$page->field('bending_hours', $field14d->{value_int});
	$page->field('bending_other_hours', $field14d->{value_intb});

	my $field14e = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/14e');
	$page->field('field14e_item_id', $field14e->{item_id});
	$page->field('pushing_hours', $field14e->{value_int});
	$page->field('pushing_other_hours', $field14e->{value_intb});

	my $field14f = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/14f');
	$page->field('field14f_item_id', $field14f->{item_id});
	$page->field('twisting_hours', $field14f->{value_int});
	$page->field('twisting_other_hours', $field14f->{value_intb});

	my $field14g = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/14g');
	$page->field('field14g_item_id', $field14g->{item_id});
	$page->field('other_posture_hours', $field14g->{value_int});
	$page->field('other_posture_other_hours', $field14g->{value_intb});
	$page->field('other_posture', $field14g->{value_text});


	#populate field 15
	my $field15 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/15');
	$page->field('field15_item_id', $field15->{item_id});
	my @specificRestrictions = split(',', $field15->{value_text});
	$page->field('specific_restrictions', @specificRestrictions);
	$page->field('other_specific_restriction', $field15->{value_textb});


	#populate field 16
	my $field16 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/16');
	$page->field('field16_item_id', $field16->{item_id});
	$page->field('other_restrictions_notes', $field16->{value_text});


	#populate field 17
	my $field17a = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/17a');
	$page->field('field17a_item_id', $field17a->{item_id});
	$page->field('walking_hours', $field17a->{value_int});
	$page->field('walking_other_hours', $field17a->{value_intb});

	my $field17b = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/17b');
	$page->field('field17b_item_id', $field17b->{item_id});
	$page->field('climbing_hours', $field17b->{value_int});
	$page->field('climbing_other_hours', $field17b->{value_intb});

	my $field17c = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/17c');
	$page->field('field17c_item_id', $field17c->{item_id});
	$page->field('grasping_hours', $field17c->{value_int});
	$page->field('grasping_other_hours', $field17c->{value_intb});

	my $field17d = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/17d');
	$page->field('field17d_item_id', $field17d->{item_id});
	$page->field('wrist_hours', $field17d->{value_int});
	$page->field('wrist_other_hours', $field17d->{value_intb});

	my $field17e = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/17e');
	$page->field('field17e_item_id', $field17e->{item_id});
	$page->field('reaching_hours', $field17e->{value_int});
	$page->field('reaching_other_hours', $field17e->{value_intb});

	my $field17f = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/17f');
	$page->field('field17f_item_id', $field17f->{item_id});
	$page->field('overhead_reaching_hours', $field17f->{value_int});
	$page->field('overhead_reaching_other_hours', $field17f->{value_intb});

	my $field17g = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/17g');
	$page->field('field17g_item_id', $field17g->{item_id});
	$page->field('keyboarding_hours', $field17g->{value_int});
	$page->field('keyboarding_other_hours', $field17g->{value_intb});

	my $field17h = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/17h');
	$page->field('field17h_item_id', $field17h->{item_id});
	$page->field('other_motion_hours', $field17h->{value_int});
	$page->field('other_motion_other_hours', $field17h->{value_intb});
	$page->field('other_motion', $field17h->{value_text});


	#populate field 18
	my $field18 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/18');
	$page->field('field18_item_id', $field18->{item_id});
	my $carryInstructions = $field18->{value_int};
	$page->field('lift_carry_instructions', $carryInstructions);
	if($carryInstructions == 1)
	{
		$page->field('carry_lbs', $field18->{value_text});
		$page->field('carry_hours', $field18->{value_textb});
	}
	elsif($carryInstructions == 3)
	{
		$page->field('other_carry_restrictions', $field18->{value_text});
	}
	

	#populate field 19
	my $field19a = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19a');
	$page->field('field19a_item_id', $field19a->{item_id});
	$page->field('max_hours_of_work', $field19a->{value_int});

	my $field19b = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19b');
	$page->field('field19b_item_id', $field19b->{item_id});
	$page->field('sit_stretch_breaks_per', $field19b->{value_text});
	$page->field('num_of_sit_stretch_breaks', $field19b->{value_int});

	my $field19c = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19c');
	$page->field('field19c_item_id', $field19c->{item_id});
	$page->field('wear_splint_cast', $field19c->{value_int});

	my $field19d = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19d');
	$page->field('field19d_item_id', $field19d->{item_id});
	$page->field('crutches', $field19d->{value_int});

	my $field19e = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19e');
	$page->field('field19e_item_id', $field19e->{item_id});
	$page->field('no_driving', $field19e->{value_int});

	my $field19f = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19f');
	$page->field('field19f_item_id', $field19f->{item_id});
	$page->field('auto_transmission_only', $field19f->{value_int});

	my $field19g = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19g');
	$page->field('field19g_item_id', $field19g->{item_id});
	my $workLimitations = $field19g->{value_int};
	$page->field('work_limitations', $workLimitations);
	$page->field('work_temp_environment', $field19g->{value_text}) if $workLimitations;
	$page->field('work_height_environment', $field19g->{value_textb}) if $workLimitations;
	if($workLimitations == 2)
	{
		$page->field('work_hours_per_day', $field19g->{value_intb});
	}

	my $field19h = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19h');
	$page->field('field19h_item_id', $field19h->{item_id});
	$page->field('must_keep_text', $field19h->{value_text});
	$page->field('elevated', $field19h->{value_int});
	$page->field('clean_dry', $field19h->{value_intb});

	my $field19i = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19i');
	$page->field('field19i_item_id', $field19i->{item_id});
	$page->field('no_skin_contact_with', $field19i->{value_text});

	my $field19j = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19j');
	$page->field('field19j_item_id', $field19j->{item_id});
	$page->field('dress_changes', $field19j->{value_int});

	my $field19k = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/19k');
	$page->field('field19k_item_id', $field19k->{item_id});
	$page->field('no_running', $field19k->{value_int});


	#populate field 20
	my $field20 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/20');
	$page->field('field20_item_id', $field20->{item_id});
	$page->field('prescription_meds', $field20->{value_text});
	$page->field('otc_meds', $field20->{value_textb});
	$page->field('drowsy_meds', $field20->{value_int});


	#populate field 21
	my $field21 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/21');
	$page->field('field21_item_id', $field21->{item_id});
	$page->field('injury_diag_info', $field21->{value_text});


	#populate field 22
	my $field22a = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/22a');
	$page->field('field22a_item_id', $field22a->{item_id});
	$page->field('eval_time', $field22a->{value_text});
	$page->field('eval_date', $field22a->{value_date});

	my $field22b = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/22b');
	$page->field('field22b_item_id', $field22b->{item_id});
	$page->field('ref_consult_with', $field22b->{value_text});
	$page->field('ref_consult_time', $field22b->{value_textb});
	$page->field('ref_consult_date', $field22b->{value_date});

	my $field22c = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/22c');
	$page->field('field22c_item_id', $field22c->{item_id});
	$page->field('phys_med_per_week', $field22c->{value_int});
	$page->field('phys_med_weeks', $field22c->{value_intb});
	$page->field('phys_med_start_date', $field22c->{value_date});
	$page->field('phys_med_start_time', $field22c->{value_text});

	my $field22d = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/22d');
	$page->field('field22d_item_id', $field22d->{item_id});
	$page->field('special_list', $field22d->{value_text});
	$page->field('special_studies_time', $field22d->{value_textb});
	$page->field('special_studies_date', $field22d->{value_date});

	my $field22e = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/22e');
	$page->field('field22e_item_id', $field22e->{item_id});
	$page->field('no_services_anticipated', $field22e->{value_int});


	#populate field 23
	my $field23 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/23');
	$page->field('field23_item_id', $field23->{item_id});
	$page->field('visit_type', $field23->{value_int});


	#populate field 24
	my $field24 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/24');
	$page->field('field24_item_id', $field24->{item_id});
	$page->field('doctor_role', $field24->{value_int});
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $dateValueType = App::Universal::ATTRTYPE_DATE;

	#4
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field4_item_id') || undef,
			parent_id => $invoiceId,			
			item_name => 'Invoice/TWCC73/4',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('employee_descr') || undef,
			_debug => 0
	);


	#13
	my $valueDate13;
	my $valueDateA13;
	my $valueDateB13;
	my $returnToWork = $page->field('return_to_work');
	if($returnToWork == 1)
	{
		$valueDate13 = $page->field('return_date_no_restrict');
	}
	elsif($returnToWork == 2)
	{
		$valueDateA13 = $page->field('return_date_restrict_from');
		$valueDateB13 = $page->field('return_date_restrict_to');
	}
	elsif($returnToWork == 3)
	{
		$valueDateA13 = $page->field('prevent_return_date_from');
		$valueDateB13 = $page->field('prevent_return_date_to');
	}

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field13_item_id') || undef,
			parent_id => $invoiceId,			
			item_name => 'Invoice/TWCC73/13',
			value_type => defined $dateValueType ? $dateValueType : undef,			
			value_int => $returnToWork || undef,
			value_date => $valueDate13 || undef,
			value_dateA => $valueDateA13 || undef,
			value_dateB => $valueDateB13 || undef,
			_debug => 0
	);


	#14
	my $standingHours = $page->field('standing_hours');
	my $otherStandingHours = $page->field('standing_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field14a_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/14a',
			value_type => defined $textValueType ? $textValueType : undef,
			value_int => defined $standingHours ? $standingHours : undef,
			value_intB => defined $otherStandingHours ? $otherStandingHours : undef,
			_debug => 0
	);

	my $sittingHours = $page->field('sitting_hours');
	my $otherSittingHours = $page->field('sitting_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field14b_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/14b',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $sittingHours ? $sittingHours : undef,
			value_intB => defined $otherSittingHours ? $otherSittingHours : undef,
			_debug => 0
	);

	my $kneelingHours = $page->field('kneeling_hours');
	my $otherKneelingHours = $page->field('kneeling_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field14c_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/14c',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $kneelingHours ? $kneelingHours : undef,
			value_intB => defined $otherKneelingHours ? $otherKneelingHours : undef,
			_debug => 0
	);

	my $bendingHours = $page->field('bending_hours');
	my $otherBendingHours = $page->field('bending_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field14d_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/14d',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $bendingHours ? $bendingHours : undef,
			value_intB => defined $otherBendingHours ? $otherBendingHours : undef,
			_debug => 0
	);

	my $pushingHours = $page->field('pushing_hours');
	my $otherPushingHours = $page->field('pushing_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field14e_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/14e',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $pushingHours ? $pushingHours : undef,
			value_intB => defined $otherPushingHours ? $otherPushingHours : undef,
			_debug => 0
	);

	my $twistingHours = $page->field('twisting_hours');
	my $otherTwistingHours = $page->field('twisting_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field14f_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/14f',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $twistingHours ? $twistingHours : undef,
			value_intB => defined $otherTwistingHours ? $otherTwistingHours : undef,
			_debug => 0
	);

	my $postureHours = $page->field('other_posture_hours');
	my $otherPostureHours = $page->field('other_posture_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field14g_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/14g',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('other_posture') || undef,
			value_int => defined $postureHours ? $postureHours : undef,
			value_intB => defined $otherPostureHours ? $otherPostureHours : undef,
			_debug => 0
	);


	#15
	my @specificRestrictions = $page->field('specific_restrictions');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field15_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/15',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => join(',', @specificRestrictions) || undef,
			value_textB => $page->field('other_specific_restriction') || undef,
			_debug => 0
	);


	#16
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field16_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/16',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('other_restrictions_notes') || undef,
			_debug => 0
	);


	#17
	my $walkingHours = $page->field('walking_hours');
	my $otherWalkingHours = $page->field('walking_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17a_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/17a',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $walkingHours ? $walkingHours : undef,
			value_intB => defined $otherWalkingHours ? $otherWalkingHours : undef,
			_debug => 0
	);

	my $climbingHours = $page->field('climbing_hours');
	my $otherClimbingHours = $page->field('climbing_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17b_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/17b',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $climbingHours ? $climbingHours : undef,
			value_intB => defined $otherClimbingHours ? $otherClimbingHours : undef,
			_debug => 0
	);

	my $graspingHours = $page->field('grasping_hours');
	my $otherGraspingHours = $page->field('grasping_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17c_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/17c',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $graspingHours ? $graspingHours : undef,
			value_intB => defined $otherGraspingHours ? $otherGraspingHours : undef,
			_debug => 0
	);

	my $wristHours = $page->field('wrist_hours');
	my $otherWristHours = $page->field('wrist_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17d_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/17d',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $wristHours ? $wristHours : undef,
			value_intB => defined $otherWristHours ? $otherWristHours : undef,
			_debug => 0
	);

	my $reachingHours = $page->field('reaching_hours');
	my $otherReachingHours = $page->field('reaching_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17e_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/17e',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $reachingHours ? $reachingHours : undef,
			value_intB => defined $otherReachingHours ? $otherReachingHours : undef,
			_debug => 0
	);

	my $overheadReachingHours = $page->field('overhead_reaching_hours');
	my $otherOverheadReachingHours = $page->field('overhead_reaching_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17f_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/17f',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $overheadReachingHours ? $overheadReachingHours : undef,
			value_intB => defined $otherOverheadReachingHours ? $otherOverheadReachingHours : undef,
			_debug => 0
	);

	my $keyboardingHours = $page->field('keyboarding_hours');
	my $otherKeyboardingHours = $page->field('keyboarding_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17g_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/17g',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $keyboardingHours ? $keyboardingHours : undef,
			value_intB => defined $otherKeyboardingHours ? $otherKeyboardingHours : undef,
			_debug => 0
	);

	my $motionHours = $page->field('other_motion_hours');
	my $otherMotionHours = $page->field('other_motion_other_hours');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17h_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/17h',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('other_motion') || undef,
			value_int => defined $motionHours ? $motionHours : undef,
			value_intB => defined $otherMotionHours ? $otherMotionHours : undef,
			_debug => 0
	);


	#18
	my $carryInstructions = $page->field('lift_carry_instructions');
	my $valueText18;
	my $valueTextB18;
	if($carryInstructions == 1)
	{
		$valueText18 = $page->field('carry_lbs');
		$valueTextB18 = $page->field('carry_hours');
	}
	elsif($carryInstructions == 3)
	{
		$valueText18 = $page->field('other_carry_restrictions');
	}

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field18_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/18',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $valueText18 || undef,
			value_textB => $valueTextB18 || undef,
			value_int => $carryInstructions || undef,
			_debug => 0
	);


	#19
	my $maxHrsWork = $page->field('max_hours_of_work');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19a_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19a',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $maxHrsWork ? $maxHrsWork : undef,
			_debug => 0
	);

	my $sitStretchNo = $page->field('num_of_sit_stretch_breaks');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19b_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19b',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('sit_stretch_breaks_per') || undef,
			value_int => defined $sitStretchNo ? $sitStretchNo : undef,
			_debug => 0
	);

	my $wearSplint = $page->field('wear_splint_cast');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19c_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19c',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $wearSplint ? $wearSplint : undef,
			_debug => 0
	);

	my $crutches = $page->field('crutches');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19d_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19d',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $crutches ? $crutches : undef,
			_debug => 0
	);

	my $noDriving = $page->field('no_driving');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19e_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19e',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $noDriving ? $noDriving : undef,
			_debug => 0
	);

	my $autoTransOnly = $page->field('auto_transmission_only');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19f_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19f',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $autoTransOnly ? $autoTransOnly : undef,
			_debug => 0
	);

	my $workLimitations = $page->field('work_limitations');
	my $valueText19 = $page->field('work_temp_environment') if $workLimitations;
	my $valueTextB19 = $page->field('work_height_environment') if $workLimitations;
	my $valueIntB19;
	if($workLimitations == 2)
	{
		$valueIntB19 = $page->field('work_hours_per_day');
	}

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19g_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19g',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $valueText19 || undef,
			value_textB => $valueTextB19 || undef,
			value_int => defined $workLimitations ? $workLimitations : undef,
			value_intB => defined $valueIntB19 ? $valueIntB19 : undef,
			_debug => 0
	);

	my $keepElevated = $page->field('elevated');
	my $keepCleanDry = $page->field('clean_dry');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19h_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19h',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('must_keep_text') || undef,
			value_int => defined $keepElevated ? $keepElevated : undef,
			value_intB => defined $keepCleanDry ? $keepCleanDry : undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19i_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19i',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('no_skin_contact_with') || undef,
			_debug => 0
	);

	my $dressing = $page->field('dress_changes');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19j_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19j',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $dressing ? $dressing : undef,
			_debug => 0
	);

	my $noRunning = $page->field('no_running');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19k_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/19k',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $noRunning ? $noRunning : undef,
			_debug => 0
	);


	#20
	my $prescriptMeds = $page->field('prescription_meds');
	my $otcMeds = $page->field('otc_meds');
	my $drowsyMeds = $page->field('drowsy_meds');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field20_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/20',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => defined $prescriptMeds ? $prescriptMeds : undef,
			value_textB => defined $otcMeds ? $otcMeds : undef,
			value_int => defined $drowsyMeds ? $drowsyMeds : undef,
			_debug => 0
	);


	#21
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field21_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/21',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('injury_diag_info') || undef,
			_debug => 0
	);


	#22
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field22a_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/22a',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('eval_time') ||  undef,
			value_date => $page->field('eval_date') ||  undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field22b_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/22b',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('ref_consult_with') ||  undef,
			value_textB => $page->field('ref_consult_time') ||  undef,
			value_date => $page->field('ref_consult_date') ||  undef,
			_debug => 0
	);

	my $valueInt22 = $page->field('phys_med_per_week');
	my $valueIntB22 = $page->field('phys_med_weeks');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field22c_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/22c',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $valueInt22 ? $valueInt22 : undef,
			value_intB => defined $valueIntB22 ? $valueIntB22 : undef,
			value_text => $page->field('phys_med_start_time') ||  undef,
			value_date => $page->field('phys_med_start_date') ||  undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field22d_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/22d',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('special_list') ||  undef,
			value_textB => $page->field('special_studies_time') ||  undef,
			value_date => $page->field('special_studies_date') ||  undef,
			_debug => 0
	);

	my $noFurtherCare = $page->field('no_services_anticipated');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field22e_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/22e',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $noFurtherCare ? $noFurtherCare : undef,
			_debug => 0
	);


	#23
	my $visitType = $page->field('visit_type');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field23_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/23',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $visitType ? $visitType : undef,
			_debug => 0
	);


	#24
	my $roleOfDoc = $page->field('doctor_role');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field24_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC73/24',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => defined $roleOfDoc ? $roleOfDoc : undef,
			_debug => 0
	);

	$page->redirect("/invoice/$invoiceId/summary");
}

1;
