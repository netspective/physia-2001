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
use App::Statements::Scheduling;
use App::IntelliCode;
use Carp;
use CGI::Dialog;
use App::Dialog::OnHold;
use CGI::Validator::Field;
use App::Universal;
use App::Utilities::Invoice;
use App::Dialog::Field::Invoice;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'procedure' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'procedures', heading => '$Command Procedure/Lab');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'item_type'),
		new CGI::Dialog::Field(type => 'hidden', name => 'claim_diags'),
		new CGI::Dialog::Field(type => 'hidden', name => 'data_num_a'),	#used to indicate if item is FFS (null if it isn't)

		new CGI::Dialog::Field(type => 'hidden', name => 'code_type'),
		new CGI::Dialog::Field(type => 'hidden', name => 'use_fee'),
		new CGI::Dialog::Field(type => 'hidden', name => 'fee_schedules_item_id'),	#for storing and updating fee schedules as attribute
		new CGI::Dialog::Field(type => 'hidden', name => 'fee_schedules_catalog_ids'),	#for storing the internal catalog ids of the fee schedules entered in


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
		#new App::Dialog::Field::ServicePlaceType(caption => 'Service Place'),
		#new CGI::Dialog::Field(
		#		caption => 'Service Place',
		#		name => "servplace",
		#		size => 6, options => FLDFLAG_REQUIRED,
		#		#defaultValue => 11,
		#		findPopup => '/lookup/serviceplace'),
		new CGI::Dialog::Field(type=>'hidden', name => "servtype"),

		new App::Dialog::Field::ProcedureLine(name=>'cptModfField', caption => 'CPT / Modf'),
		new App::Dialog::Field::DiagnosesCheckbox(caption => 'ICD-9 Codes', options => FLDFLAG_REQUIRED, name => 'procdiags'),

		new CGI::Dialog::Field(caption => 'Fee Schedule(s)',
			name => 'fee_schedules',
			size => 24,
			findPopupAppendValue => ',',
			findPopup => '/lookup/catalog',
			#options => FLDFLAG_PERSIST,
		),
		new App::Dialog::Field::ProcedureChargeUnits(caption => 'Charge/Units',
			name => 'proc_charge_fields'
		),

		new CGI::Dialog::MultiField(caption => 'Units', name => 'units_emg_fields',
			fields => [
				new CGI::Dialog::Field(caption => 'Units', name => 'procunits', type => 'integer', size => 6, minValue => 1, value => 1, options => FLDFLAG_REQUIRED),
				new CGI::Dialog::Field(caption => 'EMG', name => 'emg', type => 'bool', style => 'check'),
			]),

		new CGI::Dialog::Field(caption => 'Unit Cost',
			name => 'alt_cost',
			#type => 'select',
			#options => FLDFLAG_REQUIRED,
		),

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
								#['Submit Claim for Review', "/invoice/%param.invoice_id%/review"],
								['Submit Claim for Transfer', "/invoice/%param.invoice_id%/submit"],
								['Go to Work List', "/worklist"],
								],
						cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $procItem = App::Universal::INVOICEITEMTYPE_SERVICE;
	my $labItem = App::Universal::INVOICEITEMTYPE_LAB;
	my $invoiceId = $page->param('invoice_id');

	$self->setFieldFlags('alt_cost', FLDFLAG_INVISIBLE, 1);
	$self->setFieldFlags('units_emg_fields', FLDFLAG_INVISIBLE, 1);

	if($command eq 'add')
	{
		my $serviceInfo = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceProcedureItems', $invoiceId, $procItem, $labItem);

		my $numOfHashes = scalar (@{$serviceInfo});
		my $idx = $numOfHashes - 1;

		if($numOfHashes > 0)
		{
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
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	$page->field('proccharge', $page->field('alt_cost'));
	$page->field('', $page->getDate());
	my $sqlStampFmt = $page->defaultSqlStampFormat();
	my $itemId = $page->param('item_id');

	$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selProcedure', $itemId);
	$page->field('servtype','');
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

	my $feeSchedules = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Fee Schedules');
	$page->field('fee_schedules', $feeSchedules->{value_textb});
	$page->field('fee_schedules_item_id', $feeSchedules->{item_id});
}

sub customValidate
{
	my ($self, $page) = @_;

	my $servicetype = $page->field('servtype');
	my $cptCode = $page->field('procedure');
	my $modCode = $page->field('procmodifier');
	my $use_fee = $page->field('use_fee');

	my @fsIntIds = ();
	my @feeSchedules = split(/\s*,\s*/, $page->field('fee_schedules'));
	foreach (@feeSchedules)
	{
		my $catalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInternalCatalogIdByIdType',
					$page->session('org_internal_id'), $_, App::Universal::CATALOGTYPE_FEESCHEDULE);

		push(@fsIntIds, $catalog->{internal_catalog_id});
		#$page->addError("FS Names: $_");
		#$page->addError("FS Ids: $catalog->{internal_catalog_id}");
	}

	$page->field('fee_schedules_catalog_ids', join(',', @fsIntIds));

	my $svc_type = App::IntelliCode::getSvcType($page, $cptCode, $modCode, \@fsIntIds);
	my $count_type = scalar(@$svc_type);
	my $count=0;
	unless ($servicetype)
	{
		if ($count_type==1||$use_fee ne '')
		{
			foreach(@$svc_type)
			{
				#Store code_type and service type in hidden fields
				if($count_type==1||$use_fee eq $count)
				{
					$page->field("servtype",$_->[1]);
					$page->field('code_type',$_->[3]);
				}
			 	$count++
			}
		}
		elsif ($count_type>1)
		{
			my $html_svc = $self->getMultiSvcTypesHtml($page,$cptCode, $svc_type);
			#Use the service place to send error message because service type field is hidden
			my $type = $self->getField('cptModfField')->{fields}->[0];
			$type->invalidate($page, $html_svc);
		}
		else
		{
			my $type = $self->getField('cptModfField')->{fields}->[0];
			$type->invalidate($page,"Unable to find Code '$cptCode' in fee schedule(s) " . join ",",@fsIntIds);
		}
	}
	#GET ITEM COST FROM FEE SCHEDULE
	$count=0;
	if (! $page->field('proccharge') && ! $page->field('alt_cost'))
	{
		my $unitCostField = $self->getField('proc_charge_fields')->{fields}->[0];
		my $fsResults = App::IntelliCode::getItemCost($page, $cptCode, $modCode, \@fsIntIds);
		my $resultCount = scalar(@$fsResults);
		if($resultCount == 0)
		{
			$unitCostField->invalidate($page, 'No unit cost was found');
		}
		elsif($resultCount == 1 || $use_fee ne '')
		{
			foreach (@$fsResults)
			{
				if ($count_type==1 || $use_fee eq $count)
				{
					my $unitCost = $_->[1];
					$page->field('proccharge', $unitCost);

					my $isFfs = $_->[2];
					$page->field('data_num_a', $isFfs);
				}
				$count++;
			}

		}
		else
		{
			my @costs = ();
			foreach (@$fsResults)
			{
				push(@costs, $_->[1]);
			}

			$self->updateFieldFlags('alt_cost', FLDFLAG_INVISIBLE, 0);
			$self->updateFieldFlags('units_emg_fields', FLDFLAG_INVISIBLE, 0);
			$self->updateFieldFlags('proc_charge_fields', FLDFLAG_INVISIBLE, 1);

			#my $costList = join(';', @costs);
			#$self->getField('alt_cost')->{selOptions} = "$costList";

			my $field = $self->getField('alt_cost');

			#my $html = $self->getMultiPricesHtml($page, $fsResults);
			#$field->invalidate($page, $html);
		}
	}

	explosionCodeValidate($self, $page);
}

