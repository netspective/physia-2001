##############################################################################
package XAP::Component::Command::ShowDialogFields;
##############################################################################

use strict;
use XAP::Component;
use XAP::Component::Command;

use base qw(XAP::Component::Command);

XAP::Component->registerXMLTagClass('cmd-show-dlg-fields', __PACKAGE__);

sub execute
{
	my XAP::Component::Command::ShowDialogFields $self = shift;
	my ($page, $flags, $execParams) = @_;
	
	return $execParams->{dialog}->getBodyHtml($page);
}

1;