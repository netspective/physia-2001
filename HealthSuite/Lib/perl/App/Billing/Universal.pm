###############################################################################################
package App::Billing::Universal;
###############################################################################################


use constant NSFDEST_ARRAY => 0;
use constant NSFDEST_FILE => 1;
use constant NSF_HALLEY => '0';
use constant NSF_ENVOY => '1';



use Exporter;

use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(NSFDEST_ARRAY NSFDEST_FILE NSF_HALLEY NSF_ENVOY);


1;



