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
use App::Statements::Catalog;
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
		new CGI::Dialog::Field(type => 'hidden', name => 'claim_diags'),

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
				#begin_options => FLDFLAG_REQUIRED,
				begin_caption => 'From Date',
				end_caption => 'To Date'
				),
		new App::Dialog::Field::ServicePlaceType(caption => 'Service Place/Type'),
		new App::Dialog::Field::ProcedureLine(caption => 'CPT / Modf'),
		new App::Dialog::Field::DiagnosesCheckbox(caption => 'ICD-9 Codes', options => FLDFLAG_REQUIRED, name => 'procdiags'),

		new CGI::Dialog::Field(caption => 'Fee Schedules', name => 'fee_schedules', options => FLDFLAG_PERSIST),
		new App::Dialog::Field::ProcedureChargeUnits(caption => 'Charge/Units', name => 'proc_charge_fields'),

		new CGI::Dialog::MultiField(caption => 'Units', name => 'units_emg_fields',
			fields => [
				new CGI::Dialog::Field(caption => 'Units', name => 'procunits', type => 'integer', size => 6, minValue => 1, value => 1, options => FLDFLAG_REQUIRED),
				new CGI::Dialog::Field(caption => 'EMG', name => 'emg', type => 'bool', style => 'check'),
			]),

		new CGI::Dialog::Field(caption => 'Please choose a unit cost', name => 'alt_cost', type => 'select', options => FLDFLAG_REQUIRED),

		#new CGI::Dialog::Field(caption => 'Reference', name => 'reference'),
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

	$self->setFieldFlags('alt_cost', FLDFLAG_INVISIBLE, 1);
	$self->setFieldFlags('units_emg_fields', FLDFLAG_INVISIBLE, 1);


	my $procItem = App::Universal::INVOICEITEMTYPE_SERVICE;
	my $labItem = App::Universal::INVOICEITEMTYPE_LAB;

	if($command eq 'add')
	{
		my $serviceInfo = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceProcedureItems', $invoiceId, $procItem, $labItem);

		my $numOfHashes = scalar (@{$serviceInfo});
		my $idx = $numOfHashes - 1;

		if($numOfHashes > 0)
		{
			$page->field('servplace', $serviceInfo->[$idx]->{hcfa_service_place});
			$self->setFieldFlags('servplace', FLDFLAG_READONLY);

			if($page->field('servtype') eq '')
			{
				$page->field('servtype', $serviceInfo->[$idx]->{hcfa_service_type});
			}

			if($page->field('service_begin_date') eq '')
			{
				$page->field('service_begin_date', $serviceInfo->[$idx]->{service_begin_date});
			}

			if($page->field('service_end_date') eq '')
			{
				$page->field('service_end_date', $serviceInfo->[$idx]->{service_end_date});
			}
		}
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	my $invoiceId = $page->param('invoice_id');

	$page->field('claim_diags', $STMTMGR_INVOICE->getSingleValue($page, 0, 'selClaimDiags', $invoiceId));

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	$page->field('', $page->getDate());
	my $sqlStampFmt = $page->defaultSqlStampFormat();
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
	
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());

	my $invoiceId = $page->param('invoice_id');
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $mainTransData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selTransactionById', $invoice->{main_transaction});
	
	my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;
	my $invoiceFlags = $invoice->{flags};
	unless($invoiceFlags & $attrDataFlag)
	{
		storeFacilityInfo($page, $command, $invoiceId, $invoice, $mainTransData);
		storeAuthorizations($page, $command, $invoiceId, $invoice, $mainTransData);
		storePatientInfo($page, $command, $invoiceId, $invoice, $mainTransData);
		storePatientEmployment($page, $command, $invoiceId, $invoice, $mainTransData);
		storeProviderInfo($page, $command, $invoiceId, $invoice, $mainTransData);		
		
		if($invoice->{invoice_subtype} != App::Universal::CLAIMTYPE_SELFPAY)
		{
			storeInsuranceInfo($page, $command, $invoiceId, $invoice, $mainTransData);
		}
		
		if($invoice->{invoice_subtype} == App::Universal::CLAIMTYPE_HMO)
		{
			hmoCapWriteoff($page, $command, $invoiceId, $invoice, $mainTransData);
		}
		
		createActiveProbTrans($page, $command, $invoiceId, $invoice, $mainTransData);		
	}

	#----NOW UPDATE THE INVOICE STATUS AND SET THE FLAG----#

	## Update invoice status, set flag for attributes, enter in submitter_id and date of submission
	$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $invoiceId,
			invoice_status => App::Universal::INVOICESTATUS_SUBMITTED,
			submitter_id => $page->session('user_id') || undef,
			submit_date => $todaysDate || undef,
			flags => $invoiceFlags | $attrDataFlag,
			_debug => 0
	);


	## create invoice attribute for history of invoice status
	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => 'Reviewed',
			value_date => $todaysDate || undef,
			_debug => 0
	);
}

