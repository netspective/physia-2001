##############################################################################
package XAP::Component::FileType::All;
##############################################################################

#
# this package does a "use" on all the different FileTypes so that they can
# auto-register themselves into XAP::Component::FileType::FILETYPE_MAP
#

use XAP::Component::FileType;
use XAP::Component::FileType::Template;
use XAP::Component::FileType::Component;
use XAP::Component::FileType::XML::ComponentDefn;

1;
