##############################################################################
package App::Dialog::Directory::Org::General::ZipCodeLookup;
##############################################################################

use strict;
use Carp;
use App::Dialog::Directory;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Search::OrgDirectory;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Directory);

sub new
{
	my $self = App::Dialog::Directory::new(@_, id => 'provider-zip-code', heading => 'State + City + Zip');

	$self->addContent(
			new CGI::Dialog::Field(caption => 'State',  name => 'state', size=> '2', maxlength=> '2'),
			new CGI::Dialog::Field(caption => 'City',  name => 'city', size=> '15', maxlength=> '15'),
			new CGI::Dialog::Field(caption => 'Zip Code',  name => 'zip', size=> '5', maxlength=> '5'),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $state = $page->field('state') eq '' ? '*' : $page->field('state');
	my $city = $page->field('city') eq '' ? '*' : $page->field('city');
	my $zip = $page->field('zip') eq '' ? '*' : $page->field('zip');

	my $stateLike = $state =~ s/\*/%/g ? 'state' : '';
	my $cityLike = $city =~ s/\*/%/g ? 'city' : '';
	my $zipLike = $zip =~ s/\*/%/g ? 'zip' : '';
	my $sessionId = $page->session('org_internal_id');
	my $like = $stateLike || $cityLike || $zipLike  ? '_like' : 'statecityzip';
	my $appendStmtName = "sel_$stateLike$cityLike$zipLike$like";

	return $STMTMGR_ORG_DIR_SEARCH->createHtml($page, STMTMGRFLAG_NONE, "$appendStmtName",
						[uc($state), uc($city), uc($zip),
						$sessionId]);

}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;