sub hmoCapWriteoff
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $writeoffCode = App::Universal::ADJUSTWRITEOFF_CONTRACTAGREEMENT;
	my $totalAdjForItems = 0;
	my $procItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	foreach my $proc (@{$procItems})
	{
		next if $proc->{item_type} == App::Universal::INVOICEITEMTYPE_ADJUST || $proc->{item_type} == App::Universal::INVOICEITEMTYPE_COPAY || $proc->{item_type} == App::Universal::INVOICEITEMTYPE_DEDUCTIBLE;
	
		my $writeoffAmt = $proc->{balance};
		my $netAdjust = 0 - $writeoffAmt;
		my $itemId = $proc->{item_id};
		$page->schemaAction(
			'Invoice_Item_Adjust', 'add',
			parent_id => $itemId || undef,
			pay_date => $todaysDate,
			writeoff_code => defined $writeoffCode ? $writeoffCode : undef,
			writeoff_amount => defined $writeoffAmt ? $writeoffAmt : undef,
			net_adjust => defined $netAdjust ? $netAdjust : undef,
			comments => 'Writeoff auto-generated by system',
			_debug => 0
		);	

		my $totalAdjustForItem = $proc->{total_adjust} + $netAdjust;
		my $itemBalance = $proc->{extended_cost} + $totalAdjustForItem;
		$page->schemaAction(
			'Invoice_Item', 'update',
			item_id => $itemId || undef,
			total_adjust => defined $totalAdjustForItem ? $totalAdjustForItem : undef,
			balance => defined $itemBalance ? $itemBalance : undef,
			_debug => 0
		);

		$totalAdjForItems += $netAdjust;
	}



	## update the invoice
	my $totalAdjustForInvoice = $invoice->{total_adjust} + $totalAdjForItems;
	my $invBalance = $invoice->{total_cost} + $totalAdjustForInvoice;
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId || undef,
		total_adjust => defined $totalAdjustForInvoice ? $totalAdjustForInvoice : undef,
		balance => defined $invBalance ? $invBalance : undef,
		_debug => 0
	);



	## create invoice attribute for history of these adjustments
	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => 'Auto-generated writeoffs for HMO Capitated claim',
			value_date => $todaysDate || undef,
			_debug => 0
	);
}

sub storeFacilityInfo
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	##billing facility information
	my $billFacilityId = $mainTransData->{billing_facility_id};
	my $billingFacilityAddr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $billFacilityId, 'Mailing');
	my $billingFacilityName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $billFacilityId);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Facility/Billing',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $billingFacilityName || undef,
			value_textB => $billFacilityId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Address', $command,
			parent_id => $invoiceId,
			address_name => 'Billing',
			line1 => $billingFacilityAddr->{line1} || undef,
			line2 => $billingFacilityAddr->{line2} || undef,
			city => $billingFacilityAddr->{city} || undef,
			state => $billingFacilityAddr->{state} || undef,
			zip => $billingFacilityAddr->{zip} || undef,
			_debug => 0
		);

	##SERVICE FACILITY INFORMATION
	my $servFacilityId = $mainTransData->{service_facility_id};
	my $serviceFacility = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $servFacilityId, 'Mailing');
	my $serviceFacilityName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $servFacilityId);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Facility/Service',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $serviceFacilityName || undef,
			value_textB => $servFacilityId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Address', $command,
			parent_id => $invoiceId,
			address_name => 'Service',
			line1 => $serviceFacility->{line1} || undef,
			line2 => $serviceFacility->{line2} || undef,
			city => $serviceFacility->{city} || undef,
			state => $serviceFacility->{state} || undef,
			zip => $serviceFacility->{zip} || undef,
			_debug => 0
		);
}

