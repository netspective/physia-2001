##############################################################################
package App::Dialog::Directory::Org::General::ServiceStCityLookup;
##############################################################################

use strict;
use Carp;
use App::Dialog::Directory;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Component::Org;
use App::Statements::Search::OrgDirectory;
use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Directory);

sub new
{
	my $self = App::Dialog::Directory::new(@_, id => 'provider-service-state-city', heading => 'Service + State + City');

	$self->addContent(
			new CGI::Dialog::Field(caption =>'Service',
						name => 'service',
						options => FLDFLAG_PREPENDBLANK|FLDFLAG_REQUIRED,
						fKeyStmtMgr => $STMTMGR_TRANSACTION,
						fKeyStmt => 'selReferralType',
						fKeyDisplayCol => 1,
						fKeyValueCol => 0),
			new CGI::Dialog::Field(caption =>'State',
						name => 'state',
						size => 2,
						maxLength => 2),
			new CGI::Dialog::Field(caption => 'City',  name => 'city'),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $service = $page->field('service') eq '' ? '*' : $page->field('service');
	my $state = $page->field('state') eq '' ? '*' : $page->field('state');
	my $city = $page->field('city') eq '' ? '*' : $page->field('city');

	my $serviceLike = $service =~ s/\*/%/g ? 'service' : '';
	my $stateLike = $state =~ s/\*/%/g ? 'state' : '';
	my $cityLike = $city =~ s/\*/%/g ? 'city' : '';
	my $sessionId = $page->session('org_internal_id');
	my $like = $serviceLike || $stateLike || $cityLike  ? '_like' : 'servicestatecity';
	my $appendStmtName = "sel_s$serviceLike$stateLike$cityLike$like";

	return $STMTMGR_ORG_SERVICE_DIR_SEARCH->createHtml($page, STMTMGRFLAG_NONE, "$appendStmtName",
						[uc($service), uc($state), uc($city),
						$sessionId]);

}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;