##############################################################################
package App::Dialog::Attribute::Association::Contact;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Association;
use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Person;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'assoc-contact-emergency' => {
		valueType => App::Universal::ATTRTYPE_EMERGENCY,
		heading => '$Command Emergency Contact',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_EMERGENCY()
		},

	'assoc-contact-family' => {
		valueType => App::Universal::ATTRTYPE_FAMILY,
		heading => '$Command Family Contact',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_FAMILY()
		},

);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_);

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Subhead(heading => 'Link to Existing Person Record', name => 'exists_heading'),
		new App::Dialog::Field::Person::ID(caption =>'Person ID', name => 'rel_id', addType => 'patient', hints => 'Please provide an existing Person ID. A link will be created between the patient and contact.'),
		new CGI::Dialog::Subhead(heading => 'Or Provide A Contact Name', name => 'notexists_heading'),
		new CGI::Dialog::Field(caption =>'Full Name', name => 'rel_name', hints => 'Please provide the full name of the contact if a record does not exist for him/her. A link will not be created between the patient and contact.'),
		new CGI::Dialog::Subhead(heading => 'Contact Information', name => 'contact_heading'),
		new App::Dialog::Field::Association(options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'phone', caption => 'Phone Number', name => 'phone_number'),
		new CGI::Dialog::Field(type => 'date', caption => 'Begin Date', name => 'begin_date', defaultValue => ''),
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "\u$self->{id} to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub customValidate
{
	my ($self, $page) = @_;

	my $pId = $self->getField('rel_id');
	my $pName = $self->getField('rel_name');
	my $personId = $page->param('person_id');
	my $relation = $self->getField('relation')->{fields}->[0];
	my $phone = $self->getField('phone_number');
	if($page->field('rel_id') && $page->field('rel_name'))
	{
		$pId->invalidate($page, "Cannot provide both '$pId->{caption}' and '$pName->{caption}'");
		$pName->invalidate($page, "Cannot provide both '$pId->{caption}' and '$pName->{caption}'");
	}
	else
	{
		unless($page->field('rel_id') || $page->field('rel_name'))
		{
			$pId->invalidate($page, "Please provide either '$pId->{caption}' or '$pName->{caption}'");
			$pName->invalidate($page, "Please provide either '$pId->{caption}' or '$pName->{caption}'");
		}
	}

	if ($page->field('rel_id') eq $personId && $page->field('rel_type') ne 'Self')
	{
		$relation->invalidate($page, "Should select 'Self' as 'Relatioship' when the Person ID is '$personId'");
	}

	if (($page->field('rel_id') ne $personId || $page->field('rel_name')) && $page->field('rel_type') eq 'Self')
	{
		$relation->invalidate($page, "The Relationship should be other than 'Self' when the Person ID is not '$personId'");
	}

	if (($page->field('rel_name')  && $page->field('phone_number') eq ''))
	{
		$phone->invalidate($page, "'Phone Number' is required when an existing Person ID isn't supplied.");
	}

}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');

	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonAssociation', $itemId);
	my $itemName = $page->field('item_name');
	my @itemNamefragments = split('/', $itemName);
	if($itemNamefragments[0] eq 'Other')
	{
		$page->field('rel_type', $itemNamefragments[0]);
		$page->field('other_rel_type', $itemNamefragments[1]);
	}
	else
	{
		$page->field('rel_type', $itemNamefragments[0]);
	}

	if(my $intId = $page->field('value_int'))
	{
		$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonEmpIdAssociation', $itemId);
	}
	else
	{
		$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonEmpNameAssociation', $itemId);
	}
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	if ($page->field('rel_id') && $page->field('phone_number') eq '')
	{
		my $parentId = $page->field('rel_id');
		my $preferredExists = $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selPreferredPhoneExists', $parentId);
		my $preferredPhone = '';

		if ($preferredExists)
		{
			$preferredPhone = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selPreferredPhoneExists', $parentId);
		}

		else
		{
			$preferredPhone = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selHomePhone', $parentId);
		}

		$page->field('phone_number', $preferredPhone)
	}

	my $relType = $page->field('rel_type');
	my $otherRelType = $page->field('other_rel_type');
	$otherRelType = "\u$otherRelType";

	my $relationship = $relType eq 'Other' ? "Other/$otherRelType" : $relType;

	my $relId = $page->field('rel_id');
	my $relName = $page->field('rel_name');

	my $valueText = $relId eq '' ? $relName : $relId;
	my $constrained = $relId eq '' ? 0 : 1;
	my $valueType = $self->{valueType};

	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->param('person_id'),
		item_id => $page->param('item_id') || undef,
		item_name => $relationship || undef,
		value_type => $valueType || undef,
		value_text => $valueText || undef,
		value_textB => $page->field('phone_number') || undef,
		value_date => $page->field('begin_date') || undef,
		value_int => defined $constrained ? $constrained : undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;
