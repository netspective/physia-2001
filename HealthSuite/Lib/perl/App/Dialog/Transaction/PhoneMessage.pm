##############################################################################
package App::Dialog::Transaction::PhoneMessage;
##############################################################################

use DBI::StatementManager;
use Data::TextPublish;
use App::Statements::Person;
use App::Statements::Transaction;
use App::Statements::Device;
use App::Universal;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Universal;
use App::Device;
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
		new CGI::Dialog::Field(type => 'hidden', name => 'patient_phone_message'),
		new App::Dialog::Field::Person::ID(name => 'person_called', caption =>'Call From', options => FLDFLAG_REQUIRED, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new App::Dialog::Field::Person::ID(name => 'provider', caption =>'Call For', options => FLDFLAG_REQUIRED, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		#new CGI::Dialog::Field(name => 'datecalled', caption => 'Date', type => 'date'),
		new CGI::Dialog::Field( caption => 'Date and Time of Calling', name => 'time', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'phone_message', caption => 'Phone Message', type => 'memo', options => FLDFLAG_REQUIRED, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(name => 'responsemessage', caption => 'Comments', type => 'memo'),
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
		new CGI::Dialog::Field(
			caption =>'Printer',
			name => 'printerQueue',
			options => FLDFLAG_PREPENDBLANK,
			fKeyStmtMgr => $STMTMGR_DEVICE,
			fKeyStmt => 'sel_org_devices',
			fKeyDisplayCol => 0
		),
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'transaction',
		key => "#field.person_called#",
		data => "Phone Message from <a href='/person/#field.person_called#/profile'>#field.person_called#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	$self->updateFieldFlags('status', FLDFLAG_INVISIBLE, 1) if $command eq 'add';
	my $startTime = $page->getTimeStamp();
	$page->field('time', $startTime);
	$self->setFieldFlags('time', FLDFLAG_READONLY);

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

		$page->field('phone_message', $phoneInfo->{data_text_b});
		$page->field('time', $phoneInfo->{data_text_c});
		#$page->field('datecalled', $phoneInfo->{trans_begin_stamp});
		$page->field('provider', $phoneInfo->{provider_id});
		$page->field('responsemessage', $phoneInfo->{data_text_a});
		$page->field('status', $phoneStatus);
		$page->field('data_num_b', $phoneInfo->{data_num_b});
		$page->field('person_called', $phoneInfo->{consult_id});
	}

	elsif($phoneInfo->{data_num_a} ne '')
        {
                $page->field('phone_message', $phoneInfo->{data_text_a});
                #$page->field('datecalled', $phoneInfo->{trans_begin_stamp});
                $page->field('provider', $phoneInfo->{provider_id});
                $page->field('responsemessage', $phoneInfo->{data_text_b});
                $page->field('time', $phoneInfo->{data_text_c});
                $page->field('status', $phoneStatus);
		$page->field('data_num_b', $phoneInfo->{data_num_b});
		$page->field('person_called', $phoneInfo->{consult_id});
        }

        my $populateMessage = $page->field('phone_message');
        $page->field('patient_phone_message', $populateMessage);
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	$page->field('status', 'Not Read')if $command eq 'add';
	my $phoneStatus = $page->field('status') eq 'Not Read' ? 5 : 4;
	my $status =  $page->field('status', $phoneStatus);
	my $userId = $page->session('user_id');
	my $printerName = $page->field('printerQueue');
	my $phoneMessage = $page->field('phone_message');

	my $providerInformation = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $page->field('provider'));
	my $callerInformation = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $page->field('person_called'));
	Data::TextPublish::wrapMessage (\$phoneMessage, 72);

	my $printerMessage = ("-" x 72)."\n";
	$printerMessage .= "MESSAGE \n";
	$printerMessage .= ("-" x 72)."\n";
	$printerMessage .= "     To: ".$providerInformation->{'complete_name'}." (".$page->field('provider').")\n";
	$printerMessage .= "   From: ".$callerInformation->{'complete_name'}." (".$page->field('person_called').")\n";
	$printerMessage .= "   Time: ".$page->field('time')."\n";
	$printerMessage .= "Message:\n".$phoneMessage."\n";
	$printerMessage .= ("-" x 72)."\n\n";

	App::Device::echoToPrinter ($printerName, $printerMessage) unless ($printerName eq '');

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
                     #   trans_begin_stamp => $page->field('datecalled'),
                        data_text_a => $page->field('responsemessage') || undef,
                        data_text_b => $page->field('phone_message')  || undef,
                        data_text_c => $page->field('time')  || undef,
                        data_num_b   => $page->field('data_num_b')  || undef,
                        consult_id  => $page->field('person_called') || undef,
                        _debug => 0
                );

		$page->schemaAction(
                        'Transaction', $command,
                        trans_id => $page->param('trans_id') || undef,
                        trans_owner_id => $page->field('provider') || undef,
                        trans_owner_type => 0,
                        provider_id => $page->field('provider') || undef,
                        caption =>'Phone Message',
                        trans_type => 1000,
                        trans_status => $phoneStatus,
                        #trans_begin_stamp => $page->field('datecalled'),
                        data_text_a => $page->field('phone_message') || undef,
                        data_text_b => $page->field('responsemessage')  || undef,
                        data_text_c => $page->field('time')  || undef,
			data_num_a => $trans_id,
		        data_num_b   => $page->field('data_num_b')  || undef,
		        consult_id  => $page->field('person_called') || undef,
                        _debug => 0
                );

                $page->schemaAction(
			'Transaction', $command,
			trans_id => $page->param('trans_id') || undef,
			trans_owner_id => $userId || undef,
			trans_owner_type => 0,
			provider_id => $page->field('provider') || undef,
			caption =>'Phone Message',
			trans_type => 1000,
			trans_status => $phoneStatus,
			#trans_begin_stamp => $page->field('datecalled'),
			data_text_a => $page->field('phone_message') || undef,
			data_text_b => $page->field('responsemessage')  || undef,
			data_text_c => $page->field('time')  || undef,
			data_num_b   => $page->field('data_num_b')  || undef,
			data_num_a => $trans_id,
			consult_id  => $page->field('person_called') || undef,
			_debug => 0
                );



	}
        elsif($command eq 'update' || $command eq 'remove')
        {
                my $transId = $page->param('trans_id');
                my $hiddenMessage = $page->field('patient_phone_message');
		my $phone =  $page->field('phone_message', $hiddenMessage);
                my $phoneDataInfo = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);

                if($phoneDataInfo->{data_num_a} eq '')
                {
	                $page->schemaAction(
       			     	'Transaction', $command,
                        	trans_id => $page->param('trans_id') || undef,
                        	trans_owner_id => $page->param('person_id') || undef,
                        	provider_id => $page->field('provider') || undef,
                        	trans_status => $phoneStatus,
                        	#trans_begin_stamp => $page->field('datecalled'),
                        	data_text_a => $page->field('responsemessage') || undef,
                        	data_text_b => $page->field('phone_message')  || undef,
                        	data_text_c => $page->field('time')  || undef,
                        	data_num_b   => $page->field('data_num_b')  || undef,
                        	consult_id  => $page->field('person_called') || undef,
                        	_debug => 0
               		);
                        my $physicianData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionByData_num_a', $transId);
			my $personCommand = $physicianData->{trans_id} ne '' ? $command : 'add';

	                $page->schemaAction(
       		                'Transaction', $personCommand,
               		        trans_id => $physicianData->{trans_id}|| undef,
                       		trans_owner_id => $page->field('provider') || undef,
                        	provider_id => $page->field('provider') || undef,
                        	trans_status => $phoneStatus,
                        	#trans_begin_stamp => $page->field('datecalled'),
                        	data_text_a => $page->field('phone_message') || undef,
                        	data_text_b => $page->field('responsemessage')  || undef,
                        	data_text_c => $page->field('time')  || undef,
                        	data_num_b   => $page->field('data_num_b')  || undef,
                        	data_num_a   => $transId,
         	               consult_id  => $page->field('person_called') || undef,
                        	_debug => 0
                	);

                        my $userData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionByUserAndData_num_a', $transId, $userId);
			my $userCommand = $userData->{trans_id} ne '' ? $command : 'add';
			$page->schemaAction(
				'Transaction', $userCommand,
				trans_id => $userData->{trans_id}|| undef,
				trans_owner_id => $userId || undef,
				provider_id => $page->field('provider') || undef,
				caption =>'Phone Message',
				trans_status => $phoneStatus,
				data_text_a => $page->field('phone_message') || undef,
				data_text_b => $page->field('responsemessage')  || undef,
				data_text_c => $page->field('time')  || undef,
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
				trans_owner_id => $page->param('person_id') || undef,
				provider_id => $page->field('provider') || undef,
				trans_status => $phoneStatus,
				data_text_a => $page->field('phone_message') || undef,
				data_text_b => $page->field('responsemessage')  || undef,
				data_text_c => $page->field('time')  || undef,
				data_num_b   => $page->field('data_num_b')  || undef,
				data_num_a  => $phoneDataInfo->{'data_num_a'},
				consult_id  => $page->field('person_called') || undef,
				_debug => 0
			);
			my $user = $page->param('person_id') ne $userId ? $userId : $page->field('provider');
			my $userData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionByUserAndData_num_a', "$phoneDataInfo->{data_num_a}", $user);
			my $userCommand = $userData->{trans_id} ne '' ? $command : 'add';
			$page->schemaAction(
				'Transaction', $userCommand,
				trans_id => $userData->{trans_id}|| undef,
				trans_owner_id => $user || undef,
				provider_id => $page->field('provider') || undef,
				caption =>'Phone Message',
				trans_status => $phoneStatus,
				data_text_a => $page->field('phone_message') || undef,
				data_text_b => $page->field('responsemessage')  || undef,
				data_text_c => $page->field('time')  || undef,
				data_num_b   => $page->field('data_num_b')  || undef,
				consult_id  => $page->field('person_called') || undef,
				_debug => 0
			);

                        my $parentItemId = $phoneDataInfo->{data_num_a};
                        my $personData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionById', $parentItemId);
			my $personCommand = $personData->{trans_id} ne '' ? $command : 'add';

                        $page->schemaAction(
                                'Transaction', $personCommand,
                                trans_id => $personData->{trans_id} || undef,
                                trans_owner_id => $page->field('person_called') || undef,
                                provider_id => $page->field('provider') || undef,
                                trans_status => $phoneStatus,
                                data_text_a => $page->field('responsemessage') || undef,
                                data_text_b => $page->field('phone_message')  || undef,
                                data_text_c => $page->field('time')  || undef,
                                data_num_b   => $page->field('data_num_b')  || undef,
 	                       consult_id  => $page->field('person_called') || undef,
                                _debug => 0
                        );
                }

        }
	$self->handlePostExecute($page, $command, $flags);
}

1;
