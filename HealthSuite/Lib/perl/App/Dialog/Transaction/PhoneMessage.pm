##############################################################################
package App::Dialog::Transaction::PhoneMessage;
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

%RESOURCE_MAP = ( 'phone-message' => { transType => App::Universal::TRANSTYPE_PC_TELEPHONE,
					heading => '$Command Phone Message',
					_arl => ['person_id'] ,
					_arl_modify => ['trans_id'],
					_idSynonym => 'trans-' .App::Universal::TRANSTYPE_PC_TELEPHONE() },);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'phonemessage', heading => '$Command Phone Message');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Person::ID(name => 'person_called', caption =>'Call From', options => FLDFLAG_REQUIRED, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new App::Dialog::Field::Person::ID(name => 'provider', caption =>'Call For', options => FLDFLAG_REQUIRED, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(name => 'datecalled', caption => 'Date', type => 'date'),
		new CGI::Dialog::Field(name => 'phonemessage', caption => 'Phone Message', type => 'memo', options => FLDFLAG_REQUIRED, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(name => 'responsemessage', caption => 'Comments', type => 'memo',  readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(type => 'select',
				style => 'radio',
				selOptions => 'Not Read;Read',
				caption => 'Status',
				preHtml => "<B><FONT COLOR=DARKRED>",
				postHtml => "</FONT></B>",
				name => 'status',
				hints => 'Clicking on Read would make this message disappear from your voice message list.',
				defaultValue => 'Not Read'),
		new CGI::Dialog::Field(type => 'bool', name => 'data_num_b', caption => 'Deliver With Medical Record',  readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, style => 'check'),

	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'transaction',
		key => "#param.person_id#",
		data => "Phone Message from <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	$self->setFieldFlags('datecalled', FLDFLAG_READONLY);
	$self->updateFieldFlags('status', FLDFLAG_INVISIBLE, 1) if $command eq 'add';

}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $phoneStatus = '';
	my $transId = $page->param('trans_id');
	my $phoneInfo = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);

	if($phoneInfo->{trans_status}  == 4)
	{
		$phoneStatus = 'Read';
	}

	elsif ($phoneInfo->{trans_status}  == 5)
	{
		$phoneStatus = 'Not Read';
	}

        if($phoneInfo->{data_num_a} eq '')
        {

		$page->field('phonemessage', $phoneInfo->{data_text_b});
		$page->field('datecalled', $phoneInfo->{trans_begin_stamp});
		$page->field('provider', $phoneInfo->{provider_id});
		$page->field('responsemessage', $phoneInfo->{data_text_a});
		$page->field('status', $phoneStatus);
		$page->field('data_num_b', $phoneInfo->{data_num_b});
		$page->field('person_called', $phoneInfo->{consult_id});
	}
	elsif($phoneInfo->{data_num_a} ne '')
        {

                $page->field('phonemessage', $phoneInfo->{data_text_a});
                $page->field('datecalled', $phoneInfo->{trans_begin_stamp});
                $page->field('provider', $phoneInfo->{trans_owner_id});
                $page->field('responsemessage', $phoneInfo->{data_text_b});
                $page->field('status', $phoneStatus);
		$page->field('data_num_b', $phoneInfo->{data_num_b});
		$page->field('person_called', $phoneInfo->{consult_id});

        }
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	$page->field('status', 'Not Read')if $command eq 'add';
	my $phoneStatus = $page->field('status') eq 'Not Read' ? 5 : 4;
	my $status =  $page->field('status', $phoneStatus);

        if($command eq 'add')
	{
        	my $trans_id = $page->schemaAction(
                        'Transaction', $command,
                        trans_id => $page->param('trans_id') || undef,
                        trans_owner_id => $page->param('person_id') || undef,
                        trans_owner_type => 0,
                        provider_id => $page->field('provider') || undef,
                        caption =>'Phone Message',
                        trans_type => 1000,
                        trans_status => $phoneStatus,
                        trans_begin_stamp => $page->field('datecalled'),
                        data_text_a => $page->field('responsemessage') || undef,
                        data_text_b => $page->field('phonemessage')  || undef,
                        data_num_b   => $page->field('data_num_b')  || undef,
                        consult_id  => $page->field('person_called') || undef,
                        _debug => 0
                );

		$page->schemaAction(
                        'Transaction', $command,
                        trans_id => $page->param('trans_id') || undef,
                        trans_owner_id => $page->field('provider') || undef,
                        trans_owner_type => 0,
                        provider_id => $page->param('person_id') || undef,
                        caption =>'Phone Message',
                        trans_type => 1000,
                        trans_status => $phoneStatus,
                        trans_begin_stamp => $page->field('datecalled'),
                        data_text_a => $page->field('phonemessage') || undef,
                        data_text_b => $page->field('responsemessage')  || undef,
			data_num_a => $trans_id,
		        data_num_b   => $page->field('data_num_b')  || undef,
		        consult_id  => $page->field('person_called') || undef,
                        _debug => 0
                );

	}
        elsif($command eq 'update' || $command eq 'remove')
        {
                my $transId = $page->param('trans_id');
                my $phoneDataInfo = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);
                if($phoneDataInfo->{data_num_a} eq '')
                {
	                $page->schemaAction(
       			     	'Transaction', $command,
                        	trans_id => $page->param('trans_id') || undef,
                        	trans_owner_id => $page->param('person_id') || undef,
                        	provider_id => $page->field('provider') || undef,
                        	trans_status => $phoneStatus,
                        	trans_begin_stamp => $page->field('datecalled'),
                        	data_text_a => $page->field('responsemessage') || undef,
                        	data_text_b => $page->field('phonemessage')  || undef,
                        	data_num_b   => $page->field('data_num_b')  || undef,
                        	consult_id  => $page->field('person_called') || undef,
                        	_debug => 0
               		);
                        my $physicianData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionByData_num_a', $transId);
	                $page->schemaAction(
       		                'Transaction', $command,
               		        trans_id => $physicianData->{trans_id}|| undef,
                       		trans_owner_id => $page->field('provider') || undef,
                        	provider_id => $page->param('person_id') || undef,
                        	trans_status => $phoneStatus,
                        	trans_begin_stamp => $page->field('datecalled'),
                        	data_text_a => $page->field('phonemessage') || undef,
                        	data_text_b => $page->field('responsemessage')  || undef,
                        	data_num_b   => $page->field('data_num_b')  || undef,
         	               consult_id  => $page->field('person_called') || undef,
                        	_debug => 0
                	);

                }
                elsif($phoneDataInfo->{data_num_a} ne '')
                {
                        $page->schemaAction(
                                'Transaction', $command,
                                trans_id => $page->param('trans_id') || undef,
                                trans_owner_id => $page->field('provider') || undef,
                                trans_status => $phoneStatus,
                                trans_begin_stamp => $page->field('datecalled'),
                                data_text_a => $page->field('phonemessage') || undef,
                                data_text_b => $page->field('responsemessage')  || undef,
                                data_num_b   => $page->field('data_num_b')  || undef,
	                        consult_id  => $page->field('person_called') || undef,
                                _debug => 0
                        );
                        my $parentItemId = $phoneDataInfo->{data_num_a};
                        my $personData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionById', $parentItemId);


                        $page->schemaAction(
                                'Transaction', $command,
                                trans_id => $personData->{trans_id} || undef,
                                provider_id => $page->field('provider') || undef,
                                trans_status => $phoneStatus,
                                trans_begin_stamp => $page->field('datecalled'),
                                data_text_a => $page->field('responsemessage') || undef,
                                data_text_b => $page->field('phonemessage')  || undef,
                                data_num_b   => $page->field('data_num_b')  || undef,
 	                       consult_id  => $page->field('person_called') || undef,
                                _debug => 0
                        );
                }

        }
	$self->handlePostExecute($page, $command, $flags);

}

1;