sub explosionCodeValidate
{
	my ($self, $page) = @_;

	my $sessOrgIntId = $page->session('org_internal_id');

	#VALIDATION OF FEE SCHED RESULTS FOR CHILDREN OF EXPLOSION CODES

	my $cptCode = $page->field('procedure');
	my $miscProcChildren = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selMiscProcChildren', $sessOrgIntId, $cptCode);
	if($miscProcChildren->[0]->{code})
	{
		my $servBeginDate = $page->field('service_begin_date');
		my @listFeeSchedules = ($page->field('fee_schedules_catalog_ids'));

		my $cptModfField = $self->getField('cptModfField')->{fields}->[0];

		foreach my $child (@{$miscProcChildren})
		{
			my $childCode = $child->{code};
			my $modifier = $child->{modifier};
			my $fs_entry = App::IntelliCode::getFSEntry($page, $childCode, $modifier || undef,$servBeginDate,\@listFeeSchedules);
			my $count_type = scalar(@$fs_entry);
			if ($count_type == 0)
			{
				$cptModfField->invalidate($page,"Unable to find Code '$childCode' in fee schedule(s) " . join ",",@listFeeSchedules);
			}
			elsif ($count_type > 1)
			{
				$cptModfField->invalidate($page,"Procedure found in multiple fee schedules.");
			}
			elsif(length($fs_entry->[0]->[$INTELLICODE_FS_SERV_TYPE]) < 1)
			{
				$cptModfField->invalidate($page,"Check that Service Type is set for Fee Schedule Entry '$childCode' in fee schedule $fs_entry->[0]->[$INTELLICODE_FS_ID_NUMERIC]" );
			}
		}
	}
}

