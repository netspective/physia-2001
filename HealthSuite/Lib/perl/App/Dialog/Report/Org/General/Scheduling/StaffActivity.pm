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
				types => ['Staff'])
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
	my $dateClause ;
	$dateClause =qq{ and  trunc(pa.activity_stamp) between to_date('$reportBeginDate', 'mm/dd/yyyy') and to_date('$reportEndDate', 'mm/dd/yyyy')}if($reportBeginDate ne '' && $reportEndDate ne '');
	$dateClause =qq{ and  trunc(pa.activity_stamp) <= to_date('$reportEndDate', 'mm/dd/yyyy')	} if($reportBeginDate eq '' && $reportEndDate ne '');
	$dateClause =qq{ and  trunc(pa.activity_stamp) >= to_date('$reportBeginDate', 'mm/dd/yyyy') } if($reportBeginDate ne '' && $reportEndDate eq '');
	my $orderBy = qq{order by pa.activity_stamp desc };

	my $whereClause = qq{where
				pa.person_id = \'$person_id\'
				and	sat.id = pa.action_type
				$dateClause
				};
#	my $columns = qq{to_char(pa.activity_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT') as activity_date,
	my $columns = qq{pa.activity_stamp as activity_date,
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
	my $pub = {
		columnDefn => [
			{ colIdx => 0, head => 'Activity Date', hAlign => 'left', dAlign => 'left', dataFmt => '#0#'},
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

	my $html = createHtmlFromData($page, 0, \@data, $pub);
	return $html;

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;