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

use App::Statements::Component::Invoice;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-daily-audit-recap', heading => 'Daily Audit Recap');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'daily',
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
	$page->field('daily_begin_date', $startDate);
	$page->field('daily_end_date', $startDate);
	$page->field('org_id', $page->session('org_id'));
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $reportBeginDate = $page->field('daily_begin_date');
	my $reportEndDate = $page->field('daily_end_date');
	my $orgId = $page->field('org_id');

	return $STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.dailyAuditRecap', [$reportBeginDate,$reportEndDate,$orgId]);

}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;