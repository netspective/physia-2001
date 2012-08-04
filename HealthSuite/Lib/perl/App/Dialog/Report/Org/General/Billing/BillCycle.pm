##############################################################################
package App::Dialog::Report::Org::General::Billing::BillCycle;
##############################################################################

use strict;
use Carp;
use Date::Calc qw(Delta_Days);
use App::Dialog::Report;

use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use App::Statements::Component::Invoice;
use App::Statements::Org;
use App::Statements::Report::Accounting;

use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

use App::Utilities::Statement;
use App::Statements::BillingStatement;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-bill-cycle', heading => 'Billing Cycle Report (Statements Preview)');

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Billing Cycle',
			name => 'bill_cycle',
			hints => 'Day of Month',
			maxValue => 28, minValue => 1,
			hints => 'Day of Month (1..28)',
			size => 2, maxLength => 2, type => 'integer',
			options => FLDFLAG_REQUIRED
		),
		new App::Dialog::Field::Person::ID(caption =>'Physican ID',
			name => 'person_id',
			types => ['Physician'],
		),
		#new App::Dialog::Field::OrgType(caption => 'Service Facility',
		#	name => 'service_facility_id',
		#	options => FLDFLAG_PREPENDBLANK,
		#	types => "'PRACTICE', 'CLINIC','FACILITY/SITE','DIAGNOSTIC SERVICES', 'DEPARTMENT', 'HOSPITAL', 'THERAPEUTIC SERVICES'"),
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

	my $orgInternalId = $page->session('org_internal_id');
	my $providerId = $page->field('person_id');
	my $billCycle = $page->field('bill_cycle');

	my $hardCopy = $page->field('printReport');
	my $html;
	my $textOutputFilename;

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	my $outstandingClaims;

	if ($providerId) {
		$outstandingClaims = $STMTMGR_STATEMENTS->getRowsAsHashList($page, STMTMGRFLAG_CACHE,
			'sel_statementClaims_perOrg_perProvider', $orgInternalId, $providerId);
	} else {
		$outstandingClaims = $STMTMGR_STATEMENTS->getRowsAsHashList($page, STMTMGRFLAG_CACHE,
			'sel_statementClaims_perOrg', $orgInternalId);
	}

	my $statements = App::Utilities::Statement::populateStatementsHash($page, $outstandingClaims,
		$orgInternalId, $page->field('bill_cycle'));

	my $pubDefn =
	{
		reportTitle => "Billing Cycle",
		columnDefn =>
		[
			{	head => 'Payer', colIdx => 0, summarize => 'count', dAlign => 'left', hAlign => 'left',
				url => qq{javascript:doActionPopup('#hrefSelfPopup#&detail=last4&billtoid=#7#&paytoid=#8#&patientid=#6#&billto_name=#9#',
					null,'location,status,width=700,height=400,scrollbars,resizable')},
				hint => 'View #7# Last 4 Statements',
			},
			{ head => 'Payer Type', colIdx => 1, hAlign => 'left',},
			{ head => 'Billing Org', colIdx => 10, hAlign => 'left',},

			{ head => 'Provider', colIdx => 2, hAlign => 'left',},
			{ head => 'Patient', colIdx => 3, url => '/person/#6#/account',  hAlign => 'left',
				hint => 'View #6# Account'
			},
			{ head => 'Amount Due', colIdx => 4, dformat => 'currency', summarize => 'sum',
				hAlign => 'right',
			},
			{ head => 'Claims', colIdx => 5,},
		],
	};

	my $pubText =
		{
			reportTitle => "Billing Cycle",
			columnDefn =>
			[
				{head => 'Payer', colIdx => 0, '222', dformat => '#6#' },
				{ head => 'Type', colIdx => 1, dformat => '#0#' ,},
				{ head => 'Provider', colIdx => 2, dformat => '#1#' ,},
				{ head => 'Patient', colIdx => 3, dformat => '#2#' },
				{ head => 'Amount Due', colIdx => 4, dformat => 'currency', summarize => 'sum', dformat => '#3#' ,},
				{ head => 'Claims', colIdx => 5, dformat => '#4#' ,},
			],
	};


	my @data = ();
	my @dataTextBased = ();
	for my $key (keys %{$statements})
	{
		my $statement = $statements->{$key};
		my @rowData = ();
		my @rowDataTextBased = ();

		if ($statement->{billPartyType})
		{
			my $org = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_orgAddress',
				$statement->{billToId});
			push(@rowData, $org->{name_primary});
		}
		else
		{
			my $person = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_personAddress',
				$statement->{billToId});
			push(@rowData, $person->{simple_name});
		}

		my @invoiceIds = ();
		my @invoiceIdsTextBased = ();
		for (@{$statement->{invoices}})
		{
			if ($_->{invoiceId} > 0)
			{
				push(@invoiceIds, qq{<a href="/invoice/$_->{invoiceId}/summary" title="View Invoice $_->{invoiceId} Summary">
					$_->{invoiceId}</a>});
				push(@invoiceIdsTextBased, $_->{invoiceId});
			}
			else
			{
				my $planId = $_->{invoiceId};
				$planId =~ s/^PP//;
				push(@invoiceIds, qq{Payment Plan '$planId' });
				push(@invoiceIdsTextBased, qq{Payment Plan '$planId' });
			}
		}

		my $person = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_personAddress',
			$statement->{clientId});

		my $billToName = $rowData[0];
		$billToName =~ s/\'/&quot;/g;

		push(@rowData,
			$statement->{billPartyType} ? 'Org' : 'Person',
			$statement->{billingProviderId},
			$person->{simple_name},
			$statement->{amountDue},
			join(', ', @invoiceIds),
			$statement->{clientId},
			$statement->{billToId},
			$statement->{payToId},
			$billToName,
			$statement->{billingOrgId},
		);

		push(@rowDataTextBased,
			$billToName,
			$statement->{billPartyType} ? 'Org' : 'Person',
			$statement->{billingProviderId},
			$person->{simple_name},
			$statement->{amountDue},
			join(', ', @invoiceIdsTextBased),
			$statement->{clientId},
			$statement->{billToId},
			$statement->{payToId},
		);

		push(@data, \@rowData);
		push(@dataTextBased, \@rowDataTextBased);
	}

	my @sortedData = sort{$b->[4] <=> $a->[4]} @data;
	my @sortedDataTextBased = sort{$b->[4] <=> $a->[4]} @dataTextBased;
	$html .= createHtmlFromData($page, 0,  \@sortedData, $pubDefn);
	$textOutputFilename = createTextRowsFromData($page, 0,  \@sortedDataTextBased, $pubText);

	my $tempDir = $CONFDATA_SERVER->path_temp();
	my $Constraints = [
	{ Name => "Billing Cycle ", Value => $billCycle},
	{ Name => "Physican ID ", Value => $providerId},
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

	#return createHtmlFromData($page, 0, \@sortedData, $pubDefn);

}