sub storeAuthorizations
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $boolValueType = App::Universal::ATTRTYPE_BOOLEAN;
	my $dateValueType = App::Universal::ATTRTYPE_DATE;
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());

	my $clientId = $invoice->{client_id};
	my $patSignature = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByPersonAndValueType', $clientId, App::Universal::ATTRTYPE_AUTHPATIENTSIGN);
	my $provAssign = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByPersonAndValueType', $clientId, App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN);
	my $infoRelease = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByPersonAndValueType', $clientId, App::Universal::ATTRTYPE_AUTHINFORELEASE);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId || undef,
			item_name => 'Patient/Signature',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $patSignature->{value_text} || undef,
			value_textB => $patSignature->{value_textb} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId || undef,
			item_name => 'Provider/Assign Indicator',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $provAssign->{value_text} || undef,
			value_textB => $provAssign->{value_textb} || undef,
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
}

sub storePatientInfo
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;
	
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $phoneValueType = App::Universal::ATTRTYPE_PHONE;
	my $dateValueType = App::Universal::ATTRTYPE_DATE;

	my $clientId = $invoice->{client_id};
	my $personData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $clientId);
	my $personPhone = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selHomePhone', $clientId);
	my $personAddr = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $clientId);

	$page->schemaAction(
			'Invoice_Address', $command,
			parent_id => $invoiceId,
			address_name => 'Patient',
			line1 => $personAddr->{line1} || undef,
			line2 => $personAddr->{line2} || undef,
			city => $personAddr->{city} || undef,
			state => $personAddr->{state} || undef,
			zip => $personAddr->{zip} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Name',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{complete_name} || undef,
			value_textB => $clientId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Name/Last',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{name_last} || undef,
			value_textB => $clientId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Name/First',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{name_first} || undef,
			value_textB => $clientId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Name/Middle',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{name_middle} || undef,
			value_textB => $clientId || undef,
			_debug => 0
		) if $personData->{name_middle} ne '';

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Account Number',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{person_ref} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Contact/Home Phone',
			value_type => defined $phoneValueType ? $phoneValueType : undef,
			value_text => $personPhone || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Personal/Marital Status',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{marstat_caption} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Personal/Gender',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{gender_caption} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Personal/DOB',
			value_type => defined $dateValueType ? $dateValueType : undef,
			value_date => $personData->{date_of_birth} || undef,
			_debug => 0
		);
}

sub storePatientEmployment
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	# a list of employment statuses:
	my $ftEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDFULL;	#220
	my $ptEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDPART;	#221
	my $selfEmployAttr = App::Universal::ATTRTYPE_SELFEMPLOYED;	#222
	my $retiredAttr = App::Universal::ATTRTYPE_RETIRED;			#223
	my $ftStudentAttr = App::Universal::ATTRTYPE_STUDENTFULL;	#224
	my $ptStudentAttr = App::Universal::ATTRTYPE_STUDENTPART;	#225
	my $unknownAttr = App::Universal::ATTRTYPE_EMPLOYUNKNOWN;	#226

	my $personEmployStat = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selEmploymentStatusCaption', $invoice->{client_id});
	foreach my $employStat (@{$personEmployStat})
	{
		my $valueType = $employStat->{value_type};
	
		my $status = '';
		$status = $employStat->{caption};
		$status = 'Retired' if $valueType == $retiredAttr;
		$status = 'Employed' if $valueType >= $ftEmployAttr && $valueType <= $selfEmployAttr;

		if($status eq 'Employed')
		{
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Patient/Employment/Status',
					value_type => defined $valueType ? $valueType : undef,
					value_text => $status || undef,
					_debug => 0
				);
		}
		elsif($status eq 'Student (Full-Time)' || $status eq 'Student (Part-Time)')
		{
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Patient/Student/Status',
					value_type => defined $valueType ? $valueType : undef,
					value_text => $status || undef,
					_debug => 0
				);
		}
	}
}

