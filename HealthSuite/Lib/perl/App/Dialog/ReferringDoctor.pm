##############################################################################
package App::Dialog::ReferringDoctor;
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
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'referring-doctor' => {
		heading => '$Command Referring Doctor',
		_arl => ['person_id'],
		_arl_modify => ['person_id'],
		_idSynonym => 'Referring-Doctor'
	},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'referring-doctor', heading => 'Referring Doctor');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;


	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'ref-phy_item_id'),
		new App::Dialog::Field::Person::ID::New(caption => 'Person/Patient ID', name => 'person_id', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, types => ['Referring-Doctor'],),
		#options => FLDFLAG_REQUIRED),
		#new App::Dialog::Field::Association(caption => 'Relationship', options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::Person::Name(),
		new CGI::Dialog::MultiField(
					name => 'phone_fax',
					invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
					fields => [
						new CGI::Dialog::Field(
							caption => 'Phone',
							type=>'phone',
							name => 'phone',
							options => FLDFLAG_REQUIRED,
							invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						),
						new CGI::Dialog::Field(
							caption => 'Fax',
							type=>'phone',
							name => 'fax',
							invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						),
					],
			),
		new CGI::Dialog::MultiField(
					invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
					fields => [
						new CGI::Dialog::Field(
							caption => 'UPIN Number',
							name    => 'upin_num',
						),
						new CGI::Dialog::Field(
							caption => 'Exp Date',
							name    => 'upin_date',
						),
						new CGI::Dialog::Field(
							caption => 'Facility ID',
							name    => 'upin_facility',
							fKeyStmtMgr => $STMTMGR_ORG,
							fKeyStmt => 'selChildFacilityOrgs',
							fKeyDisplayCol => 0,
							fKeyValueCol => 0,
							type => 'select',
							fKeyStmtBindSession => ['org_internal_id'],
							options => FLDFLAG_PREPENDBLANK,
							invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						),
					],
			),
	);
	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions_add => [
							['View Referring Doctor Summary', "/person/%field.person_id%/profile", 1],
							['Add Another Referring Doctor', "/org/#session.org_id#/dlg-add-ref-doctor"],
							['Go to Search', "/search/person/id/%field.person_id%"],
							['Return to Home', "/person/#session.user_id#/home"],
							['Go to Work List', "person/worklist"],
							],
						cancelUrl => $self->{cancelUrl} || undef)
	);

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

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	my $personId = $page->param('person_id');

	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);

	my $PhysicianType = 'Physician/Type';
	my $physicianType  = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $PhysicianType);

	$page->field('ref_phy_item_id', $physicianType->{'item_id'});

	if($command eq 'remove')
	{
		$page->field('delete_record', 1);
	}
}

sub execute
{
	my ($self, $page, $command, $flags, $member) = @_;

	my $personId = $page->field('person_id');
	my $intOrgId = $page->session('org_internal_id');

	$page->schemaAction(
			'Person', $command,
			person_id => $personId || undef,
			name_prefix => $page->field('name_prefix') || undef,
			name_first => $page->field('name_first') || undef,
			name_middle => $page->field('name_middle') || undef,
			name_last => $page->field('name_last') || undef,
			name_suffix => $page->field('name_suffix') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			parent_org_id => $intOrgId ||undef,
			item_name => 'Physician/Type',
			value_type => App::Universal::ATTRTYPE_TEXT,
			value_text => 'Referring Doctor',
			_debug => 0
		)if $command eq 'add';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Home',
			value_type => App::Universal::ATTRTYPE_PHONE || undef,
			value_text => $page->field('phone') || undef,
			_debug => 0
			) if $page->field('phone') ne '' && $command eq 'add';

		$page->schemaAction(
				'Person_Attribute', $command,
				parent_id => $personId,
				item_name => 'Home',
				value_type => App::Universal::ATTRTYPE_FAX || undef,
				value_text => $page->field('fax') || undef,
				_debug => 0
		) if $page->field('fax') ne'' && $command eq 'add';

	$page->schemaAction(
			'Person_Org_Category', $command,
			person_id => $personId || undef,
			category => 'Referring-Doctor' || undef,
			org_internal_id => $intOrgId || undef,
			_debug => 0
		);

	my $facility = $page->field('upin_facility') ne '' ? $page->field('upin_facility') : $page->session('org_id');
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => "UPIN",
			value_type => App::Universal::ATTRTYPE_PROVIDER_NUMBER,
			value_text => $page->field('upin_num') || undef,
			value_textB => "UPIN",
			name_sort  => $facility,
			value_dateEnd => $page->field('upin_date') || undef,
			_debug => 0
		)if $page->field('upin_num') ne '' && $command eq 'add';
	$self->handlePostExecute($page, $command, $flags);
}

1;
