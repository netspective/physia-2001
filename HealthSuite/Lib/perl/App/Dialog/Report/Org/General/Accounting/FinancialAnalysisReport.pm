##############################################################################
package App::Dialog::Report::Org::General::Accounting::FinancialAnalysisReport;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

use App::Statements::Report::Accounting;
use App::Statements::Org;
use Date::Calc qw(:all);
use Date::Manip;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-financial-analysis-report', heading => 'Financial Analysis Report');

	$self->addContent(
				new CGI::Dialog::Field::Duration(
					name => 'batch',
					caption => 'Report Date',
					begin_caption => 'Report Begin Date',
					end_caption => 'Report End Date',
					options=>FLDFLAG_REQUIRED,
					),
				new CGI::Dialog::Field::Duration(
					name => 'service',
					caption => 'Service Date',
					begin_caption => 'Service Begin Date',
					end_caption => 'Service End Date',
					),
				new App::Dialog::Field::Organization::ID(caption =>'Site Organization ID', name => 'org_id'),
				new App::Dialog::Field::Person::ID(caption =>'Physican ID', name => 'person_id'),

				new CGI::Dialog::Field(
					name => 'printReport',
					type => 'bool',
					style => 'check',
					caption => 'Print report',
					defaultValue => 0
					),

				new CGI::Dialog::Field(
					caption =>'Printer',
					name => 'printerQueue',
					options => FLDFLAG_PREPENDBLANK,
					fKeyStmtMgr => $STMTMGR_DEVICE,
					fKeyStmt => 'sel_org_devices',
					fKeyDisplayCol => 0
				),
			);
	$self->addFooter(new CGI::Dialog::Buttons);
	$self;
}

sub populateData
{
#	my ($self, $page, $command, $activeExecMode, $flags) = @_;
#
#	$page->field('person_id', $page->session('person_id'));
}