sub storeProviderInfo
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;
	
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $licenseValueType = App::Universal::ATTRTYPE_LICENSE;

	my $providerId = $mainTransData->{provider_id};
	my $providerInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $providerId);
	my $providerTaxId = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $providerId, 'Tax ID', $licenseValueType);
	my $providerUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $providerId, 'UPIN', $licenseValueType);
	my $providerBcbs = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $providerId, 'BCBS', $licenseValueType);
	my $providerMedicare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $providerId, 'Medicare', $licenseValueType);
	my $providerMedicaid = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $providerId, 'Medicaid', $licenseValueType);
	my $providerChampus = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $providerId, 'Champus', $licenseValueType);
	my $providerSpecialty = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $providerId, 'Primary', App::Universal::ATTRTYPE_SPECIALTY);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Name',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{complete_name} || undef,
			value_textB => $providerId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Name/First',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{name_first} || undef,
			value_textB => $providerId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Name/Middle',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{name_middle} || undef,
			value_textB => $providerId || undef,
			_debug => 0
		) if $providerInfo->{name_middle} ne '';

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Name/Last',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{name_last} || undef,
			value_textB => $providerId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/UPIN',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $providerUpin->{value_text} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/BCBS',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $providerBcbs->{value_text} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Medicare',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $providerMedicare->{value_text} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Medicaid',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $providerMedicaid->{value_text} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Champus',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $providerChampus->{value_text} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Tax ID',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $providerTaxId->{value_text} || undef,
			value_textB => $providerTaxId->{value_textb} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Specialty',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerSpecialty->{value_text} || undef,
			value_textB => $providerSpecialty->{value_textb} || undef,
			_debug => 0
		);
}

