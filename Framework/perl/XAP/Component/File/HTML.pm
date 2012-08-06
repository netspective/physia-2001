##############################################################################
package XAP::Component::File::HTML;
##############################################################################

use strict;
use Exporter;
use XAP::Component::File;
use base qw(XAP::Component::File Exporter);

sub getBodyHtml
{
	my XAP::Component::File::HTML $self = shift;

	return "Unable to open $self->{fileName}: $!" unless open(SRCFILE, $self->{fileName});

	my @contents = <SRCFILE>;
	close(SRCFILE);

	return join('', @contents);
}

1;