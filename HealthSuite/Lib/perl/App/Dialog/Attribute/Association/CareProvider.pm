##############################################################################
package App::Dialog::Attribute::Association::CareProvider;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Association;
use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;
use Date::Manip;
use DBI::StatementManager;
use App::Statements::Person;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'assoc-provider' => {
		valueType => App::Universal::ATTRTYPE_PROVIDER,
		heading => '$Command Care Provider',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_PROVIDER()
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'provider');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Person::ID(caption =>'Physician/Provider ID', name => 'value_text', types => ['Physician', 'Referring-Doctor'], hints => 'Please provide an existing Person ID.', options => FLDFLAG_REQUIRED, incSimpleName=>1),
		new CGI::Dialog::Field(caption => 'Is Primary Physician?', type => 'bool', name => 'value_int', style => 'check', hints => 'Please check the check-box if the Physician is Primary Physician '),
		new CGI::Dialog::Field(caption => 'Specialty',
								#type => 'foreignKey',
								name => 'value_textb',
								fKeyStmtMgr => $STMTMGR_PERSON,
								fKeyStmt => 'selMedicalSpeciality',
								fKeyDisplayCol => 0,
								fKeyValueCol => 1),

	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "\u Care Provider to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub customValidate
{
	my ($self, $page) = @_;

	my $pId = $self->getField('value_text');
	my $sName = $self->getField('value_textb');
	my $itemId = $page->param('item_id');
	my $sequence = $page->field('speciality_seq');
	my $physicianId = $page->field('value_text');
	my $personId = $page->param('person_id');
	my $specialty = $page->field('value_textb');
	my $sequenceExists = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selPhysicianSpecialty', $personId, $physicianId, $specialty);
	if (($sequenceExists->{'value_textb'} eq $specialty) && ($itemId ne $sequenceExists->{'item_id'}))
	{
		$sName->invalidate($page, "This $sName->{caption} already exists for the Physician '$physicianId'");
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

	my $relId = $page->field('value_text');
	my $medSpecCode = $page->field('value_textb');
	my $parentId = $page->param('person_id');
	my $valueType = App::Universal::ATTRTYPE_PROVIDER;
	my $medSpecCaption = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selMedicalSpecialtyCaption', $medSpecCode);
	my $primaryPhy = $page->field('value_int');
	if ($primaryPhy ne '')
	{
		my $checkPrimary = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAttributeByPersonAndValueType', $parentId, $valueType);
		foreach my $primaryPhysician(@{$checkPrimary})
		{
			if ($primaryPhysician->{'value_int'} ne '')
			{
				my $itemId = $primaryPhysician->{'item_id'};
				$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'updClearPrimaryPhysician', $itemId);
			}
		}

	}
	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $parentId || undef,
		item_id => $page->param('item_id') || undef,
		item_name => $medSpecCaption || undef,
		value_type => App::Universal::ATTRTYPE_PROVIDER || undef,
		value_text => $relId || undef,
		value_textB => $page->field('value_textb') || undef,
		value_int => $primaryPhy || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;
