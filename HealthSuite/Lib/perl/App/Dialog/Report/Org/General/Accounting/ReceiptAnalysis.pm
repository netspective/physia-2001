##############################################################################
package App::Dialog::Report::Org::General::Accounting::ReceiptAnalysis;
##############################################################################

use strict;
use Carp;
use Date::Calc qw(:all);
use Date::Manip;
use App::Dialog::Report;
use App::Universal;
use App::Configuration;
use App::Device;
use App::Statements::Device;
use App::Statements::Org;
use Data::Publish;
use Data::TextPublish;
use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Dialog::Field::Person;
use App::Statements::Invoice;
use App::Statements::Component::Invoice;
use App::Statements::Report::Accounting;
use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-receipt-analysis', heading => 'Receipt Analysis');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				options=>FLDFLAG_REQUIRED,
				name => 'batch',
				caption => 'Batch Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				),		
			new App::Dialog::Field::Person::ID(caption =>'Physician ID',types => ['Physician'], name => 'person_id', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			new CGI::Dialog::Field(caption =>'Payment Type',
					name => 'transaction_type',
					options => FLDFLAG_PREPENDBLANK,
					fKeyStmtMgr => $STMTMGR_INVOICE,
					fKeyStmt => 'selPaymentMethod',
					fKeyDisplayCol => 0
					),

			new CGI::Dialog::Field(caption => 'Batch ID', size => 12,name=>'batch_id'),						
			new CGI::Dialog::Field(
				name => 'totalReport',
				type => 'bool',
				style => 'check',
				caption => 'Totals Report',
				defaultValue => 0
			),			
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


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $provider = $page->field('person_id');
	my $receipt = $page->field('transaction_type');
	my $batch_id = $page->field('batch_id');
	my $reportBeginDate = $page->field('batch_begin_date');
	my $reportEndDate = $page->field('batch_end_date');
	my $inc_date=0;
	my $hardCopy = $page->field('printReport');
	my $totalReport = $page->field('totalReport');
	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openRawPrintHandle ($printerDevice);
	
	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');


	if($reportEndDate eq $reportBeginDate)
	{
		$inc_date = 1;
	}
	my $allPub;
	if (!$inc_date)
	{ $allPub =
		{
		reportTitle => $self->heading(),
		columnDefn =>
			[
			{ colIdx => 0,hAlign=>'left', head => 'Physician Name', groupBy => '#0#', dAlign => 'LEFT' },			
			{ colIdx => 1, ,hAlign=>'left',head => 'Category' ,groupBy => '#1#'},
			{ colIdx => 2, ,hAlign=>'left',head => 'Tranaction Type',groupBy => '#2#' },
			{ colIdx => 3,,hAlign=>'left', head => 'Payer Name',groupBy => 'Sub-Total'  },
			{ colIdx => 4, head => 'Month Rcpt',  summarize => 'sum',dformat => 'currency' },
			{ colIdx => 5, head => 'Year Rcpt',summarize => 'sum',dformat => 'currency' },
		],
		};
	}
	else
	{
	   $allPub =
		{
			reportTitle => $self->heading(),
			columnDefn =>
				[
			{ colIdx => 0,hAlign=>'left', head => 'Physician Name', groupBy => '#0#', dAlign => 'LEFT' },			
			{ colIdx => 1, ,hAlign=>'left',head => 'Category' ,groupBy => '#1#'},
			{ colIdx => 2, ,hAlign=>'left',head => 'Tranaction Type',groupBy => '#2#' },
			{ colIdx => 3,,hAlign=>'left', head => 'Payer Name',groupBy => 'Sub-Total'  },
			{ colIdx => 6, head => 'Batch Date' },			
			{ colIdx => 7, head => 'Batch Date Rcpt', summarize => 'sum', dformat => 'currency' },			
			{ colIdx => 4, head => 'Month Rcpt',  summarize => 'sum',dformat => 'currency' },
			{ colIdx => 5, head => 'Year Rcpt',summarize => 'sum',dformat => 'currency' },
			],
		};	
	}
	my $orgInternalId = $page->session('org_internal_id');
	
	#Get Fiscal year for Main Org
	my $fiscal = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selAttribute',$page->session('org_internal_id')||undef,'Fiscal Month');	
	
	#month is 1 less so add a 1
	my $month = $fiscal->{value_int}+1;	
	
	#Check if end date if less then fiscal month if so go back one year
	my @start_Date = Decode_Date_US($reportBeginDate);
	if ($start_Date[1] < $month)
	{
		#Go back one year
		$start_Date[0]--;
	}
	#Use Fiscal month
	$start_Date[1] = $month;
	
	#First of first month
	$start_Date[2] = 1;
	
	my $startDate = sprintf("%02d/%02d/%04d", $start_Date[1],$start_Date[2],$start_Date[0]);

	#Convert to first day of fiscal month
	$reportBeginDate =$startDate;

	#Get Report Data 
	my $rcpt;
	if($totalReport)
	{
		$rcpt =  $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'sel_providerreceiptTotal',
		$provider,$receipt,$batch_id,$reportBeginDate,$reportEndDate,$orgInternalId)  ;			
	}
	else
	{
		$rcpt =  $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'sel_providerreceipt',
			$provider,$receipt,$batch_id,$reportBeginDate,$reportEndDate,$orgInternalId);	
	}
	my @data = ();
	foreach (@$rcpt)
	{
		#set batch date to report end date 
		#if end date a begin date are the same then output batch date
 		$_->{batch_date} = $reportEndDate;
		if($_->{payer_type} == 1)
		{
			my $getName = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selId',$_->{payer_id}) unless $totalReport;	
			$_->{payer_type} = 'Insurance Receipts';
			$_->{payer_id} = $getName->{org_id} unless $totalReport;
		}
		elsif($_->{payer_type}==-1)
		{
			$_->{payer_type} = 'Cap Insurance Receipts'; 				
		}
		else
		{
			$_->{payer_type} = 'Personal Receipts';
		}

		my @rowData =
		(
			$_->{provider},
			$_->{payer_type},			
			$_->{pay_type},
			$_->{payer_id},									
			$_->{month_rcpt},			
			$_->{year_rcpt},
			$_->{batch_date},
			$_->{batch_rcpt},
		);
		push(@data, \@rowData);		
	}	
	my $html = '<br> <b style="font-family:Helvetica; font-size:10pt">(Fiscal Range '. $reportBeginDate .' - ' . $reportEndDate . ' ) </b><br>';
	$html .= createHtmlFromData($page, 0, \@data,$allPub);
	my $textOutputFilename = createTextRowsFromData ($page, 0, \@data, $allPub);
	
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

	my $pages = $self->getFilePageCount(File::Spec->catfile($CONFDATA_SERVER->path_temp, $textOutputFilename));
	return ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version - $pages Page(s)</a> <br>} : "" ) . $html;

}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;