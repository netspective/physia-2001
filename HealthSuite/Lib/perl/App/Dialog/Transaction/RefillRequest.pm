##############################################################################
package App::Dialog::Transaction::RefillRequest;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Transaction;
use App::Universal;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'refill-request' => {
		transType => App::Universal::TRANSTYPE_PRESCRIBEMEDICATION,
		heading => '$Command Refill Request',
		_arl => ['person_id'] ,
		_arl_modify => ['trans_id'],
		_idSynonym => 'trans-refill-' .App::Universal::TRANSTYPE_PRESCRIBEMEDICATION()
		},
	);
sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'refillrequest', heading => '$Command Refill Request');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(name => 'refill', caption => 'Refill', type => 'memo', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'refilldate', caption => 'Date', type => 'date'),
		new App::Dialog::Field::Person::ID(name => 'provider', caption => 'Physician', types => ['Physician'], options => FLDFLAG_REQUIRED, hints => 'Physician approving the refill.'),
		new App::Dialog::Field::Person::ID(name => 'filler', caption => 'Refill Processor', options => FLDFLAG_REQUIRED, hints => 'Person processing the refill.'),
		new CGI::Dialog::Field(name => 'comments', caption => 'Comments', type => 'memo'),
		new CGI::Dialog::Field(type => 'select',
				style => 'radio',
				selOptions => 'Pending;Filled;Denied',
				caption => 'Status',
				preHtml => "<B><FONT COLOR=DARKRED>",
				postHtml => "</FONT></B>",
				name => 'status',
				defaultValue => 'Pending'),
		);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'transaction',
		key => "#param.person_id#",
		data => "Refill Request for <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{

	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $refillStatus = '';
	my $transId = $page->param('trans_id');
	my $refillInfo = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);

	if($refillInfo->{trans_status}  == App::Universal::TRANSSTATUS_PENDING)
	{
		$refillStatus = 'Pending';
	}
	elsif ($refillInfo->{trans_status}  == App::Universal::TRANSSTATUS_FILLED)
	{
		$refillStatus = 'Filled';
	}
	elsif ($refillInfo->{trans_status}  == App::Universal::TRANSSTATUS_DENIED)
	{
		$refillStatus = 'Denied';
	}

        if($refillInfo->{data_num_a} eq '')
        {

		$page->field('filler', $refillInfo->{processor_id});
		$page->field('refilldate', $refillInfo->{trans_begin_stamp});
		$page->field('provider', $refillInfo->{provider_id});
		$page->field('refill', $refillInfo->{data_text_a});
		$page->field('comments', $refillInfo->{display_summary});
		$page->field('status', $refillStatus);
	}
	elsif($refillInfo->{data_num_a} ne '')
        {

                $page->field('filler', $refillInfo->{trans_owner_id});
                $page->field('refilldate', $refillInfo->{trans_begin_stamp});
                $page->field('provider', $refillInfo->{provider_id});
                $page->field('refill', $refillInfo->{data_text_a});
                $page->field('comments', $refillInfo->{display_summary});
                $page->field('status', $refillStatus);
        }

}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	my $refillStatus = '';
	my $status = $page->field('status');
	if($status eq 'Pending')
	{
		$refillStatus = App::Universal::TRANSSTATUS_PENDING;
	}
	elsif($status eq 'Filled')
	{
		$refillStatus = App::Universal::TRANSSTATUS_FILLED;
	}
	elsif($status eq 'Denied')
	{
		$refillStatus = App::Universal::TRANSSTATUS_DENIED;
	}

	if($command eq 'add')
	{
        	my $trans_id = $page->schemaAction(
                        'Transaction', $command,
                        trans_id => $page->param('trans_id') || undef,
                        trans_owner_id => $page->param('person_id') || undef,
                        trans_owner_type => 0,
                        processor_id => $page->field('filler')  || undef,
                        processor_type => 0,
			receiver_id => $page->param('person_id') || undef,
			receiver_type => 0,
                        provider_id => $page->field('provider') || undef,
                        caption =>'Refill Request',
                        trans_type => 7000,
                        trans_status => $refillStatus,
                        trans_begin_stamp => $page->field('refilldate'),
                        data_text_a => $page->field('refill') || undef,
                        display_summary => $page->field('comments') || undef,
                        _debug => 0
                );

		$page->schemaAction(
                        'Transaction', $command,
                        trans_id => $page->param('trans_id') || undef,
                        trans_owner_id => $page->field('filler') || undef,
                        trans_owner_type => 0,
                        processor_id => $page->field('filler')  || undef,
                        processor_type => 0,
			receiver_id => $page->param('person_id') || undef,
			receiver_type => 0,
                        provider_id => $page->field('provider') || undef,
                        caption =>'Refill Request',
                        trans_type => 7000,
                        trans_status => $refillStatus,
                        trans_begin_stamp => $page->field('refilldate'),
                        data_text_a => $page->field('refill') || undef,
                        display_summary => $page->field('comments') || undef,
			data_num_a => $trans_id,
                        _debug => 0
                );

	}
	elsif($command eq 'update' || $command eq 'remove')
	{

                my $transId = $page->param('trans_id');
                my $refillDataInfo = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);
                if($refillDataInfo->{data_num_a} eq '')
                {
	                $page->schemaAction(
       			     	'Transaction', $command,
                        	trans_id => $page->param('trans_id') || undef,
                        	trans_owner_id => $page->param('person_id') || undef,
                        	provider_id => $page->field('provider') || undef,
                        	trans_status => $refillStatus,
                        	trans_begin_stamp => $page->field('refilldate'),
                        	data_text_a => $page->field('refill') || undef,
                        	data_text_b => $page->field('filler')  || undef,
                        	display_summary => $page->field('comments') || undef,
                        	_debug => 0
               		);
                        my $fillerData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionByData_num_a', $transId);
	                $page->schemaAction(
       		                'Transaction', $command,
               		        trans_id => $fillerData->{trans_id}|| undef,
                       		trans_owner_id => $page->field('filler') || undef,
                        	provider_id => $page->field('provider') || undef,
                        	trans_status => $refillStatus,
                        	trans_begin_stamp => $page->field('refilldate'),
                        	data_text_a => $page->field('refill') || undef,
                        	data_text_b => $page->param('person_id')  || undef,
                        	display_summary => $page->field('comments') || undef,
                        	_debug => 0
                	);

                }
                elsif($refillDataInfo->{data_num_a} ne '')
                {
                        $page->schemaAction(
                                'Transaction', $command,
                                trans_id => $page->param('trans_id') || undef,
                                provider_id => $page->field('provider') || undef,
                                trans_owner_id => $page->field('filler') || undef,
                                trans_status => $refillStatus,
                                trans_begin_stamp => $page->field('refilldate'),
                                data_text_a => $page->field('refill') || undef,
                                display_summary => $page->field('comments') || undef,
                                _debug => 0
                        );
                        my $parentItemId = $refillDataInfo->{data_num_a};
                        my $personData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionById', $parentItemId);


                        $page->schemaAction(
                                'Transaction', $command,
                                trans_id => $personData->{trans_id} || undef,
                                provider_id => $page->field('provider') || undef,
                                trans_status => $refillStatus,
                                trans_begin_stamp => $page->field('refilldate'),
                                data_text_a => $page->field('refill') || undef,
                                data_text_b => $page->param('person_id')  || undef,
                                display_summary => $page->field('comments') || undef,
                                _debug => 0
                        );


                }

	}


	$self->handlePostExecute($page, $command, $flags);
}

1;
