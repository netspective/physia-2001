##############################################################################
package App::Dialog::Report::Org::General::Accounting::ClaimStatus;
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

use App::Statements::Report::ClaimStatus;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-claim-status', heading => 'Claim Status');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'report',
				caption => 'Start/End Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),
			new CGI::Dialog::Field::Duration(
				name => 'service',
				caption => 'Start/End Service Date',
				begin_caption => 'Service Begin Date',
				end_caption => 'Service End Date',
				),
			new CGI::Dialog::Field(type => 'select',
				defaultValue=>'0',
				selOptions=>"Selected:0;All:1",
				name => 'product_select',
				caption => 'Claim Selection',
				hints=>"Select 'All' to search all claim statuses",
				onChangeJS => qq{showFieldsOnValues(event, [0], ['claim_status']);},
				),
			new CGI::Dialog::Field(name => 'claim_status',
				caption => 'Claim Status',
				style => 'multidual',
				type => 'select',
				caption => '',
				multiDualCaptionLeft => 'Claim Status',
				multiDualCaptionRight => 'Selected Status',
				width => '200',
				size => '8',
				fKeyStmtMgr => $STMTMGR_RPT_CLAIM_STATUS,
				fKeyStmt => 'sel_claim_status_used',
				fKeyDisplayCol => 0,
				fKeyValueCol => 1,
				#style => 'multicheck',
				defaultValue => 0
				),
			new App::Dialog::Field::OrgType(
				caption => 'Service Facility',
				name => 'service_facility_id',
				options => FLDFLAG_PREPENDBLANK,
				types => "'PRACTICE', 'CLINIC','FACILITY/SITE','DIAGNOSTIC SERVICES', 'DEPARTMENT', 'HOSPITAL', 'THERAPEUTIC SERVICES'"),

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
	$page->field('report_begin_date', $startDate);
	$page->field('report_end_date', $startDate);
	$page->field('product_select',0);
}

sub customValidate
{
	my ($self, $page) = @_;
	my $status = join(',',  $page->field('claim_status'));
	my $statusField = $self->getField('claim_status');
	$statusField->invalidate($page, "Claim status not selected.  To view all claim status select 'All Claims'.") if $status eq '' && !$page->field('product_select');
}

sub buildSqlStmt
{

	my ($self, $page, $flags) = @_;
	my $reportBeginDate = $page->field('report_begin_date');
	my $reportEndDate = $page->field('report_end_date');
	my $serviceBeginDate = $page->field('service_begin_date');
	my $serviceEndDate = $page->field('service_end_date');
	my $status = join(',',  $page->field('claim_status'));
	my $orgId = $page->session('org_internal_id');
	my $serviceId = $page->field('service_facility_id');
	my $prodSelect = $page->field('product_select');
	my $statusClause='';
	my $serviceClause='';
	my $dateClause;
	my $serviceDateClause;
	$statusClause = qq{i_s.id in ($status)  and} if !($status=~m/-1/) && defined $status && $prodSelect != 1;
	$dateClause =qq{ and  trunc(i.invoice_date) between to_date('$reportBeginDate', 'mm/dd/yyyy') and to_date('$reportEndDate', 'mm/dd/yyyy')}if($reportBeginDate ne '' && $reportEndDate ne '');
	$dateClause =qq{ and  trunc(i.invoice_date) <= to_date('$reportEndDate', 'mm/dd/yyyy')	} if($reportBeginDate eq '' && $reportEndDate ne '');
	$dateClause =qq{ and  trunc(i.invoice_date) >= to_date('$reportBeginDate', 'mm/dd/yyyy') } if($reportBeginDate ne '' && $reportEndDate eq '');
	$serviceClause =qq{ and t.service_facility_id = $serviceId} if $serviceId;
	my $orderBy = qq{order by i.invoice_date desc , i.invoice_id asc };

	if($serviceBeginDate ne '' && $serviceEndDate ne '')
	{
		$serviceDateClause = qq{ and i.invoice_id in
								(select parent_id from invoice_item ii
									where ii.service_begin_date >= to_date('$serviceBeginDate', 'mm/dd/yyyy')
									and ii.service_end_date <= to_date('$serviceEndDate', 'mm/dd/yyyy')
									and ii.item_type in (0,1,2)
									and ii.data_text_b is NULL
								)
							};
	}

	my $whereClause = qq{where $statusClause
						i.owner_type = 1
					and 	i.owner_id = '$orgId'
					and 	bs.id =ib.bill_sequence
					and     i.invoice_status = i_s.id
					and     t.trans_id = i.main_transaction
					and     ib.invoice_id = i.invoice_id
					and  	ct.id = t.bill_type
					and 	ib.BILL_SEQUENCE = 1
					and     ib.invoice_item_id is NULL
					and		i.client_id = p.person_id
					$dateClause
					$serviceClause
					$serviceDateClause
				   };
	my $columns = qq{i.invoice_id,
			i.total_items, i.client_id,
			to_char(i.invoice_date, 'MM/dd/YYYY') as invoice_date,
			i_s.caption as invoice_status,
			decode(ib.bill_party_type,0,ib.bill_to_id,1,ib.bill_to_id,(select org_id FROM ORG WHERE org_internal_id = ib.bill_to_id)) as  bill_to_id,
			i.total_cost,
			i.total_adjust,
			i.balance,
			i.reference,
			ct.caption,
			bs.caption as cap,
			p.simple_name};

	my $fromTable= qq{invoice i,
		   	invoice_status i_s,
		   	transaction t,
		   	invoice_billing ib,
		   	claim_type ct,
			bill_sequence bs,
			person p};

	my $sqlStmt = qq {select  $columns
			  from 	$fromTable
				$whereClause
				$orderBy		};

	return $sqlStmt;
}


sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub prepare_detail_payment
{
	my ($self, $page) = @_;

	my $startDate   = $page->field('report_begin_date');
	my $endDate     = $page->field('report_end_date');

	my $sqlStmt = $self->buildSqlStmt($page);

	my $publishDefn = {
		columnDefn =>
		[
			{head => 'Invoice ID', colIdx => 0, dAlign => 'left',
			},
			{head => 'Procedure Code', colIdx => 1, dAlign => 'center',
			},
			{head => 'Payer ID', colIdx => 2, dAlign => 'center',},
			{head => 'Payment Type', colIdx => 6, dAlign => 'center',},
			{head => 'Payment Date', colIdx => 3, dAlign => 'center'},
			{head => 'Authorization Number', colIdx => 4, dAlign => 'center'},
			{head => 'Payment Amount ',tAlign => 'RIGHT',tDataFmt => '&{sum_currency:&{?}}', colIdx => 5, dAlign => 'center',dformat => 'currency'},

		],
	};
	my $invoice_id = $page->param('payer');
	$page->addContent(
	'<b style="font-family:Helvetica; font-size:12pt">(Claim Payment Information) </b><br><br>',
	@{[ $STMTMGR_RPT_CLAIM_STATUS->createHtml($page, STMTMGRFLAG_NONE,
	'sel_claim_detail',[$invoice_id], undef, undef, $publishDefn) || "No pay"] }
	);
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $pub = {
		columnDefn => [
			{ colIdx => 0, head => 'Invoice ID', hAlign => 'center',dAlign => 'center',dataFmt => '#0#',
			url => qq{javascript:doActionPopup('#hrefSelfPopup#&detail=payment&payer=#0#',null,'width=800,height=600,scrollbars,resizable')},},
			{ colIdx => 1, head => 'Number Of Items',dAlign => 'center', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Client', dAlign => 'center',dataFmt => '#13# <A HREF = "/person/#2#/account">#2#</A>' },
			{ colIdx => 3, head => 'Invoice Date', dAlign => 'center',dataFmt => '#3#' },
			{ colIdx => 4, head => 'Invoice Status',dAlign => 'center' ,dataFmt => '#4#' },
			{ colIdx => 5, head => 'Bill To ID', dAlign => 'center',dataFmt => '#5#' },
			{ colIdx => 6, head => 'Total Cost', hAlign => 'center', dAlign => 'center',
			tAlign => 'RIGHT',tDataFmt => '&{sum_currency:&{?}}',dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => 'Total Adjustment', dAlign =>'center', dataFmt => '#7#',
			tDataFmt => '&{sum_currency:&{?}}', tAlign => 'RIGHT',dformat => 'currency' },
			{ colIdx => 8, head => 'Balance', dAlign => 'center',dataFmt => '#8#', dformat => 'currency',
			tDataFmt => '&{sum_currency:&{?}}', tAlign => 'RIGHT'},
			#{ colIdx => 9, head => 'Reference', dAlign => 'center',dataFmt => '#9#' },
			{ colIdx => 10, head => 'Bill To Type', dAlign => 'center',dataFmt => '#10#' },
			{ colIdx => 12, head => 'Notes',},
		],
	};

	my $sqlStmt = $self->buildSqlStmt($page, $flags);
	my $claimStatus = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmt);
	my @data = ();
	foreach (@$claimStatus)
	{
		my $sqlStmtNote = qq{select value_text from invoice_history where cr_user_id = 'EDI_PERSE' AND parent_id = $_->{invoice_id} and rownum < 6 order by item_id asc};
		my $getEDINotes = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmtNote);
		my $notes='';
		foreach my $value (@$getEDINotes)
		{
			$notes .= "<b>Note :</b> $value->{value_text} </br>";
		}
		my @rowData = (
		$_->{invoice_id},
		$_->{total_items}||'0',
		$_->{client_id},
		$_->{invoice_date},
		$_->{invoice_status},
		$_->{bill_to_id},
		$_->{total_cost},
		$_->{total_adjust}||'0',
		$_->{balance},
		$_->{reference},
		$_->{caption},
		$_->{cap},
		$notes,
		$_->{simple_name});
		push(@data, \@rowData);
	};

	my $hardCopy = $page->field('printReport');

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	my $html = createHtmlFromData($page, 0, \@data,$pub);

	my $textOutputFilename = createTextRowsFromData($page, 0,  \@data, $pub);

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