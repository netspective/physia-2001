##############################################################################
package App::Page::Person::Billing;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::BillingStatement;
use App::Statements::Component::Scheduling;

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
	my $orgInternalId = $self->session('org_internal_id');

	$self->addContent(qq{
		<style>
			a {text-decoration: none;}
		</style>

		<CENTER>
		<b>Last 10 Statements for @{[$self->param('person_id')]}</b>
		@{[ $STMTMGR_PERSON->createHtml($self, STMTMGRFLAG_NONE, 'selStatementsForClient',
			[$personId, $orgInternalId],) ]}

		<P>
		<b>Payment Plan for @{[$self->param('person_id')]}</b>
		@{[ $STMTMGR_STATEMENTS->createHtml($self, STMTMGRFLAG_NONE, 'sel_paymentPlan',
			[$personId, $orgInternalId],) ]}

		<P>
		<b>Last 10 Payments from @{[$self->param('person_id')]}</b>
		@{[ $STMTMGR_STATEMENTS->createHtml($self, STMTMGRFLAG_NONE, 'sel_paymentHistory',
			[$personId, $orgInternalId, $self->session('GMT_DAYOFFSET')],) ]}

		<P>
		<b>Insurance Verification</b>
		@{[ $STMTMGR_COMPONENT_SCHEDULING->createHtml($self, STMTMGRFLAG_NONE, 'sel_verified_events',
			[$orgInternalId, $personId],) ]}

		</CENTER>
	});
}

1;