sub prepare_detail_last4
{
	my ($self, $page) = @_;

	my $billToId = $page->param('billtoid');
	my $payToId = $page->param('paytoid');
	my $patientId = $page->param('patientid');
	my $billToName = $page->param('billto_name');

	$page->addContent("<b>$billToName Last 4 Statements</b><br><br>",
		$STMTMGR_STATEMENTS->createHtml($page, STMTMGRFLAG_CACHE, 'sel_last4Statements',
			[$billToId, $payToId, $patientId])
	);
}

sub __execute
{
	my ($self, $page, $command, $flags) = @_;

	my $billCycle = $page->field('bill_cycle');
	my $facility = $page->field('service_facility_id');
	my $doc = $page->field('person_id');
	my $html;
	my $pub =
	{
		reportTitle => $self->heading(),
		columnDefn =>
		[
			{ colIdx => 0, summarize=>'count', head => 'Bill Cycle', hAlign=>'left', tAlign=>'left', dAlign => 'left',},
			{ colIdx => 1, summarize=>'sum', head => 'Number Patients', hAlign=>'left', tAlign=>'left', dAlign => 'left',},
			{ colIdx => 2, summarize=>'sum', head => '# Bills', hAlign=>'left', tAlign=>'left', dAlign => 'left',},
			{ colIdx => 3, summarize=>'sum', head => 'Bill Amount', dformat=>'currency'},
			{ colIdx => 4,
				url => qq{javascript:doActionPopup('#hrefSelfPopup#&detail=cycle&cycle_date=#4#&cycle_day=#0#',null,'width=900,height=600,scrollbars,resizable')},
				head => 'Bill Date', hAlign=>'left', tAlign=>'left', dAlign => 'left',
			},
		],
	};

	my $patientCount = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
		'selPatientInBillCycle', $billCycle, $page->session('org_internal_id'));

	my @data = ();
	foreach (@$patientCount)
	{
		#my $checkCycle = length($_->{cycle})==1 ? "0$_->{cycle}" : $_->{cycle};
		my $checkCycle = $_->{cycle};
		#pull statement sent for this billing cycle
		my $cycleData = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'selFourBillCycleData', $checkCycle, $facility, $doc, $page->session('org_internal_id'));

		#If cycle Data is empty then place one element in array so we get the bill cycle data
		push (@{$cycleData},{empty=>1}) unless @$cycleData;
		my $size = scalar(@$cycleData);
	 	for my $cycle (@$cycleData)
		{
			my @rowData = (
			$_->{cycle},
			$_->{tlt_patient},
			$cycle->{stmt_count} || 0,
			$cycle->{amount}||0,
			$cycle->{cycle_date} || 'N/A');
			push(@data, \@rowData);
		}
	};
	return createHtmlFromData($page, 0, \@data, $pub);
}

sub prepare_detail_cycle
{
	my ($self, $page) = @_;
	my $billCycle = $page->field('bill_cycle');
	my $facility = $page->field('service_facility_id');
	my $doc = $page->field('person_id');
	my $cycleDate = $page->param('cycle_date');
	my $cycleDay = $page->param('cycle_day');
	my $html;
	my $pub =
	{
		reportTitle => $self->heading(),
		columnDefn =>
		[
			{ colIdx => 0, head => 'Patient ID', hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ colIdx => 1, head => 'Patient Name' , hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ colIdx => 3, head => 'Statement Status',},
			{ colIdx => 2, dformat=>'currency', summarize=>'sum', head => 'Statement Amount',},
		],
	};

	my $cycleData = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
		'selBillCycleData', $cycleDate, $facility, $doc, $page->session('org_internal_id'));

	my @data = ();
	foreach (@$cycleData)
	{
		my @rowData = (
		$_->{patient_id},
		$_->{simple_name},
		$_->{amount_due},
		$_->{status}||'UNK');
		push(@data, \@rowData);
	};

	my $html = '<b style="font-family:Helvetica; font-size:12pt">(Cycle Date '. $cycleDate . ' ) </b><br><br>' . createHtmlFromData($page, 0, \@data,$pub);
	$page->addContent($html);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	$page->field('bill_cycle', (localtime)[3]);
}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
