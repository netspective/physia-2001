##############################################################################
package App::Dialog::Report::Org::General::Accounting::AgedInsuranceData;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Org;

use App::Statements::Component::Invoice;
use App::Statements::Report::Accounting;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-aged-insurance-data', heading => 'Aged Insurance Receivables');

	$self->addContent(
			new App::Dialog::Field::Organization::ID(caption => 'Payer Organization ID', name => 'ins_org_id'),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $orgId = $page->field('ins_org_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId);
	return $STMTMGR_REPORT_ACCOUNTING->createHtml($page, STMTMGRFLAG_NONE, 'sel_aged_insurance', [$orgIntId]);
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;