sub storeInsuranceInfo
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;
	
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $phoneValueType = App::Universal::ATTRTYPE_PHONE;
	my $dateValueType = App::Universal::ATTRTYPE_DATE;
	my $durationValueType = App::Universal::ATTRTYPE_DURATION;
	my $primaryIns = App::Universal::INSURANCE_PRIMARY;
	my $uniqPlan = App::Universal::RECORDTYPE_PERSONALCOVERAGE;

	my $ftEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDFULL;		#220
	my $ptEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDPART;		#221
	my $selfEmployAttr = App::Universal::ATTRTYPE_SELFEMPLOYED;		#222
	my $retiredAttr = App::Universal::ATTRTYPE_RETIRED;				#223
	my $ftStudentAttr = App::Universal::ATTRTYPE_STUDENTFULL;		#224
	my $ptStudentAttr = App::Universal::ATTRTYPE_STUDENTPART;		#225
	my $unknownAttr = App::Universal::ATTRTYPE_EMPLOYUNKNOWN;	#226

	my $clientId = $invoice->{client_id};

	my $invoicePayers = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selInvoiceBillingRecs', $invoiceId);
	foreach my $payer (@{$invoicePayers})
	{
		my $partyType = $payer->{bill_party_type};
		my $insIntId = $payer->{bill_ins_id};

		next if $partyType == App::Universal::INVOICEBILLTYPE_CLIENT;	#don't want to continue because this type is a self-pay
	
		my $payerBillSeq = 'Primary' if $payer->{bill_sequence} == App::Universal::PAYER_PRIMARY;
		$payerBillSeq = 'Secondary' if $payer->{bill_sequence} == App::Universal::PAYER_SECONDARY;
		$payerBillSeq = 'Tertiary' if $payer->{bill_sequence} == App::Universal::PAYER_TERTIARY;
		$payerBillSeq = 'Quaternary' if $payer->{bill_sequence} == App::Universal::PAYER_QUATERNARY;

		if($partyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYORG)
		{
			my $thirdPartyInsur = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInsuranceData', $insIntId);
			my $parentInsId = $thirdPartyInsur->{parent_ins_id};
			my $thirdPartyId = $thirdPartyInsur->{guarantor_id};
			
			my $thirdPartyName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $thirdPartyId);
			my $thirdPartyPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsurancePayerPhone', $parentInsId);
			my $thirdPartyAddr = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAddrWithOutColNameChanges', $parentInsId);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Third-Party/Org/Name',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $thirdPartyName || undef,
					value_textB => $thirdPartyId || undef,
					_debug => 0
				);
		
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Third-Party/Org/Phone',
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $thirdPartyPhone->{phone} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => 'Third-Party',
					line1 => $thirdPartyAddr->{line1} || undef,
					line2 => $thirdPartyAddr->{line2} || undef,
					city => $thirdPartyAddr->{city} || undef,
					state => $thirdPartyAddr->{state} || undef,
					zip => $thirdPartyAddr->{zip} || undef,
					_debug => 0
				);
		
		}
		elsif($partyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYPERSON)
		{
			my $thirdPartyInsur = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInsuranceData', $insIntId);
			my $parentInsId = $thirdPartyInsur->{parent_ins_id};
			my $thirdPartyId = $thirdPartyInsur->{guarantor_id};

			my $thirdPartyName = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selRegistry', $thirdPartyId);
			my $thirdPartyPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsurancePayerPhone', $parentInsId);
			my $thirdPartyAddr = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAddrWithOutColNameChanges', $parentInsId);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Third-Party/Person/Name',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $thirdPartyName || undef,
					value_textB => $thirdPartyId || undef,
					_debug => 0
				);
		
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Third-Party/Person/Phone',
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $thirdPartyPhone->{phone} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => 'Third-Party',
					line1 => $thirdPartyAddr->{line1} || undef,
					line2 => $thirdPartyAddr->{line2} || undef,
					city => $thirdPartyAddr->{city} || undef,
					state => $thirdPartyAddr->{state} || undef,
					zip => $thirdPartyAddr->{zip} || undef,
					_debug => 0
				);
		
		}
		elsif($partyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYINS)
		{
			my $personInsur = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInsuranceForInvoiceSubmit', $insIntId);
			#next if $personInsur->{bill_sequence} == App::Universal::INSURANCE_WORKERSCOMP;
			my $insOrgId = $personInsur->{ins_org_id};
			my $parentInsId = $personInsur->{parent_ins_id};

			#Basic Insurance Information --------------------
			my $insOrgName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $insOrgId);
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Name",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insOrgName || undef,
					value_textB => $insOrgId || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Effective Dates",
					value_type => defined $durationValueType ? $durationValueType : undef,
					value_date => $personInsur->{coverage_begin_date} || undef,
					value_dateEnd => $personInsur->{coverage_end_date} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Type",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $personInsur->{claim_type} || undef,
					value_textB => $personInsur->{extra} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Group Number",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $personInsur->{plan_name} || $personInsur->{product_name} || $personInsur->{group_name} || undef,
					value_textB => $personInsur->{group_number} || $personInsur->{policy_number} || undef,
					_debug => 0
				);




			#HMO-PPO Indicator and BCBS Plan Code --------------------
			my $ppoHmo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'HMO-PPO/Indicator');
			my $bcbsCode = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'BCBS Plan Code');
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/HMO-PPO ID",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $ppoHmo->{value_text} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/BCBS Plan Code",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $bcbsCode->{value_text} || undef,
					_debug => 0
				);




			#Payment Source --------------------
			my $claimType = $personInsur->{claim_type};
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
					item_name => "Insurance/$payerBillSeq/Payment Source",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $paySource || undef,
					_debug => 0
				);




			#Champus Information --------------------
			my $champusStatus = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'Champus Status');
			my $champusBranch = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'Champus Branch');
			my $champusGrade = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'Champus Grade');

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Champus Branch",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $champusBranch->{value_text} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Champus Status",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $champusStatus->{value_text} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Champus Grade",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $champusGrade->{value_text} || undef,
					_debug => 0
				);




			#Insurance Contact Info --------------------
			my $insOrgPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsurancePayerPhone', $parentInsId);
			my $insOrgAddr = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAddrWithOutColNameChanges', $parentInsId);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Phone",
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $insOrgPhone->{phone} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => "$payerBillSeq Insurance",
					line1 => $insOrgAddr->{line1} || undef,
					line2 => $insOrgAddr->{line2} || undef,
					city => $insOrgAddr->{city} || undef,
					state => $insOrgAddr->{state} || undef,
					zip => $insOrgAddr->{zip} || undef,
					_debug => 0
				);



			#Relationship to Insured --------------------
			my $relToCaption = $STMTMGR_INSURANCE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInsuredRelationship', $personInsur->{rel_to_insured});
			my $relToCode = '';
			$relToCode = '01' if $relToCaption eq 'Self';
			$relToCode = '02' if $relToCaption eq 'Spouse';
			$relToCode = '18' if $relToCaption eq 'Parent';
			$relToCode = '03' if $relToCaption eq 'Child';
			$relToCode = '99' if $relToCaption eq 'Other';
			#patient's relationship to the insured
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Patient-Insured/Relationship",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $relToCaption || undef,
					value_int => $relToCode || undef,
					_debug => 0
				);



			#Insured Information --------------------
			my $insuredData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $personInsur->{insured_id});
			my $insuredId = $insuredData->{person_id};
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Name",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{complete_name} || undef,
					value_textB => $insuredId || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Name/Last",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{name_last} || undef,
					value_textB => $insuredId || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Name/First",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{name_first} || undef,
					value_textB => $insuredId || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Name/Middle",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{name_middle} || undef,
					value_textB => $insuredId || undef,
					_debug => 0
				) if $insuredData->{name_middle} ne '';

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Personal/Marital Status",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{marstat_caption} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Personal/Gender",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{gender_caption} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Personal/DOB",
					value_type => defined $dateValueType ? $dateValueType : undef,
					value_date => $insuredData->{date_of_birth} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Personal/SSN",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{ssn} || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Member Number",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $personInsur->{member_number} || undef,
					_debug => 0
				);



			#Insured's Contact Information
			my $insuredPhone = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selHomePhone', $personInsur->{insured_id});
			my $insuredAddr = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $personInsur->{insured_id});

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$payerBillSeq/Insured/Contact/Home Phone",
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $insuredPhone || undef,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => "$payerBillSeq Insured",
					line1 => $insuredAddr->{line1} || undef,
					line2 => $insuredAddr->{line2} || undef,
					city => $insuredAddr->{city} || undef,
					state => $insuredAddr->{state} || undef,
					zip => $insuredAddr->{zip} || undef,
					_debug => 0
				);



			#Insured's Employment Info
			my $insuredEmployers = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selEmploymentAssociations', $personInsur->{insured_id});
			foreach my $employer (@{$insuredEmployers})
			{
				my $valueType = $employer->{value_type};
				next if $valueType == $retiredAttr;

				my $occupType = 'Employer';
				$occupType = 'School' if $valueType == $ftStudentAttr || $valueType == $ptStudentAttr;

				my $empStatus = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selEmploymentStatus', $valueType);

				my $employerName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $employer->{value_text});

				$page->schemaAction(
						'Invoice_Attribute', $command,
						parent_id => $invoiceId,
						item_name => "Insurance/$payerBillSeq/Insured/$occupType/Name",
						value_type => defined $valueType ? $valueType : undef,
						value_text => $employerName || undef,
						value_textB => $empStatus || undef,
						_debug => 0
					);
			}

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

			#OLD ATTRIBUTES
			#Create attributes for secondary insurance (for HCFA Box 11d, 9a-d)
			#	'Payment Source/Secondary',
			#	'Insurance/Secondary/Group Number',
			#	"Other Insured/$occupType/Name",
			#	'Other Insured/Personal/Gender',
			#	'Other Insured/Personal/DOB',
		}
	}
}

