##############################################################################
package App::Dialog::Procedure;
##############################################################################
use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Person;
use App::Statements::Insurance;
use App::Statements::Transaction;
use App::Statements::Org;
use App::IntelliCode;
use Carp;
use CGI::Dialog;
use App::Dialog::OnHold;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Invoice;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'procedures', heading => '$Command Procedure/Lab');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'item_type'),

		new CGI::Dialog::Field::Duration(
				name => 'illness',
				caption => 'Illness: Similar/Current',
				begin_caption => 'Similar Illness Date',
				end_caption => 'Current Illness Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),
		new CGI::Dialog::Field::Duration(
				name => 'disability',
				caption => 'Disability: Begin/End',
				begin_caption => 'Begin Date',
				end_caption => 'End Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),
		new CGI::Dialog::Field::Duration(
				name => 'hospitalization',
				caption => 'Hospitalization: Admit/Discharge',
				begin_caption => 'Admission Date',
				end_caption => 'Discharge Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),
		new CGI::Dialog::Field::Duration(
				name => 'service',
				caption => 'Service Dates: From/To',
				begin_options => FLDFLAG_REQUIRED,
				begin_caption => 'From Date',
				end_caption => 'To Date'
				),
		new App::Dialog::Field::ServicePlaceType(caption => 'Service Place/Type'),
		new App::Dialog::Field::ProcedureLine(caption => 'CPT / Modf'),
		new App::Dialog::Field::DiagnosesCheckbox(caption => 'ICD-9 Codes', options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::ProcedureChargeUnits(caption => 'Charge/Units'),

		new CGI::Dialog::Field(caption => 'Reference', name => 'reference'),
		new CGI::Dialog::Field(caption => 'Comments', name => 'comments', type => 'memo', cols => 25, rows => 4),
	);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'invoice_item',
		key => "#param.invoice_id#",
		data => "Procedure #param.item_id# to claim <a href='/invoice/#param.invoice_id#'>#param.invoice_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(
							nextActions_add => [
								['Add Another Procedure', "/invoice/%param.invoice_id%/dialog/procedure/add", 1],
								['Put Claim On Hold', "/invoice/%param.invoice_id%/dialog/hold"],
								['Submit Claim for Review', "/invoice/%param.invoice_id%/review"],
								['Submit Claim for Transfer', "/invoice/%param.invoice_id%/review"],
								],
						cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	my $invoiceId = $page->param('invoice_id');
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $procItem = App::Universal::INVOICEITEMTYPE_SERVICE;
	my $labItem = App::Universal::INVOICEITEMTYPE_LAB;

	if($command eq 'add')
	{
		my $serviceInfo = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceProcedureItems', $invoiceId, $procItem, $labItem);

		my $numOfHashes = scalar (@{$serviceInfo});
		my $idx = $numOfHashes - 1;

		if($numOfHashes > 0 && $command eq 'add')
		{
			if($page->field('servplace') eq '')
			{
				$page->field('servplace', $serviceInfo->[$idx]->{data_num_a});
			}

			if($page->field('servtype') eq '')
			{
				$page->field('servtype', $serviceInfo->[$idx]->{data_num_b});
			}

			if($page->field('service_begin_date') eq '')
			{
				$page->field('service_begin_date', $serviceInfo->[$idx]->{data_date_a});
			}

			if($page->field('service_end_date') eq '')
			{
				$page->field('service_end_date', $serviceInfo->[$idx]->{data_date_b});
			}
		}
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	$page->field('', $page->getDate());
	my $sqlStampFmt = $page->defaultSqlStampFormat();
	my $invoiceId = $page->param('invoice_id');
	my $itemId = $page->param('item_id');

	$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selProcedure', $itemId);
	if($page->field('item_type') == App::Universal::INVOICEITEMTYPE_LAB)
	{
		$page->field('lab_indicator', 1)
	}

	my $itemDiagCodes = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selRelDiags', $itemId);
	my @icdCodes = split(/[,\s]+/, $itemDiagCodes);
	$page->field('procdiags', @icdCodes);

	$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrIllness',$invoiceId);
	$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrDisability',$invoiceId);
	$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrHospitalization',$invoiceId);
}

sub execAction_submit
{
	my ($page, $command) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $clientId = $invoice->{client_id};

	my $claimType = $invoice->{invoice_subtype};
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());


	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $phoneValueType = App::Universal::ATTRTYPE_PHONE;
	my $boolValueType = App::Universal::ATTRTYPE_BOOLEAN;
	my $currencyValueType = App::Universal::ATTRTYPE_CURRENCY;
	my $dateValueType = App::Universal::ATTRTYPE_DATE;
	my $licenseValueType = App::Universal::ATTRTYPE_LICENSE;

	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $uniqPlan = App::Universal::RECORDTYPE_PERSONALCOVERAGE;
	my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;

	#----FIRST CREATE THE INVOICE ATTRIBUTES FOR THE OLD HCFA1500!!----#

	my $invoiceFlags = $invoice->{flags};

	unless($invoiceFlags & $attrDataFlag)
	{
		my $mainTransId = $invoice->{main_transaction};
		my $mainTransData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selTransaction', $mainTransId);

		##BILLING FACILITY INFORMATION
		my $billingFacility = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $mainTransData->{billing_facility_id}, 'Mailing');
		my $billingFacilityName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $mainTransData->{billing_facility_id});

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Service Provider/Facility/Billing',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $billingFacilityName,
				value_textB => $billingFacility->{billing_facility_id}
			);

		$page->schemaAction(
				'Invoice_Address', $command,
				parent_id => $invoiceId,
				address_name => 'Billing',
				line1 => $billingFacility->{line1},
				line2 => $billingFacility->{line2},
				city => $billingFacility->{city},
				state => $billingFacility->{state},
				zip => $billingFacility->{zip},
				_debug => 0
			);

		##SERVICE FACILITY INFORMATION
		my $serviceFacility = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $mainTransData->{service_facility_id}, 'Mailing');
		my $serviceFacilityName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $mainTransData->{service_facility_id});

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Service Provider/Facility/Service',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $serviceFacilityName,
				value_textB => $serviceFacility->{service_facility_id}
			);

		$page->schemaAction(
				'Invoice_Address', $command,
				parent_id => $invoiceId,
				address_name => 'Service',
				line1 => $serviceFacility->{line1},
				line2 => $serviceFacility->{line2},
				city => $serviceFacility->{city},
				state => $serviceFacility->{state},
				zip => $serviceFacility->{zip},
				_debug => 0
			);


		##PATIENT INFO AND AUTHORIZATIONS
		my $personData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $clientId);
		my $personPhone = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selHomePhone', $clientId);
		my $personAddr = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $clientId);
		my $patSignature = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $clientId, 'Signature Source', App::Universal::ATTRTYPE_AUTHPATIENTSIGN);
		my $provAssign = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $clientId, 'Provider Assignment', App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN);
		my $infoRelease = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $clientId, 'Information Release', App::Universal::ATTRTYPE_AUTHINFORELEASE);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId || undef,
				item_name => 'Patient/Signature',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $patSignature->{value_text} || undef,
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId || undef,
				item_name => 'Provider/Assign Indicator',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $provAssign->{value_text} || undef,
				_debug => 0
			);

		my $infoRelIndctr = $infoRelease->{value_text} eq 'Yes' ? 1 : 0;
		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId || undef,
				item_name => 'Information Release/Indicator',
				value_type => defined $boolValueType ? $boolValueType : undef,
				value_int => defined $infoRelIndctr ? $infoRelIndctr : undef,
				value_date => $infoRelease->{value_date} || undef,
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId || undef,
				item_name => 'Provider/Signature/Date',
				value_type => defined $dateValueType ? $dateValueType : undef,
				value_date => $todaysDate || undef,
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Address', $command,
				parent_id => $invoiceId,
				address_name => 'Patient',
				line1 => $personAddr->{line1},
				line2 => $personAddr->{line2},
				city => $personAddr->{city},
				state => $personAddr->{state},
				zip => $personAddr->{zip},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Patient/Name',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $personData->{complete_name},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Patient/Name/Last',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $personData->{name_last},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Patient/Name/First',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $personData->{name_first},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Patient/Name/Middle',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $personData->{name_middle},
				_debug => 0
			) if $personData->{name_middle} ne '';

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Patient/Account Number',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $personData->{person_ref},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Patient/Contact/Home Phone',
				value_type => defined $phoneValueType ? $phoneValueType : undef,
				value_text => $personPhone,
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Patient/Personal/Marital Status',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $personData->{marstat_caption},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Patient/Personal/Gender',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $personData->{gender_caption},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Patient/Personal/DOB',
				value_type => defined $dateValueType ? $dateValueType : undef,
				value_date => $personData->{date_of_birth},
				_debug => 0
			);


		##PATIENT'S EMPLOYMENT STATUS

		my $personEmployStat = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selEmploymentStatusCaption', $clientId);
		#here's a list of statuses:

		my $ftEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDFULL;	#220
		my $ptEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDPART;	#221
		my $selfEmployAttr = App::Universal::ATTRTYPE_SELFEMPLOYED;	#222
		my $retiredAttr = App::Universal::ATTRTYPE_RETIRED;			#223
		my $ftStudentAttr = App::Universal::ATTRTYPE_STUDENTFULL;	#224
		my $ptStudentAttr = App::Universal::ATTRTYPE_STUDENTPART;	#225
		my $unknownAttr = App::Universal::ATTRTYPE_EMPLOYUNKNOWN;	#226

		foreach my $employStat (@{$personEmployStat})
		{
			my $status = '';
			$status = $employStat->{caption};
			$status = 'Retired' if $employStat->{value_type} == $retiredAttr;
			$status = 'Employed' if $employStat->{value_type} >= $ftEmployAttr && $employStat->{value_type} <= $selfEmployAttr;

			if($status eq 'Employed')
			{
				$page->schemaAction(
						'Invoice_Attribute', $command,
						parent_id => $invoiceId,
						item_name => 'Patient/Employment/Status',
						value_type => defined $textValueType ? $textValueType : undef,
						value_text => $status,
						_debug => 0
					);
			}
			elsif($status eq 'Student (Full-Time)' || $status eq 'Student (Part-Time)')
			{
				$page->schemaAction(
						'Invoice_Attribute', $command,
						parent_id => $invoiceId,
						item_name => 'Patient/Student/Status',
						value_type => defined $textValueType ? $textValueType : undef,
						value_text => $status,
						_debug => 0
					);
			}
		}


		##PATIENT'S PROVIDER INFO, CONDITION RELATED TO, AND REFERRING PHYSICIAN NAME AND ID
		my $providerInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $mainTransData->{provider_id});
		my $providerTaxId = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $mainTransData->{provider_id}, 'Tax ID', App::Universal::ATTRTYPE_LICENSE);
		my $providerUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $mainTransData->{provider_id}, 'UPIN', App::Universal::ATTRTYPE_LICENSE);
		my $providerSpecialty = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $mainTransData->{provider_id}, 'Primary', App::Universal::ATTRTYPE_SPECIALTY);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Provider/Name',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $providerInfo->{complete_name},
				value_textB => $mainTransData->{provider_id},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Provider/Name/First',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $providerInfo->{name_first},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Provider/Name/Middle',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $providerInfo->{name_middle},
				_debug => 0
			) if $providerInfo->{name_middle} ne '';

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Provider/Name/Last',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $providerInfo->{name_last},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Provider/UPIN',
				value_type => defined $licenseValueType ? $licenseValueType : undef,
				value_text => $providerUpin->{value_text},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Provider/Tax ID',
				value_type => defined $licenseValueType ? $licenseValueType : undef,
				value_text => $providerTaxId->{value_text},
				value_textB => $providerTaxId->{value_textb},
				_debug => 0
			);

		$page->schemaAction(
				'Invoice_Attribute', $command,
				parent_id => $invoiceId,
				item_name => 'Provider/Specialty',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $providerSpecialty->{value_text},
				value_textB => $providerSpecialty->{value_textb},
				_debug => 0
			);


		if($claimType != $selfPay)
		{
			##PATIENT'S INSURANCE INFO, INSURED INFO, OTHER INSURED INFO (IF ANY)

			my $primaryIns = App::Universal::INSURANCE_PRIMARY;
			my $textValueType = App::Universal::ATTRTYPE_TEXT;
			my $durationValueType = App::Universal::ATTRTYPE_DURATION;

			my $personInsur = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selPersonInsurance', $clientId, $primaryIns);
			my $claimType = $personInsur->{claim_type};

			my $insOrgName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $personInsur->{ins_org_id});

			my $parentId = $personInsur->{parent_ins_id} if $personInsur->{record_type} != $uniqPlan;
			$parentId = $personInsur->{ins_internal_id} if $personInsur->{record_type} == $uniqPlan;

			my $champusStatus = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentId, 'Champus Status');
			my $champusBranch = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentId, 'Champus Branch');
			my $champusGrade = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentId, 'Champus Grade');

			my $ppoHmo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentId, 'HMO-PPO/Indicator');
			my $bcbsCode = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentId, 'BCBS Plan Code');
			my $insOrgPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsurancePayerPhone', $parentId);
			my $insOrgAddr = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAddrWithOutColNameChanges', $parentId);


			my $relToCaption = $STMTMGR_INSURANCE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInsuredRelationship', $personInsur->{rel_to_insured});
			my $relToCode = '';
			$relToCode = '01' if $relToCaption eq 'Self';
			$relToCode = '02' if $relToCaption eq 'Spouse';
			$relToCode = '18' if $relToCaption eq 'Parent';
			$relToCode = '03' if $relToCaption eq 'Child';
			$relToCode = '99' if $relToCaption eq 'Other';

			my $paySource = '';
			$paySource = 'A' if $claimType eq 'Self-Pay';
			$paySource = 'B' if $claimType eq 'Workers Compensation';
			$paySource = 'C' if $claimType eq 'Medicare';
			$paySource = 'D' if $claimType eq 'Medicaid';
			#$paySource = 'E' if $claimType eq 'Other Federal Program';
			$paySource = 'F' if $claimType eq 'Insurance';
			#$paySource = 'G' if $claimType eq 'Blue Cross/Blue Shield';
			$paySource = 'H' if $claimType eq 'CHAMPUS';
			$paySource = 'I' if $claimType eq 'HMO';
			#$paySource = 'J' if $claimType eq 'Federal Employee’s Program (FEP)';
			#$paySource = 'K' if $claimType eq 'Central Certification';
			#$paySource = 'L' if $claimType eq 'Self Administered';
			#$paySource = 'M' if $claimType eq 'Family or Friends';
			#$paySource = 'N' if $claimType eq 'Managed Care - Non-HMO';
			$paySource = 'P' if $claimType eq 'BCBS';
			#$paySource = 'T' if $claimType eq 'Title V';
			#$paySource = 'V' if $claimType eq 'Veteran’s Administration Plan';
			$paySource = 'X' if $claimType eq 'PPO';
			$paySource = 'Z' if $claimType eq 'Client Billing' || $claimType eq 'ChampVA' || $claimType eq 'FECA Blk Lung';


			#first add insurance info
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insurance/Primary/Name',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insOrgName,
					value_textB => $personInsur->{ins_org_id},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insurance/Primary/Effective Dates',
					value_type => defined $durationValueType ? $durationValueType : undef,
					value_date => $personInsur->{coverage_begin_date},
					value_dateEnd => $personInsur->{coverage_end_date},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insurance/Primary/Type',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $claimType || undef,
					value_textB => $personInsur->{extra} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'HMO-PPO/Indicator',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $ppoHmo->{value_text} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'BCBS Plan Code',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $bcbsCode->{value_text} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Champus Branch',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $champusBranch->{value_text} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Champus Status',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $champusStatus->{value_text} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Champus Grade',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $champusGrade->{value_text} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Payment Source/Primary',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $paySource,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insurance/Primary/Phone',
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $insOrgPhone->{phone},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insurance/Primary/Group Number',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $personInsur->{group_name} || $personInsur->{plan_name},
					value_textB => $personInsur->{group_number} || $personInsur->{policy_number},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => 'Insurance',
					line1 => $insOrgAddr->{line1},
					line2 => $insOrgAddr->{line2},
					city => $insOrgAddr->{city},
					state => $insOrgAddr->{state},
					zip => $insOrgAddr->{zip},
					_debug => 0
				);

			#patient's relationship to the insured
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Patient/Insured/Relationship',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $relToCaption,
					value_int => $relToCode,
					_debug => 0
				);

			#now add insured info
			my $insuredData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $personInsur->{insured_id});
			my $insuredPhone = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selHomePhone', $personInsur->{insured_id});
			my $insuredAddr = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $personInsur->{insured_id});
			my $insuredEmployers = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selEmploymentAssociations', $personInsur->{insured_id});

			foreach my $employer (@{$insuredEmployers})
			{
				next if $employer->{value_type} == $retiredAttr;

				my $occupType = 'Employer';
				$occupType = 'School' if $employer->{value_type} == $ftStudentAttr || $employer->{value_type} == $ptStudentAttr;

				my $empStatus = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selEmploymentStatus', $employer->{value_type});

				my $employerName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $employer->{value_text});

				$page->schemaAction(
						'Invoice_Attribute', $command,
						parent_id => $invoiceId,
						item_name => "Insured/$occupType/Name",
						value_type => defined $textValueType ? $textValueType : undef,
						value_text => $employerName,
						value_textB => $empStatus,
						_debug => 0
					);
			}

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => 'Insured',
					line1 => $insuredAddr->{line1},
					line2 => $insuredAddr->{line2},
					city => $insuredAddr->{city},
					state => $insuredAddr->{state},
					zip => $insuredAddr->{zip},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insured/Name',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{complete_name},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insured/Name/Last',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{name_last},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insured/Name/First',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{name_first},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insured/Name/Middle',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{name_middle},
					_debug => 0
				) if $insuredData->{name_middle} ne '';

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insured/Contact/Home Phone',
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $insuredPhone,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insured/Personal/Marital Status',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{marstat_caption},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insured/Personal/Gender',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{gender_caption},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insured/Personal/DOB',
					value_type => defined $dateValueType ? $dateValueType : undef,
					value_date => $insuredData->{date_of_birth},
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Insured/Personal/SSN',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{ssn},
					_debug => 0
				);


			##MEDICAID - RESUBMISSION CODE AND ORIGINAL REFERENCE

			#if(I think this is needed when a claim is resubmitted - check with toi)
			#{
			#	$page->schemaAction(
			#			'Invoice_Attribute', $command,
			#			parent_id => $invoiceId,
			#			item_name => 'Medicaid/Resubmission',
			#			value_type => defined $textValueType ? $textValueType : undef,
			#			value_text => (code)
			#			value_textB => (reference)
			#			_debug => 0
			#		);
			#}


			#Create attributes for secondary insurance (for HCFA Box 11d, 9a-d)
			my $secondaryIns = App::Universal::INSURANCE_SECONDARY;
			my $secondInsur = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selPersonInsurance', $clientId, $secondaryIns);
			if($secondInsur->{ins_internal_id})
			{
				$page->schemaAction(
						'Invoice_Attribute', $command,
						parent_id => $invoiceId,
						item_name => 'Insurance/Secondary/Group Number',
						value_type => defined $textValueType ? $textValueType : undef,
						value_text => $secondInsur->{group_name},
						value_textB => $secondInsur->{group_number} || $secondInsur->{policy_number},
						_debug => 0
					);

				my $claimType = $secondInsur->{claim_type};

				my $paySource = '';
				$paySource = 'A' if $claimType eq 'Self-Pay';
				$paySource = 'B' if $claimType eq 'Workers Compensation';
				$paySource = 'C' if $claimType eq 'Medicare';
				$paySource = 'D' if $claimType eq 'Medicaid';
				#$paySource = 'E' if $claimType eq 'Other Federal Program';
				$paySource = 'F' if $claimType eq 'Insurance';
				#$paySource = 'G' if $claimType eq 'Blue Cross/Blue Shield';
				$paySource = 'H' if $claimType eq 'CHAMPUS';
				$paySource = 'I' if $claimType eq 'HMO';
				#$paySource = 'J' if $claimType eq 'Federal Employee’s Program (FEP)';
				#$paySource = 'K' if $claimType eq 'Central Certification';
				#$paySource = 'L' if $claimType eq 'Self Administered';
				#$paySource = 'M' if $claimType eq 'Family or Friends';
				#$paySource = 'N' if $claimType eq 'Managed Care - Non-HMO';
				$paySource = 'P' if $claimType eq 'BCBS';
				#$paySource = 'T' if $claimType eq 'Title V';
				#$paySource = 'V' if $claimType eq 'Veteran’s Administration Plan';
				$paySource = 'X' if $claimType eq 'PPO';
				$paySource = 'Z' if $claimType eq 'Client Billing' || $claimType eq 'ChampVA' || $claimType eq 'FECA Blk Lung';

				$page->schemaAction(
						'Invoice_Attribute', $command,
						parent_id => $invoiceId,
						item_name => 'Payment Source/Secondary',
						value_type => defined $textValueType ? $textValueType : undef,
						value_text => $paySource,
						_debug => 0
					);

				my $otherInsuredData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $secondInsur->{insured_id});
				my $otherInsuredEmployers = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selEmploymentAssociations', $secondInsur->{insured_id});

				foreach my $employer (@{$otherInsuredEmployers})
				{
					next if $employer->{value_type} == $retiredAttr;

					my $occupType = 'Employer';
					$occupType = 'School' if $employer->{value_type} == $ftStudentAttr || $employer->{value_type} == $ptStudentAttr;

					my $empStatus = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selEmploymentStatus', $employer->{value_type});

					my $employerName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $employer->{value_text});

					$page->schemaAction(
							'Invoice_Attribute', $command,
							parent_id => $invoiceId,
							item_name => "Other Insured/$occupType/Name",
							value_type => defined $textValueType ? $textValueType : undef,
							value_text => $employerName,
							value_textB => $empStatus,
							_debug => 0
						);
				}

				$page->schemaAction(
						'Invoice_Attribute', $command,
						parent_id => $invoiceId,
						item_name => 'Other Insured/Personal/Gender',
						value_type => defined $textValueType ? $textValueType : undef,
						value_text => $otherInsuredData->{gender_caption},
						_debug => 0
					);

				$page->schemaAction(
						'Invoice_Attribute', $command,
						parent_id => $invoiceId,
						item_name => 'Other Insured/Personal/DOB',
						value_type => defined $dateValueType ? $dateValueType : undef,
						value_date => $otherInsuredData->{date_of_birth},
						_debug => 0
					);
			}
		}

		##CREATE TRANSACTIONS FOR DIAGNOSES (ICD CODES)

		my @icdCodes = split(', ', $invoice->{claim_diags});
		foreach my $icdCode (@icdCodes)
		{
			$page->schemaAction(
					'Transaction', $command,
					trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
					trans_owner_id => $clientId,
					parent_trans_id => $mainTransId,
					trans_type => App::Universal::TRANSTYPEDIAG_ICD,
					trans_status => App::Universal::TRANSSTATUS_ACTIVE,
					billing_facility_id => $mainTransData->{billing_facility_id},
					service_facility_id => $mainTransData->{service_facility_id},
					code => $icdCode || undef,
					provider_id => $mainTransData->{provider_id},
					trans_begin_stamp => $todaysDate,
					_debug => 0
				);
		}
	}



	#----NOW UPDATE THE INVOICE STATUS AND SET THE FLAG----#

	## Update invoice status, set flag for attributes, enter in submitter_id and date of submission
	$todaysDate = $page->getDate();
	$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $invoiceId,
			invoice_status => App::Universal::INVOICESTATUS_SUBMITTED,
			submitter_id => $page->session('user_id') || undef,
			flags => $invoiceFlags | $attrDataFlag,
			_debug => 0
		);


	## Then, create invoice attributes for history of invoice status
	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => 'Reviewed',
			value_textB => $page->field('comments') || undef,
			value_date => $todaysDate,
			_debug => 0
	);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $itemId = $page->param('item_id');
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $invItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId) if $command ne 'update';

	my $sessOrg = $page->session('org_id');
	my $sessUser = $page->session('user_id');
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());

	my $itemType = App::Universal::INVOICEITEMTYPE_SERVICE;
	if($page->field('lab_indicator'))
	{
		$itemType = App::Universal::INVOICEITEMTYPE_LAB;
	}

	my @relDiags = $page->field('procdiags');
	my @cptCodes = split(/,/, $page->field('procedure'));
	my @hcpcsCode = split(/,/, $page->field('hcpcs'));
	my $comments = $page->field('comments');
	my $emg = $page->field('emg') == 1 ? 1 : 0;
	my $extCost = $page->field('proccharge') * $page->field('procunits');
	my $balance = $extCost + $invItem->{total_adjust};


	## RUN INTELLICODE
	if($command ne 'remove')
	{
		App::IntelliCode::incrementUsage($page, 'Cpt', \@cptCodes, $sessUser, $sessOrg);
		#App::IntelliCode::incrementUsage($page, 'Hcpcs', \@hcpcsCode, $sessUser, $sessOrg);

		my $feeSchedules = App::IntelliCode::getItemCost($page, \@cptCodes, $sessOrg, $invoice->{ins_id});

		if($feeSchedules eq 'HASH')
		{
			foreach my $fee (@{$feeSchedules})
			{
				$page->addDebugStmt("Intellicode: $fee->{catalog_id}, $fee->{unit_cost}");
			}
		}
		elsif($feeSchedules eq 'ARRAY')
		{
			foreach my $fee (@$feeSchedules)
			{
				$page->addDebugStmt("Intellicode: $fee->[0]");
				$page->addDebugStmt("Intellicode: $fee->[1]");
			}
		}
	}

	$page->schemaAction(
			'Invoice_Item', $command,
			item_id => $itemId || undef,
			parent_id => $invoiceId,
			item_type => defined $itemType ? $itemType : undef,
			code => $page->field('procedure') || undef,
			modifier => $page->field('procmodifier') || undef,
			rel_diags => join(', ', @relDiags) || undef,
			unit_cost => $page->field('proccharge') || undef,
			quantity => $page->field('procunits') || undef,
			extended_cost => $extCost || undef,
			balance => defined $balance ? $balance : undef,
			emergency => defined $emg ? $emg : undef,
			comments => $comments || '',
			reference => $page->field('reference') || undef,
			hcfa_service_place => $page->field('servplace') || undef,
			hcfa_service_type => $page->field('servtype') || 'NULL',
			service_begin_date => $page->field('service_begin_date') || undef,
			service_end_date => $page->field('service_end_date') || undef,
			_debug => 0
		);




	## UPDATE INVOICE TO WHICH ITEM BELONGS

	my $totalItems = $invoice->{total_items};
	if($command eq 'add')
	{
		$totalItems = $invoice->{total_items} + 1;
	}
	elsif($command eq 'remove')
	{
		$totalItems = $invoice->{total_items} - 1;
	}

	my $allInvItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selInvoiceItems', $invoiceId);
	my $totalCostForInvoice = '';
	foreach my $item (@{$allInvItems})
	{
		$totalCostForInvoice += $item->{extended_cost};
	}

	$balance = $totalCostForInvoice + $invoice->{total_adjust};

	$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $invoiceId || undef,
			total_items => defined $totalItems ? $totalItems : undef,
			total_cost => defined $totalCostForInvoice ? $totalCostForInvoice : undef,
			balance => defined $balance ? $balance : undef,
			_debug => 0
		);




	## ADD HISTORY ATTRIBUTE

	my $action = '';
	$action = 'Added' if $command eq 'add';
	$action = 'Updated' if $command eq 'update';
	$action = 'Deleted' if $command eq 'remove';
	my $itemNum = $page->param('item_seq') || $invoice->{total_items} + 1;

	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => "$action line item $itemNum",
			value_textB => $comments || undef,
			value_date => $todaysDate,
			_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);
}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hierarchies
# 4: any text notes about the actual change/action
#
use constant PROCEDURE_DIALOG => 'Dialog/Procedure';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '12/27/1999', 'MAF',
		PROCEDURE_DIALOG,
		'Added submitter_id and submit_date to schema action (when updating invoice after submitting).'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '12/27/1999', 'MAF',
		PROCEDURE_DIALOG,
		'Fixed invoice statuses according to changes made to invoice_status table.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/03/2000', 'MAF',
		PROCEDURE_DIALOG,
		'Added Pay Source, Insurance Type Code, Provider/UPIN invoice attributes.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/05/2000', 'MAF',
		PROCEDURE_DIALOG,
		'Added HMO-PPO invoice attribute.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/10/2000', 'MAF',
		PROCEDURE_DIALOG,
		"Removed 'execAction_x' functions for 'hold' and 'review'."],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/13/2000', 'MAF',
		PROCEDURE_DIALOG,
		'Added Information Release attribute here (taken out from Create Claim).'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/14/2000', 'MAF',
		PROCEDURE_DIALOG,
		'Added increment tracking of cpt codes (see ref_cpt_usage table).'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/14/1999', 'RK',
		PROCEDURE_DIALOG,
		'Added activityLog & nextAction_add to the sub new subroutine and added handlePostExecute in execute subroutine.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/17/1999', 'MAF',
		PROCEDURE_DIALOG,
		'Added a field to allow users to enter in a reference number per line item.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/24/1999', 'MAF',
		PROCEDURE_DIALOG,
		'Replaced magic numbers with constants.'],
);

1;