sub customValidate
{
	my ($self, $page) = @_;

	my $reportBeginDate = $page->field('batch_begin_date');
	my $reportEndDate = $page->field('batch_end_date');
	#Check Dates
	#And Fiscal Month
	my $orgInternalId = $page->session('org_internal_id');

	#Get Fiscal year for Main Org
	my $fiscal = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selAttribute',$orgInternalId,'Fiscal Month');

	#month is 1 less so add a 1
	my $month = $fiscal->{value_int}+1;


	my @start_Date = Decode_Date_US($reportBeginDate);
	my @end_Date = Decode_Date_US($reportEndDate);
	my $field = $self->getField('batch');
	#Check if month in begin date is less then fiscal month
	#$page->addError("[$start_Date[0]] [$end_Date[0]]");
	if ($start_Date[1] < $month && $end_Date[1] >= $month)
	{
		#Go back one year
		#Error message
		#my $contractID = $page->field('contract_id');
		#my $code = $page->field('code');
		$field->invalidate($page, qq{Requested dates [$reportBeginDate - $reportEndDate]  cross fiscal year [check month]});

	}
	elsif($start_Date[0] != $end_Date[0])
	{
	 	#unless ($start_Date[0]+1 == $end_Date[0] && end_Date[1]  < $month)
		$field->invalidate($page, qq{Requested dates [$reportBeginDate - $reportEndDate]  cross fiscal year. Check Year})unless ($start_Date[0] + 1 == $end_Date[0] && $end_Date[1]  < $month);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $reportBeginDate = $page->field('batch_begin_date');
	my $reportEndDate = $page->field('batch_end_date');
	my $orgId = $page->field('org_id');
	my $serviceBeginDate = $page->field('service_begin_date');
	my $serviceEndDate = $page->field('service_end_date');
	my $person_id = $page->field('person_id')||undef;
	my $batch_from = $page->field('batch_id_from')||undef;
	my $batch_to = $page->field('batch_id_to')||undef;
	my $orgIntId = undef;
	my @data=();

	##
	my $hardCopy = $page->field('printReport');
	my $html;
	my $textOutputFilename;

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	##
	my $pub ={
		reportTitle => "Financial Analysis",
		columnDefn =>
		[
		{colIdx => 12, head =>'Year', dAlign => 'left',},
		{colIdx => 0, head => 'Month', dAlign => 'left',},
		{colIdx => 1, head => 'Chrgs', dAlign => 'left',summarize => 'sum',dformat => 'currency' },
		{colIdx => 2, head => 'Misc Chrgs',dAlign =>'left' , hAlign =>'left',summarize => 'sum',dformat => 'currency' },
		{colIdx => 3, head => 'Chrg Adj', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
		{colIdx => 4, head => 'Ins W/O', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
		{colIdx => 5, head => 'Net Chrgs', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
		{colIdx => 6, head => 'Bal Trans', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
		{colIdx => 7, head => 'Per Rcpts',dAlign => 'center',summarize => 'sum',dformat => 'currency' },
		{colIdx => 8, head => 'Ins Rcpts', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
		{colIdx => 9, head => 'Rcpt Adj', dAlign => 'center',summarize => 'sum',dformat => 'currency'},
		{colIdx => 10,head => 'Net Rcpts', summarize => 'sum',  dformat => 'currency' },
		{colIdx => 13,head => 'Monthly A/R', summarize => 'sum', dformat => 'currency' },
		{colIdx => 11,head => 'A/R', 	tDataFmt => '&{sum_currency:14}',dformat => 'currency' },
		],
		};
#'&{count:0} Contracts'


	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;

	my $far = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE , 'sel_financial_monthly',$reportBeginDate,
	$reportEndDate,$orgIntId,$person_id,$page->session('org_internal_id'), $serviceBeginDate, $serviceEndDate);


	my $orgInternalId = $page->session('org_internal_id');

	#Get Fiscal year for Main Org
	my $fiscal = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selAttribute',$orgInternalId,'Fiscal Month');

	#month is 1 less so add a 1
	my $month = $fiscal->{value_int}+1;

	#Check if end date is less then fiscal month if so go back one year
	my @start_Date = Decode_Date_US($reportBeginDate);
	if ($start_Date[1] < $month)
	{
		#Go back one year
		$start_Date[0]--;
	}
	my $startFiscal = sprintf("%02d/%02d/%04d", $month,$start_Date[2],$start_Date[0]);

	my $total_ar=$STMTMGR_REPORT_ACCOUNTING->getSingleValue($page,STMTMGRFLAG_NONE,'sel_a_r_before',$startFiscal,$reportBeginDate,$page->session('org_internal_id'),$person_id,$orgIntId);
	#$page->addError("Value : $total_ar");
	my $track_ar = $total_ar;
	foreach (@$far)
	{
		$total_ar +=$_->{a_r};
		$track_ar +=$_->{a_r};
		my @rowData =
		(
		$_->{invoice_month},
		$_->{total_charges},
		$_->{misc_charges},
		$_->{person_write_off},
		$_->{insurance_write_off},
		$_->{net_charge},
		$_->{balance_transfer},
		$_->{person_pay},
		$_->{insurance_pay},
		$_->{refund},
		$_->{net_rcpts},
		$total_ar,
		$_->{invoice_year},
		$_->{a_r},
		$track_ar
		);
		$track_ar = 0;
		push(@data, \@rowData);
	}
	#$page->param('total_ar',$total_ar);
	$html .= createHtmlFromData($page, 0,  \@data, $pub);
	$textOutputFilename = createTextRowsFromData($page, 0,  \@data, $pub);

	if ($hardCopy == 1 and $printerAvailable) {
		my $reportOpened = 1;
		my $tempDir = $CONFDATA_SERVER->path_temp();
		open (ASCIIREPORT, $tempDir.$textOutputFilename) or $reportOpened = 0;
		if ($reportOpened) {
			while (my $reportLine = <ASCIIREPORT>) {
				print $printHandle $reportLine;
			}
		}
		close ASCIIREPORT;
	}

	return ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version</a> <br>} : "" ) . $html;
	#return createHtmlFromData($page, 0, \@data,$pub);
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;