sub createActiveProbTrans
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;
	
	my $personValueType = App::Universal::ENTITYTYPE_PERSON;
	my $transStatActive = App::Universal::TRANSSTATUS_ACTIVE;
	my $todaysStamp = $page->getTimeStamp();

	my @icdCodes = split(/\s*,\s*/, $invoice->{claim_diags});
	foreach my $icdCode (@icdCodes)
	{
		$page->schemaAction(
				'Transaction', $command,
				trans_owner_type => defined $personValueType ? $personValueType : undef,
				trans_owner_id => $invoice->{client_id} || undef,
				parent_trans_id => $mainTransData->{trans_id} || undef,
				trans_type => App::Universal::TRANSTYPEDIAG_ICD,
				trans_status => defined $transStatActive ? $transStatActive : undef,
				init_onset_date => $mainTransData->{init_onset_date} || undef,
				curr_onset_date => $mainTransData->{curr_onset_date} || undef,
				billing_facility_id => $mainTransData->{billing_facility_id} || undef,
				service_facility_id => $mainTransData->{service_facility_id} || undef,
				code => $icdCode || undef,
				provider_id => $mainTransData->{provider_id} || undef,
				care_provider_id => $mainTransData->{care_provider_id} || undef,
				trans_begin_stamp => $todaysStamp || undef,
				_debug => 0
		);
	}
}

