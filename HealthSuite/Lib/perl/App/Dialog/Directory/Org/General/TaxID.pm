##############################################################################
package App::Dialog::Directory::Org::General::TaxIDLookup;
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
	my $self = App::Dialog::Directory::new(@_, id => 'provider-Tax ID', heading => 'Tax ID');

	$self->addContent(
			new CGI::Dialog::Field(caption => 'Tax ID',  name => 'tax_id'),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $taxid = $page->field('tax_id') eq '' ? '*' : $page->field('tax_id');
	my $taxidLike = $taxid =~ s/\*/%/g ? 'taxid' : '';
	my $like = $taxidLike  ? '_like' : 'taxid';
	my $appendStmtName = "sel_$taxidLike$like";
	my $sessionId = $page->session('org_internal_id');
	return $STMTMGR_ORG_DIR_SEARCH->createHtml($page, STMTMGRFLAG_NONE, "$appendStmtName",
						[uc($taxid), $sessionId]);

}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;