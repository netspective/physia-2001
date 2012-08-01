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
use App::Statements::Org;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'alert-person' => {
		transType => App::Universal::TRANSTYPE_ALERTORG, heading => '$Command Alert',
		_arl => ['person_id'],
		_arl_modify => ['trans_id'],
		_idSynonym => [
			'trans-' .App::Universal::TRANSTYPE_ALERTORG(),
			'trans-' .App::Universal::TRANSTYPE_ALERTORGFACILITY(),
			'trans-' .App::Universal::TRANSTYPE_ALERTPATIENT(),
			'trans-' .App::Universal::TRANSTYPE_ALERTACCOUNTING(),
			'trans-' .App::Universal::TRANSTYPE_ALERTINSURANCE(),
			'trans-' .App::Universal::TRANSTYPE_ALERTMEDICATION(),
			'trans-' .App::Universal::ATTRTYPE_STUDENTPART(),
			'trans-' .App::Universal::TRANSTYPE_ALERTACTION(),
			'trans-' .App::Universal::TRANSTYPE_ALERTAPPOINTMENT(),
		],
	},

	'alert-org' => { transType => App::Universal::TRANSTYPE_ALERTORG,
		heading => '$Command Alert',
		_arl => ['org_id'],
		_arl_modify => ['trans_id'],
	},
);

use constant ALERT_ACTIVE => 2;
use constant ALERT_INACTIVE => 3;
use constant ALERT_ACCOUNTING => 8025;

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'alert', heading => '$Command Alert');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::MultiField(
			fields => [
				new App::Dialog::Field::Scheduling::Date(caption => 'Begin Alert',
					name => 'trans_begin_stamp',
					options => FLDFLAG_REQUIRED,
					futureOnly => 0
				),
				new App::Dialog::Field::Scheduling::Date(caption => 'End Alert',
					name => 'trans_end_stamp',
					defaultValue => '',
				),
			],
		),
		new CGI::Dialog::Field::TableColumn(
			caption => 'Type',
			schema => $schema,
			name => 'trans_type',
			column => 'Transaction.trans_type',
			typeRange => '8000..8999',
			onChangeJS => qq{showFieldsOnValues(event, [@{[ALERT_ACCOUNTING]}], ['data_text_a']);},
		),
		new CGI::Dialog::Field(caption => 'Accounting Alert',
			name => 'data_text_a',
			choiceDelim =>',',
			selOptions => qq{	Bad Address:'Bad Address',
				Returned Check:'Returned Check',
				Dismissed:'Dismissed',
				Collection Agency:'Collection Agency',
				Bankruptcy:'Bankruptcy',
				In House Collections:'In House Collections',
				Incorrect Insurance:'Incorrect Insurance',
				Payment Plan:'Payment Plan',},
			type => 'select',
		),
		new CGI::Dialog::Field(lookup => 'Alert_Priority', caption => 'Priority',
			name => 'trans_subtype',
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(caption => 'Caption',
			name => 'caption',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(type => 'memo', caption => 'Details',
			name => 'detail',
			options => FLDFLAG_REQUIRED,
		),
		new App::Dialog::Field::Person::ID(caption => 'Staff Member',
			name => 'initiator_id',
			types => ['Physician', 'Staff', 'Nurse'],
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(caption => 'Alert Status',
			name => 'trans_status',
			choiceDelim =>',',
			selOptions => "Active:@{[ALERT_ACTIVE]}, InActive:@{[ALERT_INACTIVE]}",
			type => 'select',
			style => 'radio',
			options => FLDFLAG_REQUIRED,
		),
	);

	$self->{activityLog} =
	{
		level => 2,
		scope =>'transaction',
		key => "#param.person_id##param.org_id#",
		data => "Alert '#field.caption#' for <a href='/org/#param.org_id#/profile'>#param.org_id#</a><a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons);

	$self->addPostHtml(qq{
		<script language="JavaScript1.2">
		<!--
		if (opObj = eval('document.dialog._f_trans_type'))
		{
			if (opObj.value != @{[ ALERT_ACCOUNTING ]})
			{
				setIdDisplay('data_text_a', 'none');
			}
		}
		// -->
		</script>
	});

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	#$self->updateFieldFlags('acct_alert', FLDFLAG_INVISIBLE, $page->field('trans_type') != 8025);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	if (my $transId = $page->param('trans_id')) {
		$STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);
	} else {
		$page->field('initiator_id', $page->session('user_id'));
		$page->field('trans_status', ALERT_ACTIVE);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $transId = $page->param('trans_id');
	my $transStatus = $command eq 'remove' ?
		App::Universal::TRANSSTATUS_INACTIVE : $page->field('trans_status');

	my $actualCommand = $command eq 'remove' ? 'update' : $command;

	my $entityId = $page->param('person_id') ? $page->param('person_id') : $page->param('org_id');
	my $entityType = $page->param('person_id') ? '0' : '1';

	if($entityType eq '1')
	{
		my $orgId = $page->param('org_id') ? $page->param('org_id') : $page->session('org_id');
		my $orgIntId = $page->session('org_internal_id');
		$entityId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $orgIntId, $orgId)
			if $page->param('org_id');
	}

	$page->schemaAction(
		'Transaction', $actualCommand,
		trans_id => $transId || undef,
		trans_owner_type => $entityType,
		trans_owner_id => $entityId || undef,
		trans_type => $page->field('trans_type') || undef,
		trans_subtype => $page->field('trans_subtype') || undef,
		caption => $page->field('caption') || undef,
		detail => $page->field('detail') || undef,
		trans_status => $transStatus || undef,
		initiator_id => $page->field('initiator_id'),
		initiator_type => 0,
		trans_status => $transStatus,
		trans_begin_stamp => $page->field('trans_begin_stamp') || undef,
		trans_end_stamp => $page->field('trans_end_stamp') || undef,
		data_text_a => $page->field('trans_type') == 8025 ? $page->field('data_text_a') : undef,
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;