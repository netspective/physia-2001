##############################################################################
package App::Dialog::Report::Org::General::Billing::ClaimStatus;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Dialog::Field::Insurance;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Report::ClaimStatus;
use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

use enum qw(BITMASK:FLAG_ GETCOUNTS);

my $typeOrg = App::Universal::ENTITYTYPE_ORG;

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'claimStatus');
	$self->{heading} = 'Claims Status';

	$self->addContent(
		new CGI::Dialog::Field::Duration(caption => 'Read Batch Report Date',
			name => 'report',
			options => FLDFLAG_REQUIRED,
		),

		new CGI::Dialog::Field::Duration(
			name => 'service',
			caption => 'Start/End Service Date',
			begin_caption => 'Service Begin Date',
			end_caption => 'Service End Date',
		),

		new App::Dialog::Field::Insurance::Plan(caption => 'Claim Number(s)',
			name => 'claim_numbers',
			findPopup => '/lookup/claim',
			findPopupAppendValue => ',',
		),

		new CGI::Dialog::Field(caption => 'Payer Type',
			name => 'payer_type',
			type => 'select',
			fKeyStmtMgr => $STMTMGR_RPT_CLAIM_STATUS,
			fKeyStmt => 'sel_payer_type',
			fKeyDisplayCol => 0,
			fKeyValueCol => 1,
		),

		new CGI::Dialog::Field(caption => 'Insurance Company ID',
			name => 'ins_org_id',
			type => 'select',
			fKeyStmtMgr => $STMTMGR_RPT_CLAIM_STATUS,
			fKeyStmt => 'sel_distinct_ins_org_id_by_id',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			fKeyStmtBindSession=>['org_internal_id']
		),

		new App::Dialog::Field::Insurance::Product(caption => 'Insurance Product',
			name => 'product_name',
			findPopup => '/lookup/insproduct/insorgid/itemValue',
			findPopupControlField => '_f_ins_org_id'
		),

		new App::Dialog::Field::Insurance::Plan(caption => 'Insurance Plan',
			name => 'plan_name',
			findPopup => '/lookup/insplan/product/itemValue',
			findPopupControlField => '_f_product_name'
		),

		new App::Dialog::Field::Person::ID(caption => 'Physician/Provider ID',
			name => 'provider_id',
			types => ['Physician'],
		),

		new App::Dialog::Field::Organization::ID(caption => 'Facility ID',
			name => 'facility_id',
			types => ['Facility'],
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

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('report_begin_date', $startDate);
	$page->field('report_end_date', $startDate);
	$page->field('payer', -11);
	$page->field('ins_org_id', '');
}

sub buildSqlStmt
{
	my ($self, $page, $flags) = @_;

	my $facilityId  = $page->field('facility_id');
	my $internalFacilityId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId',
		$page->session('org_internal_id'), $facilityId);

	my $startDate   = $page->field('report_begin_date');
	my $endDate     = $page->field('report_end_date');

	my $claimNumberCond;
	my $insuranceNameCond;
	my $insuranceProductCond;
	my $insurancePlanCond;
	my $providerCond;
	my $facilityCond;
	my $insId = $page->param('_f_ins_org_id');
	my $insOrgId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId',
		$page->session('org_internal_id'), $insId);

	#my $insOrgId = $page->param('_f_ins_org_id');
	my $productName = $page->param('_f_product_name');
	my $planName = $page->param('_f_plan_name');
	my $providerId = $page->param('_f_provider_id');
	my $claimNumbers = $page->param('_f_claim_numbers');

	$claimNumberCond = qq{and Invoice.invoice_id in ($claimNumbers)} if $claimNumbers;

	$insuranceNameCond = qq{and Insurance.ins_org_id = $insOrgId} if $insOrgId;
	$insuranceProductCond = qq{and Insurance.product_name = '$productName'}	if $productName;
	$insurancePlanCond = qq{and Insurance.plan_name = '$planName'} if $planName;

	my $transTable;
	if ($providerId || $facilityId)
	{
		$transTable = qq{Transaction, };
	}

	$providerCond = qq{
		and Transaction.trans_id = Invoice.main_transaction
		and upper(Transaction.provider_id) = upper('$providerId')
	} if $providerId;

	if ($facilityId)
	{
		if ($providerId)
		{
			$facilityCond = qq{
				and Transaction.service_facility_id = $internalFacilityId
			};
		}
		else
		{
			$facilityCond = qq{
				and Transaction.trans_id = Invoice.main_transaction
				and Transaction.service_facility_id = $internalFacilityId
			};
		}
	}

	my $payerTypeCond;
	my $payerType = $page->param('_f_payer_type');
	$payerTypeCond = qq{and Invoice_Billing.bill_party_type = $payerType}
		if $payerType != -1;

	my ($columns, $groupBy, $invoiceStatusCond);
	if ($flags & FLAG_GETCOUNTS)
	{
		$columns = qq{Invoice_Status.caption as caption, count(Invoice_Status.caption) as cnt,
			Invoice.invoice_status
		};

		$groupBy = qq{group by Invoice_Status.caption, Invoice.invoice_status};
	}
	else
	{
		my $invoiceStatus = $page->param('invoice_status');
		$invoiceStatusCond = qq{and Invoice.invoice_status = $invoiceStatus};

		my $submitDate;
		if ($invoiceStatus == 4)
		{
			$submitDate = qq{to_char(nvl(submit_date, invoice_date), '$SQLSTMT_DEFAULTDATEFORMAT') as submit_date,};
		}
		else
		{
			$submitDate = qq{to_char(submit_date, '$SQLSTMT_DEFAULTDATEFORMAT') as submit_date,};
		}

		$columns = qq{to_char(Invoice.invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date,
			$submitDate
			decode(Invoice_Billing.bill_party_type,0,Invoice_Billing.bill_to_id,1,Invoice_Billing.bill_to_id,(select org_id FROM ORG WHERE org_internal_id = Invoice_Billing.bill_to_id)) as  bill_to_id,
			product_name as insurance_product,
			plan_name as insurance_plan,
			total_cost as total_charge,
			total_adjust,
			Invoice.invoice_id,
			Invoice.client_id,
			(select ia.value_text
			 FROM insurance_attribute  ia
			 WHERE ia.parent_id = Insurance.parent_ins_id
			 AND ia.item_name = 'Contact Method/Telephone/Primary' ) as phone_number,
			 Person.simple_name
		};

		$groupBy = qq{order by 3,1};
	}

	my $html = qq{
		select $columns
			from $transTable Insurance, Invoice_Billing, Invoice_Status, Invoice, Person
			where Invoice.owner_id = ?
				and Invoice.owner_type = $typeOrg
				and Invoice.invoice_date between to_date(? || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and to_date(? || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and Invoice.Invoice_ID in (
					Select Parent_ID from Invoice_Item
					Where (? Is NULL or Invoice_Item.service_begin_date >= to_date(? || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT'))
					and (? Is NULL or Invoice_Item.service_end_date <= to_date(? || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT'))
				)
				$claimNumberCond
				$invoiceStatusCond
				and Invoice_Status.id = Invoice.invoice_status
				and Invoice_Billing.invoice_id = Invoice.invoice_id
				$payerTypeCond
				and Insurance.ins_internal_id (+)= Invoice_Billing.bill_ins_id
				and Invoice_Billing.bill_sequence=1
				and Invoice_BIlling.invoice_item_id is NULL
				$insuranceNameCond
				$insuranceProductCond
				$insurancePlanCond
				$providerCond
				$facilityCond
				and Invoice.client_id = Person.person_id
			$groupBy
	};

	return $html;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $startDate   = $page->field('report_begin_date');
	my $endDate     = $page->field('report_end_date');
	my $serviceBeginDate = $page->field('service_begin_date');
	my $serviceEndDate = $page->field('service_end_date');

	my $hardCopy = $page->field('printReport');
	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openRawPrintHandle ($printerDevice);

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	my $orgId = $page->session('org_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId);

	my $publishDefn = {
		reportTitle => $self->heading (),
		columnDefn =>
		[
			{	head => 'Claims',
				url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=status&invoice_status=#2#&status_caption=#0#', null, 'width=800,height=600,scrollbars,resizable')},
				hint => 'View Details'
			},
			{head => 'Count', dAlign => 'right'},
		],
	};

	my $sqlStmt = $self->buildSqlStmt($page, $flags | FLAG_GETCOUNTS);
	my $data = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsArray($page, STMTMGRFLAG_DYNAMICSQL, $sqlStmt, $orgIntId, $startDate, $endDate, $serviceBeginDate, $serviceBeginDate, $serviceEndDate, $serviceEndDate);
	my $textOutputFilename = createTextRowsFromData($page, STMTMGRFLAG_NONE, $data, $publishDefn);

	my $html = qq{
	<table cellpadding=10>
		<tr align=center valign=top>
		<td>
			@{[ $STMTMGR_RPT_CLAIM_STATUS->createHtml($page, STMTMGRFLAG_DYNAMICSQL,
				$sqlStmt,
				[$orgIntId, $startDate, $endDate, $serviceBeginDate, $serviceBeginDate, $serviceEndDate, $serviceEndDate], undef, undef, $publishDefn) ]}
		</td>
		</tr>
	</table>
	};
	my $tempDir = $CONFDATA_SERVER->path_temp();
	my $Constraints = [
	{ Name => "Read Batch Report Date ", Value => $startDate."  ".$endDate},
	{ Name => "Start/End Service Date ", Value => $serviceBeginDate."  ".$serviceEndDate},
	{ Name => "Claim Number(s) ", Value => $page->field('claim_numbers')},
	{ Name => "Payer Type ", Value => $page->field('payer_type')},
	{ Name => "Insurance Company ID ", Value => $page->field('ins_org_id')},
	{ Name => "Insurance Product ", Value => $page->field('product_name')},
	{ Name => "Insurance Plan ", Value => $page->field('plan_name')},
	{ Name => "Physician/Provider ID  ", Value => $page->field('provider_id')},
	{ Name => "Facility ID ", Value => $page->field('facility_id')},
	{ Name=> "Print Report ", Value => ($hardCopy) ? 'Yes' : 'No' },
	{ Name=> "Printer ", Value => $printerDevice},
	];
	my $FormFeed = appendFormFeed($tempDir.$textOutputFilename);
	my $fileConstraint = appendConstraints($page, $tempDir.$textOutputFilename, $Constraints);
	if ($hardCopy == 1 and $printerAvailable) {
		my $reportOpened = 1;
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

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub prepare_detail_status
{
	my ($self, $page) = @_;

	my $startDate   = $page->field('report_begin_date');
	my $endDate     = $page->field('report_end_date');
	my $serviceBeginDate = $page->field('service_begin_date');
	my $serviceEndDate = $page->field('service_end_date');

	my $sqlStmt = $self->buildSqlStmt($page);

	my $pub = {
		columnDefn =>
		[
			{head => 'Bill To',groupBy=>'#2#' ,sAlign=>'left',colIdx => 2, dAlign => 'left',hAlign=>'left'},
			{head => 'Claim ID', colIdx => 7, dAlign => 'center',
				url => q{javascript:chooseItemForParent('/invoice/#7#/summary') },
				hint => 'View Invoice Summary',
			},
			{head => 'Patient', colIdx => 8, dAlign => 'center', dataFmt => '#11#',
				url => q{javascript:chooseItemForParent('/person/#8#/account')},
				hint => 'View #8# Account',
			},
			{head => 'Invoice Date', colIdx => 0,},
			{head => 'Submit Date', colIdx => 1,},
			{head => 'Insurance Product', colIdx => 3, dAlign => 'center'},
			{head => 'Insurance Plan', colIdx => 4, dAlign => 'center'},
			{head => 'Total Charge', colIdx => 5,
				dformat => 'currency', tAlign => 'RIGHT', summarize=>'sum',
				tDataFmt => '&{avg_currency:&{?}}<BR>&{sum_currency:&{?}}'
			},
			{head => 'Total Adjust', colIdx => 6,
				dformat => 'currency', tAlign => 'RIGHT', summarize=>'sum',
			},
			{head =>'Contact Number' , colIdx =>9},
			{head =>'Notes' , colIdx =>10},
		],
	};

	my @data = ();
	my $claimStatus = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmt,$page->session('org_internal_id'), $startDate, $endDate, $serviceBeginDate, $serviceBeginDate, $serviceEndDate, $serviceEndDate);
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
		$_->{invoice_date},
		$_->{submit_date},
		$_->{bill_to_id},
		$_->{insurance_product},
		$_->{insurance_plan},
		$_->{total_charge},
		$_->{total_adjust},
		$_->{invoice_id},
		$_->{client_id},
		$_->{phone_number},
		$notes,
		$_->{simple_name});
		push(@data, \@rowData);
	};

	my $caption =$page->param('status_caption');
	my $html =qq{<b style="font-family:Helvetica; font-size:12pt">('$caption' Claims) </b><br><br>};
	$html .= createHtmlFromData($page, 0, \@data,$pub);
	#$page->addContent('<b style="font-family:Helvetica; font-size:12pt">('. $page->param('status_caption') . ' Claims) </b><br><br>',
	#	@{[ $STMTMGR_RPT_CLAIM_STATUS->createHtml($page, STMTMGRFLAG_DYNAMICSQL, #| STMTMGRFLAG_DEBUG,
	#	$sqlStmt,	[$page->session('org_internal_id'), $startDate, $endDate, $serviceBeginDate, $serviceBeginDate, $serviceEndDate, $serviceEndDate], undef, undef, $publishDefn) ]}
	#);
	$page->addContent($html);
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
