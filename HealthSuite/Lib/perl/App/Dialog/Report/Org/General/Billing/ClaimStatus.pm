##############################################################################
package App::Dialog::Report::Org::General::Billing::ClaimStatus;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::Report::ClaimStatus;
use Data::Publish;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'claimStatus', heading => 'Claim Status');

	$self->addContent(

		new CGI::Dialog::Field::Duration(name => 'report',
			caption => 'Report Dates',
			options => FLDFLAG_REQUIRED
		),

		new App::Dialog::Field::Person::ID(name => 'resource_id',
			caption => 'Resource ID',
			types => ['Physician'],
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

	my $resource_id = $page->field('resource_id');
	my $facility_id = $page->field('facility_id');
	my $startDate   = $page->field('report_begin_date');
	my $endDate     = $page->field('report_end_date');

	my $html = qq{
	<table cellpadding=10>
		<tr align=center valign=top>

		<td>
			<b style="font-size:8pt; font-family:Tahoma">By Payer</b>
			@{[ $STMTMGR_RPT_CLAIM_STATUS->createHtml($page, STMTMGRFLAG_NONE, 'sel_payers',
				[$facility_id, $startDate, $endDate]) ]}
		</td>

		</tr>
	</table>
	};

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

	$page->addContent($STMTMGR_REPORT_BILLING->createHtml($page, STMTMGRFLAG_NONE, 'sel_detail_payers',
		[$facility_id, $startDate, $endDate, $payer]));
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
