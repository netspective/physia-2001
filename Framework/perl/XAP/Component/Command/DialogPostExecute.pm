##############################################################################
package XAP::Component::Command::DialogPostExecute;
##############################################################################

use strict;
use XAP::Component;
use XAP::Component::Command;

use base qw(XAP::Component::Command);

XAP::Component->registerXMLTagClass('cmd-handle-post-exec', __PACKAGE__);

sub isSingleton
{
	return 1;
}

sub execute
{
	my XAP::Component::Command::DialogPostExecute $self = shift;
	my ($page, $flags, $execParams) = @_;
	
	return $execParams->{dialog}->handlePostExecute($page, $execParams->{dialogCmd}, $execParams->{dialogFlags});
}

1;