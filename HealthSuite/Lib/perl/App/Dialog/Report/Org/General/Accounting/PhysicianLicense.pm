##############################################################################
package App::Dialog::Report::Org::General::Accounting::PhysicianLicense;
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

use App::Statements::Report::PhysicianLicense;

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
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-physician-license', heading => 'Physician License');

	my $curYear = UnixDate('today', '%Y');
	my $year;
	for my $i ($curYear..$curYear + 25)
	{
		$year .= "$i:$i;"
	}

	$self->addContent(
		new CGI::Dialog::Field(
			caption => 'Provider',
			name => 'provider_id',
			fKeyStmtMgr => $STMTMGR_PERSON,
			fKeyStmt => 'selPersonBySessionOrgAndCategory',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			options => FLDFLAG_PREPENDBLANK
		),
		
		new CGI::Dialog::MultiField(
			fields => [
				new CGI::Dialog::Field(caption => 'Expiry Month',
					name => 'month',
					type => 'select',
					selOptions => 'January:01;February:02;March:03;April:04;May:05;June:06;July:07;August:08;September:09;October:10;November:11;December:12',
					options => FLDFLAG_PREPENDBLANK
				),

				new CGI::Dialog::Field(
					caption => 'Year',
					name => 'year',
					type => 'select',
					selOptions => $year,
					options => FLDFLAG_PREPENDBLANK
				),
			],
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

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $providerId = $page->field('provider_id');
	my $monthYear;
	if ($page->field('month') ne '' && $page->field('year') ne '')
	{
		$monthYear = $page->field('month') . "/" . $page->field('year');
	}

	my ($data, $html);

	if($providerId eq '')
	{
		if ($monthYear eq '')
		{
			$data = $STMTMGR_REPORT_PHYSICIAN_LICENSE->getRowsAsArray($page, STMTMGRFLAG_NONE, 'sel_physician_license', $page->session('org_internal_id'));
			$html = $STMTMGR_REPORT_PHYSICIAN_LICENSE->createHtml($page, STMTMGRFLAG_NONE, 'sel_physician_license', [$page->session('org_internal_id')]);
		}
		else
		{
			$data = $STMTMGR_REPORT_PHYSICIAN_LICENSE->getRowsAsArray($page, STMTMGRFLAG_NONE, 'sel_physician_license_exp', $page->session('org_internal_id'), $monthYear);
			$html = $STMTMGR_REPORT_PHYSICIAN_LICENSE->createHtml($page, STMTMGRFLAG_NONE, 'sel_physician_license_exp', [$page->session('org_internal_id'), $monthYear]);
		}
	}
	else
	{
		if ($monthYear eq '')
		{
			$data = $STMTMGR_REPORT_PHYSICIAN_LICENSE->getRowsAsArray($page, STMTMGRFLAG_NONE, 'sel_physician_license_prov', $page->session('org_internal_id'), $providerId);
			$html = $STMTMGR_REPORT_PHYSICIAN_LICENSE->createHtml($page, STMTMGRFLAG_NONE, 'sel_physician_license_prov', [$page->session('org_internal_id'), $providerId]);
		}
		else
		{
			$data = $STMTMGR_REPORT_PHYSICIAN_LICENSE->getRowsAsArray($page, STMTMGRFLAG_NONE, 'sel_physician_license_prov_exp', $page->session('org_internal_id'), $providerId, $monthYear);
			$html = $STMTMGR_REPORT_PHYSICIAN_LICENSE->createHtml($page, STMTMGRFLAG_NONE, 'sel_physician_license_prov_exp', [$page->session('org_internal_id'), $providerId, $monthYear]);
		}

	}
	
	return $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;