##############################################################################
package App::Page::Person::Account;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Universal;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/account' => {},
	);


sub prepare_view
{
	my ($self) = @_;

	$self->addLocatorLinks(['Account', 'account']);

	my $personId = $self->param('person_id');
	my $todaysDate = $self->getDate();
	my $invoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');
	my $queryStmt = $self->param('viewall') ? 'selAllInvoiceTypeForClient' : 'selNonVoidInvoiceTypeForClient';


	$self->addContent(
		"<CENTER>
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=5>
			<TR VALIGN=TOP>
				<TD>
					#component.stp-person.account-notes#<BR>
					</font>
				</TD>
				<TD>
					#component.stp-person.insuranceVerify#<BR>
					</font>
				</TD>
			</TR>
		</TABLE>",
		$STMTMGR_INVOICE->createHtml($self, STMTMGRFLAG_NONE, $queryStmt,
			[$personId, $self->session('org_internal_id')],
		),
		"</CENTER>"
	);
}

1;
