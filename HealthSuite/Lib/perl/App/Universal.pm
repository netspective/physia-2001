##############################################################################
package App::Universal;
##############################################################################

use strict;
use Carp;

#ATTRIBUTE TYPE: MISC
use constant ATTRTYPE_TEXT => 0;
use constant ATTRTYPE_PHONE => 10;
use constant ATTRTYPE_FAX => 15;
use constant ATTRTYPE_PAGER => 20;
use constant ATTRTYPE_BILLING_PHONE => 25;
use constant ATTRTYPE_EMAIL => 40;
use constant ATTRTYPE_URL => 50;
use constant ATTRTYPE_CONTACT => 70;
use constant ATTRTYPE_BOOLEAN => 100;
use constant ATTRTYPE_INTEGER => 110;
use constant ATTRTYPE_CURRENCY => 140;
use constant ATTRTYPE_DATE => 150;
use constant ATTRTYPE_DURATION => 160;
use constant ATTRTYPE_HISTORY => 950;
use constant ATTRTYPE_FAKE_ADDRESS => 99910;



#ATTRIBUTE TYPE: ASSOCIATIONS
use constant ATTRTYPE_FAMILY => 200;
use constant ATTRTYPE_EMERGENCY => 201;
use constant ATTRTYPE_PROVIDER => 210;
use constant ATTRTYPE_EMPLOYEDFULL => 220;
use constant ATTRTYPE_EMPLOYEDPART => 221;
use constant ATTRTYPE_SELFEMPLOYED => 222;
use constant ATTRTYPE_RETIRED => 223;
use constant ATTRTYPE_STUDENTFULL => 224;
use constant ATTRTYPE_STUDENTPART => 225;
use constant ATTRTYPE_EMPLOYUNKNOWN => 226;
use constant ATTRTYPE_RESOURCEPERSON => 250;
use constant ATTRTYPE_RESOURCEOTHER => 251;
use constant ATTRTYPE_RESOURCEORG => 252;

#SEVICE PLACE ABBREV
use constant SERVICE_PLACE_OFFICE => 11;
use constant SERVICE_PLACE_INPATIENTHOSPITAL => 21;
use constant SERVICE_PLACE_OUTPATIENTHOSPITAL => 22;
use constant SERVICE_PLACE_EMERGENCYROOM => 23;



#ATTRIBUTE TYPE: INSURANCE PLANS
use constant ATTRTYPE_INSGRPINSPLAN => 360;
use constant ATTRTYPE_INSGRPWORKCOMP => 361;

#ATTRIBUTE TYPE: AUTHORIZATION
use constant ATTRTYPE_AUTHPATIENTSIGN => 370;
use constant ATTRTYPE_AUTHPROVIDERASSIGN => 371;
use constant ATTRTYPE_AUTHINFORELEASE => 372;



#ATTRIBUTE TYPE: PREVENTIVE CARE
use constant PREVENTIVE_CARE => 400;

#ATTRIBUTE TYPE: ALLERGIES
use constant MEDICATION_ALLERGY => 410;
use constant ENVIRONMENTAL_ALLERGY => 411;
use constant MEDICATION_INTOLERANCE => 412;

#ATTRIBUTE TYPE: DIRECTIVES
use constant DIRECTIVE_PATIENT => 420;
use constant DIRECTIVE_PHYSICIAN => 421;



#ATTRIBUTE TYPE: CERTIFICATE (FOR PERSON)
use constant ATTRTYPE_LICENSE => 500;
use constant ATTRTYPE_STATE => 510;
use constant ATTRTYPE_ACCREDITATION => 520;
use constant ATTRTYPE_AFFILIATION => 530;
use constant ATTRTYPE_SPECIALTY => 540;



#ATTRIBUTE TYPE: CREDENTIALS (FOR ORG)
use constant ATTRTYPE_CREDENTIALS => 600;



#ATTRIBUTE TYPE: EMPLOYMENT BENEFITS
use constant BENEFIT_INSURANCE => 700;
use constant BENEFIT_RETIREMENT => 710;
use constant BENEFIT_OTHER => 720;



#ATTRIBUTE TYPE: GENERAL
use constant ATTRTYPE_EMPLOYEEATTENDANCE => 800;
use constant ATTRTYPE_EMPLOYMENTRECORD => 810;
use constant ATTRTYPE_PERSONALGENERAL => 820;
use constant ATTRTYPE_ORGGENERAL => 830;



#CATALOG TYPES
use constant CATALOGTYPE_FEESCHEDULE => 0;


