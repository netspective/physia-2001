##############################################################################
package App::Dialog::ResponsibleParty;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Association;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;

use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'guarantor', heading => 'Responsible Party');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;


	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'resp_item_id'),
		new App::Dialog::Field::Person::ID::New(caption => 'Person/Patient ID', name => 'resp_party_id', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, types => ['Guarantor'], options => FLDFLAG_REQUIRED),
		#new App::Dialog::Field::Association(caption => 'Relationship', options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::Person::Name(),
		new CGI::Dialog::Field(type=> 'ssn', caption => 'Social Security', name => 'ssn'),
		new App::Dialog::Field::Address(caption=>'Home Address', options => FLDFLAG_REQUIRED, invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, name => 'address'),
		new CGI::Dialog::MultiField(caption =>'Home/Work Phone', name => 'home_work_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(type => 'phone', caption => 'Home Phone', name => 'home_phone', options => FLDFLAG_REQUIRED, invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				new CGI::Dialog::Field(type => 'phone', caption => 'Work Phone', name => 'work_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			]),
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $partyName = $page->param('party_name');

	if($partyName && $command eq 'add')
	{
		$page->field('resp_party_id', $partyName);
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $personId = $page->param('person_id');
	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);
	my $personInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);
	my $partyId = $personInfo->{'person_id'};
	$page->field('resp_party_id', $partyId);
	my $parentId = $page->param('person_id');
	my $relationName = 'Guarantor';
	my $respData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $parentId, $relationName);
	#$respData->{'value_text'} eq $personId ? $page->field('resp_self', 1) : $page->field('party_name', $respData->{'value_text'});

	#my $relation = $respData->{'value_text'};
	#my @itemNamefragments = split('/', $relation);

	#if($itemNamefragments[0] eq 'Other')
	#{
	#	$page->field('rel_type', $itemNamefragments[0]);
	#	$page->field('other_rel_type', $itemNamefragments[1]);
	#}

	#else
	#{
	#	$page->field('rel_type', $itemNamefragments[0]);
	#}

	#$page->field('resp_item_id', $respData->{'item_id'});

	if($command eq 'remove')
	{
		$page->field('delete_record', 1);
	}
}

sub execute
{
	my ($self, $page, $command, $flags, $member) = @_;

	my $personId = $page->field('resp_party_id');
	my $orgId = $page->session('org_id');

	$page->schemaAction(
			'Person', $command,
			person_id => $personId || undef,
			name_prefix => $page->field('name_prefix') || undef,
			name_first => $page->field('name_first') || undef,
			name_middle => $page->field('name_middle') || undef,
			name_last => $page->field('name_last') || undef,
			name_suffix => $page->field('name_suffix') || undef,
			ssn => $page->field('ssn') || undef,
			_debug => 0
		);
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Home',
			value_type => 10,
			value_text => $page->field('home_phone'),
			_debug => 0
		) if $page->field('home_phone') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Work',
			value_type => 10,
			value_text => $page->field('work_phone'),
			_debug => 0
		) if $page->field('work_phone') ne '';
	$page->schemaAction(
			'Person_Address', $command,
			parent_id => $personId,
			address_name => 'Home',
			line1 => $page->field('addr_line1'),
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city'),
			state => $page->field('addr_state'),
			zip => $page->field('addr_zip'),
			_debug => 0
		) if $page->field('addr_line1') ne '';

	$page->schemaAction(
			'Person_Org_Category', $command,
			person_id => $personId || undef,
			category => 'Guarantor' || undef,
			org_id => $orgId || undef,
			_debug => 0
		);

	#my $relType = $page->field('rel_type');
	#my $otherRelType = $page->field('other_rel_type');
	#$otherRelType = "\u$otherRelType";

	#my $relationship = $relType eq 'Other' ? "Other/$otherRelType" : $relType;
	#my $commandResponsible = $command eq 'update' &&  $page->field('resp_item_id') eq '' ? 'add' : $command;
	#$page->schemaAction(
	#	'Person_Attribute', $commandResponsible,
	#	parent_id => $personId || undef,
	#	item_id => $page->field('resp_item_id') || undef,
	#	item_name => 'Responsible Party' || undef,
	#	value_type => App::Universal::ATTRTYPE_EMERGENCY || undef,
	#	value_text => $relationship || undef,
	#	value_textB => $page->field('home_phone') || undef,
	#	_debug => 0
	#);

	#$page->schemaAction(
	#		'Person_Attribute',	$command,
	#		parent_id => $page->param('person_id') || undef,
	#		item_id => $page->param('item_id') || undef,
	#		item_name => $page->field('phone_number') || undef,
	#		value_type => App::Universal::ATTRTYPE_EMERGENCY || undef,
	#		value_text => $page->field('misc_notes') || undef,
	#		value_int => 1,
	#		_debug => 0
	#);

	$self->handlePostExecute($page, $command, $flags);
}

1;
