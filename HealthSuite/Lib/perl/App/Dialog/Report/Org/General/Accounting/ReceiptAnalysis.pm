##############################################################################
package App::Dialog::Report::Org::General::Accounting::ReceiptAnalysis;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;
use Data::Publish;
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


	my $allPub =
	{
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
	
	return createHtmlFromData($page, 0, \@data,$allPub);	
	
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;