#CATALOG ENTRY TYPES
use constant CATALOGENTRYTYPE_ITEMGRP => 0;
use constant CATALOGENTRYTYPE_ICD => 80;
use constant CATALOGENTRYTYPE_CPT => 100;
use constant CATALOGENTRYTYPE_PROCEDURE => 110;
use constant CATALOGENTRYTYPE_PROCCERT => 120;
use constant CATALOGENTRYTYPE_SERVICE => 150;
use constant CATALOGENTRYTYPE_SERVICECERT => 160;
use constant CATALOGENTRYTYPE_PRODUCT => 200;
use constant CATALOGENTRYTYPE_HCPCS => 210;


#RELATIONSHIP TYPE: RELATIONSHIPS
use constant RELATIONSHIP_OTHER => 0;
use constant RELATIONSHIP_MOTHER => 1;
use constant RELATIONSHIP_FATHER => 2;
use constant RELATIONSHIP_SISTER => 3;
use constant RELATIONSHIP_BROTHER => 4;
use constant RELATIONSHIP_SON => 5;
use constant RELATIONSHIP_DAUGHTER => 6;
use constant RELATIONSHIP_COUSIN => 7;
use constant RELATIONSHIP_GRANDPARENT => 8;

#TRANS TYPE: TELEPHONE
use constant TRANSTYPE_PC_TELEPHONE => 1000;

#TRANS TYPE: VISIT
use constant TRANSTYPEVISIT_OFFICE => 2000;
use constant TRANSTYPEVISIT_CLINIC => 2010;
use constant TRANSTYPEVISIT_HOSPITAL => 2020;
use constant TRANSTYPEVISIT_FACILITY => 2030;
use constant TRANSTYPEVISIT_PHYSICALEXAM => 2040;
use constant TRANSTYPEVISIT_EXECPHYSICAL => 2050;
use constant TRANSTYPEVISIT_SCHOOLPHYSICAL => 2060;
use constant TRANSTYPEVISIT_REGULARVISIT => 2070;
use constant TRANSTYPEVISIT_COMPLICATEDVISIT => 2080;
use constant TRANSTYPEVISIT_WELLWOMENEXAM => 2090;
use constant TRANSTYPEVISIT_CONSULTATION => 2100;
use constant TRANSTYPEVISIT_INJECTIONONLY => 2110;
use constant TRANSTYPEVISIT_PROCEDURE => 2120;
use constant TRANSTYPEVISIT_WORKMANSCOMP => 2130;
use constant TRANSTYPEVISIT_RADIOLOGY => 2140;
use constant TRANSTYPEVISIT_LAB => 2150;
use constant TRANSTYPEVISIT_COUNSELING => 2160;
use constant TRANSTYPEVISIT_PHYSICALTHERAPY => 2170;
use constant TRANSTYPEVISIT_SPECIAL => 2180;

#TRANS TYPE: DIAGNOSES
use constant TRANSTYPEDIAG_TRANSIENT => 3000;
use constant TRANSTYPEDIAG_PERMANENT => 3010;
use constant TRANSTYPEDIAG_ICD => 3020;
use constant TRANSTYPEDIAG_NOTES => 3100;
use constant TRANSTYPEDIAG_SURGICAL => 4050;

#TRANS TYPE: PROCEDURES
use constant TRANSTYPEPROC_REGULAR => 4000;
use constant TRANSTYPEPROC_IMMUNIZATION => 4010;
use constant TRANSTYPEPROC_HLTHMAINTENANCE => 4020;
use constant TRANSTYPEPROC_OUTPATIENT => 4030;
use constant TRANSTYPEPROC_INPATIENT => 4040;
use constant TRANSTYPEPROC_SURGICAL => 4050;
use constant TRANSTYPEPROC_NEWOFFICEVISIT => 4060;
use constant TRANSTYPEPROC_RETURNOFFICEVISIT => 4070;
use constant TRANSTYPEPROC_VACCINATION => 4080;

#TRANS TYPE: ACTIONS
use constant TRANSTYPEACTION_PLAN => 9000;
use constant TRANSTYPEACTION_NOTES => 9010;
use constant TRANSTYPEACTION_VOID => 9020;

#TRANS TYPE: TRANSACTIONS
use constant TRANSTYPE_PRESCRIBEMEDICATION => 7000;
use constant TRANSTYPE_CURRENTMEDICATION_OTC => 7010;
use constant TRANSTYPE_CURRENTMEDICATION_HOMEO => 7020;

