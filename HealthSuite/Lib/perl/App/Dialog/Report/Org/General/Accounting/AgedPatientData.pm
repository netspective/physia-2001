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

use App::Statements::Report::Accounting;
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
	return $STMTMGR_REPORT_ACCOUNTING->createHtml($page, STMTMGRFLAG_NONE, 'sel_aged_patient', [$personId,$page->session('org_internal_id')]);


}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;