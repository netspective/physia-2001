##############################################################################
package App::Dialog::Report::Org::General::Accounting::AgedPatientData;
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
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-aged-patient-data', heading => 'Aged Patient Receivables');

	$self->addContent(
			new App::Dialog::Field::Person::ID(caption =>'Patient ID', name => 'person_id', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');

	if ( $personId ne '')
	{
		return $STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.agedPatientData', [$personId]);
	}
	else
	{
		return $STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.agedPatientDataAll');
	}



}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;