##############################################################################
package App::Dialog::Report::Org::General::Accounting::AppointmentCharges;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;

use App::Statements::Component::Invoice;
use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-appointment-charges', heading => 'Appointment Charges');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'daily',
				caption => 'Start/End Appointment Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),
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

	my $hardCopy = $page->field('printReport');
	my $html;
	my $textOutputFilename;

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");
	
	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	my $data = $STMTMGR_COMPONENT_INVOICE->getRowsAsArray($page, 0, 'invoice.appointmentCharges', 
		$reportBeginDate, $reportEndDate, $page->session('org_internal_id'), $page->session('GMT_DAYOFFSET'));

#	return $STMTMGR_COMPONENT_INVOICE->createHtml($page, 0, 'invoice.appointmentCharges', 
#		[$reportBeginDate, $reportEndDate, $page->session('org_internal_id'), $page->session('GMT_DAYOFFSET')]);

	my $pub = {
		columnDefn => [
			{ colIdx => 11, head => 'Patient ID', dataFmt => '#11#',},
			{ colIdx => 0, head => 'Receptionist', dataFmt => '#0#' },
			{ colIdx => 1, head => 'Date', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Start Time', dataFmt => '#2#' },
			{ colIdx => 3, head => 'End Time', dataFmt => '#3#' },
			{ colIdx => 4, head => 'Org', dataFmt => '#4#' },
			{ colIdx => 5, head => 'Reason', dataFmt => '#5#' },
			#{ colIdx => 6, head => 'Visit Type', dataFmt => '#6#' },
			{ colIdx => 7, head => 'Visit Type', dataFmt => '#7#' },
			{ colIdx => 8, head => 'Provider Name', dataFmt => '#8#' },
			{ colIdx => 9, head => 'Billed To', dataFmt => '#9#' },
			{ colIdx => 10, head => 'Charges', dataFmt => '#10#', dformat => 'currency'},
		],
	};

	$html .= createHtmlFromData($page, 0, $data, $pub);
	$textOutputFilename = createTextRowsFromData($page, 0, $data, $pub);

#	if ($tempFileOpened) {
#		print TMPFILEHANDLE $textOutput;
#		close TMPFILEHANDLE
#	}

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