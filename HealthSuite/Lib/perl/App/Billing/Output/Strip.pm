##############################################################################
package App::Billing::Output::Strip;
##############################################################################

#
# this class creates an NSF entry for a single Claim or multiple claims


use strict;

use App::Billing::Claim;


sub new
{
	
	my $class = shift;
	my $self = {};
	
	return bless($self, $class);
}



sub strip
{
	my ($self, $claimList) = @_;
	
	my $claims = $claimList->getClaim();
	
	foreach my $claim (@{$claims})
	{	
		$self->stripDash($claim);
		$self->fillData($claim);
	}		
}



sub stripDash
{
	my($self, $claim) = @_;
	$claim->{payToProvider}->{federalTaxId} =~ s/-//g;
	$claim->{renderingProvider}->{federalTaxId} =~ s/-//g;
	$claim->{payToOrganization}->{federalTaxId} =~ s/-//g;
	$claim->{renderingOrganization}->{federalTaxId} =~ s/-//g;

	$claim->{payToProvider}->{address}->{zipCode} =~ s/-//g;
	$claim->{renderingProvider}->{address}->{zipCode} =~ s/-//g;
	$claim->{payToOrganization}->{address}->{zipCode} =~ s/-//g;
    $claim->{renderingOrganization}->{address}->{zipCode} =~ s/-//g;
    $claim->{careReceiver}->{address}->{zipCode} =~ s/-//g;
    $claim->{insured}->[0]->{address}->{zipCode} =~ s/-//g;
	$claim->{insured}->[1]->{address}->{zipCode} =~ s/-//g;
	$claim->{insured}->[2]->{address}->{zipCode} =~ s/-//g;
	$claim->{insured}->[3]->{address}->{zipCode} =~ s/-//g;
	$claim->{policy}->[0]->{address}->{zipCode} =~ s/-//g;
	$claim->{policy}->[1]->{address}->{zipCode} =~ s/-//g;
	$claim->{policy}->[2]->{address}->{zipCode} =~ s/-//g;
	$claim->{policy}->[3]->{address}->{zipCode} =~ s/-//g;
	$claim->{legalRepresentator}->{address}->{zipCode} =~ s/-//g;
}

sub fillData
{
	my ($self, $claim) = @_;
	
	$self->populateDate($claim);
	
	$claim->{insured}->[0]->{anotherHealthBenefitPlan} = '3';
	$claim->{insured}->[1]->{anotherHealthBenefitPlan} = '3';
	$claim->{insured}->[2]->{anotherHealthBenefitPlan} = '3';
	$claim->{insured}->[3]->{anotherHealthBenefitPlan} = '3';
	
	$claim->{insured}->[0]->{relationshipToPatient} = '01';
	$claim->{insured}->[1]->{relationshipToPatient} = '01';
	$claim->{insured}->[2]->{relationshipToPatient} = '01';
	$claim->{insured}->[3]->{relationshipToPatient} = '01';
	
	$claim->{policy}->[0]->{acceptAssignment} = 'Y';
	$claim->{policy}->[1]->{acceptAssignment} = 'Y';
	$claim->{policy}->[2]->{acceptAssignment} = 'Y';
	$claim->{policy}->[3]->{acceptAssignment} = 'Y';

	
	$claim->{payToProvider}->{sex} = ($claim->{payToProvider}->{sex} =~ /['F','M']/) ? $claim->{payToProvider}->{sex} : '';
	$claim->{renderingProvider}->{sex} = ($claim->{renderingProvider}->{sex} =~ /['F','M']/) ? $claim->{renderingProvider}->{sex} : '';
	$claim->{careReceiver}->{sex} = ($claim->{careReceiver}->{sex} =~ /['F','M']/) ? $claim->{careReceiver}->{sex} : '';
	$claim->{insured}->[0]->{sex} = ($claim->{insured}->[0]->{sex} =~ /['F','M']/) ? $claim->{insured}->[0]->{sex} : '';
	$claim->{insured}->[1]->{sex} = ($claim->{insured}->[1]->{sex} =~ /['F','M']/) ? $claim->{insured}->[1]->{sex} : '';
	$claim->{insured}->[2]->{sex} = ($claim->{insured}->[2]->{sex} =~ /['F','M']/) ? $claim->{insured}->[2]->{sex} : '';
	$claim->{insured}->[3]->{sex} = ($claim->{insured}->[3]->{sex} =~ /['F','M']/) ? $claim->{insured}->[3]->{sex} : '';
	$claim->{policy}->[0]->{sex} = ($claim->{policy}->[0]->{sex} =~ /['F','M']/) ? $claim->{policy}->[0]->{sex} : '';
	$claim->{policy}->[1]->{sex} = ($claim->{policy}->[1]->{sex} =~ /['F','M']/) ? $claim->{policy}->[1]->{sex} : '';
	$claim->{policy}->[2]->{sex} = ($claim->{policy}->[2]->{sex} =~ /['F','M']/) ? $claim->{policy}->[2]->{sex} : '';
	$claim->{policy}->[3]->{sex} = ($claim->{policy}->[3]->{sex} =~ /['F','M']/) ? $claim->{policy}->[3]->{sex} : '';



	my $procedures = $claim->{procedures};
		
	if ($#$procedures > -1)
	{
		for my $procedure (0..$#$procedures)
		{
			$claim->{procedures}->[$procedure]->{placeOfService} = '11';
		}	
	}
	
	
		
}


sub populateDate
{
	my ($self, $claim) = @_;

	$claim->{careReceiver}->{signatureDate} = ($claim->{careReceiver}->{signatureDate} eq "" ? '19990101': $claim->{careReceiver}->{signatureDate});
	$claim->{informationReleaseDate} = ($claim->{informationReleaseDate} eq "" ? '19990101': $claim->{informationReleaseDate});
		
}

1;