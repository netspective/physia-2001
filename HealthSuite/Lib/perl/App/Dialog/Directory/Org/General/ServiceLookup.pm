##############################################################################
package App::Dialog::Directory::Org::General::ServiceLookup;
##############################################################################

use strict;
use Carp;
use App::Dialog::Directory;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Search::OrgDirectory;
use App::Statements::Transaction;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Directory);

sub new
{
	my $self = App::Dialog::Directory::new(@_, id => 'provider-service', heading => 'Service');

	$self->addContent(
						new CGI::Dialog::Field(caption =>'Service',
								name => 'service',
								options => FLDFLAG_PREPENDBLANK|FLDFLAG_REQUIRED,
								fKeyStmtMgr => $STMTMGR_TRANSACTION,
								fKeyStmt => 'selReferralType',
								fKeyDisplayCol => 1,
								fKeyValueCol => 0),
					);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $service = $page->field('service') eq '' ? '*' : $page->field('service');
	my $serviceLike = $service =~ s/\*/%/g ? 'onlyservice_like' : 'onlyservice';
	my $appendStmtName = "sel_$serviceLike";
	my $sessionId = $page->session('org_internal_id');

	return $STMTMGR_ORG_SERVICE_DIR_SEARCH->createHtml($page, STMTMGRFLAG_NONE, "$appendStmtName",
						[uc($service), $sessionId]);

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;