sub getMultiSvcTypesHtml
{
	my ($self, $page,$code,  $fsResults) = @_;

	my $html = qq{Multiple fee schedule have code '$code'.  Please select a fee schedule to use for this item.};
	my $count=0;
	foreach (@$fsResults)
	{
		my $svc_type=$_->[1];
		#my $svc_name=$_->[4];
		#Use the above line if you want to see the fee schedule name instead of the fee schedule number
		my $svc_name=$_->[0];
		$html .= qq{
			<input onClick="document.dialog._f_use_fee.value=this.value"
				type=radio name='_f_multi_svc_type' value=$count>$svc_name
		};
		$count++;
	}

	return $html;
}

sub getMultiPricesHtml
{
	my ($self, $page, $fsResults) = @_;

	my $html = qq{Multiple prices found.  Please select a price for this item.};

	foreach (@$fsResults)
	{
		my $cost = sprintf("%.2f", $_->[1]);
		$html .= qq{
			<input onClick="document.dialog._f_alt_cost.value=this.value"
				type=radio name='_f_multi_price' value=$cost>\$$cost
		};
	}

	return $html;
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $mainTransId = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInvoiceMainTransById', $invoiceId);
	my $mainTransData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransCreateClaim', $mainTransId);

	#if cpt is a misc procedure code, get children and create invoice item for each child
	my $miscProcChildren = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selMiscProcChildren', $page->session('org_internal_id'), $page->field('procedure'));
	if($miscProcChildren->[0]->{code})
	{
		createExplosionItems($self, $page, $command, $mainTransData, $miscProcChildren);
	}
	else
	{
		handleProcedure($self, $page, $command, $flags, $mainTransData);
	}

	$self->handlePostExecute($page, $command, $flags);
}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $mainTransId = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInvoiceMainTransById', $invoiceId);
	my $mainTransData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransCreateClaim', $mainTransId);

	handleProcedure($self, $page, $command, $flags, $mainTransData);
	$self->handlePostExecute($page, $command, $flags);
}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	voidInvoiceItem($page, $page->param('item_id'));
	$page->redirect("/invoice/$invoiceId/summary");
}

