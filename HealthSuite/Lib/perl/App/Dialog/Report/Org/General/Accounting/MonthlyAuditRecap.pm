##############################################################################
package App::Dialog::Report::Org::General::Accounting::MonthlyAuditRecap;
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

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-monthly-audit-recap', heading => 'Monthly Audit Recap');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'monthly',
				caption => 'Start/End Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),
			new App::Dialog::Field::Organization::ID(caption =>'Organization ID', name => 'org_id', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('monthly_begin_date', $startDate);
	$page->field('monthly_end_date', $startDate);
	$page->field('org_id', $page->session('org_id'));
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $reportBeginDate = $page->field('monthly_begin_date');
	my $reportEndDate = $page->field('monthly_end_date');
	my $orgId = $page->field('org_id');

	#my @startDateItems = split(/\//, $reportBeginDate);
	#my @endDateItems = split(/\//, $reportEndDate);
	
	#my @varTempArray1 = ($startDateItems[2], $startDateItems[0], $startDateItems[0]);
	#my @varTempArray2 = ($endDateItems[2], $endDateItems[0], $endDateItems[0]);
	#my $daysDiff = Delta_Days(@varTempArray1, @varTempArray2); 

	#$page->addDebugStmt("The number of days difference is $daysDiff");
	return $STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.monthlyAuditRecap', [$reportBeginDate,$reportEndDate,$orgId]);

}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;