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
	my ($data, $html);

	if($providerId eq '')
	{
		$data = $STMTMGR_REPORT_PHYSICIAN_LICENSE->getRowsAsArray($page, STMTMGRFLAG_NONE, 'sel_physician_license', $page->session('org_internal_id'));
		$html = $STMTMGR_REPORT_PHYSICIAN_LICENSE->createHtml($page, STMTMGRFLAG_NONE, 'sel_physician_license', [$page->session('org_internal_id')]);
	}
	else
	{
		$data = $STMTMGR_REPORT_PHYSICIAN_LICENSE->getRowsAsArray($page, STMTMGRFLAG_NONE, 'sel_physician_license_prov', $page->session('org_internal_id'), $providerId);
		$html = $STMTMGR_REPORT_PHYSICIAN_LICENSE->createHtml($page, STMTMGRFLAG_NONE, 'sel_physician_license_prov', [$page->session('org_internal_id'), $providerId]);
	}
	
	return $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;