##############################################################################
package App::Dialog::Person::Physician;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use App::Dialog::Field::Scheduling;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;
use App::Universal;
use Date::Manip;
use constant MAXID => 25;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Person);

%RESOURCE_MAP = ( 'physician' => { heading => '$Command Physician/Provider',
				  _arl => ['person_id'],
				  _arl_modify => ['person_id'],
				  _idSynonym => 'Physician' },);

sub initialize
{
	my $self = shift;

	my $postHtml = "<a href=\"javascript:doActionPopup('/lookup/person');\">Lookup existing person</a>";

	$self->heading('$Command Physician/Provider');
	$self->addContent(
			new App::Dialog::Field::Person::ID::New(caption => 'Physician/Provider ID',
							name => 'person_id',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						postHtml => $postHtml),
			);

	$self->SUPER::initialize();
	$self->addContent(
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
					selOptions => 'DEA;DPS;IRS',
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
					selOptions => 'BCBS;Memorial Sisters Charity;EPSDT;Medicaid;Medicare;UPIN;Tax ID;Railroad Medicare;Champus;WC#;National Provider Identification',
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

		new CGI::Dialog::Subhead(heading => 'Billing Information', name => 'billing_id_section', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(caption => 'ID Type', name => 'billing_id_type', type => 'select', selOptions => 'Per Se:0;THINnet:2;Other:3', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(caption => 'Billing ID',
			#type => 'foreignKey',
			name => 'billing_id',
#			fKeyStmtMgr => $STMTMGR_PERSON,
#			fKeyStmt => 'selMedicalSpeciality',
#			fKeyDisplayCol => 0,
#			fKeyValueCol => 1,
#			options => FLDFLAG_PREPENDBLANK,
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new App::Dialog::Field::Scheduling::Date(caption => 'Effective Date',
			#type => 'foreignKey',
			name => 'billing_effective_date',
			type => 'date',
#			fKeyStmtMgr => $STMTMGR_PERSON,
#			fKeyStmt => 'selMedicalSpeciality',
#			fKeyDisplayCol => 0,
#			fKeyValueCol => 1,
#			options => FLDFLAG_PREPENDBLANK,
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Field(
			name => 'billing_active',
			type => 'bool',
			style => 'check',
			caption => 'Process Live Claims',
			defaultValue => 0),

 		new CGI::Dialog::Subhead(heading => 'Certification/Accreditations', name => 'cert_for_physician', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::MultiField(caption => '1. Specialty/Sequence', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, name => 'specialty1',
			fields => [
					new CGI::Dialog::Field(caption => '1. Specialty',
						#type => 'foreignKey',
						name => 'specialty_code',
						fKeyStmtMgr => $STMTMGR_PERSON,
						fKeyStmt => 'selMedicalSpeciality',
						fKeyDisplayCol => 0,
						fKeyValueCol => 1,
						options => FLDFLAG_PREPENDBLANK,
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
					new CGI::Dialog::Field(caption => 'Specialty Sequence', name => 'value_int1', type => 'select', selOptions => 'Unknown:5;Primary:1;Secondary:2;Tertiary:3;Quaternary:4', value => '5', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
				]),

		new CGI::Dialog::MultiField(caption => '2. Specialty/Sequence', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, name => 'specialty2',
			fields => [
					new CGI::Dialog::Field(caption => '2. Specialty',
						#type => 'foreignKey',
						name => 'specialty2_code',
						fKeyStmtMgr => $STMTMGR_PERSON,
						fKeyStmt => 'selMedicalSpeciality',
						fKeyDisplayCol => 0,
						fKeyValueCol => 1,
						options => FLDFLAG_PREPENDBLANK,
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
					new CGI::Dialog::Field(caption => 'Specialty Sequence', name => 'value_int2', type => 'select', selOptions => 'Unknown:5;Primary:1;Secondary:2;Tertiary:3;Quaternary:4', value => '5', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
				]),

		new CGI::Dialog::MultiField(caption => '3. Specialty/Sequence', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, name => 'specialty3',
			fields => [
					new CGI::Dialog::Field(caption => '3. Specialty',
						#type => 'foreignKey',
						name => 'specialty3_code',
						fKeyStmtMgr => $STMTMGR_PERSON,
						fKeyStmt => 'selMedicalSpeciality',
						fKeyDisplayCol => 0,
						fKeyValueCol => 1,
						options => FLDFLAG_PREPENDBLANK,
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
					new CGI::Dialog::Field(caption => 'Specialty Sequence', name => 'value_int3', type => 'select', selOptions => 'Unknown:5;Primary:1;Secondary:2;Tertiary:3;Quaternary:4', value => '5', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
				]),

		new CGI::Dialog::MultiField(caption => 'Affiliation/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Affiliation', name => 'affiliation'),
				new CGI::Dialog::Field(type => 'date', caption => 'Date', name => 'value_dateend', futureOnly => 0, defaultValue => ''),
			]),
		new CGI::Dialog::MultiField(caption => 'Board Certification Name/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Board Certification Name', name => 'board_certification'),
				new CGI::Dialog::Field(type => 'date', caption => 'Date', name => 'board_dateend', futureOnly => 0, defaultValue => ''),
			]),
		#new CGI::Dialog::MultiField(caption => 'Board Certification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		#				fields => [
		#					new CGI::Dialog::Field(caption => 'Accreditations', name => 'accreditations'),
		#					new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'accredit_exp_date', defaultValue => ''),
		#					]),
		#new CGI::Dialog::MultiField(caption =>'Tax ID/Type/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		#	fields => [
		#		new CGI::Dialog::Field(caption => 'Tax ID', name => 'tax_id'),
		#		new CGI::Dialog::Field(caption => 'Tax ID Type',
		#				name => 'tax_id_type',
		#				fKeyStmtMgr => $STMTMGR_PERSON,
		#				fKeyStmt => 'selTaxIdType',
		#				fKeyDisplayCol => 1,
		#				fKeyValueCol => 0),
		#		new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'taxid_exp_date', futureOnly => 1, defaultValue => ''),
		#		]),
		#new CGI::Dialog::MultiField(caption =>'IRS/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		#	fields => [
		#		new CGI::Dialog::Field( caption => 'IRS', name => 'irs'),
		#		new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'irs_exp_date', futureOnly => 1, defaultValue => ''),
		#		]),
		#new CGI::Dialog::MultiField(caption =>'DEA/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		#	fields => [
		#		new CGI::Dialog::Field( caption => 'DEA', name => 'dea'),
		#		new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'dea_exp_date', futureOnly => 1, defaultValue => ''),
		#		]),
		#new CGI::Dialog::MultiField(caption =>'DPS/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		#	fields => [
		#		new CGI::Dialog::Field( caption => 'DPS', name => 'dps'),
		#		new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'dps_exp_date', futureOnly => 1, defaultValue => ''),
		#		]),
		new CGI::Dialog::MultiField(caption =>'1. State/License/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'State', name => 'state1'),
				new CGI::Dialog::Field(caption => 'License', name => 'license1'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'state1_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'2. State/License/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'State', name => 'state2'),
				new CGI::Dialog::Field(caption => 'License', name => 'license2'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'state2_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'3. State/License/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'State', name => 'state3'),
				new CGI::Dialog::Field(caption => 'License', name => 'license3'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'state3_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		#new CGI::Dialog::MultiField(caption =>'National Provider Indentification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		#	fields => [
		#		new CGI::Dialog::Field(caption => 'provider identification', name => 'provider_identif_num'),
		#		new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'identif_exp_date', futureOnly => 1, defaultValue => ''),
		#		]),

		new CGI::Dialog::Field(
						type => 'bool',
						name => 'delete_record',
						caption => 'Delete record?',
						style => 'check',
						invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
						readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE),
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
							['View Physician Summary', "/person/%field.person_id%/profile", 1],
							['Add Another Physician', "/org/#session.org_id#/dlg-add-physician"],
							['Go to Search', "/search/person/id/%field.person_id%"],
							['Return to Home', "/person/#session.user_id#/home"],
							['Go to Work List', "/worklist"],
							],
						cancelUrl => $self->{cancelUrl} || undef)
	);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->updateFieldFlags('acct_chart_num', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('nurse_title', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('misc_notes', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('party_name', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('relation', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('license_num_state', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('create_unknown_phone', FLDFLAG_INVISIBLE, 1);

	#if ($command eq 'update' || $command eq 'remove')
	#$self->updateFieldFlags('physician_type', FLDFLAG_INVISIBLE, 1) if $command eq 'update' || $command eq 'remove'  ;
	my $personId = $page->param('person_id');

	if($command eq 'remove')
	{
		my $deleteRecord = $self->getField('delete_record');
		$deleteRecord->invalidate($page, "Are you sure you want to delete Physician '$personId'?");
	}

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub customValidate
{
	my ($self, $page) = @_;

	my $command = $self->getActiveCommand($page);

	return () if ($command eq 'remove' || $command eq 'update');
	my $personId = $page->field('person_id');
	my $specialty2 = $self->getField('specialty2')->{fields}->[0];
	my $specialty3 = $self->getField('specialty3')->{fields}->[0];
	my $medSpecCode = $page->field('specialty_code');
	my $medSpecCode2 = $page->field('specialty2_code');
	my $medSpecCode3 = $page->field('specialty3_code');
	my $specSeq1 = $page->field('value_int1');
	my $specSeq2 = $page->field('value_int2');
	my $specSeq3 = $page->field('value_int3');
	my $specValid1 = $self->getField('specialty1')->{fields}->[1];
	my $specValid2 = $self->getField('specialty2')->{fields}->[1];
	my $specValid3 = $self->getField('specialty3')->{fields}->[1];


	if	($medSpecCode ne '' && ($medSpecCode eq $medSpecCode2))
	{
		$specialty2->invalidate($page, "Cannot add the same Specialty more than once for $personId");
	}

	if (($medSpecCode2 ne '' && ($medSpecCode2 eq $medSpecCode3)) ||
		($medSpecCode3 ne '' && ($medSpecCode3 eq $medSpecCode)))
	{
		$specialty3->invalidate($page, "Cannot add the same Specialty more than once for $personId");
	}

	if ($specSeq2 ne '' && ($specSeq2 eq $specSeq1 || $specSeq2 eq $specSeq3) && $specSeq2 ne App::Universal::SPECIALTY_UNKNOWN)
	{
		$specValid2->invalidate($page, "The same 'Specialty Sequence' cannot be added more than once.");
	}

	if ($specSeq3 ne '' && ($specSeq3 eq $specSeq1 || $specSeq3 eq $specSeq2) && $specSeq3 ne App::Universal::SPECIALTY_UNKNOWN)
	{
		$specValid3->invalidate($page, "The same 'Specialty Sequence' cannot be added more than once.");
	}

	if($medSpecCode ne '' && $specSeq1 ne App::Universal::SPECIALTY_UNKNOWN && $specSeq1 ne App::Universal::SPECIALTY_PRIMARY
	   && ($specSeq1-1 ne  $specSeq2 && $specSeq1-1 > $specSeq3))
	{
		$specValid1->invalidate($page, "This 'Specialty Sequence' cannot be added unless the previous sequence is added.");
	}

	if($medSpecCode2 ne '' && $specSeq2 ne App::Universal::SPECIALTY_UNKNOWN && $specSeq2 ne App::Universal::SPECIALTY_PRIMARY
	   && ($specSeq2-1 ne $specSeq1 && $specSeq2-1 ne $specSeq3))
	{
		$specValid2->invalidate($page, "This 'Specialty Sequence' cannot be added unless the previous sequence is added.");
	}

	if($medSpecCode3 ne '' && $specSeq3 ne App::Universal::SPECIALTY_UNKNOWN && $specSeq3 ne App::Universal::SPECIALTY_PRIMARY
	   && ($specSeq3-1 ne $specSeq1 && $specSeq3-1 ne $specSeq2))
	{
		$specValid3->invalidate($page, "This 'Specialty Sequence' cannot be added unless the previous sequence is added.");
	}
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $member = 'Physician';
	$page->beginUnitWork("Unable to add Physician");
	$self->SUPER::handleRegistry($page, $command, $flags, $member);

	my $medSpecCode = $page->field('specialty_code');
	my $medSpecCode2 = $page->field('specialty2_code');
	my $medSpecCode3 = $page->field('specialty3_code');
	my $medSpecCaption = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selMedicalSpecialtyCaption', $medSpecCode);
	my $medSpecCaption2 = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selMedicalSpecialtyCaption', $medSpecCode2);
	my $medSpecCaption3 = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selMedicalSpecialtyCaption', $medSpecCode3);

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => $member,
			value_type => App::Universal::ATTRTYPE_BILLING_INFO,
			value_text => $page->field('billing_id') || undef,
			value_intB => $page->field('billing_active') || undef,
			value_int => $page->field('billing_id_type') || undef,
			value_date => $page->field('billing_effective_date') || undef,
			_debug => 0,
		);

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => $medSpecCaption,
			value_type => App::Universal::ATTRTYPE_SPECIALTY,
			value_text => $medSpecCode || undef,
			value_textB => $medSpecCaption || undef,
			value_int => $page->field('value_int1') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => $medSpecCaption2,
			value_type => App::Universal::ATTRTYPE_SPECIALTY,
			value_text => $medSpecCode2 || undef,
			value_textB => $medSpecCaption2 || undef,
			value_int => $page->field('value_int2') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => $medSpecCaption3,
			value_type => App::Universal::ATTRTYPE_SPECIALTY,
			value_text => $medSpecCode3 || undef,
			value_textB => $medSpecCaption3 || undef,
			value_int => $page->field('value_int3') || undef,
			_debug => 0
		);

	my $affiliation = $page->field('affiliation');
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => "$affiliation",
			value_type => App::Universal::ATTRTYPE_AFFILIATION,
			value_text => $affiliation || undef,
			value_dateEnd => $page->field('value_dateend') ||undef,
			_debug => 0
	) if $affiliation ne '';

	my $boardCertication = $page->field('board_certification');
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => "$boardCertication",
			value_type => App::Universal::ATTRTYPE_BOARD_CERTIFICATION,
			value_text => $boardCertication || undef,
			value_dateEnd => $page->field('board_dateend') ||undef,
			_debug => 0
	) if $boardCertication ne '';

	my $accreditation = $page->field('accreditations');
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => "$accreditation",
			value_type => App::Universal::ATTRTYPE_ACCREDITATION,
			value_text => $accreditation || undef,
			value_dateEnd => $page->field('accredit_exp_date') || undef,
			_debug => 0
	) if $accreditation ne '';



	#ID Numbers

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

	#State Licenses

	my $state1 = $page->field('state1');
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => "$state1",
			value_type => App::Universal::ATTRTYPE_STATE,
			value_text => $page->field('license1') || undef,
			value_textB => $state1 || undef,
			value_dateEnd => $page->field('state1_exp_date') || undef,
			_debug => 0
	) if $state1 ne '' && $page->field('license1') ne '';


	my $state2 = $page->field('state2');
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => "$state2",
			value_type => App::Universal::ATTRTYPE_STATE,
			value_text => $page->field('license2') || undef,
			value_textB => $state2 || undef,
			value_dateEnd => $page->field('state2_exp_date') || undef,
			_debug => 0
	) if $state2 ne '' && $page->field('license2') ne '';

	my $state3 = $page->field('state3');
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => "$state3",
			value_type => App::Universal::ATTRTYPE_STATE,
			value_text => $page->field('license3') || undef,
			value_textB => $state3 || undef,
			value_dateEnd => $page->field('state3_exp_date') || undef,
			_debug => 0
	) if $state3 ne '' && $page->field('license3') ne '';

	$self->handleContactInfo($page, $command, $flags, 'Physician');
	$page->endUnitWork();

}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Physician';
	$page->beginUnitWork("Unable to update Physician");
	$self->SUPER::handleRegistry($page, $command, $flags, $member);
	$page->endUnitWork();
}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Physician';
	$page->beginUnitWork("Unable to delete Physician");
	$self->SUPER::execute_remove($page, $command, $flags, $member);
	$page->endUnitWork();
}

1;