sub handleProcedure
{
	my ($self, $page, $command, $flags, $mainTransData) = @_;

	my $sessOrgIntId = $page->session('org_internal_id');
	my $sessUser = $page->session('user_id');
	my $invoiceId = $page->param('invoice_id');
	my $itemId = $page->param('item_id');
	my $codeType = $page->field('code_type');

	my $itemType = App::Universal::INVOICEITEMTYPE_SERVICE;
	if($page->field('lab_indicator'))
	{
		$itemType = App::Universal::INVOICEITEMTYPE_LAB;
	}

	my $comments = $page->field('comments');
	my $emg = $page->field('emg') == 1 ? 1 : 0;

	my $unitCost = $page->field('proccharge') || $page->field('alt_cost');
	my $extCost = $unitCost * $page->field('procunits');

	my @relDiags = $page->field('procdiags');					#diags for this particular procedure
	my @claimDiags = split(/\s*,\s*/, $page->field('claim_diags'));		#all diags for a claim
	#my @hcpcsCode = split(/\s*,\s*/, $page->field('hcpcs'));
	my @cptCodes = split(/\s*,\s*/, $page->field('procedure'));		#there will always be only one value in this array

	## run increment usage in intellicode
	#App::IntelliCode::incrementUsage($page, 'Cpt', \@cptCodes, $sessUser, $sessOrgIntId);
	#App::IntelliCode::incrementUsage($page, 'Hcpcs', \@hcpcsCode, $sessUser, $sessOrgIntId);

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
	my $cptShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $cptCodes[0]);
	my $hcpcsShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericHCPCSCode', $cptCodes[0]);
	my $epsdtShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericEPSDTCode', $cptCodes[0]);
	my $codeShortName = $cptShortName->{name} || $hcpcsShortName->{name} || $epsdtShortName->{name};

	#get service place based on service facility, then convert code to its id
	my $servPlace = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $mainTransData->{service_facility_id}, 'HCFA Service Place');
	my $servPlaceId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServicePlaceByAbbr', $servPlace->{value_text});

	#convert service type code to its id
	my $servType = $page->field('servtype');
	my $servTypeId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServiceTypeByAbbr', $servType);

	$page->schemaAction(
			'Invoice_Item', $command,
			item_id => $itemId || undef,
			parent_id => $invoiceId,
			item_type => defined $itemType ? $itemType : undef,
			code => $cptCodes[0] || undef,
			code_type => $codeType || undef,
			caption => $codeShortName || undef,
			modifier => $page->field('procmodifier') || undef,
			rel_diags => join(', ', @relDiags) || undef,
			unit_cost => $unitCost || undef,
			quantity => $page->field('procunits') || undef,
			extended_cost => $extCost || undef,
			emergency => defined $emg ? $emg : undef,
			comments => $comments || undef,
			hcfa_service_place => defined $servPlaceId ? $servPlaceId : undef,
			hcfa_service_type => defined $servTypeId ? $servTypeId : undef,
			service_begin_date => $page->field('service_begin_date') || undef,
			service_end_date => $page->field('service_end_date') || undef,
			data_text_a => join(', ', @diagCodePointers) || undef,
			data_num_a => $page->field('data_num_a') || undef,
			_debug => 0
		);


	## ADD HISTORY ITEM
	my $action;
	$action = 'Added' if $command eq 'add';
	$action = 'Updated' if $command eq 'update';
	addHistoryItem($page, $invoiceId, value_text => "$action $cptCodes[0]", value_textB => $comments || undef);


	## UPDATE FEE SCHEDULES ATTRIBUTE
	if(my $feeSchedItemId = $page->field('fee_schedules_item_id'))
	{
		my $activeCatalogs = uc($page->field('fee_schedules_catalog_ids'));
		my $defaultCatalogs = uc($page->field('fee_schedules'));
		$page->schemaAction(
				'Invoice_Attribute', 'update',
				item_id => $feeSchedItemId,
				value_text => $activeCatalogs || undef,
				value_textB => $defaultCatalogs || undef,
				_debug => 0
		);
	}
}

