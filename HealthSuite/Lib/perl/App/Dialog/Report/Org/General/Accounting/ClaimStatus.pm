##############################################################################
package App::Dialog::Report::Org::General::Accounting::ClaimStatus;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use App::Statements::Component::Invoice;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-claim-status', heading => 'Claim Status');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'report',
				caption => 'Start/End Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),				
			new CGI::Dialog::Field(name => 'claim_status',
				caption => 'Claim Status',
				enum => 'invoice_status',					
				style => 'multicheck',	
				defaultValue => 0
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

	my $reportBeginDate = $page->field('report_begin_date');
	my $reportEndDate = $page->field('report_end_date');
	my $status = join(',',  $page->field('claim_status')) || $page->field('claim_status');
	my $orgId = $page->session('org_id');

	#$page->addDebugStmt("status, orgid, begindate, enddate are $status , $orgId, $reportBeginDate, $reportEndDate");
	#return 	$STMTMGR_COMPONENT_INVOICE->createHtml($page, 0, 'invoice.claimStatus',$status eq 'all' || $status eq 'incomplete' ? [uc($orgId)] : [$status, uc($orgId)]);
	return 	$STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.claimStatus',[$status , $orgId, $reportBeginDate, $reportEndDate]);

}

#select 	invoice_id, total_items, client_id, invoice_date as invoice_date,
#	invoice_status as invoice_status, bill_to_id, total_cost, total_adjust,
#	balance, reference, bill_to_type
#from 	invoice
#where	invoice_status in (0,1)
#and 	owner_type = 1
#and 	owner_id = 'CLMEDGRP'
#order by invoice_date DESC



# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;