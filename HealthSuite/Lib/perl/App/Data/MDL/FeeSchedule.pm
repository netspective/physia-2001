##############################################################################
package App::Data::MDL::FeeSchedule;
##############################################################################

use strict;
use App::Data::MDL::Module;
use DBI::StatementManager;
use App::Statements::Org;
use vars qw(@ISA);
use Dumpvalue;

@ISA = qw(App::Data::MDL::Module);


sub new
{
	my $type = shift;
	my $self = new App::Data::MDL::Module(@_, parentTblPrefix => 'Offering_Catalog');
	return bless $self, $type;
}

sub importEntry
{
	my ($self, $flags, $catalog, $entryList, $internalId, $parentEntry) = @_;

	$entryList = [$entryList] if ref $entryList eq 'HASH';
	foreach my $entry (@$entryList)
	{
		#my $dv = new Dumpvalue;
		#$dv->dumpValue($parentEntry);
		my $parentEntry = $self->schemaAction($flags, "Offering_Catalog_Entry", 'add',
					catalog_id =>  $internalId,
					entry_type => $self->translateEnum($flags, "Catalog_Entry_Type", $entry->{type}),
					status => $self->translateEnum($flags, "Catalog_Entry_Status", $entry->{status}),
					unit_cost => $entry->{price},
					cost_type => $self->translateEnum($flags, "Catalog_Entry_Cost_Type", $entry->{'cost-type'}),
					code => $entry->{'cat-code'},
					parent_entry_id => $parentEntry || undef,
					modifier =>  $entry->{modifier},
					description => $entry->{description});

		my $entryData = [$entry] if ref $entry eq 'HASH';

		foreach my $item (@$entryData)
		{
			if(my $entry = $item->{'schedule-entry'})
			{
				$self->importEntry($flags, $catalog, $entry, $internalId, $parentEntry);

			}

		}
	}

}

sub importCatalog
{
	my ($self, $flags, $catalog, $parentCatalog) = @_;

	#my $dv = new Dumpvalue;
	#$dv->dumpValue($catalog);
	#my $catId = $catalog->{id};
	my $orgId = $catalog->{'org-id'};

	my $ownerOrg = exists $catalog->{'owner-org'} ? $catalog->{'owner-org'} : $orgId;
	my $ownerOrgIdExist = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $ownerOrg);
	my $internalOrgId = exists $catalog->{'owner-org'} ? $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrg', $ownerOrgIdExist, $orgId) : $ownerOrgIdExist;

	my $internalId = $self->schemaAction($flags, 'Offering_Catalog', 'add',
				catalog_id => $catalog->{'id'} || undef,
				org_internal_id  => $internalOrgId || undef,
				catalog_type =>  $self->translateEnum($flags,"Offering_Catalog_Type", $catalog->{type} || 'Fee Schedule') || undef,
				caption => $catalog->{'fee-caption'} || undef,
				parent_catalog_id => $parentCatalog || undef,
				description => $catalog->{description} || undef,
				rvrbs_multiplier => $catalog->{multiplier} || undef);

	if (my $childEntry = $catalog->{'schedule-entry'} )
	{
		$self->importEntry($flags, $catalog, $childEntry, $internalId);
	}

	my $catalogData = [$catalog] if ref $catalog eq 'HASH';
	foreach my $item (@$catalogData)
	{

		if(my $childSchedule = $item->{'fee-schedule'})
		{
			$self->importCatalog($flags, $childSchedule, $internalId);

		}
		#elsif(my $childEntry = $item->{feeentry})
		#{
		#	$self->importEntry($flags, $item, $childEntry);
		#}
	}
}

sub importStruct
{
	my ($self, $flags, $offeringCatalogs, $parentCatalog) = @_;
	$self->{mainStruct} = $offeringCatalogs unless $parentCatalog;
	my $list = $offeringCatalogs;

	$list = [$list] if ref $list eq 'HASH';
	foreach my $item (@$list)
	{
		if(my $childSchedule = $item->{'fee-schedule'})
		{
			$self->importCatalog($flags, $childSchedule);
		}
	}
}

1;