##############################################################################
package App::Dialog::Directory::Org::General::ProviderNameLookup;
##############################################################################

use strict;
use Carp;
use App::Dialog::Directory;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Search::OrgDirectory;


use vars qw(@ISA $INSTANCE %RESOURCE_MAP);

@ISA = qw(App::Dialog::Directory);

sub new
{
	my $self = App::Dialog::Directory::new(@_, id => 'providername', heading => 'Provider Name');

	$self->addContent(
			new CGI::Dialog::Field(caption => 'Provider Name',  name => 'provider_name'),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $provider = $page->field('provider_name') eq '' ? '*' : $page->field('provider_name');
	my $providerLike = $provider =~ s/\*/%/g ? 'providername' : '';
	my $like = $providerLike  ? '_like' : 'providername';
	my $appendStmtName = "sel_$providerLike$like";
	my $sessionId = $page->session('org_internal_id');
	return $STMTMGR_ORG_DIR_SEARCH->createHtml($page, STMTMGRFLAG_NONE, "$appendStmtName",
						[uc($provider), $sessionId]);

}



# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;