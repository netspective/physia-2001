##############################################################################
package App::Dialog::Report::Org::General::Accounting::ReceiptAnalysis;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Component::Invoice;
use App::Statements::Report::Accounting;
use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-receipt-analysis', heading => 'Receipt Analysis');

	$self->addContent(
			new App::Dialog::Field::Person::ID(caption =>'Provider ID', name => 'person_id', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			new CGI::Dialog::Field(caption =>'Payment Type',
					name => 'transaction_type',
					options => FLDFLAG_PREPENDBLANK,
					fKeyStmtMgr => $STMTMGR_INVOICE,
					fKeyStmt => 'selPaymentMethod',
					fKeyDisplayCol => 0
					),
			new CGI::Dialog::Field(caption =>'Begin Date',
						type => 'date',
						name => 'auth_date',
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						defaultValue => '',
						options => FLDFLAG_REQUIRED),

			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $provider = $page->field('person_id') eq '' ? '*' : $page->field('person_id');
	my $receipt = $page->field('transaction_type') eq '' ? '*' : $page->field('transaction_type');
	my $begin = $page->field('auth_date');

	my $providerLike = $provider =~ s/\*/%/g ? 'provider' : '';
	my $receiptLike = $receipt =~ s/\*/%/g ? 'receipt' : '';

	my $like = $providerLike || $receiptLike ? '_like' : 'providerreceipt';
	my $appendStmtName = "sel_$providerLike$receiptLike$like";

	return $STMTMGR_REPORT_ACCOUNTING->createHtml($page, STMTMGRFLAG_NONE, "$appendStmtName",
					[$begin, $begin,$page->session('org_internal_id'), uc($provider), uc($receipt)]);

}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;