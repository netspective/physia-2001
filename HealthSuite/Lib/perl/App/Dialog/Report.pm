##############################################################################
package App::Dialog::Report;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use vars qw(@ISA %DIRECTORY %RESOURCE_MAP);
%RESOURCE_MAP = ();

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

sub getFilePageCount
{
	my ($self, $filename) = @_;

	my $pages = 0;
	my $buffer;

	open(FILE, $filename) or return 0;  # die "Can't open '$filename': $!";
	while (sysread FILE, $buffer, 4096)
	{
		$pages += ($buffer =~ tr/\f//);
	}
	close FILE;
	return $pages + 1;
}

sub getFileLineCount
{
	my ($self, $filename) = @_;

	my $lines = 0;
	my $buffer;

	open(FILE, $filename) or return 0;  # die "Can't open '$filename': $!";
	while (sysread FILE, $buffer, 4096)
	{
		$lines += ($buffer =~ tr/\n//);
	}
	close FILE;
	return $lines + 1;
}

1;