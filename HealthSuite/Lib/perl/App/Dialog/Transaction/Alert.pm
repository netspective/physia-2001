##############################################################################
package App::Dialog::Transaction::Alert;
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

%RESOURCE_MAP =( 'alert-person' => { transType => App::Universal::TRANSTYPE_ALERTORG, heading => '$Command Alert',  
				    _arl => ['person_id'], _arl_modify => ['trans_id'] ,
				    _idSynonym => [
						'trans-' .App::Universal::TRANSTYPE_ALERTORG(),
						'trans-' .App::Universal::TRANSTYPE_ALERTORGFACILITY(),
						'trans-' .App::Universal::TRANSTYPE_ALERTPATIENT(),
						'trans-' .App::Universal::TRANSTYPE_ALERTINSURANCE(),
						'trans-' .App::Universal::TRANSTYPE_ALERTMEDICATION(),
						'trans-' .App::Universal::ATTRTYPE_STUDENTPART(),
						'trans-' .App::Universal::TRANSTYPE_ALERTACTION()
						] 
				    },);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'alert', heading => '$Command Alert');


	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field::TableColumn(
				caption => 'Type',
				schema => $schema,
				column => 'Transaction.trans_type', typeRange => '8000..8999'),

			new CGI::Dialog::Field(lookup => 'Alert_Priority', caption => 'Priority', name => 'trans_subtype', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(caption => 'Caption', name => 'caption', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(type => 'memo', caption => 'Details', name => 'detail', options => FLDFLAG_REQUIRED),

			new App::Dialog::Field::Person::ID(caption => 'Staff Member', name => 'initiator_id', types => ['Physician', 'Staff', 'Nurse'], readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			new CGI::Dialog::Field(type => 'date', caption => 'Begin Alert', name => 'trans_begin_stamp', options => FLDFLAG_REQUIRED, futureOnly => 0),
			new CGI::Dialog::Field(type => 'date', caption => 'End Alert', name => 'trans_end_stamp')
		);
		$self->{activityLog} =
		{
			level => 2,
			scope =>'transaction',
			key => "#param.person_id#",
			data => "Alert '#field.trans_subtype#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
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

	my $transaction = $self->{transaction};
	my $transId = $transaction->{trans_id} || $page->param('trans_id');

	my $transStatus = $command eq 'remove' ? App::Universal::TRANSSTATUS_INACTIVE : App::Universal::TRANSSTATUS_ACTIVE;
	# don't actually delete any trans records
	$command = $command eq 'remove' ? 'update' : $command;

	my $entityId = $page->param('person_id') ? $page->param('person_id') : $page->param('org_id');
	my $entityType = $page->param('person_id') ? '0' : '1';

	$page->schemaAction(
		'Transaction', $command,
		trans_owner_type => $entityType,
		trans_owner_id => $entityId || undef,
		trans_id => $transId || undef,
		trans_type => $page->field('trans_type') || undef,
		trans_subtype => $page->field('trans_subtype') || undef,
		caption => $page->field('caption') || undef,
		detail => $page->field('detail') || undef,
		trans_status => $transStatus || undef,
		initiator_id => $page->field('initiator_id') || 0,
		trans_begin_stamp => $page->field('trans_begin_stamp') || undef,
		trans_end_stamp => $page->field('trans_end_stamp') || undef
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}


1;