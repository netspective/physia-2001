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
use constant MAXID => 25;

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
		new App::Dialog::Field::Address(caption=>'Work Address', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, name => 'address'),

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

		new CGI::Dialog::Field(type => 'hidden', name => 'phy_type_item_id'),

		new CGI::Dialog::Subhead(heading => 'License ID Numbers', name => 'id_numbers_section', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::DataGrid(
			caption =>'',
			name => 'id_numbers',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			rows => MAXID,
			rowFields => [
				{
					_class => 'CGI::Dialog::Field',
					type => 'select',
					selOptions => 'DEA;DPS;IRS;Board Certification;BCBS;Nursing/License;Memorial Sisters Charity;EPSDT',
					caption => 'License',
					name => 'id_name',
					options => FLDFLAG_PREPENDBLANK,
					readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
					onChangeJS => qq{showHideRows('id_numbers', 'id_name', @{[ MAXID ]});},
				},
				{
					_class => 'CGI::Dialog::Field',
					caption => 'Number',
					name => 'id_num',
				},
				{
					_class => 'CGI::Dialog::Field',
					type=> 'date',
					caption => 'Exp Date',
					name => 'id_exp_date',
					defaultValue => '',
				},
				{
					_class => 'CGI::Dialog::Field',
					caption => 'Facility ID',
					name => 'id_facility',
					fKeyStmtMgr => $STMTMGR_ORG,
					fKeyStmt => 'selChildFacilityOrgs',
					fKeyDisplayCol => 0,
					fKeyValueCol => 0,
					type => 'select',
					fKeyStmtBindSession => ['org_internal_id'],
					options => FLDFLAG_PREPENDBLANK,
					invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				},
			]),
		new CGI::Dialog::Subhead(heading => 'Provider Numbers', name => 'provider_id_numbers_section', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::DataGrid(
			caption =>'',
			name => 'prov_id_numbers',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			rows => MAXID,
			rowFields => [
				{
					_class => 'CGI::Dialog::Field',
					type => 'select',
					selOptions => 'Medicaid;Medicare;UPIN;Tax ID;Railroad Medicare;Champus;WC#;National Provider Identification',
					caption => 'License',
					name => 'prov_id_name',
					options => FLDFLAG_PREPENDBLANK,
					readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
					onChangeJS => qq{showHideRows('prov_id_numbers', 'prov_id_name', @{[ MAXID ]});},
				},
				{
					_class => 'CGI::Dialog::Field',
					caption => 'Number',
					name => 'prov_id_num',
				},
				{
					_class => 'CGI::Dialog::Field',
					type=> 'date',
					caption => 'Exp Date',
					name => 'prov_id_exp_date',
					defaultValue => '',
				},
				{
					_class => 'CGI::Dialog::Field',
					caption => 'Facility ID',
					name => 'prov_id_facility',
					fKeyStmtMgr => $STMTMGR_ORG,
					fKeyStmt => 'selChildFacilityOrgs',
					fKeyDisplayCol => 0,
					fKeyValueCol => 0,
					type => 'select',
					fKeyStmtBindSession => ['org_internal_id'],
					options => FLDFLAG_PREPENDBLANK,
					invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				},
			]),


	);

	$self->addPostHtml(qq{
		<script language="JavaScript1.2">
		<!--

		showHideRows('id_numbers', 'id_name', @{[ MAXID ]});
		showHideRows('prov_id_numbers', 'prov_id_name', @{[ MAXID ]});

		// -->
		</script>
	});

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

	$page->schemaAction(
			'Person_Address', $command,
			parent_id => $personId,
			address_name => 'Work',
			line1 => $page->field('addr_line1'),
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city'),
			state => $page->field('addr_state'),
			zip => $page->field('addr_zip'),
			_debug => 0
		) if $page->field('addr_line1') ne '';

	my $facility = $page->field('upin_facility') ne '' ? $page->field('upin_facility') : $page->session('org_id');
	my $y = '';
	for (my $x = 1; $y !=1; $x++)
	{
		my $idName = "id_name_$x";
		my $idNum = "id_num_$x";
		my $idDate = "id_exp_date_$x";
		my $idFacility = "id_facility_$x";
		my $facility = $page->field("$idFacility") ne '' ? $page->field("$idFacility") : $page->session('org_id');

		if ($idName ne '')
		{

			$page->schemaAction(
					'Person_Attribute', $command,
					parent_id => $personId || undef,
					item_name => $page->field("$idName") || undef,
					value_type => App::Universal::ATTRTYPE_LICENSE,
					value_text => $page->field("$idNum") || undef,
					value_textB => $page->field("$idName") || undef,
					name_sort  => $facility,
					value_dateEnd => $page->field("$idDate") || undef,
					_debug => 0
			)if $page->field("$idName") ne '';

		}

		$y = $page->field("$idName") ne '' ? '' : 1;
	};

	#Provider Numbers

	my $q = '';
	for (my $p = 1; $q !=1; $p++)
	{
		my $idPName = "prov_id_name_$p";
		my $idPNum = "prov_id_num_$p";
		my $idPDate = "prov_id_exp_date_$p";
		my $idPFacility = "prov_id_facility_$p";
		my $pFacility = $page->field("$idPFacility") ne '' ? $page->field("$idPFacility") : $page->session('org_id');

		if ($idPName ne '')
		{

			$page->schemaAction(
					'Person_Attribute', $command,
					parent_id => $personId || undef,
					item_name => $page->field("$idPName") || undef,
					value_type => App::Universal::ATTRTYPE_PROVIDER_NUMBER,
					value_text => $page->field("$idPNum") || undef,
					value_textB => $page->field("$idPName") || undef,
					name_sort  => $pFacility,
					value_dateEnd => $page->field("$idPDate") || undef,
					_debug => 0
			)if $page->field("$idPName") ne '';

		}

		$q = $page->field("$idPName") ne '' ? '' : 1;
	};

	$self->handlePostExecute($page, $command, $flags);
}

1;
