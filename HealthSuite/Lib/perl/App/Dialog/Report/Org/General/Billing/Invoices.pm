##############################################################################
package App::Dialog::Report::Org::General::Billing::Invoices;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::Report::Billing;
use App::Statements::Org;
use Data::Publish;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'invoice', heading => 'Invoices');

	$self->addContent(

		new CGI::Dialog::Field::Duration(name => 'report',
			caption => 'Report Dates',
			options => FLDFLAG_REQUIRED
		),
		new App::Dialog::Field::Organization::ID(name => 'facility_id',
			caption => 'Facility ID',
			types => ['Facility'],
			options => FLDFLAG_REQUIRED
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
	$page->field('resource_id', $page->session('user_id'));
	$page->field('facility_id', $page->session('org_id'));
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $facility_id = $page->field('facility_id');
	my $startDate   = $page->field('report_begin_date');
	my $endDate     = $page->field('report_end_date');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', 
		$page->session('org_internal_id'), $facility_id);

	my $html = qq{
	<table cellpadding=10>
		<tr align=center valign=top>

		<td>
			<b style="font-size:8pt; font-family:Tahoma">By Payer Type</b>
			@{[ $STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_payers',
				[$orgIntId, $startDate, $endDate,$page->session('org_internal_id')]) ]}
		</td>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">By Insurance</b>
			@{[ $STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_payersByInsurance',
				[$orgIntId, $startDate, $endDate,$page->session('org_internal_id')]) ]}
		</td>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Earnings</b>
			@{[ $STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_earningsFromItem_Adjust',
				[$startDate, $endDate, $orgIntId,$page->session('org_internal_id'), $startDate, $endDate, $orgIntId,
				$page->session('org_internal_id')]) ]}
		</td>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Procedures</b>
			@{[ $STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_proceduresFromInvoice_Item',
				[$startDate, $endDate, $orgIntId,$page->session('org_internal_id')]) ]}
		</td>


		</tr>
	</table>
	};

		#<td>
		#	<b style="font-size:8pt; font-family:Tahoma">Diagnostics</b>
		#	@{[ $STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_diagsFromInvoice_Item',
		#		[$startDate, $endDate, $orgIntId]) ]}
		#</td>
	return $html;
}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub prepare_detail_payer
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $payer       = $page->param('payer');

	my $internalFacilityId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId',
		$page->session('org_internal_id'), $facility_id);

	$page->addContent($STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_detail_payers',
		[$internalFacilityId, $startDate, $endDate, $payer,$page->session('org_internal_id'),]));
}

sub prepare_detail_insurance
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $insurance   = $page->param('insurance');

	my $internalFacilityId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId',
		$page->session('org_internal_id'), $facility_id);
		
	my $internalInusranceId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId',
		$page->session('org_internal_id'), $insurance);
		
	$page->addContent($STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_detail_insurance',
		[$internalFacilityId, $startDate, $endDate, $internalInusranceId,$page->session('org_internal_id')]));
}

sub prepare_detail_earning
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $insurance   = $page->param('insurance');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', 
		$page->session('org_internal_id'), $facility_id);
	$facility_id = $orgIntId;
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', 
		$page->session('org_internal_id'), $insurance);
	my $type = $page->param('type');
	if($type == 1)
	{
		$page->addContent($STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_detailearnings_person',
			[ $startDate, $endDate,$facility_id, $insurance,$page->session('org_internal_id')]));
	}
	else
	{
		$page->addContent($STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_detailearnings_insurance',
			[ $startDate, $endDate,$facility_id, $orgIntId,$page->session('org_internal_id')]));	
	}
}

sub prepare_detail_cpt
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $code        = $page->param('code');

	my $internalFacilityId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId',
		$page->session('org_internal_id'), $facility_id);
	
	$page->addContent($STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_detailProcedures',
		[$internalFacilityId, $startDate, $endDate, $code,$page->session('org_internal_id')]));
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
