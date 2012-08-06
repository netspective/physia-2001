##############################################################################
package App::Data::Obtain::Perse::Epayer;
##############################################################################

use strict;
use App::Data::Manipulate;
use vars qw(@ISA $VERSION);

use base 'App::Data::Obtain';

use constant PAYERTYPE_NON_COMMERCIAL => 0;
use constant PAYERTYPE_COMMERCIAL => 100;

$VERSION = "1.00";

sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	my $payersFile = $params{ePayersFile};

	unless(open(PERSE, $payersFile)) {
		$self->addError("unable to open Perse payers file '$payersFile': $!");
		return;
	}	

	my $data = $collection->{data};
	my @cols = ();
	my $count = 0;

	$self->reportMsg("Loading Perse Payers ...") if $flags & DATAMANIPFLAG_VERBOSE;
	
	while (<PERSE>)
	{
		chomp;
		my ($id, $name, $id2) = split(/\s*,\s*/);
		
		push(@$data, [
			App::Data::Manipulate::trim($id),
			#($id2 =~ /N\/A/i) ? undef : App::Data::Manipulate::trim($id2),
			$name,
			2, # pSource = Perse
			($id2 =~ /N\/A/i) ? PAYERTYPE_NON_COMMERCIAL : PAYERTYPE_COMMERCIAL,
		]);
		
		$count++;
		print "\rReading line $count" if $count % 200 == 0;
	}
	$self->reportMsg("$count lines read from $payersFile") if $flags & DATAMANIPFLAG_VERBOSE;
}

1;
