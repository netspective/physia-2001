##############################################################################
package App::Dialog::Report::Org::General::Accounting::RevenueCollection;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use App::Statements::Report::Accounting;
use App::Statements::Org;
use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-revenue-collection', heading => "Revenue and Collection");

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'batch',
				caption => 'Batch Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				),
			new CGI::Dialog::MultiField(caption => 'Batch ID Range', name => 'batch_fields', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						fields => [
			new CGI::Dialog::Field(caption => 'Batch ID From', name => 'batch_id_from', size => 12),
			new CGI::Dialog::Field(caption => 'Batch ID To', name => 'batch_id_to', size => 12),											
			]),				
			new App::Dialog::Field::Organization::ID(caption =>'Site Organization ID', name => 'org_id', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			new App::Dialog::Field::Person::ID(caption =>'Physician ID', name => 'person_id',types => ['Physician'] ),			
			new CGI::Dialog::Field(type => 'select',
							style => 'radio',
							selOptions => 'Segmented:0;Whole:1',
							caption => 'Report View: ',
							preHtml => "<B><FONT COLOR=DARKRED>",
							postHtml => "</FONT></B>",
							name => 'format',options=>FLDFLAG_REQUIRED,
				defaultValue => '0',),			
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
			new CGI::Dialog::Field(type => 'hidden',name=>'title');
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('batch_begin_date', $page->param('_f_batch_begin_date')|| $startDate);
	$page->field('batch_end_date', $page->param('_f_batch_begin_end')||$startDate);
	#$page->field('org_id', $page->param('_f_org_id') || $page->session('org_id') );
	$page->field('title',"Revenue and Collection(s)");
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $reportBeginDate = $page->field('batch_begin_date')||'01/01/1800';
	my $reportEndDate = $page->field('batch_end_date')||'01/01/9999';
	my $orgId = $page->field('org_id');
	my $person_id = $page->field('person_id')||undef;
	my $batch_from = $page->field('batch_id_from')||undef;
	my $batch_to = $page->field('batch_id_to')||undef;
	my $format_report = $page->field('format');
	my $orgIntId = undef;
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;
	my @data=undef;	

	my $hardCopy = $page->field('printReport');
	my $html;
	my $textOutputFilename;

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openRawPrintHandle ($printerDevice);
	
	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	my $allPub =
	{
		reportTitle => $self->heading(),
		columnDefn =>
			[
			{ colIdx => 0, head => 'Physican ID',  dAlign => 'LEFT' },			
			{ colIdx => 1, head => 'FFS Prof', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 2, head => 'X-Ray', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 3, head => 'Lab', summarize => 'sum', , dformat => 'currency' },
			{ colIdx => 4, head => 'Total Non-Cap Prod', summarize => 'sum', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 5, head => 'Cap Prof', summarize => 'sum', , dformat => 'currency' },
			{ colIdx => 6, head => 'Cap X-Ray', summarize => 'sum', dformat => 'currency' },
			{ colIdx => 7, head => 'Cap Lab', summarize => 'sum', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 8, head => 'Total Cap Prod', summarize => 'sum', , dformat => 'currency' },
			{ colIdx => 9, head => 'Total Prof Prod', summarize => 'sum', dformat => 'currency' },			
			{ colIdx => 10, head => 'Grand Total Prod', summarize => 'sum', dformat => 'currency' },			
			{ colIdx => 11, head =>'Recpt Adj', summarize => 'sum',  dformat => 'currency' },			
			{ colIdx => 12, head =>'Ancill Pmts', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 13, head =>'Prof Pmts', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 14, head =>'FFS Pmts', summarize => 'sum',  dformat => 'currency' },			
			{ colIdx => 15, head =>'Cap Pmts', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 16, head =>'Net Recpts', summarize => 'sum',  dformat => 'currency' },	
			{ colIdx => 17, head =>'% To Gross', tAlign=>'RIGHT',tDataFmt=> '&{sum_percent:16,10}'},	
			{ colIdx => 18 ,head =>'Hospital Visits', summarize => 'sum',  },				
			{ colIdx => 19, head =>'Office Visits', summarize => 'sum',  },			
			{ colIdx => 20, head =>'Avg Chrg per Visit', summarize => 'sum',  dformat => 'currency' },	
		],
	};		

	my $collPub =
	{
		reportTitle => 'Collection Information',
		columnDefn =>
			[
			{ colIdx => 0, head => 'Physican ID',  dAlign => 'LEFT' },			
			{ colIdx => 1, head => 'FFS Prof', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 2, head => 'X-Ray', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 3, head => 'Lab', summarize => 'sum', , dformat => 'currency' },
			{ colIdx => 4, head => 'Total Non-Cap Prod', summarize => 'sum', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 5, head => 'Cap Prof', summarize => 'sum', , dformat => 'currency' },
			{ colIdx => 6, head => 'Cap X-Ray', summarize => 'sum', dformat => 'currency' },
			{ colIdx => 7, head => 'Cap Lab', summarize => 'sum', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 8, head => 'Total Cap Prod', summarize => 'sum', , dformat => 'currency' },
			{ colIdx => 9, head => 'Total Prof Prod', summarize => 'sum', dformat => 'currency' },			
			{ colIdx => 10, head => 'Grand Total Prod', summarize => 'sum', dformat => 'currency' },					
		],
	};		
	my $prodPub =
		{
			reportTitle => 'Production Information',
			columnDefn =>
				[	
				{ colIdx => 0, head => 'Physican ID',  dAlign => 'LEFT' },	
				{ colIdx => 1, head =>'Recpt Adj', summarize => 'sum',  dformat => 'currency' },							
				{ colIdx => 2, head =>'Ancill Pmts', summarize => 'sum',  dformat => 'currency' },
				{ colIdx => 3, head =>'Prof Pmts', summarize => 'sum',  dformat => 'currency' },
				{ colIdx => 4, head =>'FFS Pmts', summarize => 'sum',  dformat => 'currency' },			
				{ colIdx => 5, head =>'Cap Pmts', summarize => 'sum',  dformat => 'currency' },
				{ colIdx => 6, head =>'Net Recpts', summarize => 'sum',  dformat => 'currency' },			
				{ colIdx => 7, head =>'% To Gross',tAlign=>'RIGHT', tDataFmt=> '&{sum_percent:6,11}', dAlign=>'Right' },
				{ colIdx => 8 ,head =>'Hospital Visits', summarize => 'sum',  },			
				{ colIdx => 9, head =>'Office Visits', summarize => 'sum',  },			
				{ colIdx => 10, head =>'Avg Chrg per Visit',  dformat => 'currency' },			
			],
	};		
	my $rev_coll = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page,STMTMGRFLAG_NONE,'sel_revenue_collection',$reportBeginDate,$reportEndDate,
	,$orgIntId,$person_id,$batch_from,$batch_to,$page->session('org_internal_id'));
	my @data = ();	
	my @data2 = ();
	foreach (@$rev_coll)
	{
		
		next unless $_->{provider}; 				
		my $visit = $STMTMGR_REPORT_ACCOUNTING->getRowAsHash($page,STMTMGRFLAG_NONE,'selGetVisit',$reportBeginDate,$reportEndDate,
						,$orgIntId,$_->{provider},$batch_from,$batch_to,$page->session('org_internal_id'));
		$_->{total_non_cap_prod} = $_->{ffs_prof} + $_->{x_ray} + $_->{lab};
		$_->{total_cap_prod} = $_->{cap_ffs_prof} + $_->{cap_x_ray}+ $_->{cap_lab};
		$_->{total_prof_prod} = $_->{ffs_prof} + $_->{cap_ffs_prof};
		$_->{grand_total_prod} = $_->{total_non_cap_prod} +$_->{total_cap_prod};
		$_->{net_recpts} = $_->{prof_pmt} + $_->{ancill_pmt} +$_->{refund};
		$_->{gross_per} = sprintf  "%3.2f", ($_->{net_recpts} / $_->{grand_total_prod} )*100 if $_->{grand_total_prod} > 0;
		$_->{chrg_per_visit} = $visit->{visits} / $_->{grand_total_prod} if  $_->{grand_total_prod} >0;
		$_->{prof_pmt} ;
		$_->{avg_cost_vist} = $_->{grand_total_prod} / $visit->{office_visit} if $visit->{office_visit} > 0;
		my @rowData = 
		(	
			$_->{provider},
			$_->{ffs_prof},
			$_->{x_ray},
			$_->{lab},
			$_->{total_non_cap_prod},
			$_->{cap_ffs_prof},
			$_->{cap_x_ray},
			$_->{cap_lab},
			$_->{total_cap_prod},
			$_->{total_prof_prod},
			$_->{grand_total_prod},
		);
		my @rowData2 =
		(
			$_->{provider},
			$_->{refund},
			$_->{ancill_pmt},
			$_->{prof_pmt},
			$_->{ffs_pmt},
			$_->{cap_pmt},
			$_->{net_recpts},
			$_->{gross_per}||'0.00',
			$visit->{hospital_visit},			
			$visit->{office_visit},
			$_->{avg_cost_vist}||'0',
			$_->{grand_total_prod},			
		);
		if ($format_report != 0)
		{
			push(@data,[@rowData, @rowData2[1..scalar(@rowData2)] ]);	
		}
		else
		{
			push(@data2, \@rowData2);		
			push(@data, \@rowData);		
		}
	}
	if($format_report != 0)
	{		
		$html .= createHtmlFromData($page, 0, \@data,$allPub);			
		$textOutputFilename = createTextRowsFromData($page, 0, \@data, $allPub);
		$html = ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version</a> <br>} : "" ) . $html;
		$self->heading("Revenue Collection Report");

		if ($hardCopy == 1 and $printerAvailable) {
			my $reportOpened = 1;
			open (ASCIIREPORT, $textOutputFilename) or $reportOpened = 0;
			if ($reportOpened) {
				while (my $reportLine = <ASCIIREPORT>) {
					print $printHandle $reportLine;
				}
			}
			close ASCIIREPORT;
		}
	}
	else
	{
		my ($collFilename, $prodFilename);
		$html .="<b>PRODUCTION INFORMATION<b>";
		$html .= createHtmlFromData($page, 0, \@data,$collPub);
		$collFilename = createTextRowsFromData($page, 0, \@data, $collPub);
		$html .="<BR><BR><b>COLLECTION INFORMATION<b>";
		$html .= createHtmlFromData($page, 0, \@data2,$prodPub);	
		$prodFilename = createTextRowsFromData($page, 0, \@data2, $prodPub);
		$html = ($prodFilename ? qq{<a href="/temp$prodFilename">Collection Information (Printable version)</a> <br>} : "" ) . $html;
		$html = ($collFilename ? qq{<a href="/temp$collFilename">Production Information (Printable version)</a> <br>} : "" ) . $html;
		$self->heading("Revenue / Collection Report");

		if ($hardCopy == 1 and $printerAvailable) {
			my $reportOpened = 1;
			my $tempDir = $CONFDATA_SERVER->path_temp();
			open (ASCIIREPORT, $tempDir.$collFilename) or $reportOpened = 0;
			if ($reportOpened) {
				while (my $reportLine = <ASCIIREPORT>) {
					print $printHandle $reportLine;
				}
			}
			close ASCIIREPORT;

			print $printHandle "\f";

			my $reportOpened = 1;
			open (ASCIIREPORT, $tempDir.$prodFilename) or $reportOpened = 0;
			if ($reportOpened) {
				while (my $reportLine = <ASCIIREPORT>) {
					print $printHandle $reportLine;
				}
			}
			close ASCIIREPORT;
		}
	}
	return $html
	
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
