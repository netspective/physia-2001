##############################################################################
package App::Page::PatientBill;
##############################################################################

use strict;

use App::Page::Invoice;
use Devel::ChangeLog;
use DBI::StatementManager;
use App::Statements::Org;

use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Page);

sub prepare
{
	my ($self) = @_;
	
	my $orgId = $self->param('org_id')  || $self->session('org_id');
	my $invoiceId = $self->param('invoice_id');
	
	my $orgInfo = $STMTMGR_ORG->getRowAsHash($self, STMTMGRFLAG_CACHE,
		'sel_payToOrgInfo', $invoiceId);
		
	my $personInfo = $STMTMGR_ORG->getRowAsHash($self, STMTMGRFLAG_CACHE,
		'sel_personDataFromInvoice', $invoiceId);
		
	my $clientId = $personInfo->{person_id};
		
	my $invoiceCostItems = $STMTMGR_ORG->getRowsAsHashList($self, STMTMGRFLAG_CACHE,
		'sel_invoiceCostItems', $invoiceId);
		
	my $paymentAmount = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_CACHE,
		'sel_invoicePaymentAmount', $invoiceId);
		
	my $previousBalance = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_CACHE,
		'sel_previousBalance', $clientId, $invoiceId);
	
	$self->addContent(qq{
		$orgInfo->{name_primary} <br>
		$orgInfo->{complete_addr_html} <br>
		$orgInfo->{phone} <br>
		
		$personInfo->{complete_name} <br>
		$personInfo->{complete_addr_html} <br>
		
		@{[ $STMTMGR_ORG->createHtml($self, STMTMGRFLAG_CACHE, 'sel_invoiceCostItems', [$invoiceId]) ]}
		
		Payment: $paymentAmount <br>
		
		Previous Balance: $previousBalance
		
		
	});

	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;
	return 1;
}

sub prepare_page_content_header
{
	my $self = shift;
	return 1;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->param('invoice_id', $pathItems->[0]);
	$self->param('org_id', $pathItems->[1]);
	$self->param('patient_id', $pathItems->[2]);
	
	$self->printContents();
	return 0;
}

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '04/25/2000', 'TVN',
		'Page/PatientBill',
		'Added Patient Bill page.'],
);

1;
