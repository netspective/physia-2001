##############################################################################
package App::Dialog::PrintSuperbill;
##############################################################################

use strict;
use Carp;

use DBI::StatementManager;
#use App::Statements::Invoice;
#use App::Statements::Catalog;
#use App::Statements::Insurance;
use App::Statements::Device;
use App::Statements::Report::Accounting;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Report;
use App::Dialog::Field::Person;
#use App::Dialog::Field::Invoice;
use App::Universal;
use App::Configuration;
use App::Device;
#use App::Dialog::Field::BatchDateID;
use Data::Publish;
use Data::TextPublish;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);
use constant NEXTACTION_PATIENTSUMMARY => "/person/%field.patient_id%/profile";
use constant NEXTACTION_PATIENTACCT => "/person/%field.patient_id%/account";
use constant NEXTACTION_PATIENTWORKLIST => "/worklist/patientflow";

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'printsuperbill' => {
		_arl => ['event_id'],
	},
);

sub new
{
	my $self = CGI::Dialog::new(@_, heading => 'Print Superbill');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(
			name => 'patient_id',
			type => 'hidden',
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

	$self->addFooter(
		new CGI::Dialog::Buttons(
			nextActions => [
				['Go to Patient Summary', NEXTACTION_PATIENTSUMMARY, 1],
				['Go to Patient Account', NEXTACTION_PATIENTACCT],
				['Return to Patient Flow Work List', NEXTACTION_PATIENTWORKLIST],
			],
			cancelUrl => $self->{cancelUrl} || undef,
		),
	);

	return $self;
}

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	# all of the Person::* panes expect a person_id parameter
	# -- we can use field('attendee_id') because it was created in populateData
	if(my $personId = $page->field('attendee_id'))
	{
		$page->param('person_id', $personId);

		return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
					#component.stpd-person.contactMethodsAndAddresses#<BR>
					#component.stpd-person.extendedHealthCoverage#<BR>
					#component.stpd-person.accountPanel#<BR>
					#component.stpd-person.careProviders#<BR>
					#component.stpd-person.authorization#<BR>
			});
	}
	return $self->SUPER::getSupplementaryHtml($page, $command);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $eventID = $page->param ('event_id');
	
#	my $eventAttribute = $STMTMGR_REPORT_ACCOUNTING->getRowAsHash($page, STMTMGRFLAG_NONE,
#		'sel_patient_id_from_eventid', $eventID);

#	my $personId = $eventAttribute->{value_text};
	my $personId = $page->param ('person_id');
	$page->field('patient_id', $personId);
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $eventID = $page->param('event_id');
	my $patientID = $page->param('person_id');
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
		'sel_patient_superbill_info_from_eventid', $eventID, $page->session('GMT_DAYOFFSET'));

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

#	my $html = createHtmlFromData ($page, STMTMGRFLAG_NONE, $superbillData, 
#		$STMTMGR_REPORT_ACCOUNTING->{"_dpd_sel_patient_superbill_info"});

#	return ($tempFileOpened ? qq{<a href="/temp$theFilename">Printable version</a> <br>} : "" ) . qq{<br><b>Printer Device: </b> oki<br><b>printerAvailable: </b> $printerAvailable<br><b>Event ID: </b> $eventID<br>} . $html;
#	return ($textOutputFilename ? qq{<a href="$textOutputFilename">Printable version</a> <br>} : "" ) . $html;

	$self->handlePostExecute($page, $command, $flags);
}

1;
