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
use App::Statements::Report::Accounting;
use App::Statements::Org;

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
					),
				new App::Dialog::Field::Organization::ID(caption =>'Site Organization ID', name => 'org_id'),
				new App::Dialog::Field::Person::ID(caption =>'Physican ID', name => 'person_id'),
			
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

#sub populateData
#{
#	my ($self, $page, $command, $activeExecMode, $flags) = @_;
#
#	$page->field('person_id', $page->session('person_id'));
#}


sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $reportBeginDate = $page->field('batch_begin_date')||'01/01/1800';
	my $reportEndDate = $page->field('batch_end_date')||'01/01/9999';
	my $orgId = $page->field('org_id');
	my $person_id = $page->field('person_id')||undef;
	my $batch_from = $page->field('batch_id_from')||undef;
	my $batch_to = $page->field('batch_id_to')||undef;	
	my $orgIntId = undef;
	my @data=();
	my $pub ={
		columnDefn =>
		[
		{colIdx => 12, head =>'Year',groupBy=>'#12#', dAlign => 'left',},
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
		{colIdx => 11,head => 'A/R', tDataFmt => '&{sum_currency:13}',sDataFmt => '&{sum_currency:13}',  dformat => 'currency' },
		],
		};
		
	
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;

	my $far = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE , 'sel_financial_monthly',$reportBeginDate,
	$reportEndDate,$orgIntId,$person_id,$page->session('org_internal_id'));
	my $total_ar = 0;
	foreach (@$far)	
	{
		$total_ar +=$_->{a_r};
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
		);
		push(@data, \@rowData);				
	}
	return createHtmlFromData($page, 0, \@data,$pub);
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;