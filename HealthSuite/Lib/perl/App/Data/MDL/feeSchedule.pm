##############################################################################
package App::Data::MDL::FeeSchedule;
##############################################################################

use strict;
use App::Data::MDL::Module;
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
	my ($self, $flags, $catalog, $entryList, $parentEntry) = @_;	

	$entryList = [$entryList] if ref $entryList eq 'HASH';	
	foreach my $entry (@$entryList)
	{
		#my $dv = new Dumpvalue;
		#$dv->dumpValue($parentEntry);
		my $parentEntry = $self->schemaAction($flags, "Offering_Catalog_Entry", 'add',
					catalog_id =>  $catalog->{id},
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
				$self->importEntry($flags, $catalog, $entry, $parentEntry);

			}

		}
	}

}

sub importCatalog
{
	my ($self, $flags, $catalog, $parentCatalog) = @_;

	#my $dv = new Dumpvalue;
	#$dv->dumpValue($catalog);	
	$self->schemaAction($flags|MDLFLAG_LOGACTIVITY, 'Offering_Catalog', 'add',
			catalog_id => $catalog->{id},
			catalog_type =>  $self->translateEnum($flags,"Offering_Catalog_Type", $catalog->{type} || 'Fee Schedule'),
			caption => $catalog->{'fee-caption'},
			parent_catalog_id => defined $parentCatalog ? $parentCatalog->{id} : undef,
			description => $catalog->{description});
			
	if (my $childEntry = $catalog->{'schedule-entry'} )
	{
		$self->importEntry($flags, $catalog, $childEntry);
	}

	my $catalogData = [$catalog] if ref $catalog eq 'HASH';	
	foreach my $item (@$catalogData)
	{	
		
		if(my $childSchedule = $item->{'fee-schedule'})
		{				
			$self->importCatalog($flags, $childSchedule, $item);
			
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