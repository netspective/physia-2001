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

use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-aged-patient-data', heading => 'Aged Patient Receivables');

	$self->addContent(
			new App::Dialog::Field::Person::ID(caption =>'Patient ID', name => 'person_id', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
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

	my $personId = $page->field('person_id');
	my $hardCopy = $page->field('printReport');
	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");
	
	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');


	my $data = $STMTMGR_REPORT_ACCOUNTING->getRowsAsArray($page, STMTMGRFLAG_NONE, 'sel_aged_patient', $personId, $page->session('org_internal_id'));
	my $html = $STMTMGR_REPORT_ACCOUNTING->createHtml($page, STMTMGRFLAG_NONE, 'sel_aged_patient', [$personId,$page->session('org_internal_id')]);
	
	my $textOutputFilename = createTextRowsFromData($page, STMTMGRFLAG_NONE, $data, $STMTMGR_REPORT_ACCOUNTING->{"_dpd_sel_aged_patient"});

	if ($hardCopy == 1 and $printerAvailable) {
		my $reportOpened = 1;
		my $tempDir = $CONFDATA_SERVER->path_temp();
		open (ASCIIREPORT, $tempDir.$textOutputFilename) or $reportOpened = 0;
		if ($reportOpened) {
			while (my $reportLine = <ASCIIREPORT>) {
				print $printHandle $reportLine;
			}
		}
		close ASCIIREPORT;
	}

	return ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version</a> <br>} : "" ) . $html;
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;