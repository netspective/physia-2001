##############################################################################
package App::Dialog::Report::Org::General::Accounting::DailyAuditRecap;
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
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-daily-audit-recap', heading => 'Daily Audit Recap');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'batch',
				caption => 'Batch Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),
			new App::Dialog::Field::Organization::ID(caption =>'Site Organization ID', name => 'org_id'),
			new App::Dialog::Field::Person::ID(caption =>'Physican ID', name => 'person_id', ),
			new CGI::Dialog::MultiField(caption => 'Batch ID Range', name => 'batch_fields', 
						fields => [
			new CGI::Dialog::Field(caption => 'Batch ID From', name => 'batch_id_from', size => 12),
			new CGI::Dialog::Field(caption => 'Batch ID To', name => 'batch_id_to', size => 12),
			]),
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
	$page->field('org_id', $page->param('_f_org_id') || $page->session('org_id') );
}

sub prepare_detail_payment
{
	my ($self, $page) = @_;	
	my $orgId = $page->field('org_id');
	my $person_id = $page->field('person_id');
	my $batch_from = $page->field('batch_id_from');
	my $batch_to = $page->field('batch_id_to');
	my $orgIntId = undef;
	my $html =undef;	
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;	

	my $pub = {
		columnDefn =>
		[
			{head => 'Invoice ID', dAlign => 'left',url => q{javascript:chooseItemForParent('/invoice/#0#/summary') }, },					
			{head => 'Physican', dAlign => 'left',},
			{head => 'Proc Code', dAlign => 'center'},		
			{head => 'Proc Name', dAlign => 'center'},		
			{head => 'Service From', dAlign => 'center'},			
			{head => 'Service To', dAlign => 'center'},						
			{head => 'Diag Code',dAlign => 'center'},			
			{head => 'Chrgs', dAlign => 'center',tDataFmt => '&{sum_currency:&{?}}',dformat => 'currency' },			
			{head => 'Misc Chrgs', dAlign => 'center',tDataFmt => '&{sum_currency:&{?}}',dformat => 'currency'},
			{head => 'Chrg Adj', dAlign => 'center',tDataFmt => '&{sum_currency:&{?}}',dformat => 'currency'},			
			{head => 'Units', dAlign => 'center',tDataFmt => '&{sum:&{?}}'},
			{head => 'Unit Cost', dAlign => 'center',tDataFmt => '&{sum_currency:&{?}}',dformat => 'currency'},			
		],
	};
	my $batch_date = $page->param('batch_date');	
	my $daily_audit_detail = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page,STMTMGRFLAG_NONE,'sel_daily_audit_detail',
		$batch_date,$orgIntId,$person_id,$batch_from,$batch_to);	
	my @data = ();	
	foreach (@$daily_audit_detail)
	{	
	
		my @rowData = 
		(	
			$_->{invoice_id},			
			$_->{care_provider_id},
			$_->{code}||"UNK",
			$_->{caption},
			$_->{service_begin_date},
			$_->{service_end_date},
			$_->{rel_diags},
			$_->{total_charges},
			$_->{misc_charges},						
			$_->{charge_adjust},							
			$_->{units}||0,
			$_->{unit_cost}||0,
		);
		push(@data, \@rowData);
	}
	
	$html = '<b style="font-family:Helvetica; font-size:12pt">(Batch Date '. $batch_date . ' ) </b><br><br>' . createHtmlFromData($page, 0, \@data,$pub);	
	$page->addContent($html);

}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
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
	my $orgIntId = undef;
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;
	my @data=undef;	
	my $html;
	my $pub =
	{
		columnDefn =>
			[
			{ colIdx => 0, head => 'Batch Date', dataFmt => '#0#', dAlign => 'RIGHT' ,
			url => qq{javascript:doActionPopup('#hrefSelfPopup#&detail=payment&batch_date=#0#',null,'width=900,height=600,scrollbars,resizable')}},
			{ colIdx => 1, head => 'Chrgs', summarize => 'sum', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 2, head => 'Misc Chrgs', summarize => 'sum', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 3, head => 'Chrg Adj', summarize => 'sum', dataFmt => '#4#', dformat => 'currency' },
			{ colIdx => 4, head => 'Net Chrgs', summarize => 'sum', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 5, head => 'Bal Trans', summarize => 'sum', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 6, head => 'Ins Rcpts', summarize => 'sum', dataFmt => '#9#', dformat => 'currency' },
			{ colIdx => 7, head => 'Ins Wrt-Off', summarize => 'sum', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 8, head => 'Per Rcpts', summarize => 'sum', dataFmt => '#8#', dformat => 'currency' },
			{ colIdx => 9, head => 'Per Wrt-Off', summarize => 'sum', dataFmt => '#5#', dformat => 'currency' },			
			{ colIdx => 10, head =>'Ttl Rcpts', summarize => 'sum', dataFmt => '#10#', dformat => 'currency' },
			#{ colIdx => 11, head => 'End A/R', summarize => 'sum', dataFmt => '#11#', dformat => 'currency' },
		],
	};		
	my $daily_audit = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page,STMTMGRFLAG_NONE,'sel_daily_audit',$reportBeginDate,$reportEndDate,
	,$orgIntId,$person_id,$batch_from,$batch_to);
	my @data = ();	
	foreach (@$daily_audit)
	{
				
		my @rowData = 
		(	
			$_->{invoice_date},
			$_->{total_charges},
			$_->{misc_charges},
			$_->{charge_adjust},
			$_->{total_charges} + $_->{misc_charges} + $_->{charge_adjust}, #Net Charges						
			$_->{balance_transfer},								
			$_->{insurance_pay},					
			$_->{insurance_write_off},						
			$_->{person_pay},
			$_->{person_write_off},			
			$_->{person_pay} + $_->{insurance_pay},
		);
		push(@data, \@rowData);
	}
	
	$html .= createHtmlFromData($page, 0, \@data,$pub);
	return $html
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
