##############################################################################
package App::Dialog::Directory::Org::General::VendorCodeLookup;
##############################################################################

use strict;
use Carp;
use App::Dialog::Directory;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use App::Statements::Component::Invoice;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Directory);

sub new
{
	my $self = App::Dialog::Directory::new(@_, id => 'provider-vendor-code', heading => 'Vendor Code');

	$self->addContent(
			new CGI::Dialog::Field(caption => 'Vendor Code',  name => 'vendorcode'),
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

	my $personId = $page->field('person_id');

	if ( $personId ne '')
	{
		return $STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.procAnalysis', [$personId]);
	}
	else
	{
		return $STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.procAnalysisAll');
	}



}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;