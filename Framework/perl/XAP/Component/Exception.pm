##############################################################################
package XAP::Component::Exception;
##############################################################################

use strict;
use Exporter;
use XAP::Component;
use base qw(XAP::Component Exporter);
use fields qw(message stackTrace);

sub init
{
	my XAP::Component::Exception $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);

	$self->{message} = exists $params{message} ? $params{message} : "No message provided in '@{[ ref $self ]}::init'";
	$self->{caption} = $self->{message};
	$self->{heading} = $self->{caption};

	my $stackTrace = '';
	my $start = 0;
	my ($package, $fileName, $line) = caller();
	while($fileName)
	{
		$stackTrace .= "<BR>$fileName line $line";
		($package, $fileName, $line) = caller(++$start);
	}
	$self->{stackTrace} = $stackTrace;

	$self;
}

sub getBodyHtml
{
	my XAP::Component::Exception $self = shift;
	return qq{
		<H2><font color=red>$self->{message}</font></H2>
		<code>$self->{stackTrace}</code>
		};
}

1;