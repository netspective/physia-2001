##############################################################################
package App::Billing::Output::Validate::THIN;
##############################################################################

use strict;
use vars qw(@ISA %PAYERSMAP);
use App::Billing::Claim;
use App::Billing::Claims;
use App::Billing::Validator;
use Devel::ChangeLog;
use Benchmark;


use vars qw(@CHANGELOG);
@ISA = qw(App::Billing::Validator);

use constant PAYERINFOIDX_NAME         => 0;
use constant PAYERINFOIDX_VALIDATEFUNC => 1;
use constant GREATER => 7;
use constant LESS => 1;
use constant EQUAL => 2;
use constant NOT_EQUAL => 20;
use constant CONTAINS => 0;
use constant NOT_CONTAINS => 1;
use constant NOT_ALL => 3;
use constant CHECK_EXACT_VALUES => 50;
use constant CHECK_CHARACTERS => 60;


%PAYERSMAP =
(
	'F' =>
	[
		'Commercial Claims',
		sub 
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);		
			
			# Validations for AA0
			
			
			
			
			# Validations for BA0
				# Provider Tax ID
				$self->isRequired($claim->{payToProvider}->getFederalTaxId(),$claim,'BA0:Provider Tax Id');
			
				#Provider Tax Id Type
				$self->isRequired($claim->{payToProvider}->getTaxTypeId(),$claim,'BA0:Provider Tax Id Type');
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES , '','',$claim->{payToProvider}->getTaxTypeId(),$claim,'BA0:Provide Tax Id Type',('E','S','X'));

			

			# Validations for BA1
			
			
			
		}
	],

	'C' =>
	[
		'Medicare Claims',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);			
	   	

				
		}
	]


);
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
sub validate
{
	my ($self,$valMgr,$callSeq,$vFlags,$claim) = @_;
	my $result = 0; # no error
	my $payerId;

	$self->{claim} = $claim;
    $self->{valMgr} = $valMgr;
	 
#	 my $t0 = new Benchmark;

	 $payerId = $claim->getProgrammerName();
    
#    if ($claim->getPayerId() =~ m/^VN/)
#    {
#    	$payerId = 'VN';
#    }
#    else
#    {
#    	$payerId = $claim->getPayerId();
#    }
    
    
#	if(my $payerInfo = $PAYERSMAP{$payerId})
#	{
#		$result = &{$payerInfo->[PAYERINFOIDX_VALIDATEFUNC]}($self,$valMgr,$callSeq,$vFlags,$claim);
#	}

	if(my $payerInfo = $PAYERSMAP{$payerId})
	{
		$result = &{$payerInfo->[PAYERINFOIDX_VALIDATEFUNC]}($self,$valMgr,$callSeq,$vFlags,$claim);
	}

	
#	 my $t1 = new Benchmark;
#     my $td = timediff($t1, $t0);
#	print  "Envoy NSF took:",timestr($td),"\n";

	
	return	$result;
}


sub getId()
{
	my $self = shift;

	return "THIN_NSF";
}

sub getName
{
	my $self = shift;

	return "THIN";
}


sub getCallSequences
{
	my $self =  shift;

	return 'THIN';
}


@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]

	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/18/1999', 'AUF',
	'Billing Interface/Envoy Payer Specific Editing Validation',
	'All the dates are now interperated from DD-MON-YY to CCYYMMDD by using a function ' .
    'changeDateToCCYYMMDD in EnvoyPayer module\'s ' .
    ' Blue Cross/Blue Shield of New Jersey, ' .
    ' CIGNA, ' .
    ' Equicor, ' .
    ' Healthcare Interchange ' . 
    ' Jardine Group Services ' .
    ' Qual-Med ' .
	' U.S. Healthcare ' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/18/1999', 'AUF',
	'Billing Interface/Envoy Payer Specific Editing Validation',
	'All Codes of Gender are now interprated from 0,1,2 to U,M,F in '.
    'Blue Cross/Blue Shield of New Jersey, ' .
	'Blue Cross of California, ' .
	'Blue Cross of California: Encounters, ' . 
	'Health First, ' .
	'North American Medical Management, ' .
	'Unicare of Texas' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/21/1999', 'AUF',
	'Billing Interface/Envoy Payer Specific Editing Validation',
	'All the above changes in Codes of Gender and use of changeDateToCCYYMMDD for date formats have been removed from '.
    'Blue Cross/Blue Shield of New Jersey, ' .
	'Blue Cross of California, ' .
	'Blue Cross of California: Encounters, ' . 
	'Health First, ' .
	'North American Medical Management, ' .
	'Unicare of Texas and now formated data will be provided by Claim object' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/01/2000', 'AUF',
	'Billing Interface/Envoy Payer Specific Editing Validation',
	'Function getDiagnosisPtr is being called in payer PCA Health Plans of Florida to get diagnosis pointer'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/13/2000', 'AUF',
	'Billing Interface/Envoy Payer Specific Editing Validation',
	'Checks to see no. of Procedures have been implemented in payers '.
	'Blue Cross/Blue Shield of New Jersey ' .
	'Blue Cross of California '.
	'CIGNA ' . 
	'Equicor ' . 
	'Healthcare Interchange, Inc ' .
	'John Deere Healthcare ' .
	'U.S. Healthcare ' . 
	'Unicare of Texas ' .
	', if no procedure exist then all procedures checks will be skipped'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/12/2000', 'AUF',
	'Billing Interface/Envoy Payer Specific Editing Validation',
	'A new parmeter has been added in checkValidValues method and its value could be either CHECK_EXACT_VALUES or CHECK_CHARACTERS'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '04/18/2000', 'AUF',
	'Billing Interface/Envoy Payer Specific Editing Validation',
	'Function getId of Insured object has been replaced with getSsn of same object to reflect correct value'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '05/03/2000', 'AUF',
	'Billing Interface/Envoy Payer Specific Editing Validation',
	'Function getRelationshiptoInsured of Patient object has been replaced with getRelationshipToPatient of Insured object ']




);


1;

