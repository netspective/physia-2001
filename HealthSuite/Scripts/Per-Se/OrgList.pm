
use strict;

use vars qw(%orgList @EXPORT);
use base qw(Exporter);

use CommonUtils;

@EXPORT = qw(%orgList);

%orgList = (
	2 => {
		billingId => 'phy169',
		nsfType => NSF_HALLEY,
	},
);

1;