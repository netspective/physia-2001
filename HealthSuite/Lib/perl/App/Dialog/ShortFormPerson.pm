##############################################################################
package App::Dialog::ShortFormPerson;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;

use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Association;

use DBI::StatementManager;
use App::Statements::Person;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'shortformPerson' => {
		heading => '$Command Patient',
		_arl => ['person_id'],
		_idSynonym => 'shortPerson'
	},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'shortformPerson');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'home_phone_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'work_phone_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'driver_license_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'addr_item_id'),

		new App::Dialog::Field::Person::ID::New(caption => 'Person / Patient ID',
			name => 'person_id',
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		#	options => FLDFLAG_REQUIRED,
		#	hints => '',
			postHtml => qq{&nbsp; <a href="javascript:doActionPopup('/lookup/person');">Lookup Persons</a>},
		),

		new App::Dialog::Field::Person::Name(),

		new CGI::Dialog::Field(caption => 'Gender',
			name => 'gender',
			type=> 'select',
			selOptions => 'Male:1;Female:2',
			style => 'radio',
		),
		new CGI::Dialog::Field(caption => 'Date of Birth',
			name => 'date_of_birth',
			type => 'date',
			futureOnly => 0,
			defaultValue => '',
		),
		new App::Dialog::Field::Address(caption=>'Home Address',
			name => 'address',
		),
		new CGI::Dialog::MultiField(
			fields =>
			[
				new CGI::Dialog::Field(type => 'phone', caption => 'Home ',
					name => 'home_phone',
				),
				new CGI::Dialog::Field(type => 'phone', caption => 'Work Phone',
					name => 'work_phone',
				),
			]
		),

		new CGI::Dialog::Field(caption => 'Social Security Number',
			name => 'ssn',
			type=> 'ssn'
		),
		new CGI::Dialog::MultiField(
			fields =>
			[
				new CGI::Dialog::Field(caption => 'Drivers License Number', name => 'license_number'),
				new CGI::Dialog::Field(caption => 'State', name => 'license_state', size => 2, maxLength => 2,)
			]
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $personId = $page->field('person_id', $page->param('person_id'));
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);

	my $itemName = 'Driver/License';
	my $attribute =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute',
		$personId, $itemName);
	$page->field('driver_license_item_id', $attribute->{'item_id'});
	$page->field('license_number', $attribute->{'value_text'});
	$page->field('license_state', $attribute->{'value_textb'});

	$itemName = 'Home';
	$attribute =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selAttributeByItemNameAndValueTypeAndParent', $personId, $itemName,
		App::Universal::ATTRTYPE_PHONE);
	$page->field('home_phone_item_id', $attribute->{'item_id'});
	$page->field('home_phone', $attribute->{'value_text'});

	$itemName = 'Work';
	$attribute =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selAttributeByItemNameAndValueTypeAndParent', $personId, $itemName,
		App::Universal::ATTRTYPE_PHONE);
	$page->field('home_phone_item_id', $attribute->{'item_id'});
	$page->field('work_phone', $attribute->{'value_text'});

	my $address = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $personId);
	$page->field('addr_item_id', $address->{item_id});
	$page->field('addr_line1', $address->{line1});
	$page->field('addr_line2', $address->{line2});
	$page->field('addr_city', $address->{city});
	$page->field('addr_state', $address->{state});
	$page->field('addr_zip', $address->{zip});
}

sub execute
{
	my ($self, $page, $command, $flags, $member) = @_;

	my $personId = $page->field('person_id');
	my $orgId = $page->session('org_internal_id');

	$page->schemaAction(
		'Person', $command,
		person_id => $personId || undef,
		name_prefix => $page->field('name_prefix') || undef,
		name_first => $page->field('name_first') || undef,
		name_middle => $page->field('name_middle') || undef,
		name_last => $page->field('name_last') || undef,
		name_suffix => $page->field('name_suffix') || undef,
		ssn => $page->field('ssn') || undef,
		gender => $page->field('gender'),
		date_of_birth => $page->field('date_of_birth'),
		_debug => 0
	);
	$page->schemaAction(
		'Person_Attribute', $page->field('home_phone_item_id') ? 'update' : 'add',
		item_id => $page->field('home_phone_item_id') || undef,
		parent_id => $personId,
		item_name => 'Home',
		value_type => App::Universal::ATTRTYPE_PHONE,
		value_text => $page->field('home_phone'),
		_debug => 0
	) if $page->field('home_phone');

	$page->schemaAction(
		'Person_Attribute', $page->field('work_phone_item_id') ? 'update' : 'add',
		item_id => $page->field('work_phone_item_id') || undef,
		parent_id => $personId,
		item_name => 'Work',
		value_type => App::Universal::ATTRTYPE_PHONE,
		value_text => $page->field('work_phone'),
		_debug => 0
	) if $page->field('work_phone');

	$page->schemaAction(
		'Person_Address', $page->field('addr_item_id') ? 'update' : 'add',
		item_id => $page->field('addr_item_id') || undef,
		parent_id => $personId,
		address_name => 'Home',
		line1 => $page->field('addr_line1'),
		line2 => $page->field('addr_line2') || undef,
		city => $page->field('addr_city'),
		state => $page->field('addr_state'),
		zip => $page->field('addr_zip'),
		_debug => 0
	) if $page->field('addr_line1');

	$page->schemaAction(
		'Person_Org_Category', $command,
		person_id => $personId || undef,
		category => 'Patient' || undef,
		org_internal_id => $orgId || undef,
		_debug => 0
	) if $command eq 'add';

	$page->schemaAction(
		'Person_Attribute', $page->field('driver_license_item_id') ? 'update' : 'add',
		parent_id => $personId || undef,
		item_id => $page->field('driver_license_item_id') || undef,
		item_name => 'Driver/License',
		value_type => App::Universal::ATTRTYPE_LICENSE,
		value_text => $page->field('license_number') || undef,
		value_textB => $page->field('license_state') || undef,
		_debug => 0
	) if $page->field('license_number');

	$self->handlePostExecute($page, $command, $flags);
}

1;
