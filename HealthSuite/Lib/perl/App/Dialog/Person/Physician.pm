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
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;
use App::Universal;
use Date::Manip;
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
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						postHtml => $postHtml),
			);

	$self->SUPER::initialize();
	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'phy_type_item_id'),

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
				#new CGI::Dialog::Field(
				#	type => 'select',
				#	selOptions => 'Fellow of the Royal College of Physicians;Member of the American Heart Association;
				#	Member of the Canadian Medical Association;Member of American Society for Bone and Mineral Research;
				#	Member of Quebec Society of Endocrinologists',
				#	caption => 'Affiliation',
				#	name => 'affiliation',
				#	onValidateData => $self),
				new CGI::Dialog::Field(caption => 'Affiliation', name => 'affiliation'),
				new CGI::Dialog::Field(type => 'date', caption => 'Date', name => 'value_dateend', futureOnly => 0, defaultValue => ''),
			]),
		new CGI::Dialog::MultiField(caption => 'Board Certification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						fields => [
							new CGI::Dialog::Field(caption => 'Accreditations', name => 'accreditations'),
							new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'accredit_exp_date', defaultValue => ''),
							]),
		new CGI::Dialog::MultiField(caption =>'UPIN/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(  caption => 'UPIN', name => 'upin'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'upin_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Medicare/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field( caption => 'Medicare', name => 'medicare'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'medicare_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Medicaid/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field( caption => 'Medicaid', name => 'medicaid'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'medicaid_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Tax ID/Type/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Tax ID', name => 'tax_id'),
				new CGI::Dialog::Field(caption => 'Tax ID Type',
						name => 'tax_id_type',
						fKeyStmtMgr => $STMTMGR_PERSON,
						fKeyStmt => 'selTaxIdType',
						fKeyDisplayCol => 1,
						fKeyValueCol => 0),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'taxid_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'IRS/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field( caption => 'IRS', name => 'irs'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'irs_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'DEA/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field( caption => 'DEA', name => 'dea'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'dea_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'DPS/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field( caption => 'DPS', name => 'dps'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'dps_exp_date', futureOnly => 1, defaultValue => ''),
				]),
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
		new CGI::Dialog::MultiField(caption =>'BCBS #/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'bcbs#', name => 'bcbs_num'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'bcbs_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Railroad Medicare/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'railroad_medic', name => 'rail_medic'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'rail_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Champus/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'champus', name => 'champus'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'champus_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'WC #/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'wc#', name => 'wc_num'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'wc_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'National Provider Indentification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'provider identification', name => 'provider_identif_num'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'identif_exp_date', futureOnly => 1, defaultValue => ''),
				]),

		new CGI::Dialog::Field(
						type => 'bool',
						name => 'delete_record',
						caption => 'Delete record?',
						style => 'check',
						invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
						readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE),
	);

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions_add => [
							['View Physician Summary', "/person/%field.person_id%/profile", 1],
							['Add Another Physician', "/org/#session.org_id#/dlg-add-physician"],
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

	$self->updateFieldFlags('acct_chart_num', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('nurse_title', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('misc_notes', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('ethnicity', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('party_name', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('relation', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('license_num_state', FLDFLAG_INVISIBLE, 1);
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

	#my $specialty1 = $self->getField('specialty1')->{fields}->[0];
	#my $seq1 = $self->getField('specialty1')->{fields}->[1];
	my $specialty2 = $self->getField('specialty2')->{fields}->[0];
	#my $seq2 = $self->getField('specialty2')->{fields}->[1];
	my $specialty3 = $self->getField('specialty3')->{fields}->[0];
	#my $seq3 = $self->getField('specialty3')->{fields}->[1];
	my $medSpecCode = $page->field('specialty_code');
	my $medSpecCode2 = $page->field('specialty2_code');
	my $medSpecCode3 = $page->field('specialty3_code');
	#my $specSeq1 = $page->field('value_int1');
	#my $specSeq2 = $page->field('value_int2');
	#my $specSeq3 = $page->field('value_int3');
	my $personId = $page->field('person_id');


	if	($medSpecCode ne '' && ($medSpecCode eq $medSpecCode2))
	{
		$specialty2->invalidate($page, "Cannot add the same Specialty more than once for $personId");
	}
	if (($medSpecCode2 ne '' && ($medSpecCode2 eq $medSpecCode3)) ||
		($medSpecCode3 ne '' && ($medSpecCode3 eq $medSpecCode)))
	{
		$specialty3->invalidate($page, "Cannot add the same Specialty more than once for $personId");
	}
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $member = 'Physician';

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

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'UPIN',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('upin') || undef,
			value_textB => 'UPIN' || undef,
			value_dateEnd => $page->field('upin_exp_date') || undef,
			_debug => 0
	) if $page->field('upin') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'Medicaid',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('medicaid') || undef,
			value_textB => 'Medicaid' || undef,
			value_dateEnd => $page->field('medicaid_exp_date') || undef,
			_debug => 0
	) if $page->field('medicaid') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'Medicare',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('medicare') || undef,
			value_textB => 'Medicare' || undef,
			value_dateEnd => $page->field('medicare_exp_date') || undef,
			_debug => 0
	) if $page->field('medicare') ne '';


	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'Tax ID',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('tax_id') || undef,
			value_textB => 'Tax ID' || undef,
			value_dateEnd => $page->field('taxid_exp_date') || undef,
			_debug => 0
	) if $page->field('tax_id') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'IRS',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('irs') || undef,
			value_textB => 'IRS' || undef,
			value_dateEnd => $page->field('irs_exp_date') || undef,
			_debug => 0
	) if $page->field('irs') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'DEA',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('dea') || undef,
			value_textB => 'DEA' || undef,
			value_dateEnd => $page->field('dea_exp_date') || undef,
			_debug => 0
	) if $page->field('dea') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'DPS',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('dps') || undef,
			value_textB => 'DPS' || undef,
			value_dateEnd => $page->field('dps_exp_date') || undef,
			_debug => 0
	) if $page->field('dps') ne '';


	#State Licenses

	my $state1 = $page->field('state1');
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => "$state1",
			value_type => App::Universal::ATTRTYPE_STATE,
			value_text => $page->field('license1') || undef,
			value_textB => $state1 || undef,
			value_dateEnd => $page->field('state_exp_date1') || undef,
			value_int => 1,
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
			value_dateEnd => $page->field('state_exp_date2') || undef,
			value_int => 2,
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
			value_dateEnd => $page->field('state_exp_date3') || undef,
			value_int => 3,
			_debug => 0
	) if $state3 ne '' && $page->field('license3') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'BCBS',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_textB => 'BCBS',
			value_text => $page->field('bcbs_num') || undef,
			value_dateEnd => $page->field('bcbs_exp_date') || undef,
			_debug => 0
	) if $page->field('bcbs_num') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'Railroad Medicare',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_textB => 'Railroad Medicare',
			value_text => $page->field('rail_medic') || undef,
			value_dateEnd => $page->field('rail_exp_date') || undef,
			_debug => 0
	) if $page->field('rail_medic') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'Champus',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_textB => 'Champus',
			value_text => $page->field('champus') || undef,
			value_dateEnd => $page->field('champus_exp_date') || undef,
			_debug => 0
	) if $page->field('champus') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'WC#',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_textB => 'WC#',
			value_text => $page->field('wc_num') || undef,
			value_dateEnd => $page->field('wc_exp_date') || undef,
			_debug => 0
	) if $page->field('wc_num') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'National Provider Identification',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_textB => 'National Provider Identification',
			value_text => $page->field('provider_identif_num') || undef,
			value_dateEnd => $page->field('identif_exp_date') || undef,
			_debug => 0
	) if $page->field('provider_identif_num') ne '';

	$self->handleContactInfo($page, $command, $flags, 'Physician');
}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Physician';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Physician';

	$self->SUPER::execute_remove($page, $command, $flags, $member);

}

1;
