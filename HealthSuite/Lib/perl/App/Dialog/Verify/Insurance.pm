##############################################################################
package App::Dialog::Verify::Insurance;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use DBI::StatementManager;
use App::Statements::Component::Scheduling;

use base 'CGI::Dialog';

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'insurance-records' => { 
			_arl => ['event_id', 'person_id'],
			_modes => ['verify'],
		},
);

use constant TEXTINPUTSIZE => 40;

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'template', heading => 'Verify Insurance');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'event_id'),
		new App::Dialog::Field::Person::ID(caption => 'Patient ID',
			name => 'person_id',
			size => 25,
			options => FLDFLAG_READONLY,
		),
		new App::Dialog::Field::Scheduling::Date(caption => 'Effective Date',
			name => 'effective_begin_date',
			type => 'date',
			futureOnly => 0,
			defaultValue => '',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::MultiField (
			fields => [
				new CGI::Dialog::Field::TableColumn(
					caption => 'Deductible',
					schema => $schema,
					column => 'Sch_Verify.deductible',
				),
				new CGI::Dialog::Field::TableColumn(
					caption => 'Met To-Date',
					schema => $schema,
					column => 'Sch_Verify.deductible_met',
				),
			],
		),
		new CGI::Dialog::Field(caption => 'Referral Required',
			name => 'referral_required',
			type => 'bool', style => 'check', 
		),
		
				new CGI::Dialog::Field::TableColumn(
					caption => 'Office Visit Copay',
					schema => $schema,
					column => 'Sch_Verify.ovcopay',
				),

				new CGI::Dialog::Field::TableColumn(
					caption => 'Lab/X-Ray Copay',
					schema => $schema,
					column => 'Sch_Verify.labcopay',
				),
		
		new CGI::Dialog::Field(caption => 'Separate Co-pay for Lab/X-Ray',
			name => 'sep_copay_xray',
			type => 'bool', style => 'check', 
		),

		new CGI::Dialog::Field(caption => 'Lab',
			name => 'lab',
			size => TEXTINPUTSIZE,
		),
		new App::Dialog::Field::Person::ID(caption => 'PCP ID',
			name => 'provider_id',
			types => ['Physician', 'Referring-Doctor'],
			size => 25,
		),
		new CGI::Dialog::Field::(caption => 'Coverage Required',
			name => 'coverage_req',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field(caption => 'Coverage On the Following',
			name => 'coverage_on',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field(caption => 'Referral or Pre-Cert on Out Patient',
			name => 'referral_or_precert',
			type => 'bool', style => 'check', 
		),
		new CGI::Dialog::Field::(caption => 'Pre-Cert Phone',
			name => 'precert_phone',
			type => 'phone',
			size => 20,
		),
		new CGI::Dialog::Field::(caption => 'Annual Physical Exam / WW',
			name => 'annual_pe_ww',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'GYN Exam',
			name => 'gyn_exam',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Thin Prep Pap Test (88142)',
			name => 'thin_prep_pap',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Depo Inj for Contraception',
			name => 'depo_inj',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'IUD',
			name => 'iud',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Tubal Ligament',
			name => 'tubal_lig',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Surgery',
			name => 'surgery',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Flex-Sigmoidoscopy',
			name => 'flex_sig',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Output XRays/Procs',
			name => 'output_xray',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Mammograms',
			name => 'mammogram',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Amniocenteses',
			name => 'amniocenteses',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Pelvic Ultrasound',
			name => 'pelvic_ultrasound',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Fertility Testing',
			name => 'fertility_test',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Circumcisions',
			name => 'circumcision',
			size => TEXTINPUTSIZE,
		),
		new CGI::Dialog::Field::(caption => 'Ins Rep Name',
			name => 'ins_rep_name',
			size => TEXTINPUTSIZE,
		),
		#new CGI::Dialog::Field::(caption => 'Verified By',
		#	name => 'verified_by',
		#	size => TEXTINPUTSIZE,
		#	options => FLDFLAG_READONLY,
		#),
		
		new App::Dialog::Field::Person::ID(caption => 'Verified By',
			name => 'ins_verified_by',
			types => ['Staff', 'Physician'],
			size => 20,
			useShortForm => 1,
			options => FLDFLAG_REQUIRED,
		),
		
		new App::Dialog::Field::Scheduling::Date(caption => 'Verify Date',
			name => 'ins_verify_date',
			type => 'date',
			futureOnly => 0,
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(caption => 'Verification',
			name => 'verification',
			choiceDelim =>',',
			selOptions => "Complete:2, Partial:1",
			type => 'select',
			style => 'radio',
			options => FLDFLAG_REQUIRED,
		),
		
	);

	$self->addFooter(new CGI::Dialog::Buttons());
	
	$self->{activityLog} =
	{
		scope =>'event',
		key => "#field.person_id#",
		data => "insurance 'Event #field.event_id#' <a href='/person/#field.person_id#/profile'>#field.person_id#</a>"
	};
	
	return $self;
}

###############################
# getSupplementaryHtml
###############################

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	if(my $personId = $page->field('person_id'))
	{
		return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
			#component.stpt-person.contactMethodsAndAddresses#<BR>
			#component.stpt-person.insurance#<BR>
			#component.stpt-person.accountPanel#<BR>
			#component.stpt-person.careProviders#<BR>
		});
	}
	return $self->SUPER::getSupplementaryHtml($page, $command);
}

