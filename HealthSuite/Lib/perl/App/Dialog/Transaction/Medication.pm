##############################################################################
package App::Dialog::Transaction::Medication;
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

@ISA = qw(CGI::Dialog );

%RESOURCE_MAP = ( 'medication-prescribe' => { transType => App::Universal::TRANSTYPE_PRESCRIBEMEDICATION, 
						heading => '$Command Prescribe Medication',  
						_arl => ['person_id'], _arl_modify => ['trans_id'] , 
						_idSynonym => 'trans-' . App::Universal::TRANSTYPE_PRESCRIBEMEDICATION() },);
sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'medication');
	my $typeRange = '7010..7999';
	my $dateName = 'Start Date';
	my $prescribe = 0;
	my $heading = 'Current Medication';
	my $transType = $self->{transType};
	if ($transType eq 7000)
	{
		$prescribe = 1;
		$typeRange = '7000..7000';
		$dateName = 'Prescription Date';
	}

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	if ($typeRange eq '7010..7999')
	{
		$self->addContent(
			new CGI::Dialog::Field::TableColumn(caption => 'Medication Type',
				schema => $schema, column => 'Transaction.trans_type', typeRange => $typeRange));
	}
	$self->addContent(
		new CGI::Dialog::Field::TableColumn(caption => "$dateName",
			schema => $schema, column => 'Transaction.trans_begin_stamp', type => 'date', futureOnly => 0),
		);
	$prescribe ? $self->addContent(
		new App::Dialog::Field::Person::ID(caption => 'Physician',
			name => 'provider_id', types => ['Physician'],options => FLDFLAG_REQUIRED)
		) : undef;
	$self->addContent(
		new CGI::Dialog::Field::TableColumn(caption => 'Name of Medication',
			schema => $schema, column => 'Transaction.caption',options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field::TableColumn(caption => 'Dosage',
			schema => $schema, column => 'Transaction.data_text_a')
		);
	$prescribe ? $self->addContent(
		new CGI::Dialog::Field::TableColumn(caption => 'Quantity',
			schema => $schema, column => 'Transaction.quantity', type => 'integer'),
		new CGI::Dialog::Field::TableColumn(caption => 'Number of Refills',
			schema => $schema, column => 'Transaction.data_num_a', type => 'integer'),
		new CGI::Dialog::Field::TableColumn(caption => 'Brand Name',
			schema => $schema, column => 'Transaction.data_flag_b', type => 'bool', style => 'check')
		) : undef;
	$self->addContent(
		new CGI::Dialog::Field::TableColumn(caption => 'Instructions',
			schema => $schema, column => 'Transaction.detail', type => 'memo'),
		new CGI::Dialog::Field::TableColumn(caption => 'Notes',
			schema => $schema, column => 'Transaction.data_text_b', type => 'memo')
		);
	$prescribe ? $self->addContent(
		new CGI::Dialog::Field::TableColumn(caption => 'Print Prescription',
			schema => $schema, column => 'Transaction.data_flag_c', type => 'bool', style => 'check')
		) : undef;
	$self->{activityLog} =
	{
		level => 1,
		scope =>'transaction',
		key => "#param.person_id#",
		data => "$heading to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $transId = $page->param('trans_id');

	$STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	my $transId = $transaction->{trans_id} || $page->param('trans_id');

	my $transStatus = $command eq 'remove' ? App::Universal::TRANSSTATUS_INACTIVE : App::Universal::TRANSSTATUS_ACTIVE;

	#WE DON'T WANT TO DELETE ANY TRANS RECORDS SO WE SET TRANS_STATUS TO 3 (INACTIVE) WHEN THE COMMAND IS 'REMOVE'
	#$command = $command eq 'remove' ? 'update' : $command;

	#$page->addDebugStmt($command, $transStatus);
	my $transType =  $page->field('trans_type') ? $page->field('trans_type') : App::Universal::TRANSTYPE_PRESCRIBEMEDICATION;
	$page->schemaAction(
		'Transaction',
		$command,
		trans_owner_type => 0,
		trans_owner_id => $page->param('person_id'),
		trans_id => $transId || undef,
		trans_type => $transType || undef,
		trans_status => $transStatus,
		trans_begin_stamp => $page->field('trans_begin_stamp') || undef,
		provider_id => $page->field('provider_id') || undef,
		caption => $page->field('caption') || undef,
		data_text_a => $page->field('data_text_a') || undef,
		quantity => $page->field('quantity') || undef,
		data_num_a => $page->field('data_num_a') || undef,
		data_flag_b => $page->field('data_flag_b') || undef,
		detail => $page->field('detail') || undef,
		data_text_b => $page->field('data_text_b') || undef,
		data_flag_c => $page->field('data_flag_c') || undef,
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);

	return "\u$command completed.";
}

1;