sub createExplosionItems
{
	my ($self, $page, $command, $mainTransData, $miscProcChildren) = @_;
	my $invoiceId = $page->param('invoice_id');

	my $svcPlaceCode = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $mainTransData->{service_facility_id}, 'HCFA Service Place');
	my $servPlaceId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServicePlaceByAbbr', $svcPlaceCode->{value_text});
	my $explCode = $page->field('procedure');
	my $servBeginDate = $page->field('service_begin_date');
	my $servEndDate = $page->field('service_end_date');
	my $quantity = $page->field('procunits');
	my $comments = $page->field('comments');
	my $emg = $page->field('emg') == 1 ? 1 : 0;
	my @listFeeSchedules = ($page->field('fee_schedules_catalog_ids'));

	#icd info
	my @relDiags = $page->field('procdiags');					#diags for this particular procedure
	my @claimDiags = split(/\s*,\s*/, $page->field('claim_diags'));		#all diags for a claim
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
	#---------

	my $cptCode;
	my $cptShortName;
	my $hcpcsShortName;
	my $epsdtShortName;
	my $codeShortName;
	my $modifier;
	foreach my $child (@{$miscProcChildren})
	{
		$cptCode = $child->{code};
		$modifier = $child->{modifier};
		$cptShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $cptCode);
		$hcpcsShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericHCPCSCode', $cptCode);
		$epsdtShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericEPSDTCode', $cptCode);
		$codeShortName = $cptShortName->{name} || $hcpcsShortName->{name} || $epsdtShortName->{name};

		my $fs_entry = App::IntelliCode::getFSEntry($page, $cptCode, $modifier || undef,$servBeginDate,\@listFeeSchedules);
		#my $use_fee;
		#my $count = 0;
		my $count_type = scalar(@$fs_entry);
		foreach(@$fs_entry)
		{
			my $servType = $_->[$INTELLICODE_FS_SERV_TYPE];
			my $codeType = $_->[$INTELLICODE_FS_CODE_TYPE];
			my $unitCost = $_->[$INTELLICODE_FS_COST];
			my $ffsFlag = $_->[$INTELLICODE_FS_FFS_CAP];
			my $servTypeId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServiceTypeByAbbr', $servType);

			my $extCost = $unitCost * $quantity;
			$page->schemaAction('Invoice_Item', $command,
				#item_id => $page->param("_f_proc_$line\_item_id") || undef,
				parent_id => $invoiceId,
				service_begin_date => $servBeginDate || undef,							#default for service start date is today
				service_end_date => $servEndDate || undef,								#default for service end date is today
				hcfa_service_place => defined $servPlaceId ? $servPlaceId : undef,			#
				hcfa_service_type => defined $servTypeId ? $servTypeId : undef,			#default for service type is 2 for consultation
				modifier => $modifier || undef,
				quantity => $quantity || undef,
				emergency => defined $emg ? $emg : undef,								#default for emergency is 0 or 1
				item_type => App::Universal::INVOICEITEMTYPE_SERVICE || undef,			#default for item type is service
				code => $cptCode || undef,
				code_type => $codeType || undef,
				caption => $codeShortName || undef,
				comments => $comments || undef,
				unit_cost => $unitCost || undef,
				extended_cost => $extCost || undef,
				rel_diags => join(', ', @relDiags) || undef,									#the actual icd (diag) codes
				parent_code => $explCode || undef,										#store explosion code
				data_text_a => join(', ', @diagCodePointers) || undef,						#the diag code pointers
				data_text_c => 'explosion',												#indicates this procedure comes from an explosion (misc) code
				data_num_a => $ffsFlag || undef,										#flag indicating if item is ffs
			);
		}

		## ADD HISTORY ITEM
		my $action;
		$action = 'Added' if $command eq 'add';
		$action = 'Updated' if $command eq 'update';
		addHistoryItem($page, $invoiceId, value_text => "$action $cptCode (child of explosion code $explCode)", value_textB => $comments || undef);
	}

	## UPDATE FEE SCHEDULES ATTRIBUTE
	if(my $feeSchedItemId = $page->field('fee_schedules_item_id'))
	{
		$page->schemaAction(
				'Invoice_Attribute', 'update',
				item_id => $feeSchedItemId,
				value_text => $page->field('fee_schedules_catalog_ids') || undef,
				value_textB => $page->field('fee_schedules') || undef,
				_debug => 0
		);
	}
}

1;
