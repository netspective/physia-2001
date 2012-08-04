##############################################################################
package App::Data::Obtain::InfoX::ICD;
##############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain;
use vars qw(@ISA $VERSION);

@ISA = qw(App::Data::Obtain);
$VERSION = "1.00";

sub code
{
	return 80;
}

sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	unless($params{srcFile})
	{
		$self->addError("srcFile parameters is required");
		return;
	}

	unless(open(SRC, $params{srcFile}))
	{
		$self->addError("unable to open $params{srcFile}: $!");
		return;
	}

	$self->reportMsg("Loading $params{srcFile}.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $data = $collection->{data};
	my @cols = ();
	my $code = $self->code();
	my $count = 0;
	while(<SRC>)
	{
		chomp;
		@cols = split(/\t/);
		push(@$data, [$code, $cols[0], $cols[1], $cols[2]]);
		$count++;
	}
	$self->reportMsg("$count lines read from $params{srcFile}") if $flags & DATAMANIPFLAG_SHOWPROGRESS;	

	close(SRC);
}
