##############################################################################
package App::Dialog::Report::Org::General::Accounting::DepositPayment;
##############################################################################

use strict;
use Carp;
use Date::Calc qw(Delta_Days);
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use App::Statements::Component::Invoice;
use App::Statements::Org;
use App::Statements::Report::Accounting;
use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;
use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-deposit-payment', heading => 'Deposit Report');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'batch',
				caption => 'Batch Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
				options=>FLDFLAG_REQUIRED
				),
			new CGI::Dialog::MultiField(caption => 'Batch ID Range', name => 'batch_fields',
						fields => [
			new CGI::Dialog::Field(caption => 'Batch ID From', name => 'batch_id_from', size => 12,options=>FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(caption => 'Batch ID To', name => 'batch_id_to', size => 12,options=>FLDFLAG_REQUIRED),
			]),				
			new App::Dialog::Field::Organization::ID(caption =>'Site Organization ID', name => 'org_id',),
			new App::Dialog::Field::Person::ID(caption =>'Physican ID', name => 'person_id', ),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('batch_begin_date', $page->param('_f_batch_begin_date')|| $startDate);
	$page->field('batch_end_date', $page->param('_f_batch_begin_end')||$startDate);
}


sub prepare_detail_payment
{
	

}


sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $reportBeginDate = $page->field('batch_begin_date');
	my $reportEndDate = $page->field('batch_end_date');
	my $orgId = $page->field('org_id');
	my $person_id = $page->field('person_id')||undef;
	my $batch_from = $page->field('batch_id_from');
	my $batch_to = $page->field('batch_id_to');
	my $orgIntId = undef;
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;
	my @data=undef;
	my @dataSub=undef;
	my $html;
	my $orgResult;
	my $gmtDayOffset = $page->session('GMT_DAYOFFSET');


	my $pub =
	{
		reportTitle => $self->heading(),
		columnDefn =>
			[
			{ colIdx => 0, head => 'Batch Date', hAlign=>'left', tAlign=>'left',dAlign => 'left'},
			{ colIdx => 1, head => 'Payer', hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ colIdx => 2, head => 'Payment Type',},
			{ colIdx => 3, head => 'Total Amount of Check',  dformat => 'currency' ,
			tDataFmt=>'&{sum_currency:5}',tAlign=>'right'},
			#{ colIdx => 4, head => 'Invoice ID',},			
			#{ colIdx => 5, head => 'Adjustment ID',},		
		],
	};
	$orgResult = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selDeposit',
			$reportBeginDate,$reportEndDate,$orgIntId,$person_id,$page->session('org_internal_id')) ;
	@data = ();
	@dataSub=();

	my $payerId=undef;
	my $batchDate=undef;
	my $payTitle=undef;
	my $payType=undef;
	my $check=0;
	my $payRef=undef;
	my $totalAmount=0;
	my @rowData =();
	my $paymentText ="<B>Payments Applied:</B>";
	my @rowSubData=[$paymentText];
	foreach (@$orgResult)
	{		
		
		my $payment=$_->{pay_type};
		
		#If payment method/type is check the attach Check Number to payment type
		if('Check' eq $_->{pay_type})
		{
			$payment = $_->{pay_ref} ? "$_->{pay_type} #$_->{pay_ref}" :$_->{pay_type};
		}
		
		#If payer type is an org then get org Id 
		if($_->{payer_type} == 1)
		{
			my $getName = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selId',$_->{payer_id});	
			$_->{payer_id} = $getName->{org_id};
		}	
		
		#If the key infomration has not changed then keeping counting total
		#or if this is hte first record
		if(!$payerId ||
		   !(	$batchDate ne $_->{batch_date} ||
			$payerId ne $_->{payer_id} ||
			$payTitle ne $payment ||
			$payRef ne $_->{pay_ref}
		   )
		   )
		   
		{

			$batchDate =$_->{batch_date};
			$payerId = $_->{payer_id};
			$payTitle = $payment;
			$totalAmount = $totalAmount + $_->{amount};
			$payRef = $_->{pay_ref};	
			$payType = $_->{pay_type};			
		
		}
		#if some of the group by data has changed
		#then output record and begin new group
		#also if payment method group has been left add blank line		
		elsif ($batchDate ne $_->{batch_date} ||
			$payerId ne $_->{payer_id} ||
			$payTitle ne $payment ||
			$payRef ne $_->{pay_ref}
		      )
		{
			@rowData=
			[
				$batchDate,
				$payerId,
				$payTitle,
				$totalAmount,
				$_->{invoice_id},
				$totalAmount,
				$payType
			];
			push(@data, @rowData);		
			push(@data,@rowSubData) if ($payType eq 'Check');	
			
			#If we have entered a new payment type group (from check to Visa for example)
			#then add a blank line thats what they asked for			
			push(@data,[]) if ($payType ne $_->{pay_type});
			#Clear out data 
			@rowSubData=[$paymentText];
			$batchDate =$_->{batch_date};
			$payerId = $_->{payer_id};
			$payTitle = $payment;
			$totalAmount = $_->{amount};
			$payRef = $_->{pay_ref};
			$payType = $_->{pay_type};

		}
		#Store result in sub-results field	
		push (@rowSubData,
		["",
		#"Invoice # <A HREF='/invoice/$_->{invoice_id}/summary'>$_->{invoice_id}</A>",	
		"Invoice # $_->{invoice_id}",			
		"",
		$_->{amount},
		$_->{invoice_id},				
		]);

	}
	#Add Last set of record	s
	@rowData=
	[
		$batchDate,
		$payerId,
		$payTitle,
		$totalAmount,
		$_->{invoice_id},
		$totalAmount		
	];
	push(@data, @rowData);	
	push(@data,@rowSubData)if ($payType eq 'Check');
	$html = createHtmlFromData($page, 0, \@data,$pub);
	return $html;
}



# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;