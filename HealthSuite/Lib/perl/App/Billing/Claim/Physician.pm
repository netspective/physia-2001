##############################################################################
package App::Billing::Claim::Physician;
##############################################################################

use strict;
use App::Billing::Claim::Entity;
use App::Billing::Claim::Person;
use Devel::ChangeLog;
use vars qw(@CHANGELOG);
use vars qw(@ISA);
use constant DATEFORMAT_USA => 1;
@ISA = qw(App::Billing::Claim::Person);
#
#   -- This modlue contains all physician's data
#   -- which is given in HCFA 1500 Form
sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Claim::Person(@_);

	$self->{pin} = undef;
	$self->{grp} = undef;
	$self->{name} = undef;
	$self->{contact} = undef;
	$self->{federalTaxId} = undef;
	$self->{assignIndicator} = undef;
	$self->{signatureIndicator} = undef;
	$self->{signatureDate} = undef;
	$self->{documentationIndicator} = undef;
	$self->{documentationType} = undef;
	$self->{siteId} = undef;
	$self->{specialityId} = undef;
	$self->{taxTypeId} = undef;
	$self->{medicareId} = undef;
	$self->{medicaidId} = undef;
	$self->{champusId} = undef;
	$self->{networkId} = undef;
	$self->{qualification} = undef;
	$self->{blueShieldId} = undef;
	$self->{idIndicator} = undef;
	$self->{providerId} = undef;
 
	return bless $self, $type;
}


sub getProviderId
{
	my $self = shift;
	
	return $self->{pin};
}

sub setDocumentationType
{
	my ($self,$value) = @_;
	
	$self->{documentationType} = $value;	
}

sub getDocumentationType
{
	my $self = shift;
	
	return $self->{documentationType};
}

sub setNetworkId
{
	my ($self,$value) = @_;
	
	$self->{networkId} = $value;	


}

sub getNetworkId
{
	my ($self) = @_;
	
	return $self->{networkId};

}
sub setQualification
{
	my ($self,$value) = @_;
	
	$self->{qualification} = $value;	
}

sub getQualification
{
	my ($self) = @_;
	
	return $self->{qualification};
}

sub setBlueShieldId
{
	my ($self,$value) = @_;
	
	$self->{blueShieldId} = $value;	

}

sub getBlueShieldId
{
	my ($self) = @_;
	
	return $self->{blueShieldId};

}

sub setIdIndicator
{
	my ($self,$value) = @_;
	
	$self->{idIndicator} = $value;	

}

sub getIdIndicator
{
	my ($self) = @_;
	
	return $self->{idIndicator};
}


sub setDocumentationIndicator
{
	my ($self,$value) = @_;
	
	$self->{documentationIndicator} = $value;	

}

sub getDocumentationIndicator
{
	my ($self) = @_;
	
	return $self->{documentationIndicator};

}

sub setSignatureDate
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);	
	$self->{signatureDate} = $value;	


}

sub getSignatureDate
{
	my ($self, $formatIndicator) = @_;

	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{signatureDate}) : $self->{signatureDate};
}

sub setSignatureIndicator
{
	my ($self,$value) = @_;
	
	$self->{signatureIndicator} = $value;	


}

sub getSignatureIndicator
{
	my ($self) = @_;
	
	return $self->{signatureIndicator};

}

sub setAssignIndicator
{
	my ($self,$value) = @_;
	
	$self->{assignIndicator} = $value;	


}

sub getAssignIndicator
{
	my ($self) = @_;
	
	return $self->{assignIndicator};

}

sub setTaxTypeId
{
	my ($self,$value) = @_;
	my $temp = 
		{
		   '0' => 'E',
		   '1' => 'S', 
		   '2' => 'X',
		   };

	$self->{taxTypeId} = $temp->{$value};	


}

sub getTaxTypeId
{
	my ($self) = @_;
	
	return $self->{taxTypeId};

}

sub setMedicareId
{
	my ($self,$value) = @_;
	
	$self->{medicareId} = $value;	


}

sub getMedicareId
{
	my ($self) = @_;
	print "Medicare ID = $self->{medicareId}\n";	
	return $self->{medicareId};

}

sub setMedicaidId
{
	my ($self,$value) = @_;
	$self->{medicaidId} = $value;	
}

sub getMedicaidId
{
	my ($self) = @_;
	print "Medicaid ID = $self->{medicaidId}\n";	
	return $self->{medicaidId};
}


sub setChampusId
{
	my ($self,$value) = @_;
	
	$self->{champusId} = $value;	


}

sub getChampusId
{
	my ($self) = @_;
	
	return $self->{champusId};

}


sub setSpecialityId
{
	my ($self,$value) = @_;
	
	$self->{specialityId} = $value;	

}

sub getSpecialityId
{
	my ($self) = @_;
	
	return $self->{specialityId};

}

sub setSiteId
{
	my ($self,$value) = @_;
	
	$self->{siteId} = $value;	
}

sub getSiteId
{
	my ($self) = @_;
	
	return 	$self->{siteId};

}	

sub setPIN
{
	my ($self,$value) = @_;

	$self->{pin} = $value;
}


sub setName
{
	my ($self,$value) = @_;

	$self->{name} = $value;
}


sub setGRP
{
	my ($self,$value) = @_;
	
	$self->{grp} = $value;
}


sub setContact
{
	my ($self,$value) = @_;
	
	$self->{contact} = $value;
}

sub setFederalTaxId
{
	my ($self,$value) = @_;
	
	$self->{federalTaxId} = $value;
}
	
sub getPIN
{
	my ($self) = @_;
	
	return $self->{pin};
}

sub getName
{
	my ($self) = @_;
	
	return $self->{name};
}

sub getGRP
{
	my ($self) = @_;
	
	return $self->{grp};
}

sub getContact
{
	my ($self) = @_;
	
	return $self->{contact};
}

sub getFederalTaxId
{
	my ($self) = @_;
	
	return $self->{federalTaxId};
}

sub convertDateToMMDDYYYYFromCCYYMMDD
{
	my ($self, $date) = @_;
				
	if ($date ne "")			
	{
		return substr($date,4,2) . '/' . substr($date,6,2) . '/' . substr($date,0,4) ;
	}
	else 
	{
		return "";
	}
}

@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]

	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'SSI', 'Billing Interface/Claim Physician','setSignatureDate use convertDateToCCYYMMDD  to change the date formats'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/11/2000', 'SSI', 'Billing Interface/Claim Physician','getSignatureDate can be provided with argument of DATEFORMAT_USA(constant 1) to get the date in mmddyyyy format'],
);

	
1;
