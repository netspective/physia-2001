##############################################################################
package App::Billing::Output::Driver;
##############################################################################

#
# this is the base class, made up mostly of abstract methods that describes
# how any billing data output driver should be created
#
# any methods needed by all Output drivers should be placed in here
#

use strict;
use Carp;
use App::Billing::Driver;

#use App::Billing::Claim;

#
# this object is inherited from App::Billing::Driver
#
use vars qw(@ISA);
@ISA = qw(App::Billing::Driver);

sub processClaim
{
	my ($self, $claim, %params) = @_;

	#
	# here is where all output-driver-specific processing would happen
	# -- e.g., create an NSF file
	# -- or, create an XML file
	# -- etc.
	
	$self->{encryptParams} = {};

	return $self->haveErrors();   # return 1 if successful, 0 if not
}


sub readEncryptFile
{
    
    my ($self, $encryptKeyFile) = @_;   
	my ($hash,$value,$key);
	
	open(CONF, $encryptKeyFile);
	my $abc='abc';
	while ($abc ne '')
	{
		$abc = (<CONF>);

		chop $abc;
		($hash,$value) = split(/=/,$abc);
			$self->{encryptParams}->{$hash} = $value;

	}
	close(CONF);
}

sub createPGPEncryptFile
{
	my ($self, $encryptKeyFile, $inFile) = @_;
	
	$self->readEncryptFile($encryptKeyFile);  # read the parameter from encrypt.txt 

   
    my @args = ("pgp","-e",$inFile ,$self->{encryptParams}->{cryptKeyID});

    system(@args) == 0 or die "system @args failed : $? ";

#	$obj->EncodeFileEx($inFile, $self->{encryptParams}->{encryptFile}, 
#						$self->{encryptParams}->{keyEncrypt}, 
#						$self->{encryptParams}->{sign}, 
#						$self->{encryptParams}->{signAlg},
#						$self->{encryptParams}->{convEncrypt},
#						$self->{encryptParams}->{convAlg},
#						$self->{encryptParams}->{armor},
#						$self->{encryptParams}->{textMode},
#						$self->{encryptParams}->{clear},
#						$self->{encryptParams}->{compress},
#						$self->{encryptParams}->{eyesOnly}, 
#						$self->{encryptParams}->{mime},
#						$self->{encryptParams}->{cryptKeyID},
#						$self->{encryptParams}->{signKeyID},
#						$self->{encryptParams}->{signKeyPass},
#						$self->{encryptParams}->{convPass},
#						$self->{encryptParams}->{comment},
#						\$self->{encryptParams}->{mimeSeperator});

}

1;