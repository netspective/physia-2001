##############################################################################
package App::Dialog::Report::Org::General::Scheduling::SuperBill;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Person;
use Date::Manip;
use App::Configuration;
use File::Spec;

use App::Billing::SuperBill::SuperBills;
use App::Billing::Input::SuperBillDBI;
use App::Billing::Output::SuperBillPDF;

use Data::Publish;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-super-bill', heading => 'Super Bill');

	$self->addContent(
		new CGI::Dialog::Field(
			caption => 'Physician ID',
			name => 'provider_id',
			fKeyStmtMgr => $STMTMGR_PERSON,
			fKeyStmt => 'selPersonBySessionOrgAndCategory',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			options => FLDFLAG_PREPENDBLANK
		),
		new CGI::Dialog::Field::Duration(
			name => 'report',
			caption => 'Start/End Date',
			begin_caption => 'Start Date',
			end_caption => 'End Date',
			options => FLDFLAG_REQUIRED,
		),
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('report_begin_date', $startDate);
	$page->field('report_end_date', $startDate);
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $sessOrg = $page->session('org_internal_id');
	$self->getField('provider_id')->{fKeyStmtBindPageParams} = [$sessOrg, 'Physician'];
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $superBills = new App::Billing::SuperBill::SuperBills;
	my $input = new App::Billing::Input::SuperBillDBI;
	my $output = new App::Billing::Output::SuperBillPDF;

	my $offset = $page->session('GMT_DAYOFFSET');
	my $orgId = $page->session('org_internal_id');

	$input->populateSuperBill(
		$superBills,
		$page,
		startTime => $page->field('report_begin_date'),
		endTime => $page->field('report_end_date'),
		physicianID => $page->field('provider_id')
	);

	my $theFilename = $page->session ('org_id') . $page->session ('user_id') . time() . ".superbillSample.pdf";

	$output->printReport(
		$superBills,
		file => File::Spec->catfile($CONFDATA_SERVER->path_PDFSuperBillOutput, $theFilename),
		columns => 4,
		rows => 51
	);

	my $sampleLink = File::Spec->catfile($CONFDATA_SERVER->path_PDFSuperBillOutputHREF, $theFilename);
	
	return (qq {<b>SuperBill Generated: </b><a href="$sampleLink">Click here to view</a>});
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;