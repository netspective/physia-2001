##############################################################################
package App::Dialog::Report::Org::General::Accounting::InvoiceCreditBalance;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use Data::Publish;

use App::Statements::Worklist::InvoiceCreditBalance;
use App::Statements::Person;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Person;
use App::Dialog::Field::Insurance;
use App::Configuration;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-invoice-credit-balance', heading => 'Credit Balance Invoices');

	$self->addContent(
		new CGI::Dialog::Field::Duration(
			name => 'invoice',
			caption => 'Start/End Invoice Date',
			begin_caption => 'Report Begin Date',
			end_caption => 'Report End Date',
		),
		new CGI::Dialog::Field(
			caption => 'Physician ID',
			name => 'provider_id',
			fKeyStmtMgr => $STMTMGR_PERSON,
			fKeyStmt => 'selPersonBySessionOrgAndCategory',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			options => FLDFLAG_PREPENDBLANK
		),

		new App::Dialog::Field::OrgType(
			caption => 'Site Organization ID',
			name => 'org_id',
			options => FLDFLAG_PREPENDBLANK,
			types => "'PRACTICE', 'CLINIC','FACILITY/SITE','DIAGNOSTIC SERVICES', 'DEPARTMENT', 'HOSPITAL', 'THERAPEUTIC SERVICES'",
		),
		new App::Dialog::Field::Insurance::Product(
			caption => 'Insurance Product',
			name => 'product_id',
			findPopup => '/lookup/insproduct/insorgid',
		),
		new CGI::Dialog::Field(type => 'select',
			style => 'radio',
			selOptions => 'Patients Alphabetically:1;Oldest Refund Due First:2',
			caption => 'Sorting',
			name => 'sorting',
			defaultValue => '1',
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

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('invoice_begin_date', $startDate);
	$page->field('invoice_end_date', $startDate);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $html;
	
	if ($page->field('sorting') == 1) 
	{
		$html = $STMTMGR_WORKLIST_CREDIT->createHtml($page, STMTMGRFLAG_NONE, 'sel_invoice_credit_balance_patient', 
			[ 	$page->field('invoice_begin_date'), $page->field('invoice_end_date'),
				$page->field('provider_id'), $page->field('org_id'), $page->field('product_id')
			]);
	}
	else
	{
		$html = $STMTMGR_WORKLIST_CREDIT->createHtml($page, STMTMGRFLAG_NONE, 'sel_invoice_credit_balance_age', 
			[ 	$page->field('invoice_begin_date'), $page->field('invoice_end_date'),
				$page->field('provider_id'), $page->field('org_id'), $page->field('product_id')
			]);
	}
	return $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;