sub customValidate
{
	my ($self, $page) = @_;

	#GET ITEM COST FROM FEE SCHEDULE
	my $enteredCost = $page->field('proccharge');
	unless($enteredCost)
	{
		my $unitCostField = $self->getField('proc_charge_fields')->{fields}->[0];
		my @feeSchedules = split(/\s*,\s*/, $page->field('fee_schedules'));
		my $cptCode = $page->field('procedure');
		my $modCode = $page->field('procmodifier');

		my $fsResults = App::IntelliCode::getItemCost($page, $cptCode, $modCode, \@feeSchedules);
		my $resultCount = scalar(@$fsResults);
		if($resultCount == 0)
		{
			$unitCostField->invalidate($page, 'No unit cost was found');
		}
		elsif($resultCount == 1)
		{
			foreach (@$fsResults)
			{
				my $fs = $_->[0];
				my $entry = $_->[1];
				my $unitCost = $entry->{unit_cost};
				$page->field('proccharge', $unitCost);
			}
		}
		else
		{
			my @costs = ();
			foreach (@$fsResults)
			{
				my $fs = $_->[0];
				my $entry = $_->[1];
				push(@costs, $entry->{unit_cost});

				#$unitCostField->invalidate($page, "Fee Schedule '$fs' returned the unit cost: $unitCost");
			}

			$self->updateFieldFlags('alt_cost', FLDFLAG_INVISIBLE, 0);
			$self->updateFieldFlags('units_emg_fields', FLDFLAG_INVISIBLE, 0);
			$self->updateFieldFlags('proc_charge_fields', FLDFLAG_INVISIBLE, 1);

			my $costList = join(';', @costs);
			$self->getField('alt_cost')->{selOptions} = "$costList";
		}
	}


}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	if($command eq 'add' || $command eq 'update')
	{
		execute_addOrUpdate($self, $page, $command, $flags);
	}
	else
	{
		voidProcedure($self, $page, $command, $flags);
	}

	$self->handlePostExecute($page, $command, $flags);
}

sub execute_addOrUpdate
{
	my ($self, $page, $command, $flags) = @_;

	my $sessOrg = $page->session('org_id');
	my $sessUser = $page->session('user_id');
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $invoiceId = $page->param('invoice_id');
	my $itemId = $page->param('item_id');
	my $invItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId) if $command eq 'update';

	my $itemType = App::Universal::INVOICEITEMTYPE_SERVICE;
	if($page->field('lab_indicator'))
	{
		$itemType = App::Universal::INVOICEITEMTYPE_LAB;
	}

	my $comments = $page->field('comments');
	my $emg = $page->field('emg') == 1 ? 1 : 0;

	my $unitCost = $page->field('proccharge') || $page->field('alt_cost');
	my $extCost = $unitCost * $page->field('procunits');
	my $balance = $extCost + $invItem->{total_adjust};

	my @feeSchedules = split(/\s*,\s*/, $page->field('fee_schedules'));
	my @relDiags = $page->field('procdiags');					#diags for this particular procedure
	my @claimDiags = split(/\s*,\s*/, $page->field('claim_diags'));		#all diags for a claim
	#my @hcpcsCode = split(/\s*,\s*/, $page->field('hcpcs'));
	my @cptCodes = split(/\s*,\s*/, $page->field('procedure'));		#there will always be only one value in this array

	## run increment usage in intellicode
	if($command ne 'remove')
	{
		App::IntelliCode::incrementUsage($page, 'Cpt', \@cptCodes, $sessUser, $sessOrg);
		#App::IntelliCode::incrementUsage($page, 'Hcpcs', \@hcpcsCode, $sessUser, $sessOrg);
	}

	## figure out diag code pointers
	my @diagCodePointers = ();
	my $claimDiagCount = @claimDiags;
	foreach my $relDiag (@relDiags)
	{
		foreach my $claimDiagNum (1..$claimDiagCount)
		{
			if($relDiag eq $claimDiags[$claimDiagNum-1])
			{
				push(@diagCodePointers, $claimDiagNum);
			}
		}
	}

	## get short name for cpt code
	my $cptCode = $page->field('procedure');
	my $cptShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $cptCode);

	$page->schemaAction(
			'Invoice_Item', $command,
			item_id => $itemId || undef,
			parent_id => $invoiceId,
			item_type => defined $itemType ? $itemType : undef,
			code => $cptCode || undef,
			caption => $cptShortName->{name} || undef,
			modifier => $page->field('procmodifier') || undef,
			rel_diags => join(', ', @relDiags) || undef,
			unit_cost => $unitCost || undef,
			quantity => $page->field('procunits') || undef,
			extended_cost => $extCost || undef,
			balance => defined $balance ? $balance : undef,
			emergency => defined $emg ? $emg : undef,
			comments => $comments || undef,
			#reference => $page->field('reference') || undef,
			hcfa_service_place => $page->field('servplace') || undef,
			hcfa_service_type => $page->field('servtype') || 'NULL',
			service_begin_date => $page->field('service_begin_date') || undef,
			service_end_date => $page->field('service_end_date') || undef,
			data_text_a => join(', ', @diagCodePointers) || undef,
			_debug => 0
		);



	## UPDATE INVOICE TO WHICH ITEM BELONGS
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);

	my $totalItems = $invoice->{total_items};
	if($command eq 'add')
	{
		$totalItems = $invoice->{total_items} + 1;
	}

	my $allInvItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selInvoiceItems', $invoiceId);
	my $totalCostForInvoice = '';
	foreach my $item (@{$allInvItems})
	{
		$totalCostForInvoice += $item->{extended_cost};
	}

	my $invBalance = $totalCostForInvoice + $invoice->{total_adjust};
	$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $invoiceId || undef,
			total_items => defined $totalItems ? $totalItems : undef,
			total_cost => defined $totalCostForInvoice ? $totalCostForInvoice : undef,
			balance => defined $invBalance ? $invBalance : undef,
			_debug => 0
		);




	## ADD HISTORY ATTRIBUTE

	my $action = '';
	$action = 'Added' if $command eq 'add';
	$action = 'Updated' if $command eq 'update';
	my $itemNum = $page->param('item_seq') || $invoice->{total_items} + 1;

	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => "$action $cptCode",
			value_textB => $comments || undef,
			value_date => $todaysDate || undef,
			_debug => 0
	);

}

