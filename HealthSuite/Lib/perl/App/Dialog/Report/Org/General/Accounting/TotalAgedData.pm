##############################################################################
package App::Dialog::Report::Org::General::Accounting::TotalAgedData;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use App::Statements::Report::Accounting;
use App::Statements::Report::Aging;
use App::Statements::Person;

use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-aged-data', heading => 'Total Aged Receivables');

	$self->addContent(

		new App::Dialog::Field::Person::ID(
			caption =>'Patient ID',
			name => 'person_id',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Field(
			caption => 'Physician ID',
			name => 'provider_id',
			fKeyStmtMgr => $STMTMGR_PERSON,
			fKeyStmt => 'selPersonBySessionOrgAndCategory',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			options => FLDFLAG_PREPENDBLANK),

		new App::Dialog::Field::OrgType(
			caption => 'Site Organization ID',
			name => 'org_id',
			options => FLDFLAG_PREPENDBLANK,
			types => "'PRACTICE', 'CLINIC','FACILITY/SITE','DIAGNOSTIC SERVICES', 'DEPARTMENT', 'HOSPITAL', 'THERAPEUTIC SERVICES'",
			),

		new CGI::Dialog::Field(
			name => 'totalReport',
			type => 'bool',
			style => 'check',
			caption => 'Totals Report',
			defaultValue => 0
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


sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $sessOrg = $page->session('org_internal_id');
	$self->getField('provider_id')->{fKeyStmtBindPageParams} = [$sessOrg, 'Physician'];
}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub prepare_detail_aged_data
{
	my ($self, $page) = @_;
#	my $person_id = $page->param('_f_person_id');
	my $person_id = $page->param('patient_id');
	my $owner_id = $page->session('org_internal_id');
	my $provider_id = $page->param('_f_provider_id');
	my $org_id = $page->param('_f_org_id');

	$page->addContent($STMTMGR_REPORT_ACCOUNTING->createHtml($page, STMTMGRFLAG_NONE, 'sel_aged_data_detail',
			[$person_id, $owner_id, $provider_id, $org_id]));

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $providerId = $page->field('provider_id');
	my $facilityId = $page->field('org_id');
	my $totalReport = $page->field('totalReport');
	my $hardCopy = $page->field('printReport');
	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	my $textOutputFilename;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openRawPrintHandle ($printerDevice);

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');


	my $data;
	my $html;
	my $pub  = {
			reportTitle => 'Aged Patient Receivables',
			columnDefn =>
				[
				{ colIdx => 0,dAlign=>'left',tAlign=>'left', tDataFmt => '&{count:0} Patients',hint=>"View Detail Data for : #1#", hAlign=>'left',head => 'Patient Name', dataFmt => '#0#',
				url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=aged_data&patient_id=#1#')}},
				{ colIdx => 1, hAlign=>'left', head => 'Patient ID', dataFmt => '#1#',   },
				{ colIdx => 2, head => 'Total Invoices',tAlign=>'center', summarize=>'sum',dataFmt => '#2#',dAlign =>'center' },
				{ colIdx => 3, head => '0 - 30',summarize=>'sum', dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '31 - 60', summarize=>'sum',dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '61 - 90', summarize=>'sum',dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '91 - 120',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '121 - 150',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => '151+', summarize=>'sum',dataFmt => '#8#', dformat => 'currency' },
				{ colIdx => 9, head => 'Total Balance', summarize=>'sum',dataFmt => '#9#', dformat => 'currency' },
				{ colIdx => 10, head => 'Total Pending', summarize=>'sum',dataFmt => '#10#', dAlign => 'center', dformat => 'currency' },
				{ colIdx => 11, head => 'Total Amount', summarize=>'sum',dataFmt => '#11#', dAlign => 'center', dformat => 'currency' },
				],
			};

	my $pubTotal  = {
			reportTitle => 'Total Aged Receivables',
			columnDefn =>
				[
				{ colIdx => 0,dAlign=>'left',tAlign=>'left', , hAlign=>'left',head => 'Patients', dataFmt => '#0#',},
				{ colIdx => 1, head => 'Total Invoices',tAlign=>'center', summarize=>'sum',dataFmt => '#1#',dAlign =>'center' },
				{ colIdx => 2, head => '0 - 30',summarize=>'sum', dataFmt => '#2#', dformat => 'currency' },
				{ colIdx => 3, head => '31 - 60', summarize=>'sum',dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '61 - 90', summarize=>'sum',dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '91 - 120',summarize=>'sum', dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '121 - 150',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '151+', summarize=>'sum',dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => 'Total Balance', summarize=>'sum',dataFmt => '#8#', dformat => 'currency' },
				{ colIdx => 9, head => 'Total Pending', summarize=>'sum',dataFmt => '#9#', dAlign => 'center', dformat => 'currency' },
				{ colIdx => 10, head => 'Total Amount', summarize=>'sum',dataFmt => '#10#', dAlign => 'center', dformat => 'currency' },
				],
			};

	if($totalReport)
	{
		$data = $STMTMGR_REPORT_ACCOUNTING->getRowsAsArray($page, STMTMGRFLAG_NONE, 'sel_aged_all_total',$personId, $page->session('org_internal_id'),
		$providerId, $facilityId);
		$html = createHtmlFromData($page, 0, $data, $pubTotal);
		$textOutputFilename = createTextRowsFromData($page, 0,  $data, $pubTotal);
	}
	else
	{
		$data = $STMTMGR_REPORT_ACCOUNTING->getRowsAsArray($page, STMTMGRFLAG_NONE, 'sel_aged_all',$personId, $page->session('org_internal_id'),
		$providerId, $facilityId);
		$html = createHtmlFromData($page, 0, $data,$pub);
		$textOutputFilename = createTextRowsFromData($page, 0,  $data, $pub);
	}

	#$html = $STMTMGR_REPORT_ACCOUNTING->createHtml($page, STMTMGRFLAG_NONE, 'sel_aged_all',  [$personId, $page->session('org_internal_id'),
	#$providerId, $facilityId]);
	#
	#my $textOutputFilename = createTextRowsFromData($page, STMTMGRFLAG_NONE, $data, $STMTMGR_REPORT_ACCOUNTING->{"_dpd_sel_aged_patient"});

	my $tempDir = $CONFDATA_SERVER->path_temp();
	my $Constraints = [
	{ Name => "Patient ID ", Value => $personId},
	{ Name => "Pyhsician ID ", Value => $providerId},
	{ Name => "Site Organization ID ", Value => $facilityId},
	{ Name=> "Totals Report ", Value => ($totalReport) ? 'Yes' : 'No' },
	{ Name=> "Print Report ", Value => ($hardCopy) ? 'Yes' : 'No' },
	{ Name=> "Printer ", Value => $printerDevice},
	];
	my $FormFeed = appendFormFeed($tempDir.$textOutputFilename);
	my $fileConstraint = appendConstraints($page, $tempDir.$textOutputFilename, $Constraints);

	if ($hardCopy == 1 and $printerAvailable) {
		my $reportOpened = 1;
		open (ASCIIREPORT, $tempDir.$textOutputFilename) or $reportOpened = 0;
		if ($reportOpened) {
			while (my $reportLine = <ASCIIREPORT>) {
				print $printHandle $reportLine;
			}
		}
		close ASCIIREPORT;
	}


	my $pages = $self->getFilePageCount(File::Spec->catfile($CONFDATA_SERVER->path_temp, $textOutputFilename));
	return ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version - $pages Page(s)</a> <br>} : "" ) . $html;
	#return  $html;
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;