##############################################################################
package App::Dialog::Report;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use vars qw(@ISA %DIRECTORY);

@ISA = qw(CGI::Dialog);
%DIRECTORY = ();

sub new
{
	my $self = CGI::Dialog::new(@_);

	my $id = $self->{id} || die 'id is required';
	$DIRECTORY{$id} = $self;
	return $self;
}

sub description
{
}

1;