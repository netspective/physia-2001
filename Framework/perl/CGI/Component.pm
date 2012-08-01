##############################################################################
package CGI::Component;
##############################################################################

use strict;
use CGI::Layout;
use App::Universal;

sub new
{
	my $type = shift;
	my %params = @_;

	my $self = bless \%params, $type;

	$self->{flags} = 0 unless exists $self->{flags};
	$self->{layoutDefn} =
	{
		width => '100%',
		style => 'panel',
		blocks => '#CONTENT#',
	} unless exists $self->{layoutDefn};
	$self->init(%params) if $self->can('init');

	return $self;
}

#-----------------------------------------------------------------------------

# flag-management functions:
#   $self->updateFlag($mask, $onOff) -- either turn on or turn off $mask
#   $self->setFlag($mask) -- turn on $mask
#   $self->clearFlag($mask) -- turn off $mask
#   $self->flagIsSet($mask) -- return true if any $mask are set

sub updateFlag
{
	if($_[2])
	{
		$_[0]->{flags} |= $_[1];
	}
	else
	{
		$_[0]->{flags} &= ~$_[1];
	}
}

sub setFlag
{
	$_[0]->{flags} |= $_[1];
}

sub clearFlag
{
	$_[0]->{flags} &= ~$_[1];
}

sub flagIsSet
{
	return $_[0]->{flags} & $_[1];
}

#-----------------------------------------------------------------------------

sub layoutDefn
{
	$_[0]->{layoutDefn} = $_[1] if defined $_[1];
	return $_[0]->{layoutDefn};
}

sub getHtml
{
	my ($self, $page) = @_;
	#return createLayout_html($page, $self->{flags}, $self->{layoutDefn}, $params);
}

1;
