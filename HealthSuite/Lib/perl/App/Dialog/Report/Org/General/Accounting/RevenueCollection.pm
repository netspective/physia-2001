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
	$page->field('org_id', $page->param('_f_org_id') || $page->session('org_id') );
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
	my $html;
	my $allPub =
	{
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
			{ colIdx => 11, head =>'Ancill Pmts', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 12, head =>'Prof Pmts', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 13, head =>'FFS Pmts', summarize => 'sum',  dformat => 'currency' },			
			{ colIdx => 14, head =>'Cap Pmts', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 15, head =>'Net Recpts', summarize => 'sum',  dformat => 'currency' },			
			{ colIdx => 16, head =>'% To Gross', },			
			{ colIdx => 17, head =>'Office Visits', summarize => 'sum',  },			
			{ colIdx => 18, head =>'Avg Chrg per Visit', summarize => 'sum',  dformat => 'currency' },			
		],
	};		

	my $collPub =
	{
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
			columnDefn =>
				[	
				{ colIdx => 0, head => 'Physican ID',  dAlign => 'LEFT' },	
				{ colIdx => 1, head =>'Ancill Pmts', summarize => 'sum',  dformat => 'currency' },
				{ colIdx => 2, head =>'Prof Pmts', summarize => 'sum',  dformat => 'currency' },
				{ colIdx => 3, head =>'FFS Pmts', summarize => 'sum',  dformat => 'currency' },			
				{ colIdx => 4, head =>'Cap Pmts', summarize => 'sum',  dformat => 'currency' },
				{ colIdx => 5, head =>'Net Recpts', summarize => 'sum',  dformat => 'currency' },			
				{ colIdx => 6, head =>'% To Gross', dAlign=>'Right' },			
				{ colIdx => 7, head =>'Office Visits', summarize => 'sum',  },			
				{ colIdx => 8, head =>'Avg Chrg per Visit',  dformat => 'currency' },			
			],
	};		
	my $rev_coll = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page,STMTMGRFLAG_NONE,'sel_revenue_collection',$reportBeginDate,$reportEndDate,
	,$orgIntId,$person_id,$batch_from,$batch_to);
	my @data = ();	
	my @data2 = ();
	foreach (@$rev_coll)
	{
		
		#$_->{cap_pmt}=0;			
		$_->{total_non_cap_prod} = $_->{ffs_prof} + $_->{x_ray} + $_->{lab};
		$_->{total_cap_prod} = $_->{cap_ffs_prof} + $_->{cap_x_ray}+ $_->{cap_lab};
		$_->{total_prof_prod} = $_->{ffs_prof} + $_->{cap_ffs_prof};
		$_->{grand_total_prod} = $_->{total_non_cap_prod} +$_->{total_cap_prod};
		$_->{net_recpts} = $_->{ffs_pmt} + $_->{cap_pmt} ;
		$_->{gross_per} = sprintf  "%2.2f", ($_->{net_recpts} / $_->{grand_total_prod} )*100 if $_->{grand_total_prod} > 0;
		$_->{chrg_per_visit} = $_->{visits} / $_->{grand_total_prod} if  $_->{grand_total_prod} >0;
		$_->{prof_pmts} = $_->{net_recpts} - $_->{ancill_pmt} ;
		$_->{avg_cost_vist} = $_->{grand_total_prod} / $_->{appt} if $_->{appt} > 0;
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
			$_->{ancill_pmt},
			$_->{prof_pmts},
			$_->{ffs_pmt},
			$_->{cap_pmt},
			$_->{net_recpts},
			$_->{gross_per}||0,
			$_->{appt},
			$_->{avg_cost_vist}||'0'

		);
		if ($format_report != 0)
		{
			push(@data,[@rowData, @rowData2[1..8] ]);	
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
		$self->heading("Revenue Collection Report");
	}
	else
	{
		$html .="<b>PRODUCTION INFORMATION<b>";
		$html .= createHtmlFromData($page, 0, \@data,$collPub);
		$html .="<BR><BR><b>COLLECTION INFORMATION<b>";
		$html .= createHtmlFromData($page, 0, \@data2,$prodPub);	
		$self->heading("Revenue / Collection Report");
	}
	return $html
	
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
