##############################################################################
package App::Dialog::Report::Org::General::Accounting::FinancialAnalysisReport;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use App::Statements::Report::Accounting;
use App::Statements::Org;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-financial-analysis-report', heading => 'Financial Analysis Report');

	$self->addContent(
				new CGI::Dialog::Field::Duration(
					name => 'batch',
					caption => 'Report Date',
					begin_caption => 'Report Begin Date',
					end_caption => 'Report End Date',
					),
				new App::Dialog::Field::Organization::ID(caption =>'Site Organization ID', name => 'org_id'),
				new App::Dialog::Field::Person::ID(caption =>'Physican ID', name => 'person_id'),
			
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

#sub populateData
#{
#	my ($self, $page, $command, $activeExecMode, $flags) = @_;
#
#	$page->field('person_id', $page->session('person_id'));
#}


sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $reportBeginDate = $page->field('batch_begin_date')||'01/01/1800';
	my $reportEndDate = $page->field('batch_end_date')||'01/01/9999';
	my $orgId = $page->field('org_id');
	my $person_id = $page->field('person_id')||undef;
	my $batch_from = $page->field('batch_id_from')||undef;
	my $batch_to = $page->field('batch_id_to')||undef;
	my $orgIntId = undef;
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;

	return $STMTMGR_REPORT_ACCOUNTING->createHtml($page, STMTMGRFLAG_NONE , 'sel_financial_monthly',[$reportBeginDate,
	$reportEndDate,$orgIntId,$person_id,$page->session('org_internal_id')]);

}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;