use constant TRANSTYPE_ALERTORG => 8000;
use constant TRANSTYPE_ALERTORGFACILITY => 8010;
use constant TRANSTYPE_ALERTPATIENT => 8020;
use constant TRANSTYPE_ALERTINSURANCE => 8030;
use constant TRANSTYPE_ALERTMEDICATION => 8040;
use constant TRANSTYPE_ALERTACTION => 8200;


use constant TRANSTYPE_ADMISSION => 11000;
use constant TRANSTYPE_SURGERY => 11100;
use constant TRANSTYPE_THERAPY => 11200;

use constant TRANSTYPE_TESTSMEASUREMENTS => 12000;

#TRANS STATUS
use constant TRANSSTATUS_DEFAULT => 0;
use constant TRANSSTATUS_ACTIVE => 2;
use constant TRANSSTATUS_INACTIVE => 3;

#EVENT STATUS
use constant EVENTSTATUS_SCHEDULED => 0;
use constant EVENTSTATUS_INPROGRESS => 1;
use constant EVENTSTATUS_COMPLETE => 2;
use constant EVENTSTATUS_DISCARD => 3;

#EVENT ATTRIBUTE
use constant EVENTATTRTYPE_PATIENT => 331;
use constant EVENTATTRTYPE_PHYSICIAN => 332;

#ENTITY TYPES
use constant ENTITYTYPE_PERSON => 0;
use constant ENTITYTYPE_ORG => 1;

#BILL SEQUENCE FOR INSURANCE PLANS AND INVOICE BILLING
use constant INSURANCE_INACTIVE => 99;
use constant INSURANCE_TERMINATED => 98;
use constant INSURANCE_PRIMARY => 1;
use constant INSURANCE_SECONDARY => 2;
use constant INSURANCE_TERTIARY => 3;
use constant INSURANCE_QUATERNARY => 4;
use constant INSURANCE_WORKERSCOMP => 5;

use constant PAYER_PRIMARY => 1;
use constant PAYER_SECONDARY => 2;
use constant PAYER_TERTIARY => 3;
use constant PAYER_QUATERNARY => 4;

#CONDITION RELATED TO
use constant CONDRELTO_EMPLOYMENT => 0;
use constant CONDRELTO_AUTO => 1;
use constant CONDRELTO_OTHER => 2;
use constant CONDRELTO_FAKE_NONE => -99999;


#FAKE PRODUCT VALUES FOR INSURANCE PURPOSES
use constant INSURANCE_FAKE_CLIENTBILL => 7777777777;
use constant INSURANCE_FAKE_SELFPAY => 8888888888;
use constant INSURANCE_FAKE_OTHERPAYER => 9999999999;

#CLAIM TYPES
use constant CLAIMTYPE_SELFPAY => 0;
use constant CLAIMTYPE_INSURANCE => 1;
use constant CLAIMTYPE_HMO => 2;
use constant CLAIMTYPE_PPO => 3;
use constant CLAIMTYPE_MEDICARE => 4;
use constant CLAIMTYPE_MEDICAID => 5;
use constant CLAIMTYPE_WORKERSCOMP => 6;
use constant CLAIMTYPE_CLIENT => 7;
use constant CLAIMTYPE_CHAMPUS => 8;
use constant CLAIMTYPE_CHAMPVA => 9;
use constant CLAIMTYPE_FECABLKLUNG => 10;
use constant CLAIMTYPE_BCBS => 11;
use constant CLAIMTYPE_HMO_NON_CAP => 12;

#CLAIM DATE_REASON_TYPE
use constant CLAIMDATE_VALUE => 160;

#RECORD TYPES
use constant RECORDTYPE_CATEGORY => 0;
use constant RECORDTYPE_INSURANCEPRODUCT => 1;
use constant RECORDTYPE_INSURANCEPLAN => 2;
use constant RECORDTYPE_PERSONALCOVERAGE => 3;


#DEDUCTIBLE TYPES
use constant DEDUCTTYPE_NONE => 0;
use constant DEDUCTTYPE_INDIVIDUAL => 1;
use constant DEDUCTTYPE_FAMILY => 2;
use constant DEDUCTTYPE_BOTH => 3;

