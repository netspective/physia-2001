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

use App::Statements::Component::Invoice;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-aged-insurance-data', heading => 'Aged Insurance Receivables');

	$self->addContent(
			new App::Dialog::Field::Organization::ID(caption => 'Insurance Organization ID', name => 'ins_org_id'),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $orgId = $page->field('ins_org_id');

	if ( $orgId ne '')
	{
		return $STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.agedInsuranceData', [$orgId]);
	}
	else
	{
		return $STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.agedInsuranceDataAll');
	}



}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;