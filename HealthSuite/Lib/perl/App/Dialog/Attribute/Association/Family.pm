##############################################################################
package App::Dialog::Attribute::Association::Family;
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
use vars qw(@ISA);
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'family');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'attr_path'),

		new CGI::Dialog::Subhead(heading => 'Attach to Existing Record', name => 'exists_heading'),
		new App::Dialog::Field::Person::ID(caption =>'Person ID', name => 'rel_id', hints => 'Please provide an existing Person ID. A link will be created between the patient and contact.'),
		new CGI::Dialog::Subhead(heading => 'Define New Record', name => 'notexists_heading'),
		new CGI::Dialog::Field(caption =>'Full Name', name => 'rel_name', hints => 'Please provide the full name of the contact if a record does not exist for him/her. A link will not be created between the patient and contact.'),
		new CGI::Dialog::Subhead(heading => 'Contact Information', name => 'contact_heading'),
		new App::Dialog::Field::Association(caption => 'Relationship', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'phone', caption => 'Phone Number', name => 'phone_number', options => FLDFLAG_REQUIRED),
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
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $valueType = App::Universal::ATTRTYPE_FAMILY;
	my $itemId = $page->param('item_id');

	$STMTMGR_PERSON->createFieldsFromSingleRow($page,STMTMGRFLAG_NONE,'selPersonAssociation',$itemId);
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

	my $intId = $page->field('value_int');
	if($intId)
	{
		$STMTMGR_PERSON->createFieldsFromSingleRow($page,STMTMGRFLAG_NONE,'selPersonEmpIdAssociation',$itemId);
	}
	else
	{
		$STMTMGR_PERSON->createFieldsFromSingleRow($page,STMTMGRFLAG_NONE,'selPersonEmpNameAssociation',$itemId);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $relType = $page->field('rel_type');
	my $relId = $page->field('rel_id');
	my $relName = $page->field('rel_name');

	my $otherRelType = $page->field('other_rel_type');
	$otherRelType = "\u$otherRelType";

	my $relationship = $relType eq 'Other' ? "Other/$otherRelType" : $relType;
	my $valueText = $relId eq '' ? $relName : $relId;
	my $constrained = $relId eq '' ? 0 : 1;

	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->param('person_id'),
		item_id => $page->param('item_id') || undef,
		item_name => $relationship || undef,
		value_type => App::Universal::ATTRTYPE_FAMILY || undef,
		value_text => $valueText || undef,
		value_textB => $page->field('phone_number') || undef,
		value_date => $page->field('begin_date') || undef,
		value_int => defined $constrained ? $constrained : undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

use constant PANEDIALOG_FAMILY => 'Dialog/Family';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/02/2000', 'RK',
		PANEDIALOG_FAMILY,
		'Added a new dialog for Family Pane.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/07/2000', 'RK',
		PANEDIALOG_FAMILY,
		'Renamed the Package name from App::Dialog::Association::Family to App::Dialog::Attribute::Association::Family.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/14/2000', 'RK',
		PANEDIALOG_FAMILY,
		'Removed Item Path from Item Name'],
);
1;
