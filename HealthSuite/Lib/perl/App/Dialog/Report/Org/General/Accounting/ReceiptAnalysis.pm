##############################################################################
package App::Dialog::Report::Org::General::Accounting::ReceiptAnalysis;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;
use App::Configuration;
use App::Device;
use App::Statements::Device;
use Data::Publish;
use Data::TextPublish;
use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Component::Invoice;
use App::Statements::Report::Accounting;
use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-receipt-analysis', heading => 'Receipt Analysis');

	$self->addContent(
			new App::Dialog::Field::Person::ID(caption =>'Provider ID', name => 'person_id', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			new CGI::Dialog::Field(caption =>'Payment Type',
					name => 'transaction_type',
					options => FLDFLAG_PREPENDBLANK,
					fKeyStmtMgr => $STMTMGR_INVOICE,
					fKeyStmt => 'selPaymentMethod',
					fKeyDisplayCol => 0
					),

			new CGI::Dialog::Field(caption => 'Batch ID', size => 12,name=>'batch_id'),					
			new CGI::Dialog::Field::Duration(
				name => 'batch',
				caption => 'Batch Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
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
	my $reportBeginDate = $page->field('batch_begin_date')||'01/01/1800';
	my $reportEndDate = $page->field('batch_end_date')||'01/01/9999';

	my $hardCopy = $page->field('printReport');
	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");
	
	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');


	my $allPub =
	{
		reportTitle => $self->heading(),
		columnDefn =>
			[
			{ colIdx => 0, head => 'Physician Name', groupBy => '#0#', dAlign => 'LEFT' },			
			{ colIdx => 1, head => 'Category' ,groupBy => '#1#'},
			{ colIdx => 2, head => 'Tranaction Type',groupBy => '#2#' },
			{ colIdx => 3, head => 'Payer Name',groupBy => 'Sub-Total'  },
			{ colIdx => 4, head => 'Batch Date' },			
			{ colIdx => 5, head => 'Batch Date Rcpt', summarize => 'sum', dformat => 'currency' },
			{ colIdx => 6, head => 'Month Rcpt',  dformat => 'currency' },
			{ colIdx => 7, head => 'Year Rcpt', dformat => 'currency' },
		],
	};	
	my $orgInternalId = $page->session('org_internal_id');
	my $rcpt  = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'sel_providerreceipt',
		$provider,$receipt,$batch_id,$reportBeginDate,$reportEndDate,$orgInternalId);
	my @data = ();
	my $month_rcpt=0;
	my $year_rcpt=0;
	my $track_doc=undef;
	my $track_cat=undef;
	my $track_trans=undef;
	my $track_payer=undef;
	my $track_year=undef;
	my $track_month=undef;	
	foreach (@$rcpt)
	{
		#Track informatiom so we can sum it up for month and year info
		if(! defined $track_doc)
		{
			$track_doc=$_->{provider};
			$track_cat=$_->{category};
			$track_trans=$_->{pay_type};
			$track_payer=$_->{payer_name};
			$track_year=$_->{year_date};
			$track_month=$_->{month_date};
			$month_rcpt = $_->{rcpt};
			$year_rcpt = $_->{rcpt};			
		}
		elsif ($track_doc ne $_->{provider} || $track_cat ne $_->{category} ||$track_trans ne $_->{pay_type} )
		{
			$track_doc=$_->{provider};
			$track_cat=$_->{category};
			$track_trans=$_->{pay_type};
			$track_payer=$_->{payer_name};
			$track_year=$_->{year_date};
			$track_month=$_->{month_date};
			$month_rcpt = $_->{rcpt};
			$year_rcpt = $_->{rcpt};				
			
		}
		elsif ($track_year ne $_->{year_date} )
		{
			$month_rcpt = $_->{rcpt};
			$year_rcpt = $_->{rcpt};			
			$track_year=$_->{year_date};
			$track_month=$_->{month_date};			
		}
		elsif ($track_month ne $_->{month_date})
		{
			$month_rcpt = $_->{rcpt};
			$year_rcpt  += $_->{rcpt};			
			$track_year=$_->{year_date};
			$track_month=$_->{month_date};			
			
		}
		else
		{
			$month_rcpt += $_->{rcpt};
			$year_rcpt  += $_->{rcpt}
			
		};
		
		my @rowData =
		(
			$_->{provider},
			$_->{category},
			$_->{pay_type},
			$_->{payer_name},
			$_->{invoice_date},
			$_->{rcpt},
			$month_rcpt,
			$year_rcpt,
			$_->{invoice_id},
		);
		push(@data, \@rowData);			
	}
	
	my $html = createHtmlFromData($page, 0, \@data,$allPub);
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

	return ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version</a> <br>} : "" ) . $html;
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;