##############################################################################
package App::Dialog::Field::Address;
##############################################################################

use strict;
use Carp;
require App::Billing::Locale::USCodes;
use CGI::Validator;
use CGI::Validator::Field;
use CGI::Dialog;
use Schema::Utilities;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;

	#
	# you can pass in a "types => ['x', 'y']" and "notTypes => ['a']"
	# to restrict/expand the selection
	#

	$params{namePrefix} = 'addr_' unless exists $params{namePrefix};
	$params{caption} = 'Address' unless exists $params{caption};

	my $prefix = $params{namePrefix};
	$params{fields} =
	[
		new CGI::Dialog::Field(caption => 'Address (Line 1)', name => "${prefix}line1", size => 36, maxLength => 128, postHtml => '<br>'),
		new CGI::Dialog::Field(caption => 'Address (Line 2)', name => "${prefix}line2", size => 36, maxLength => 128, postHtml => '<br>'),
		new CGI::Dialog::Field(caption => 'City', name => "${prefix}city", size => 16, maxLength => 64),
		new CGI::Dialog::Field(caption => 'State', name => "${prefix}state", size => 2, maxLength => 2),
		new CGI::Dialog::Field(type => 'zipcode', caption => 'Zip Code', name => "${prefix}zip"),
	];

	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	my ($self, $page, $validator) = @_;	
	my $fields = $self->{fields};	
	my $isRequired = $self->flagIsSet(FLDFLAG_REQUIRED);
	$fields->[0]->updateFlag(FLDFLAG_REQUIRED, $isRequired);
	# $fields->[1] is line2, which is never required
	$fields->[2]->updateFlag(FLDFLAG_REQUIRED, $isRequired);
	$fields->[3]->updateFlag(FLDFLAG_REQUIRED, $isRequired);
	$fields->[4]->updateFlag(FLDFLAG_REQUIRED, $isRequired);
	
	return $self->SUPER::needsValidation($page, $validator);
}

sub isValid
{
	my ($self, $page, $validator, $valFlags) = @_;
	
        my $state = $page->field('addr_state') || $page->field('state');
        $state = uc($state);
        my $zipCode = $page->field('addr_zip') || $page->field('zip');        
	#my $valid = $self->SUPER::isValid($page, $validator, $valFlags);
	$self->SUPER::isValid($page, $validator, $valFlags);
	#if($valid)
	#{
	if ($state || $zipCode ne '')
	{
		if (not(App::Billing::Locale::USCodes::isValidState($state)))	
		{				
			$self->invalidate($page, "Invalid State: $state");
		}	

		if (not(App::Billing::Locale::USCodes::isValidZipCode($state, $zipCode)))	
		{		
			$self->invalidate($page, "Invalid Zip Code: $zipCode ");
		}
	}
	#}
	#else
	#{
	#	$page->addError('**customValidate');
	#	return $valid;
	#}	
}
use constant ADDRESS => 'Dialog/Address';
@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/18/1999', 'RK',
		ADDRESS,
		'Added the subroutine isValid to do validation for state and zipcode fields in the address.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/27/1999', 'RK',
		ADDRESS,
		'Updated the isValid subroutine to do the validation for state and zipCode fields in the PersonalData pane and in Org General pane.'],
	
);
1;