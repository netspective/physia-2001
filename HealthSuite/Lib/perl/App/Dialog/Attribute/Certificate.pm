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
		data => "Certification '#field.value_text#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
}

sub customValidate
{
	my ($self, $page) = @_;

	my $pId = $self->getField('value_text');
	my $sName = $self->getField('value_int');
	my $licenseNum = $self->getField('value_dateend');
	my $itemId = $page->param('item_id');
	my $sequence = $page->field('value_int');
	my $personId = $page->param('person_id');
	my $specialty = $page->field('value_text');
	my $specialtyValType = App::Universal::ATTRTYPE_SPECIALTY;
	my $valueType = $self->{valueType};
	my $sequenceExists = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selSpecialtySequence', $personId, $sequence) if $sequence ne "&SEQUENCE_SPECIALTY_UNKNOWN";

	if ($valueType eq $specialtyValType  && ($sequenceExists->{'value_int'} eq $sequence) && ($itemId ne $sequenceExists->{'item_id'}) && $sequence >=SEQUENCE_SPECIALTY_PRIMARY && $sequence <=SEQUENCE_SPECIALTY_QUATERNARY)
	{
		$sName->invalidate($page, "This 'Specialty Sequence' already exists for $personId");
	}

	my $specialtyExists = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selSpecialtyExists', $personId, $specialty);

	if ($valueType eq $specialtyValType && ($specialtyExists->{'value_text'} eq $specialty) && ($itemId ne $specialtyExists->{'item_id'}))
	{
		$pId->invalidate($page, "This 'Specialty' already exists for $personId");
	}

	if($page->field('value_textb') eq 'Nursing/License' && ($page->field('value_int') eq '' || $page->field('value_dateend') eq ''))
	{
		$licenseNum->invalidate($page, "'Expiration Date' and 'License Required' should be entered when the license is 'Nursing/License' ");
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
	if($valueType == App::Universal::ATTRTYPE_ACCREDITATION || $valueType == App::Universal::ATTRTYPE_AFFILIATION)
	{
		$itemName = $page->field('value_text');
	}
	elsif($valueType == App::Universal::ATTRTYPE_SPECIALTY)
	{
		$itemName = $medSpecCaption;
	}
	else
	{
		$itemName = $page->field('value_textb');
	}
	my $valueTextB = $medSpecCaption ne '' ? $medSpecCaption : $page->field('value_textb');

	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->param('person_id'),
		item_id => $page->param('item_id') || undef,
		item_name => $itemName,
		value_type => $valueType || undef,
		value_text => $page->field('value_text') || undef,
		value_dateEnd => $page->field('value_dateend') ||undef,
		value_textB => $valueTextB || undef,
		value_int   => $page->field('value_int') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);

	return "\u$command completed.";
}

1;
