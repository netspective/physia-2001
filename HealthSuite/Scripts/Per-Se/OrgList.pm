##############################################################################
package OrgList;
##############################################################################

use strict;

use vars qw(%orgList @EXPORT);
use base qw(Exporter);

use DBI::StatementManager;
use App::Statements::BillingStatement;

@EXPORT = qw(%orgList);

sub buildOrgList
{
	my ($page) = @_;

	my $billingIds = $STMTMGR_STATEMENTS->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'sel_BillingIds');

	for (@{$billingIds})
	{
		my $orgInternalId = $_->{org_internal_id};
		
		if ($_->{provider_id})
		{
			my $key = $orgInternalId . '.' . $_->{provider_id};
			$orgList{$key}->{orgId} = $_->{org_id};
			$orgList{$key}->{billingId} = $_->{billing_id};
			$orgList{$key}->{nsfType} = $_->{nsf_type};
			$orgList{$key}->{providerId} = $_->{provider_id};
		}
		else
		{
			$orgList{$orgInternalId}->{orgId} = $_->{org_id};
			$orgList{$orgInternalId}->{billingId} = $_->{billing_id};
			$orgList{$orgInternalId}->{nsfType} = $_->{nsf_type};
		}
	}
}

1;

##############################################################################
package OldOrgList;
##############################################################################

use strict;

my %orgList = (
	2 => {
		orgId => 'WCLARKPA',
		billingId => 'phy169',
		nsfType => CommonUtils::NSF_HALLEY,
	},

	142 => {
		orgId => 'TXGULF',
		billingId => 'tex11c',
		nsfType => CommonUtils::NSF_HALLEY,
	},

	501.1 => {
		orgId => 'CHSINC',
		providerId => 'DHOEFER',
		billingId => 'hoe100',
		nsfType => CommonUtils::NSF_HALLEY,
	},

	501.2 => {
		orgId => 'CHSINC',
		providerId => 'PSHEPARD',
		billingId => 'she137',
		nsfType => CommonUtils::NSF_HALLEY,
	},

	727 => {
		orgId => 'SCOT',
		billingId => 'sur127',
		nsfType => CommonUtils::NSF_HALLEY,
	},

	749 => {
		orgId => 'CAPSTONE',
		billingId => 'cap137',
		nsfType => CommonUtils::NSF_HALLEY,
	},

	751 => {
		orgId => 'IDAH',
		billingId => 'inf104',
		nsfType => CommonUtils::NSF_HALLEY,
	},
);

1;
