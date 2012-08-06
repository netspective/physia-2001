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





sub importStruct
{
	my ($self, $flags, $offeringCatalogs) = @_;	

	$self->{mainStruct} = $offeringCatalogs;
	
	my $feeSchedule = $offeringCatalogs->{'fee-schedule'};
	my $feeId = $feeSchedule->{id};	
	$self->schemaAction($flags, 'Offering_Catalog_Entry', 'add',		
		name =>  $feeSchedule->{id},
		status => $feeSchedule->{'schedule-entry'}->{type},
		unit_cost => $feeSchedule->{price},
		code => $feeSchedule->{code},
		modifier =>  $feeSchedule->{modifier},
		parent_catalog_id => $feeSchedule->{'parent-catalog'}->{id},
		description => $feeSchedule->{description});
	
		
	
	
	
}

1;