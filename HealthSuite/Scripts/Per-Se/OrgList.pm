
use strict;

use vars qw(%orgList @EXPORT);
use base qw(Exporter);

use CommonUtils;

@EXPORT = qw(%orgList);

%orgList = (
	2 => {
		orgId => 'WCLARKPA',
		billingId => 'phy169',
		nsfType => NSF_HALLEY,
	},
	
	142 => {
		orgId => 'TXGULF',
		billingId => 'tex11c',
		nsfType => NSF_HALLEY,
	},
	
	501.1 => {
		orgId => 'CHSINC',
		providerId => 'DHOEFER',
		billingId => 'hoe100',
		nsfType => NSF_HALLEY,
	},

	501.2 => {
		orgId => 'CHSINC',
		providerId => 'PSHEPARD',
		billingId => 'she135',
		nsfType => NSF_HALLEY,
	},
	
	727 => {
		orgId => 'SCOT',
		billingId => 'sur127',
		nsfType => NSF_HALLEY,
	},

	749 => {
		orgId => 'CAPSTONE',
		billingId => 'cap137',
		nsfType => NSF_HALLEY,
	},

	751 => {
		orgId => 'IDAH',
		billingId => 'inf104',
		nsfType => NSF_HALLEY,
	},
	
);

1;