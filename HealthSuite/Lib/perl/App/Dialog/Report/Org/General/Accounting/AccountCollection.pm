##############################################################################
package App::Dialog::Report::Org::General::Accounting::AccountCollection;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use Data::Publish;
use App::Statements::Report::AccountCollection;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-account-collection', heading => 'Account Collection');

	$self->addContent(
		new CGI::Dialog::Field::Duration(
			name => 'report',
			caption => 'Start/End Report Date',
			begin_caption => 'Report Begin Date',
			end_caption => 'Report End Date',
		),
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('report_begin_date', $startDate);
	$page->field('report_end_date', $startDate);
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $html = $STMTMGR_REPORT_ACCOUNT_COLLECTION->createHtml($page, STMTMGRFLAG_NONE, 'selCollectors', [$page->field('report_begin_date'), $page->field('report_end_date')]);
	return $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;