#INVOICE STATUS
use constant INVOICESTATUS_CREATED => 0;
use constant INVOICESTATUS_INCOMPLETE => 1;
use constant INVOICESTATUS_PENDING => 2;
use constant INVOICESTATUS_ONHOLD => 3;
use constant INVOICESTATUS_SUBMITTED => 4;
use constant INVOICESTATUS_INTNLAPPRV => 5;
use constant INVOICESTATUS_INTNLREJECT => 6;
use constant INVOICESTATUS_TRANSFERRED => 7;
use constant INVOICESTATUS_EXTNLREJECT => 8;
use constant INVOICESTATUS_EXTNLAPPRV => 9;
use constant INVOICESTATUS_ETRANSFERRED => 10;
use constant INVOICESTATUS_MTRANSFERRED => 11;
use constant INVOICESTATUS_AWAITPAYMENT => 12;
use constant INVOICESTATUS_APPEALED => 13;
use constant INVOICESTATUS_PAYAPPLIED => 14;
use constant INVOICESTATUS_CLOSED => 15;
use constant INVOICESTATUS_VOID => 16;

#INVOICE TYPES
use constant INVOICETYPE_HCFACLAIM => 0;
use constant INVOICETYPE_SERVICE => 1;

#INVOICE ITEM TYPES
use constant INVOICEITEMTYPE_INVOICE => 0;
use constant INVOICEITEMTYPE_SERVICE => 1;
use constant INVOICEITEMTYPE_LAB => 2;
use constant INVOICEITEMTYPE_COPAY => 3;
use constant INVOICEITEMTYPE_COINSURANCE => 4;
use constant INVOICEITEMTYPE_ADJUST => 5;
use constant INVOICEITEMTYPE_DEDUCTIBLE => 6;

#INVOICE BILLING PARTY TYPES
use constant INVOICEBILLTYPE_CLIENT => 0;
use constant INVOICEBILLTYPE_THIRDPARTYPERSON => 1;
use constant INVOICEBILLTYPE_THIRDPARTYORG => 2;
use constant INVOICEBILLTYPE_THIRDPARTYINS => 3;


#INVOICE ITEM QUANTITY
use constant INVOICEITEM_QUANTITY => 1;				#default quantity for optimized proc entry is 1

#INVOICE ITEM DATA_TEXT_A
use constant INVOICEITEM_DATA_TEXT_A_NONEMERGENCY => 0;		#default for optimized proc entry is non emergency
use constant INVOICEITEM_DATA_TEXT_A_EMERGENCY => 1;

#HCFA1500_SERVICE_PLACE CODES
use constant HCFA1500_SERVICE_PLACE_CODE_HOSPICE => 11;		#default service place for optimized proc entry is 11

#HCFA1500_SERVICE_TYPE CODES
use constant HCFA1500_SERVICE_TYPE_CODE_MEDICAL_CARE => 0;	#default service type for optimized proc entry is 0
use constant HCFA1500_SERVICE_TYPE_CODE_CONSULTATION => 2;

#HCFA1500_MODIFIER CODES
use constant HCFA1500_MODIFIER_CODE_MANDATED_SERVICES => 32;	#default modifier for optimized proc entry is "mandated services"

#INVOICE ADJUSTMENT TYPES
use constant ADJUSTMENTTYPE_PAYMENT => 0;
use constant ADJUSTMENTTYPE_REFUND => 1;
use constant ADJUSTMENTTYPE_TRANSFER => 2;

#INVOICE ADJUSTMENT PAY TYPES
use constant ADJUSTMENTPAYTYPE_PREPAY => 0;
use constant ADJUSTMENTPAYTYPE_DEDUCTIBLE => 1;
use constant ADJUSTMENTPAYTYPE_POSTPAY => 2;
use constant ADJUSTMENTPAYTYPE_DENIED => 3;
use constant ADJUSTMENTPAYTYPE_COB => 4;

#INVOICE ADJUSTMENT PAY METHODS
use constant ADJUSTMENTPAYMETHOD_CASH => 0;
use constant ADJUSTMENTPAYMETHOD_CHECK => 1;
use constant ADJUSTMENTPAYMETHOD_MONEYORDER => 2;
use constant ADJUSTMENTPAYMETHOD_DEBIT => 3;
use constant ADJUSTMENTPAYMETHOD_MASTERCARD => 4;
use constant ADJUSTMENTPAYMETHOD_VISA => 5;
use constant ADJUSTMENTPAYMETHOD_AMEX => 6;
use constant ADJUSTMENTPAYMETHOD_DISCOVER => 7;
use constant ADJUSTMENTPAYMETHOD_DINERSCLUB => 8;

