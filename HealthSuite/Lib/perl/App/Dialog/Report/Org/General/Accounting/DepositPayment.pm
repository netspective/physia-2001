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
			{groupBy=>'#0#', colIdx => 0, head => 'Batch Date', hAlign=>'left', tAlign=>'left',dAlign => 'left'},
			{groupBy=>'#1#', colIdx => 1, head => 'Batch ID', hAlign=>'left', tAlign=>'left',dAlign => 'left'},
			{ colIdx => 2, head => 'Payer', hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ groupBy=>'#3#',colIdx => 3, head => 'Payment Type',},
			{ colIdx => 4, head => 'Check Number ',},
			{ colIdx => 5, head => 'Amount',  dformat => 'currency',sAlign=>'right',summarize=>'sum' ,
			,tAlign=>'right'},
		],
	};
	$orgResult = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selDepositSummary',
			$reportBeginDate,$reportEndDate,$orgIntId,$person_id,$page->session('org_internal_id'),
$batch_from, $batch_to) ;
	@data = ();
	@dataSub=();

	my $payerId=undef;
	my $batchDate=undef;
	my $batchId=undef;
	my $payTitle=undef;
	my $payType=undef;
	my $check=0;
	my $payRef=undef;
	my $totalAmount=0;
	my @rowData =();
	foreach (@$orgResult)
	{		
		$_->{batch_id};
		
		if($_->{pay_type} ne 'Check')
		{
			$_->{pay_ref}='';
		};
		#If payer type is an org then get org Id 
		if($_->{payer_type} == 1)
		{
			my $getName = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selId',$_->{payer_id});	
			$_->{payer_id} = $getName->{org_id};
		}	
		
		@rowData=
		[
		$_->{batch_date},
		$_->{batch_id},
		$_->{payer_id},
		$_->{pay_type}||'N/A',
		$_->{pay_ref},
		$_->{amount},
		];
		push(@data, @rowData);	
	}
	$html =   "<BR> <B>Deposit Summary</B><BR>" . createHtmlFromData($page, 0, \@data,$pub);

	#Get Detail Data
	$pub =
	{
		reportTitle => $self->heading(),
		columnDefn =>
			[
			{groupBy=>'#0#',colIdx => 0, head => 'Batch Date', hAlign=>'left', tAlign=>'left',dAlign => 'left'},
			{groupBy=>'#1#',colIdx => 1, head => 'Batch ID', hAlign=>'left', tAlign=>'left',dAlign => 'left'},
			{groupBy=>'#2#', colIdx => 2, head => 'Payer', hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{groupBy=>'#3#', colIdx => 3, head => 'Check', hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ colIdx => 4, head => 'Invoice ID' , hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ colIdx => 5, head => 'Check Amount',  dformat => 'currency',sAlign=>'right',summarize=>'sum' ,,tAlign=>'right'},
		],
	};

	$orgResult = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selDeposit',
			$reportBeginDate,$reportEndDate,$orgIntId,$person_id,$page->session('org_internal_id'), 
$batch_from, $batch_to) ;
	@data = ();
	foreach (@$orgResult)
	{		
		$_->{batch_id};
		
		#If payer type is an org then get org Id 
		if($_->{payer_type} == 1)
		{
			my $getName = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selId',$_->{payer_id});	
			$_->{payer_id} = $getName->{org_id};
		}	
		
		@rowData=
		[
		$_->{batch_date},
		$_->{batch_id} ,
		$_->{payer_id},
		$_->{pay_type}  . " #" . $_->{pay_ref},
		$_->{invoice_id},
		$_->{amount},
		];
		push(@data, @rowData);	
	}
	$html .= "<BR> <B>Check Payements Detail</B><BR>" . createHtmlFromData($page, 0, \@data,$pub);

	return $html;
}



# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
