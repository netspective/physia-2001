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
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

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
			new CGI::Dialog::Field(caption => 'Batch ID From', name => 'batch_id_from', size => 12,options=>FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(caption => 'Batch ID To', name => 'batch_id_to', size => 12,options=>FLDFLAG_REQUIRED),

			]),
			new CGI::Dialog::Field(type => 'select',
							style => 'radio',
							selOptions => 'No:0;Yes:1',
							caption => 'Include Associated Orgs: ',
							preHtml => "<B><FONT COLOR=DARKRED>",
							postHtml => "</FONT></B>",
							name => 'include_org',options=>FLDFLAG_REQUIRED,
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
}

sub prepare_detail_payment
{
	my ($self, $page) = @_;
	my $orgId = $page->field('org_id');
	my $person_id = $page->field('person_id');
	my $batch_from = $page->field('batch_id_from');
	my $batch_to = $page->field('batch_id_to');
	my $include_org =$page->field('include_org');
	my $batch_date = $page->param('batch_date');
	my $orgIntId = undef;
	my $html =undef;
	$orgIntId = $page->param('org_internal_id');#$STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;

	my $hardCopy = $page->field('printReport');
	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openRawPrintHandle ($printerDevice);

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	my $pub = {
		reportTitle => "Daily Audit Recap - $batch_date",
		columnDefn =>
		[
			{colIdx => 0, groupBy=>'#0#',head => 'Invoice', dAlign => 'left',url => q{javascript:chooseItemForParent('/invoice/#0#/summary') }, },
			{colIdx => 1,head => 'Physican', dAlign => 'left',},
			{colIdx => 2,,head => 'Patient',dAlign =>'left' , hAlign =>'left', dataFmt => '#16# <A HREF = "/person/#2#/account">#2#</A>'},
			{colIdx => 3,head => 'Proc Code', dAlign => 'center'},
			{colIdx => 4,head => 'Proc Name', dAlign => 'center'},
			{colIdx => 5,head => 'Service From', dAlign => 'center'},
			{colIdx => 6,head => 'Service To', dAlign => 'center'},
			{colIdx => 7,head => 'Diag Code',dAlign => 'center'},
			{colIdx => 8,head => 'Chrgs', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
			{colIdx => 9,head => 'Misc Chrgs', dAlign => 'center',summarize => 'sum',dformat => 'currency'},
			{colIdx => 10,head => 'Per W/O', summarize => 'sum',  dformat => 'currency' },
			{colIdx => 11,head => 'Ins W/O', summarize => 'sum',  dformat => 'currency' },
			{colIdx => 12,head => 'Ins Rcpts', summarize => 'sum',  dformat => 'currency' },
			{colIdx => 13,head => 'Per Rcpts', summarize => 'sum',  dformat => 'currency' },
			{colIdx => 14,head => 'Refund', summarize => 'sum',  dformat => 'currency',},
			{colIdx => 15,head => 'Payment Type', dAlign => 'center',},

		],
	};
	my $daily_audit_detail = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page,STMTMGRFLAG_NONE,'sel_daily_audit_detail',
		$batch_date,$orgIntId,$person_id,$batch_from,$batch_to,$page->session('org_internal_id'));
	my @data = ();
	my $trackInvoice=undef;
	foreach (@$daily_audit_detail)
	{

		if ($trackInvoice ne $_->{invoice_id})
		{
			$trackInvoice = $_->{invoice_id};
		}
		else
		{
			$_->{care_provider_id}='';
			$_->{patient_id}='';
			$_->{simple_name}='';
		};

		my @rowData =
		(
			$_->{invoice_id},
			$_->{care_provider_id},
			$_->{patient_id},
			$_->{code}||"UNK",
			$_->{caption},
			$_->{service_begin_date},
			$_->{service_end_date},
			$_->{rel_diags},
			$_->{total_charges},
			$_->{misc_charges},
			$_->{person_write_off},
			$_->{insurance_write_off},
			$_->{insurance_pay},
			$_->{person_pay},
			$_->{refund},
			$_->{pay_type},
			$_->{simple_name}
		);
		push(@data, \@rowData);
	}

	my $textOutputFilename = createTextRowsFromData($page, STMTMGRFLAG_NONE, \@data, $pub);
	$html = '<b style="font-family:Helvetica; font-size:12pt">(Batch Date '. $batch_date . ' ) </b><br><br>' . createHtmlFromData($page, 0, \@data,$pub);

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

	$html = ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version</a> <br>} : "" ) . $html;

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
	my $batch_from = $page->field('batch_id_from');
	my $batch_to = $page->field('batch_id_to')||undef;
	my $orgResult = undef;
	my $include_org =$page->field('include_org') ;
	my $orgIntId;
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;
	my @data=();
	my $html;
	my $textOutputFilename;

	my $hardCopy = $page->field('printReport');
	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openRawPrintHandle ($printerDevice);

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	my $pub ={
		reportTitle => $self->heading(),
		columnDefn =>
			[
			{ colIdx =>13 , groupBy=>'#13#', head=>'Facility',hAlign=>'LEFT'},
			{ colIdx => 0 ,head => 'Batch Date', dataFmt => '#0#', dAlign => 'RIGHT' ,
			url => qq{javascript:doActionPopup('#hrefSelfPopup#&detail=payment&batch_date=#0#&org_internal_id=#14#',null,'width=900,height=600,scrollbars,resizable')}},
			{ colIdx => 1, head => 'Chrgs', summarize => 'sum', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 2, head => 'Misc Chrgs', summarize => 'sum', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 3, head => 'Per W/O', summarize => 'sum', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 4, head => 'Ins W/O', summarize => 'sum', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 5, head => 'Net Chrgs', summarize => 'sum', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 6, head => 'Bal Trans', summarize => 'sum', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 7, head => 'Ins Rcpts', summarize => 'sum', dataFmt => '#9#', dformat => 'currency' },
			{ colIdx => 8, head => 'Per Rcpts', summarize => 'sum', dataFmt => '#8#', dformat => 'currency' },
			{ colIdx => 9, head => 'Refunds', summarize => 'sum',  dformat => 'currency' },
			{ colIdx => 10, head =>'Ttl Rcpts', summarize => 'sum', dformat => 'currency' },
			{ colIdx => 11,head =>'Collection %' ,tAlign=>'RIGHT',sAlign=>'RIGHT',tDataFmt=>'&{sum_percent:10,12}' ,dAlign=>'RIGHT'},
		],
	};
	$orgResult = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selChildernOrgs',
			$page->session('org_internal_id'),$orgIntId, $include_org);
	foreach my $orgValue (@$orgResult)
	{
		my $daily_audit = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page,STMTMGRFLAG_NONE,'sel_daily_audit',$reportBeginDate,$reportEndDate,
		,$orgValue->{org_internal_id},$person_id,$batch_from,$batch_to,$page->session('org_internal_id'));
		foreach (@$daily_audit)
		{
			$_->{tlt_rcpts}=$_->{person_pay} + $_->{insurance_pay} + $_->{refund};
			$_->{tlt_chrgs}=$_->{total_charges}+$_->{misc_charges};
			$_->{collection_per} = $_->{tlt_chrgs} > 0 ? sprintf  "%3.2f", ($_->{tlt_rcpts} / $_->{tlt_chrgs} )*100 : '0.00' ;
			my @rowData =
			(
				$_->{invoice_date},
				$_->{total_charges},
				$_->{misc_charges},
				$_->{person_write_off},
				$_->{insurance_write_off},
				$_->{total_charges} + $_->{misc_charges} + $_->{charge_adjust}, #Net Charges
				$_->{balance_transfer},
				$_->{insurance_pay},
				$_->{person_pay},
				$_->{refund},
				$_->{person_pay} + $_->{insurance_pay} + $_->{refund},
				$_->{collection_per},
				$_->{tlt_chrgs},
				$orgValue->{org_id},
				$orgValue->{org_internal_id}
			);
			push(@data, \@rowData);
		}
	}

	$html .= createHtmlFromData($page, 0, \@data,$pub);
	$textOutputFilename = createTextRowsFromData($page, STMTMGRFLAG_NONE, \@data, $pub);

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
#	return $html
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
