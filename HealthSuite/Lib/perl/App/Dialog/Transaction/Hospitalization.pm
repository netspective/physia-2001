##############################################################################
package App::Dialog::Transaction::Hospitalization;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;
use App::Statements::Transaction;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = ( 'hospitalization' => { transType => [App::Universal::TRANSTYPE_ADMISSION, App::Universal::TRANSTYPE_SURGERY,App::Universal::TRANSTYPE_THERAPY ], heading => '$Command Hospitalization',  _arl => ['person_id'], _arl_modify => ['trans_id'],
					_idSynonym => [
				'trans-' . App::Universal::TRANSTYPE_ADMISSION(),
				'trans-' . App::Universal::TRANSTYPE_SURGERY(),
				'trans-' . App::Universal::TRANSTYPE_THERAPY()
				]
		   },);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'hospitalization', heading => '$Command Hospitalization');


	my $schema = $self->{schema};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
		new CGI::Dialog::Field::TableColumn(
			caption => 'Type',schema => $schema,
			column => 'Transaction.trans_type', typeRange => '11000..11999'),
		new CGI::Dialog::MultiField(caption =>'Admission/Discharge Dates', name => 'hosp_dates',
			fields => [
				new CGI::Dialog::Field(caption => 'Admission Date', name => 'trans_begin_stamp', type => 'date', options => FLDFLAG_REQUIRED, defaultValue => '', futureOnly => 0),
				new CGI::Dialog::Field(caption => 'Discharge Date', name => 'trans_end_stamp', type => 'date', defaultValue => '', futureOnly => 1)
			]),
		new App::Dialog::Field::OrgType(caption => 'Hospital', name => 'service_facility_id', types => "'HOSPITAL'"),
		new App::Dialog::Field::Person::ID(name => 'patient_id', caption => 'Patient ID', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'caption', caption => 'Room Number'),
		new App::Dialog::Field::Person::ID(caption => 'Physician', name => 'provider_id', types => ['Physician'], incSimpleName=>1),
		new CGI::Dialog::Field(name => 'data_text_a',type => 'select', selOptions => 'In;Out', caption => 'In/Out Patient'),
		new CGI::Dialog::Field(caption => 'Procedures', name => 'data_text_c', hints => 'Enter CPT codes in a comma separated list', findPopup => '/lookup/cpt', findPopupAppendValue => ', ', options => FLDFLAG_TRIM),
		new CGI::Dialog::Field(caption => 'ICD-9 Codes', name => 'detail', hints => 'Enter ICD-9 codes in a comma separated list', findPopup => '/lookup/icd', findPopupAppendValue => ', ', options => FLDFLAG_TRIM),
		new CGI::Dialog::Field(name => 'auth_ref', caption => 'Prior Authorization'),
		new App::Dialog::Field::Person::ID(caption => 'Consulting Physician', name => 'consult_id', types => ['Physician'], incSimpleName=>1),
		new App::Dialog::Field::Person::ID(caption => 'Referring Physician ID', name => 'data_text_b', types => ['Referring-Doctor'], incSimpleName=>1),
		new CGI::Dialog::Field(caption => 'Duration of Stay', name => 'data_num_a', size => 4, type => 'integer', maxLength => 4),


		#removed on 12/14/00 according karen's doc
		#new CGI::Dialog::Field(name => 'trans_status_reason', caption => 'Reason For Admission', options => FLDFLAG_REQUIRED),
		#new CGI::Dialog::Field(type => 'memo', name => 'detail', caption => 'Orders', options => FLDFLAG_REQUIRED),
		#new CGI::Dialog::Field(type => 'memo', name => 'trans_substatus_reason', caption => 'Findings'),
	);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'transaction',
		key => "#param.person_id#",
		data => "Hospitalization to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(
		new CGI::Dialog::Buttons(
			nextActions_add => [
				['Return to Previous Screen', '', 1],
				['Create Claim for this Entry', "/person/%param.person_id%/dlg-add-claim?isHosp=1&hospId=%param.trans_id%"],
				],
			cancelUrl => $self->{cancelUrl} || undef,
			),
		);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $returnUrl = $page->referer();
	unless($returnUrl =~ /home$/)
	{
		$self->setFieldFlags('patient_id', FLDFLAG_INVISIBLE, 1);
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $transId = $page->param('trans_id');

	$STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $transOwnerType = App::Universal::ENTITYTYPE_PERSON;
	my $editTransId = $page->param('_trne_trans_id') || $page->param('trans_id');
	my $personId = $page->field('patient_id') || $page->param('person_id');
	my $transStatus = $command eq 'remove' ? App::Universal::TRANSSTATUS_INACTIVE : App::Universal::TRANSSTATUS_ACTIVE;

	my $transCommand = $command eq 'remove' ? 'update' : $command; 	# don't actually delete any trans records
	my $transId = $page->schemaAction('Transaction', $transCommand,
			trans_id => $editTransId || undef,
			trans_owner_type => defined $transOwnerType ? $transOwnerType : undef,
			trans_owner_id => $personId,
			trans_type => $page->field('trans_type') || undef,
			trans_status => $transStatus,
			trans_begin_stamp => $page->field('trans_begin_stamp') || undef,
			trans_end_stamp => $page->field('trans_end_stamp') || undef,
			service_facility_id => $page->field('service_facility_id') || undef,
			provider_id => $page->field('provider_id') || undef,
			consult_id => $page->field('consult_id') || undef,
			caption => $page->field('caption') || undef,
			detail => $page->field('detail') || undef,
			auth_ref => $page->field('auth_ref') || undef,
			data_text_a => $page->field('data_text_a') || undef,
			data_text_b => $page->field('data_text_b') || undef,
			data_text_c => $page->field('data_text_c') || undef,
			data_num_a => $page->field('data_num_a') || undef,
	);

	if($command eq 'add')
	{
		$page->param('trans_id', $transId);
		$self->handlePostExecute($page, $command, $flags);
	}
	else
	{
		$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	}

	return "\u$command completed.";
}


1;