#INVOICE ADJUSTMENT WRITEOFF CODES
use constant ADJUSTWRITEOFF_DISCOUNT => 0;
use constant ADJUSTWRITEOFF_PROFCOURTESY => 1;
use constant ADJUSTWRITEOFF_BADDEBT => 2;
use constant ADJUSTWRITEOFF_COLLECTAGENCY => 3;
use constant ADJUSTWRITEOFF_CHARITYDISCOUNT => 4;
use constant ADJUSTWRITEOFF_PASTFILEDEADLINE => 5;
use constant ADJUSTWRITEOFF_POSTINGERROR => 6;
use constant ADJUSTWRITEOFF_NONBILLSERVICE => 7;
use constant ADJUSTWRITEOFF_RETURNEDCHECK => 8;
use constant ADJUSTWRITEOFF_NSFFEE => 9;
use constant ADJUSTWRITEOFF_CONTRACTAGREEMENT => 10;


#PERSON GENDER
use constant GENDER_UNKNOWN => 0;
use constant GENDER_MALE => 1;
use constant GENDER_FEMALE => 2;
use constant GENDER_NOTAPPLICABLE => 3;

#PERSON MARITAL_STATUS
use constant MARITALSTATUS_UNKNOWN => 0;
use constant MARITALSTATUS_SINGLE => 1;
use constant MARITALSTATUS_MARRIED => 2;
use constant MARITALSTATUS_PARTNER => 3;
use constant MARITALSTATUS_LEGALLYSEPARATED => 4;
use constant MARITALSTATUS_DIVORCED => 5;
use constant MARITALSTATUS_WIDOWED => 6;
use constant MARITALSTATUS_NOTAPPLICABLE => 7;

#PERSON HEALTH_MAINTENANCE
use constant PERIODICITY_SECOND => 0;
use constant PERIODICITY_MINUTE => 1;
use constant PERIODICITY_HOUR => 2;
use constant PERIODICITY_DAY => 3;
use constant PERIODICITY_WEEK => 4;
use constant PERIODICITY_MONTH => 5;
use constant PERIODICITY_YEAR => 6;

#FLAGS FOR INDICATING TYPE OF COMPONENT
use constant COMPONENTTYPE_CLASS => 0;
use constant COMPONENTTYPE_STATEMENT => 1;

#FLAGS FOR INDICATING WHERE INVOICE DATA IS COMING FROM
use enum qw(BITMASK:INVOICEFLAG_ DATASTOREATTR);

#FLAGS FOR INDICATING PREFERRED METHOD OF CONTACT (I.E. PHONE, PAGER, EMAIL, ETC.)
use enum qw(BITMASK:CONTACTFLAG_ PREFERREDMETHOD);

#FLAGS FOR INDICATING THE PERSON FLAGS
use enum qw(BITMASK:PERSONFLAG_ ISPATIENT ISPHYSICIAN ISNURSE ISCAREPROVIDER ISSTAFF ISADMINISTRATOR);

use vars qw(%DIALOG_COMMAND_ACTIVITY_MAP);
%DIALOG_COMMAND_ACTIVITY_MAP = ('view' => 0, 'add' => 1, 'update' => 2, 'remove' => 3 );
use constant ACTIVITY_TYPE_RECORD => 0;
use constant ACTIVITY_TYPE_PAGE => 1;
use constant ACTIVITY_LEVEL_HIGH => 0;
use constant ACTIVITY_LEVEL_MEDIUM => 1;
use constant ACTIVITY_LEVEL_LOW => 2;

sub UNIVERSAL::abstract
{
	my ($pkg, $file, $line, $method) = caller(1);
	confess("$method is an abstract method");
}

sub UNIVERSAL::abstractMsg
{
	my ($pkg, $file, $line, $method) = caller(1);
	return "$method is a virtual method; please override with specific behavior";
}

# simple flag-management functions:
#   flagUpdate($flags, $mask, $onOff) -- either turn on or turn off $mask
#   flagSet($flags, $mask) -- turn on $mask
#   flagClear($flags, $mask) -- turn off $mask
#   flagIsSet($flags, $mask) -- return true if any $mask are set

sub flagUpdate
{
	if($_[2])
	{
		$_[0] |= $_[1];
	}
	else
	{
		$_[0] &= ~$_[1];
	}
}

sub flagSet
{
	$_[0] |= $_[1];
}

sub flagClear
{
	$_[0] &= ~$_[1];
}

sub flagIsSet
{
	return $_[0] & $_[1];
}

sub flagsAsStr
{
	my $str = unpack("B32", pack("N", shift));
	$str =~ s/^0+(?=\d)// if shift; # otherwise you'll get leading zeros
	return $str;
}

1;