sub voidProcedure
{
	my ($self, $page, $command, $flags) = @_;

	my $sessUser = $page->session('user_id');
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $invoiceId = $page->param('invoice_id');
	my $itemId = $page->param('item_id');
	my $invItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId);

	my $voidItemType = App::Universal::INVOICEITEMTYPE_VOID;
	my $extCost = 0 - $invItem->{extended_cost};
	my $itemBalance = $extCost + $invItem->{total_adjust};
	my $emg = $invItem->{emergency};
	my $cptCode = $invItem->{code};
	my $voidItemId = $page->schemaAction(
			'Invoice_Item', 'add',
			parent_item_id => $itemId || undef,
			parent_id => $invoiceId,
			item_type => defined $voidItemType ? $voidItemType : undef,
			code => $cptCode || undef,
			caption => $invItem->{caption} || undef,
			modifier => $invItem->{modifier} || undef,
			rel_diags => $invItem->{rel_diags} || undef,
			unit_cost => $invItem->{unit_cost} || undef,
			quantity => $invItem->{quantity} || undef,
			extended_cost => defined $extCost ? $extCost : undef,
			balance => defined $itemBalance ? $itemBalance : undef,
			emergency => defined $emg ? $emg : undef,
			#comments => $comments || undef,
			hcfa_service_place => $invItem->{hcfa_service_place} || undef,
			hcfa_service_type => $invItem->{hcfa_service_type} || 'NULL',
			service_begin_date => $invItem->{service_begin_date} || undef,
			service_end_date => $invItem->{service_end_date} || undef,
			data_text_a => $invItem->{data_text_a} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Item', 'update',
			item_id => $itemId || undef,
			data_text_b => 'void',
			_debug => 0
		);


	## UPDATE INVOICE TO WHICH ITEM BELONGS

	my $allInvItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selInvoiceItems', $invoiceId);
	my $totalCostForInvoice = '';
	foreach my $item (@{$allInvItems})
	{
		$totalCostForInvoice += $item->{extended_cost};
	}

	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $invBalance = $totalCostForInvoice + $invoice->{total_adjust};
	my $totalItems = $invoice->{total_items} - 1;
	$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $invoiceId || undef,
			total_items => defined $totalItems ? $totalItems : undef,
			total_cost => defined $totalCostForInvoice ? $totalCostForInvoice : undef,
			balance => defined $invBalance ? $invBalance : undef,
			_debug => 0
		);



	## ADD HISTORY ATTRIBUTE
	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => "Voided $cptCode",
			#value_textB => $comments || undef,
			value_date => $todaysDate || undef,
			_debug => 0
	);
}

1;
