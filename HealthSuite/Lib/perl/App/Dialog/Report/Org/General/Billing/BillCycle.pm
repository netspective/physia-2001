##############################################################################
package App::Dialog::Report::Org::General::Billing::BillCycle;
##############################################################################

use strict;
use Carp;
use Date::Calc qw(Delta_Days);
use App::Dialog::Report;
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
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $orgInternalId = $page->session('org_internal_id');
	my $providerId = $page->field('person_id');

	#$ENV{OVERRIDE_BILLING_CYCLE} = 'YES';

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
		columnDefn =>
		[
			{	head => 'Payer', colIdx => 0, summarize => 'count', dAlign => 'left',
				url => qq{javascript:doActionPopup('#hrefSelfPopup#&detail=last4&billtoid=#7#&paytoid=#8#&patientid=#6#&billto_name=#9#',
					null,'location,status,width=800,height=600,scrollbars,resizable')},
			},
			{ head => 'Type', colIdx => 1,},
			{ head => 'Provider', colIdx => 2,},
			{ head => 'Patient', colIdx => 3, url => '/person/#6#/account', hint => 'View #6# Account'},
			{ head => 'Amount Due', colIdx => 4, dformat => 'currency', summarize => 'sum',},
			{ head => 'Claims', colIdx => 5,},
		],
	};

	my @data = ();
	for my $key (keys %{$statements})
	{
		my $statement = $statements->{$key};
		my @rowData = ();

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
		for (@{$statement->{invoices}})
		{
			if ($_->{invoiceId} > 0)
			{
				push(@invoiceIds, qq{<a href="/invoice/$_->{invoiceId}/summary" title="View Invoice $_->{invoiceId} Summary">
					$_->{invoiceId}</a>});
			}
			else
			{
				push(@invoiceIds, qq{Payment Plan '@{[ - $_->{invoiceId} ]}' });
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
		);

		push(@data, \@rowData);
	}

	my @sortedData = sort{$b->[4] <=> $a->[4]} @data;

	return createHtmlFromData($page, 0, \@sortedData, $pubDefn);
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
