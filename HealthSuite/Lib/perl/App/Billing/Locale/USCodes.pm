###############################################################################
package App::Billing::Locale::USCodes;
###############################################################################

#
# This class provides valid US State and Zip Codes
#

use strict;
use Carp;

use vars qw(@VALID_USA_STATES %USA_STATE_ZIPCODE_MAP %USA_STATE_AREACODE_MAP);


@VALID_USA_STATES = (

	'AL', 'AK', 'AS','AZ','AR','AA','AP','AE','CA','CZ',
	'CO','CT','DE','DC','FL','GA','GU','HI','ID','IL',
	'IN','IA','KS','KY','LA','ME','MD','MA','MI','MN',
	'MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC',
	'ND','OH','OK','OR','PA','PR','RI','SC','SD','TN',
	'TX','TT','VI','UT','VT','VA','WA','WV','WI','WY',
	'MX','XX'

        );

%USA_STATE_ZIPCODE_MAP = (


	AL => [35000..36999], 
	AK => [99500..99999],
	AS => [96799],
	AZ => [85000..86599],
	AR => [71600..72999],
	AA => [''],
	AP => [''],
	AE => [''],
	CA => [90000..96699],
	CZ => [''],
	CO => [80000..81699],
	CT => ['06000'..'06999'],
	DE => [19700..19999],
	DC => [20000..20599],
	FL => [32000..34999],
	GA => [30000..31999],
	GU => [96900..96999],
	HI => [96700..96899],
	ID => [83200..83899],
	IL => [60000..62999],
	IN => [46000..47999],
	IA => [50000..52899],
	KS => [60000..67999],
	KY => [40000..42799],
	LA => [70000..71499],
	ME => ['03900'..'04999'],
	MD => [20600..21900],
	MA => ['01000'..'02799'],
	MI => [48000..49999],
	MN => [55000..56799],
	MS => [38600..39799],
	MO => [63000..65899],
	MT => [59000..59999],
	'NE' => [68000..69399],
	NV => [88900..89899],
	NH => ['03000'..'03899'],
	NJ => ['07000'..'08999'],
	NM => [87000..88499],
	NY => ['00400'..'00499','09000'..'14999'],
	NC => [27000..28999],
	ND => [58000..58899],
	OH => [43000..45899],
	OK => [73000..74999],
	OR => [97000..97999],
	PA => [15000..19699],
	PR => ['00600'..'00999'],
	RI => ['02800'..'02999'],
	SC => [29000..29999],
	SD => [57000..57799],
	TN => [37000..38599],
	TX => [75000..79999],
	TT => [''],
	VI => ['00600'..'00999'],
	UT => [84000..84799],
	VT => ['05000'..'05999'],
	VA => [20100..20199,22000..24699],
	WA => [98000..99499],
	WV => [24700..26899],
	WI => [53000..54999],
	WY => [82000..83199],
	MX => [''],
	XX => ['']

    );
        

%USA_STATE_AREACODE_MAP = (

    

	AL => [205,256,334], 
	AK => [907],
	AS => [''],
	AZ => [520,602],
	AR => [501,870],
	AA => [''],
	AP => [''],
	AE => [''],
	CA => [209,213,310,323,408,415,510,530,562,619,626,650,707,714,760,805,818,831,909,916,925,949],
	CZ => [507],
	CO => [303,719,720,970],
	CT => [203,860],
	DE => [302],
	DC => [202],
	FL => [305,352,407,561,813,850,904,941,954],
	GA => [404,678,706,770,912],
	GU => [671],
	HI => [808],
	ID => [208],
	IL => [217,309,312,618,630,708,773,815,847],
	IN => [219,317,765,812],
	IA => [319,515,712],
	KS => [316,785,913],
	KY => [502,606],
	LA => [318,504],
	ME => [207],
	MD => [240,301,410,443],
	MA => [413,508,617,781,978],
	MI => [248,313,517,616,734,810,906],
	MN => [218,320,507,612],
	MS => [228,601],
	MO => [314,417,573,660,816],
	MT => [406],
	'NE' => [308,402],
	NV => [702],
	NH => [603],
	NJ => [201,609,732,908,973],
	NM => [505],
	NY => [212,315,516,518,607,716,718,914,917],
	NC => [704,910,919],
	ND => [701],
	OH => [216,330,419,440,513,614,740,937],
	OK => [405,918],
	OR => [503,541],
	PA => [215,412,610,717,724,814],
	PR => [787],
	RI => [401],
	SC => [803,843,864],
	SD => [605],
	TN => [423,615,901,931],
	TX => [210,214,254,281,409,512,713,806,817,830,903,915,940,956,972],
	TT => [''],
	VI => [340],
	UT => [435,801],
	VT => [802],
	VA => [540,703,757,804],
	WA => [206,253,360,425,509],
	WV => [304],
	WI => [414,608,715,920],
	WY => [307],
	MX => [903],
	XX => ['']

    );



sub getZipCodes
{
	my ($state) = @_;
	
	(isValidState($state) ? return @{$USA_STATE_ZIPCODE_MAP{uc($state)}} : return "");
}

sub getAreaCodes
{
	my ($state) = @_;
	
	(isValidState($state) ? return @{$USA_STATE_AREACODE_MAP{uc($state)}} : return "");
	
} 


sub getStates
{
		
	return @VALID_USA_STATES;
}
	
sub isValidState
{
	my ($state) = @_;
	
	$state = uc($state);
	
	my $tempState = join("|",@VALID_USA_STATES);;
	
	if ((not($state =~ /$tempState/)) || (length($state) > 2) )
	{
		return 0;	
	}
	else
	{
		return 1;
	}
	
}


sub isValidZipCode
{
	my ($state, $zipCode) = @_;
	
	my $zipValues = "";
	my $validState = isValidState($state);
	
	if ($validState == 1)
	{
		$zipValues = join("|",@{$USA_STATE_ZIPCODE_MAP{uc($state)}});
	}
				
	if ((not($zipCode =~ /$zipValues/)) || ($zipValues eq ''))
	{
		return 0;
	}
	else
	{
		return 1;
	}
	
		
}	

sub isValidAreaCode
{
	my ($state, $areaCode) = @_;
	
	my $areaValues = "";
	my $validState = isValidState($state);
	
	if ($validState == 1)
	{
		$areaValues = join("|",@{$USA_STATE_AREACODE_MAP{uc($state)}});
	}
				
	if ((not($areaCode =~ /$areaValues/)) || ($areaValues eq '') || (length($areaCode) > 3))
	{
		return 0;
	}
	else
	{
		return 1;
	}
	
		
}	

	
1;



