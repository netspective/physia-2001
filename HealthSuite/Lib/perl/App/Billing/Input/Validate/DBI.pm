##############################################################################
package App::Billing::Input::Validate::DBI;
##############################################################################

use strict;
use Carp;
use App::Billing::Driver;

use vars qw(@ISA);
@ISA = qw(App::Billing::Validator);

use constant VALIDATORFLAGS_DEFAULT => 0;

use constant VALITEMIDX_NAME => 0;
use constant VALITEMIDX_INSTANCE => 1;
use constant VALITEMIDX_ERRCODE => 2;
use constant VALITEMIDX_MESSAGE => 3;

sub new
{
	my ($type) = @_;
	my $self = new App::Billing::Validator(@_);
	return bless $self, $type;
}

# read/write a generic property for this class
#
sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub getId
{

	return 'VDBI';
}

sub getName
{
	return 'DBI Validator Class';
}

sub getCallSequences
{
	return 'Input_DBI';

}


sub validate
{
	my ($self, $parent, $callSeq, $vFlags, $dbi) = @_;
	
	$self->validateRequired($vFlags,[['dbiCon',$dbi,200 ]],$parent);	

}

sub validateRequired
{
	my ($self, $vFlag, $vList,$parent) = @_;
	
	foreach my $item (@$vList)
	{
		my $attrName = $item->[VALITEMIDX_NAME];
		my $object = $item->[VALITEMIDX_INSTANCE];

		unless($object->{$attrName})
		{
			$parent->addError($self->getId(), $item->[VALITEMIDX_ERRCODE], $item->[VALITEMIDX_MESSAGE] || "$attrName is required");
		}
	}
}

1;