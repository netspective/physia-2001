##############################################################################
package App::Dialog::Report::Org::General::Scheduling::StaffActivity;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

use App::Statements::Report::ClaimStatus;
use App::Dialog::Field::Person;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-staff-activity', heading => 'Staff Activity');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'report',
				caption => 'Start/End Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),
			new App::Dialog::Field::Person::ID(caption => 'Staff ID',
				name => 'staff_id',
				options => FLDFLAG_REQUIRED,
				types => ['Staff']
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
	$page->field('report_begin_date', $startDate);
	$page->field('report_end_date', $startDate);
}

sub buildSqlStmt
{

	my ($self, $page, $flags) = @_;
	my $reportBeginDate = $page->field('report_begin_date');
	my $reportEndDate = $page->field('report_end_date');
	my $person_id = $page->field('staff_id');
	my $gmtDayOffset = $page->session('GMT_DAYOFFSET');
	my $dateClause ;
	$dateClause =qq{ and  trunc(pa.activity_stamp-$gmtDayOffset) between to_date('$reportBeginDate', 'mm/dd/yyyy') and to_date('$reportEndDate', 'mm/dd/yyyy')}if($reportBeginDate ne '' && $reportEndDate ne '');
	$dateClause =qq{ and  trunc(pa.activity_stamp-$gmtDayOffset) <= to_date('$reportEndDate', 'mm/dd/yyyy')	} if($reportBeginDate eq '' && $reportEndDate ne '');
	$dateClause =qq{ and  trunc(pa.activity_stamp-$gmtDayOffset) >= to_date('$reportBeginDate', 'mm/dd/yyyy') } if($reportBeginDate ne '' && $reportEndDate eq '');
	my $orderBy = qq{order by pa.activity_stamp desc };

	my $whereClause = qq{where
				pa.person_id = \'$person_id\'
				and	sat.id = pa.action_type
				$dateClause
				};
#	my $columns = qq{to_char(pa.activity_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT') as activity_date,
	my $columns = qq{pa.activity_stamp - $gmtDayOffset as activity_date,
			sat.caption as caption,
			pa.activity_data as data,
			pa.action_scope as scope,
			pa.action_key as action_key
			};

	my $fromTable= qq{Session_Action_Type sat, perSess_Activity pa};

	my $sqlStmt = qq {select  $columns
				from $fromTable
				$whereClause
				$orderBy
				};

	return $sqlStmt;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $reportBeginDate = $page->field('report_begin_date');
	my $reportEndDate = $page->field('report_end_date');
	my $person_id = $page->field('staff_id');

	my $hardCopy = $page->field('printReport');
	my $html;
	my $textOutputFilename;

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	my $pub = {
		reportTitle => "Staff Activity",
		columnDefn => [
			{ colIdx => 0, tAlign=>'left',summarize=>'count', head => 'Activity Date', hAlign => 'left', dAlign => 'left', dataFmt => '#0#'},
			{ colIdx => 1, head => 'Caption', hAlign => 'left', dAlign => 'left', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Data', hAlign => 'left', dAlign => 'left', dataFmt => '#2#' },
			{ colIdx => 3, head => 'Scope', hAlign => 'left', dAlign => 'left', dataFmt => '#3#' },
			{ colIdx => 4, head => 'Action Key', hAlign => 'left', dAlign => 'left', dataFmt => '#4#' },
		],
	};

	my $sqlStmt = $self->buildSqlStmt($page, $flags);
	my $activity = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmt);
	my @data = ();
	foreach (@$activity)
	{
		my @rowData = (
		$_->{activity_date},
		$_->{caption},
		$_->{data},
		$_->{scope},
		$_->{action_key});
		push(@data, \@rowData);
	};

	 $html = createHtmlFromData($page, 0, \@data, $pub);
	 $textOutputFilename = createTextRowsFromData($page, 0, \@data, $pub);
	 my $tempDir = $CONFDATA_SERVER->path_temp();
	 my $Constraints = [
	{ Name => "Start/End Report Date ", Value => $reportBeginDate."  ".$reportEndDate},
	{ Name => "Staff ID ", Value => $person_id},
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

	return ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version</a> <br>} : "" ) . $html;
	#return $html;

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;