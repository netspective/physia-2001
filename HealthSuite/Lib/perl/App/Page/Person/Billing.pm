##############################################################################
package App::Page::Person::Billing;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use DBI::StatementManager;
use App::Statements::Person;
use App::Universal;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/billing' => {},
	);


sub prepare_view
{
	my ($self) = @_;

	$self->addLocatorLinks(['Billing', 'billing']);

	my $personId = $self->param('person_id');
	my $todaysDate = $self->getDate();
	my $invoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	$self->addContent(
		"<CENTER>",
		$STMTMGR_PERSON->createHtml($self, STMTMGRFLAG_NONE, 'selStatementsForClient',
			[$personId, $self->session('org_internal_id')],
		),
		"</CENTER>"
	);
}

1;
