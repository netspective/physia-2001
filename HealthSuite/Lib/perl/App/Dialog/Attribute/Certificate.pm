##############################################################################
package App::Dialog::Attribute::Certificate;
##############################################################################

use DBI::StatementManager;
use App::Statements::Invoice;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use App::Statements::Person;
use constant SEQUENCE_SPECIALTY_PRIMARY => 1;
use constant SEQUENCE_SPECIALTY_SECONDARY => 2;
use constant SEQUENCE_SPECIALTY_TERTIARY => 3;
use constant SEQUENCE_SPECIALTY_QUATERNARY => 4;
use constant SEQUENCE_SPECIALTY_UNKNOWN => 5;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = ();

sub initialize
{
	my $self = shift;

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Certification '#field.value_textb# #field.value_text#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
}

sub customValidate
{
	my ($self, $page) = @_;

	my $command = $self->getActiveCommand($page);
	my $pId = $self->getField('value_text');
	my $sName = $self->getField('value_int');
	my $effectiveDate = $self->getField('value_date');
	my $licenseNum = $self->getField('value_dateend');
	my $itemId = $page->param('item_id');
	my $sequence = $page->field('value_int');
	my $personId = $page->param('person_id');
	my $specialty = $page->field('value_text');
	my $licenseName = $page->field('value_textb');
	my $facilityId = $page->field('name_sort');
	my $fName = $self->getField('name_sort');
	my $specialtyValType = App::Universal::ATTRTYPE_SPECIALTY;
	my $valueType = $self->{valueType};
	my $sequenceExists = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selSpecialtySequence', $personId, $sequence) if $sequence ne "&SEQUENCE_SPECIALTY_UNKNOWN";


	if (ParseDate($page->field('value_date')) > ParseDate($page->field('value_dateend')))
	{
		$effectiveDate->invalidate($page, "Effective Date must be less than or equal to Expiration Date");
	}

	if ($valueType eq $specialtyValType  && ($sequenceExists->{'value_int'} eq $sequence) && ($itemId ne $sequenceExists->{'item_id'}) && $sequence >=SEQUENCE_SPECIALTY_PRIMARY && $sequence <=SEQUENCE_SPECIALTY_QUATERNARY)
	{
		$sName->invalidate($page, "This 'Specialty Sequence' already exists for $personId");
	}

	my $specialtyExists = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selSpecialtyExists', $personId, $specialty);

	if ($valueType eq $specialtyValType && ($specialtyExists->{'value_text'} eq $specialty) && ($itemId ne $specialtyExists->{'item_id'}))
	{
		$pId->invalidate($page, "This 'Specialty' already exists for $personId");
	}

	#my $sequenceDoesnotExist = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selSpecialtySequence', $personId, $sequence-1) if $sequence ne "&SEQUENCE_SPECIALTY_UNKNOWN";

	#if ($command eq 'add' && $valueType eq $specialtyValType  && ($sequenceDoesnotExist->{'value_int'} eq '' || $sequence < $sequenceDoesnotExist->{'value_int'})  && $sequence > SEQUENCE_SPECIALTY_PRIMARY && $sequence <=SEQUENCE_SPECIALTY_QUATERNARY && $sequence ne "&SEQUENCE_SPECIALTY_UNKNOWN")
	#{
	#	$sName->invalidate($page, "This 'Specialty Sequence' cannot be added until the previous sequence is added");
	#}

	#if ($command ne 'add' && $valueType eq $specialtyValType  && ($sequenceDoesnotExist->{'value_int'} eq '' || $sequence < $sequenceDoesnotExist->{'value_int'})  && ($itemId ne $sequenceExists->{'item_id'}) && $sequence > SEQUENCE_SPECIALTY_PRIMARY && $sequence <=SEQUENCE_SPECIALTY_QUATERNARY && $sequence ne "&SEQUENCE_SPECIALTY_UNKNOWN")
	#{
	#	$sName->invalidate($page, "This 'Specialty Sequence' cannot be added until the previous sequence is added");
	#}
	my $sequenceDoesnotExist = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

	for (my $x = SEQUENCE_SPECIALTY_PRIMARY; $x < $sequence; $x++)
	{
		my $seqCap = '';

		if ($x == 1)
		{
			$seqCap = 'Primary';
		}
		elsif ($x == 2)
		{
			$seqCap = 'Secondary';
		}
		elsif ($x == 3)
		{
			$seqCap = 'Tertiary';
		}
		else
		{
			$seqCap = 'Unknown';
		}

		if ($sequence ne SEQUENCE_SPECIALTY_UNKNOWN)
		{
			$sName->invalidate($page, "This 'Specialty Sequence' cannot be added until the sequence '$seqCap' is added")unless $STMTMGR_PERSON->recordExists($page,STMTMGRFLAG_NONE, 'selSpecialtySequence', $personId, $x);
		}
		if ($command eq 'update' && $sequence > $sequenceDoesnotExist->{'value_int'} && $sequence ne SEQUENCE_SPECIALTY_UNKNOWN)
		{
			$sName->invalidate($page, "This 'Specialty Sequence' cannot be added until the previous sequence is added");
			last;
		}
	}

	if($page->field('value_textb') eq 'Nursing/License' && ($page->field('value_int') eq '' || $page->field('value_dateend') eq ''))
	{
		$licenseNum->invalidate($page, "'Expiration Date' and 'License Required' should be entered when the license is 'Nursing/License' ");
	}

	my $licenseData = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selAttrByItemNameParentNameSort', $personId, $licenseName, $facilityId);

	if (($licenseData->{'value_type'} eq App::Universal::ATTRTYPE_LICENSE) && $itemId ne $licenseData->{'item_id'} && $facilityId eq $licenseData->{'name_sort'} && $licenseName eq $licenseData->{'value_textb'})
	{
		$fName->invalidate($page, "This license already exists for '$personId' for the facility '$facilityId' ");
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');

	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $valueType = $self->{valueType};
	my $itemName = '';
	my $medSpecCode = $page->field('value_text');
	my $medSpecCaption = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selMedicalSpecialtyCaption', $medSpecCode);
	if($valueType == App::Universal::ATTRTYPE_ACCREDITATION || $valueType == App::Universal::ATTRTYPE_AFFILIATION || $valueType == App::Universal::ATTRTYPE_BOARD_CERTIFICATION)
	{
		$itemName = $page->field('value_text');
	}
	elsif($valueType == App::Universal::ATTRTYPE_SPECIALTY)
	{
		$itemName = $medSpecCaption;
	}
	else
	{
		$itemName = ($valueType == App::Universal::ATTRTYPE_STATE) ? uc($page->field('value_textb')) : $page->field('value_textb');
	}

	my $valueTextB = $medSpecCaption ne '' ? $medSpecCaption : $page->field('value_textb');
	$valueTextB = ($valueType == App::Universal::ATTRTYPE_STATE) ? uc($valueTextB) : $valueTextB;

	my $facilityId = $page->field('name_sort') ne '' ? $page->field('name_sort') : $page->session('org_id');
	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->param('person_id'),
		item_id => $page->param('item_id') || undef,
		item_name => $itemName,
		value_type => $valueType || undef,
		value_text => $page->field('value_text') || undef,
		value_date => $page->field('value_date') ||undef,
		value_dateEnd => $page->field('value_dateend') ||undef,
		value_textB => $valueTextB || undef,
		name_sort  => $facilityId || undef,
		value_int   => $page->field('value_int') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);

	return "\u$command completed.";
}

1;
