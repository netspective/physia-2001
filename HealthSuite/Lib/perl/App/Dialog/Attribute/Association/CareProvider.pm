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
use vars qw(@ISA);
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'provider');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		#new CGI::Dialog::Subhead(heading => 'Attach to Existing Record', name => 'exists_heading'),
		new App::Dialog::Field::Person::ID(caption =>'Physician/Provider ID', name => 'rel_id', hints => 'Please provide an existing Person ID.', options => FLDFLAG_REQUIRED),
		#new CGI::Dialog::Subhead(heading => 'Define New Record', name => 'notexists_heading'),
		#new CGI::Dialog::Field(caption =>'Full Name', name => 'rel_name', hints => 'Please provide the full name of the contact if a record does not exist for him/her. A link will not be created between the patient and contact.'),
		#new CGI::Dialog::Subhead(heading => 'Contact Information', name => 'contact_heading'),
		new CGI::Dialog::Field(caption => 'Specialty',
								#type => 'foreignKey',
								name => 'rel_type',
								fKeyStmtMgr => $STMTMGR_PERSON,
								fKeyStmt => 'selMedicalSpeciality',
								fKeyDisplayCol => 0,
								fKeyValueCol => 1,
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
						
		#new CGI::Dialog::Field(type => 'phone', caption => 'Phone Number', name => 'phone_number', options => FLDFLAG_REQUIRED),
		#new CGI::Dialog::Field(type => 'date', caption => 'Begin Date', name => 'begin_date', defaultValue => ''),
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
	#my $pName = $self->getField('rel_name');
	my $itemId = $page->param('item_id');

	#if($page->field('rel_id') && $page->field('rel_name'))
	#{
	#	$pId->invalidate($page, "Cannot provide both '$pId->{caption}' and '$pName->{caption}'");
	#	$pName->invalidate($page, "Cannot provide both '$pId->{caption}' and '$pName->{caption}'");
	#}
	#else
	#{
	#	unless($page->field('rel_id') || $page->field('rel_name'))
	#	{
	#		$pId->invalidate($page, "Please provide either '$pId->{caption}' or '$pName->{caption}'");
	#		$pName->invalidate($page, "Please provide either '$pId->{caption}' or '$pName->{caption}'");
	#	}
	#}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');

	my $data = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
	$page->field('rel_type', $data->{item_name});
	$page->field('phone_number', $data->{value_textb});
	$page->field('begin_date', $data->{value_date});

	my $valueInt =  $data->{value_int};
	#if($valueInt == 0)
	#{
	#	$page->field('rel_name', $data->{value_text});
	#}
	#else
	#{
		$page->field('rel_id', $data->{value_text});
	#}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $relId = $page->field('rel_id');
	#my $relName = $page->field('rel_name');

	#my $valueText = $relId eq '' ? $relName : $relId;
	my $constrained = $relId eq '' ? 0 : 1;
	my $medSpecCode = $page->field('rel_type');
	my $medSpecCaption = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selMedicalSpecialtyCaption', $medSpecCode);
	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->param('person_id') || undef,
		item_id => $page->param('item_id') || undef,
		item_name => $medSpecCaption || undef,
		value_type => App::Universal::ATTRTYPE_PROVIDER || undef,
		#value_text => $valueText || undef,
		value_text => $relId || undef,
		#value_textB => $page->field('phone_number') || undef,
		#value_date => $page->field('begin_date') || undef,
		value_int => defined $constrained ? $constrained : undef,
		_debug => 0
	);
	
	
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

use constant PANEDIALOG_CAREPROVIDER => 'Dialog/Care Provider';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/02/2000', 'RK',
		PANEDIALOG_CAREPROVIDER,
		'Added a new dialog for Care Provider Pane.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/07/2000', 'RK',
		PANEDIALOG_CAREPROVIDER,
		'Renamed the Package name from App::Dialog::Association::CareProvider to App::Dialog::Attribute::Association::CareProvider.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/14/2000', 'RK',
		PANEDIALOG_CAREPROVIDER,
		'Removed Item Path from Item Name'],
);

1;