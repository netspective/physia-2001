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
		new CGI::Dialog::Field(name => 'trans_begin_stamp', caption => 'Date Of Admission', type => 'date', options => FLDFLAG_REQUIRED,defaultValue => '', futureOnly => 0),
		new CGI::Dialog::Field(name => 'related_data', caption => 'Hospital Name',options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'caption', caption => 'Room Number'),
		new CGI::Dialog::Field(name => 'trans_status_reason', caption => 'Reason For Admission', options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::Person::ID(caption => 'Physician', name => 'provider_id', types => ['Physician'], options => FLDFLAG_REQUIRED, incSimpleName=>1),
		new CGI::Dialog::Field(name => 'data_text_a',type => 'select', selOptions => 'In;Out', caption => 'In/Out Patient', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'memo', name => 'detail', caption => 'Orders', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'data_text_c', caption => 'Procedures'),
		new App::Dialog::Field::Person::ID(caption => 'Consulting Physician', name => 'consult_id', types => ['Physician'], incSimpleName=>1),
		new CGI::Dialog::Field(type => 'memo', name => 'trans_substatus_reason', caption => 'Findings'),
		new CGI::Dialog::Field(caption => 'Duration of Stay', name => 'data_num_a', size => 4, options => FLDFLAG_REQUIRED, defaultValue => '1', type => 'integer', maxLength => 4),
	);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'transaction',
		key => "#param.person_id#",
		data => "Hospitalization to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
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
	my $transaction = $self->{transaction};
	my $transId = $page->param('_trne_trans_id') || $page->param('trans_id');
	my $personId = $page->param('person_id');
	my $transStatus = $command eq 'remove' ? App::Universal::TRANSSTATUS_INACTIVE : App::Universal::TRANSSTATUS_ACTIVE;
		# don't actually delete any trans records
	$command = $command eq 'remove' ? 'update' : $command;

	my $transOwnerType = App::Universal::ENTITYTYPE_PERSON;

	$page->schemaAction(
			'Transaction',
			$command,
			trans_owner_type => defined $transOwnerType ? $transOwnerType : undef,
			trans_owner_id => $page->param('person_id'),
			trans_id => $transId || undef,
			trans_type => $page->field('trans_type') || undef,
			trans_status => $transStatus,
			trans_begin_stamp => $page->field('trans_begin_stamp') || undef,
			related_data => $page->field('related_data') || undef,
			trans_status_reason => $page->field('trans_status_reason') || undef,
			provider_id => $page->field('provider_id') || undef,
			data_text_a => $page->field('data_text_a') || undef,
			data_num_a => $page->field('data_num_a') || undef,
			data_text_c => $page->field('data_text_c') || undef,
			consult_id => $page->field('consult_id') || undef,
			trans_substatus_reason => $page->field('trans_substatus_reason') || undef,
			detail => $page->field('detail') || undef,
			caption => $page->field('caption') || undef,
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}


1;