###############################
# makeStateChanges functions
###############################

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
}

###############################
# populateData functions
###############################

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	
	my $eventId = $page->param('event_id');
	
	$page->field('event_id', $eventId);
	$page->field('person_id', $page->param('person_id'));
	$page->field('ins_verified_by', $page->session('user_id'));
	
	$page->param('_verified_', $STMTMGR_COMPONENT_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE,
		'sel_populateInsVerifyDialog', $eventId));
	
	unless ($page->param('_verified_'))
	{
		$STMTMGR_COMPONENT_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE,
			'sel_MostRecentVerify', $page->param('person_id'));
		$page->field('event_id', $eventId);
	}
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $eventId = $page->field('event_id');
	
 	$page->schemaAction(
		'Sch_Verify', $page->param('_verified_') ? 'update' : 'add',
		event_id => $eventId,
		person_id => $page->field('person_id') || undef,
		effective_begin_date => $page->field('effective_begin_date') || undef,
		deductible => $page->field('deductible') || undef,
		deductible_met => $page->field('deductible_met') || undef,
		ovcopay => $page->field('ovcopay') || undef,
		labcopay => $page->field('labcopay') || undef,
		referral_required => $page->field('referral_required') || undef,
		sep_copay_xray => $page->field('sep_copay_xray') || undef,
		lab => $page->field('lab') || undef,
		provider_id => $page->field('provider_id') || undef,
		coverage_req => $page->field('coverage_req') || undef,
		coverage_on => $page->field('coverage_on') || undef,
		referral_or_precert => $page->field('referral_or_precert') || undef,
		precert_phone => $page->field('precert_phone') || undef,
		annual_pe_ww => $page->field('annual_pe_ww') || undef,
		gyn_exam => $page->field('gyn_exam') || undef,
		thin_prep_pap => $page->field('thin_prep_pap') || undef,
		depo_inj => $page->field('depo_inj') || undef,
		iud => $page->field('iud') || undef,
		tubal_lig => $page->field('tubal_lig') || undef,
		surgery => $page->field('surgery') || undef,
		flex_sig => $page->field('flex_sig') || undef,
		output_xray => $page->field('output_xray') || undef,
		mammogram => $page->field('mammogram') || undef,
		amniocenteses => $page->field('amniocenteses') || undef,
		pelvic_ultrasound => $page->field('pelvic_ultrasound') || undef,
		fertility_test => $page->field('fertility_test') || undef,
		circumcision => $page->field('circumcision') || undef,
		ins_rep_name => $page->field('ins_rep_name') || undef,
		ins_verified_by => $page->field('ins_verified_by'),
		ins_verify_date => $page->field('ins_verify_date'),
		owner_org_id => $page->session('org_internal_id'),
	);
	
	my $eventAttribute = $STMTMGR_COMPONENT_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_EventAttribute', $eventId, App::Universal::EVENTATTRTYPE_APPOINTMENT);

	my $itemId = $eventAttribute->{item_id};
	my $verifyFlags = $eventAttribute->{value_intb};
	
	$verifyFlags &= ~App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_COMPLETE;
	$verifyFlags &= ~App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_PARTIAL;
	
	$verifyFlags |= $page->field('verification') == 2 ? 
		App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_COMPLETE :
		App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_PARTIAL;
		
	$page->schemaAction(
		'Event_Attribute', 'update',
		item_id => $itemId,
		value_intB => $verifyFlags,
	);
	
	$self->handlePostExecute($page, $command, $flags);
}

1;