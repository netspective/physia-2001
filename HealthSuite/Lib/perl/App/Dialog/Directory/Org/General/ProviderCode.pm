##############################################################################
package App::Dialog::Directory::Org::General::ProviderCodeLookup;
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
	my $self = App::Dialog::Directory::new(@_, id => 'provider-code', heading => 'Provider Code');

	$self->addContent(
			new CGI::Dialog::Field(caption => 'Provider Code',  name => 'vendor_code'),
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

	my $vendor = $page->field('vendor_code') eq '' ? '*' : $page->field('vendor_code');
	my $vendorLike = $vendor =~ s/\*/%/g ? 'vendor' : '';
	my $like = $vendorLike  ? '_like' : 'vendor';
	my $appendStmtName = "sel_$vendorLike$like";
	my $sessionId = $page->session('org_internal_id');
	return $STMTMGR_ORG_DIR_SEARCH->createHtml($page, STMTMGRFLAG_NONE, "$appendStmtName",
						[uc($vendor), $sessionId]);

}



# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;