##############################################################################
package App::Dialog::Report::Org::General::Billing::Superbill;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Dialog::Field::Person;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::Report::Accounting;
use App::Statements::Org;
use App::Statements::Device;
use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'superbills', heading => 'Superbills');

	$self->addContent(
	
		new CGI::Dialog::Field(
			name => 'startDate',
			type => 'date',
			caption => 'Date'
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
	$page->field('date', $startDate);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $startDate = $page->field('startDate');
	my $hardCopy = $page->field('printReport');

	# Data placeholders...
	my $superbillData;
	my $textOutput;
#	my $textOutputFilename;

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice);
	
	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	# Create a filename and the corresponding file...
	my $tempFileOpened = 1;
	my $dataFileOpened = 1;
	my $tempDir = $CONFDATA_SERVER->path_temp();
	my $theFilename .= "/" . $page->session ('org_id') . $page->session ('user_id') . time() . ".txt";
	my $theDataFilename .= "/" . $page->session ('org_id') . $page->session ('user_id') . time() . ".data.txt";
	
	open (TMPFILEHANDLE, ">$tempDir$theFilename") or $tempFileOpened = 0;
	open (TMPDATAHANDLE, ">$tempDir$theDataFilename") or $dataFileOpened = 0;
	
	$superbillData = $STMTMGR_REPORT_ACCOUNTING->getRowsAsArray($page, STMTMGRFLAG_NONE, 
		'sel_patient_superbill_info', $startDate, $page->session('GMT_DAYOFFSET'));

	foreach my $superbillPatientInfo (@{$superbillData}) {
		my $patientID = $superbillPatientInfo->[8];

		my $superbillAcctInfo = $STMTMGR_REPORT_ACCOUNTING->getRowAsArray($page, STMTMGRFLAG_NONE, 'sel_aged_patient', $patientID, $page->session ('org_internal_id'), "", "");

		if ($#$superbillAcctInfo >= 0) {
			push @{$superbillPatientInfo},
				($superbillAcctInfo->[4] + $superbillAcctInfo->[5] + $superbillAcctInfo->[6] + $superbillAcctInfo->[7]),
				$superbillAcctInfo->[3], $superbillAcctInfo->[8], $superbillAcctInfo->[2], $superbillAcctInfo->[9];
		} else {
			push @{$superbillPatientInfo}, 0, 0, 0, 0, 0;
		}

		my $superbillInsInfo = $STMTMGR_REPORT_ACCOUNTING->getRowAsArray($page, STMTMGRFLAG_NONE, 'sel_patient_superbill_ins_info', $patientID);

		if ($#$superbillInsInfo >= 0) {
			push @{$superbillPatientInfo},
				$superbillInsInfo->[1], $superbillInsInfo->[2], $superbillInsInfo->[3];
		} else {
			push @{$superbillPatientInfo}, " ", " ", 9;
		}
	}

	$textOutput = createTextFromData($page, STMTMGRFLAG_NONE, $superbillData, 
		$STMTMGR_REPORT_ACCOUNTING->{"_dpd_sel_patient_superbill_info"});
#	$textOutputFilename = createTextRowsFromData($page, STMTMGRFLAG_NONE, $superbillData, $STMTMGR_REPORT_ACCOUNTING->{"_dpd_sel_patient_superbill_info"});

	if ($tempFileOpened) {
		print TMPFILEHANDLE $textOutput;
		close TMPFILEHANDLE
	}
	
	if ($dataFileOpened) {
		# Dump data out to the file separating each field with a |
		foreach my $superbillDataRow (@{$superbillData}) {
			my $superbillDataRowFields = join "|", @{$superbillDataRow};
			print TMPDATAHANDLE $superbillDataRowFields, "\n";
		}
		close TMPDATAHANDLE;
	}

	if ($hardCopy == 1 and $printerAvailable) {
		print $printHandle $textOutput;
		$printHandle->close;
	}

	my $html = createHtmlFromData ($page, STMTMGRFLAG_NONE, $superbillData, 
		$STMTMGR_REPORT_ACCOUNTING->{"_dpd_sel_patient_superbill_info"});

	return ($tempFileOpened ? qq{<a href="/temp$theFilename">Printable version</a> <br>} : "" ) . qq{<br><b>Printer Device: </b> oki<br><b>printerAvailable: </b> $printerAvailable<br>} . $html;
#	return ($textOutputFilename ? qq{<a href="$textOutputFilename">Printable version</a> <br>} : "" ) . $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
