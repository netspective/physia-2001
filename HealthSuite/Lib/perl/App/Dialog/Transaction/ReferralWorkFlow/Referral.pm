##############################################################################
package App::Dialog::Transaction::ReferralWorkFlow::Referral;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Transaction;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Transaction::ReferralWorkFlow);

%RESOURCE_MAP = ('referral' => {heading => '$Command Service Request',
				_arl => ['org_id'],
				_arl_modify => ['trans_id'],
				_idSynonym => 'trans-' . App::Universal::TRANSTYPEPROC_REFERRAL()},
		);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize();
	#my $self = CGI::Dialog::new(@_, id => 'referral', heading => 'Add Referral');

###################################################################
#
#   just reminding myself of how the guarantor dialog is launched
#
#if ($page->field('party_name') && $page->field('rel_type') eq 'Self')
#	{
#		$relationship->invalidate($page, "'Relationship' should be other than 'Self' when the 'Responsible Party' is not blank");
#	}
#
#	elsif($page->field('party_name') eq ''  && $page->field('rel_type') ne 'Self')
#	{
#		#$relationship->invalidate($page, "'Responsible Party' is required when the 'Relationship' is other than 'Self'");
#
#		#If user left Responsible party blank the field level validation will ignore so catch error here
#		my $createPersonHref = qq{javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-guarantor',null,null,['_f_person_id'],['_f_party_name']);};
#		my $invMsg = qq{<a href="$createPersonHref">Create Responsible Party</a> };
#		$relationship->invalidate($page, $invMsg);
#	}
######################################################################################################






	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'addr_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'work_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'ins_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'parent_referral_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'case_item_id'),

		new CGI::Dialog::Subhead(heading => 'Patient Information', name => 'patient_info_heading'),
		new App::Dialog::Field::Person::ID(caption => 'Person/Patient ID',types => ['Patient'],	name => 'person_id', options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Subhead(heading => 'Insurance Information', name => 'insurance_heading'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Plan', name => 'plan'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Employer', name => 'employer'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Your Claim Number', name => 'claim_number'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Case Manager Name', name => 'case_mgr_name'),
		new CGI::Dialog::Field(type => 'phone', caption => 'Case Mgr Phone', name => 'case_mgr_phone'),

		new CGI::Dialog::Subhead(heading => 'Problem Information', name => 'problem_heading'),
		#new App::Dialog::Field::Diagnoses(caption => 'ICD Code', name => 'icd_code1', options => FLDFLAG_TRIM, size => 6),
		#new CGI::Dialog::Field(caption => 'CPT Codes', name => 'cpt_code1', findPopup => '/lookup/cpt', size => 6),

		new CGI::Dialog::Field(caption => 'ICD Code', name => 'icd_code1',findPopup => '/lookup/icd', options => FLDFLAG_TRIM, size => 6),
		new CGI::Dialog::Field(
						caption => 'ICD Description',
						name => 'icd_desc',
						findPopup => '/lookup/icd',
						type => 'memo',
						findPopupControlField => '_f_icd_code1'
					),
		new CGI::Dialog::Field(caption => 'Date Of Injury', name => 'trans_begin_stamp', type => 'date', pastOnly => 0, defaultValue => ''),
		new CGI::Dialog::Field(name => 'comments', caption => 'Comments', type => 'memo'),
		new CGI::Dialog::Subhead(heading => 'Submitter Information', name => 'submit_info'),
		new CGI::Dialog::Field(caption =>'Contact', name => 'contact_org'),
		new CGI::Dialog::Field(caption =>'Organization', name => 'org_name'),
		new App::Dialog::Field::Address(caption =>'Org Address', name => 'org_address'),
		new CGI::Dialog::MultiField(
			fields => [
				new CGI::Dialog::Field(caption => 'Phone', name => 'org_phone', type => 'phone'),
				new CGI::Dialog::Field(caption => 'Ext', name => 'org_phone_ext', size =>'4'),
			]),

		new CGI::Dialog::Subhead(heading => 'Referral Information', name => 'referral_heading'),
		new CGI::Dialog::MultiField(caption =>'Referring MD name',name => 'mdname',
									fields => [
										new CGI::Dialog::Field(type=> 'text', caption => 'MD First name', name => 'mdfirstname'),
										new CGI::Dialog::Field(type=> 'text', caption => 'Last name', name => 'mdlastname'),
				]),
		new CGI::Dialog::Field(caption =>'Referral Type ',
					name => 'referral_type',
					options => FLDFLAG_PREPENDBLANK,
					fKeyStmtMgr => $STMTMGR_TRANSACTION,
					fKeyStmt => 'selReferralServiceDesc',
					fKeyDisplayCol => 1,
					fKeyValueCol => 0),
		new CGI::Dialog::MultiField(caption =>'CPT/HCSPCS',
					fields => [
							new CGI::Dialog::Field(caption => 'CPT Codes', name => 'cpt_code1', findPopup => '/lookup/cpt', size => 6),
							new CGI::Dialog::Field(caption => 'CPT Codes', name => 'cpt_code2', findPopup => '/lookup/cpt', size => 6)
				]),
		new CGI::Dialog::Field(
						caption => 'CPT Description',
						name => 'cpt_desc',
						findPopup => '/lookup/cpt',
						type => 'memo',
						findPopupControlField => '_f_cpt_code1'
					),
		new CGI::Dialog::Field(
						caption => 'HCSPCS Description',
						name => 'hcspcs_desc',
						findPopup => '/lookup/cpt',
						type => 'memo',
						findPopupControlField => '_f_cpt_code2'
					),
		new CGI::Dialog::Field(caption =>'Comments on requested service', name => 'details', type => 'memo'),

		new CGI::Dialog::Field(caption =>'Date Of Request ', name => 'trans_end_stamp', type => 'date', pastOnly => 1),
		new CGI::Dialog::MultiField(name => 'coord_status',
			fields => [
					new App::Dialog::Field::Person::ID(caption => 'Intake Coordinator', name => 'intake_coordinator', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
					new CGI::Dialog::Field(caption => 'Status',
								name => 'status',
								options => FLDFLAG_REQUIRED,
								type => 'select',
								readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
								selOptions => " ;Assigned;Unassigned;Done",
								defaultValue => 'Assigned'),
				]),

	);

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions_add => [
							['View Summary', "/org/%param.org_id%/profile"],
							['Go to Service Request Work List', "/worklist/referral"],
							['Go to Referral Work List', "/worklist/referral/?user=physician"],
							['Go to Referral Form', "/org/%session.org_id%/dlg-add-trans-6010/%field.parent_referral_id%", 1],
							['Go to Menu', "/worklist/menu"],
							],
						nextActions_update => [
							['View Summary', "/person/%param.person_id%/profile"],
							['Go to Service Request Work List', "/worklist/referral", 1],
							['Go to Referral Work List', "/worklist/referral/?user=physician"],
							['Go to Referral Form', "/org/%session.org_id%/dlg-add-trans-6010/%param.trans_id%"],
							['Go to Menu', "/worklist/menu"],
							],
						cancelUrl => $self->{cancelUrl} || undef)

	);

}
 sub makeStateChanges
 {
       my ($self, $page, $command, $dlgFlags) = @_;

       $self->SUPER::makeStateChanges($page, $command, $dlgFlags);
       my  $otherPayer = $self->getField('other_payer_fields');

       $self->updateFieldFlags('other_payer_fields', FLDFLAG_INVISIBLE, 1);
       my $personSessionId = $page->session('person_id');
       $page->field('intake_coordinator',$personSessionId);

 }

 sub getSupplementaryHtml
 {
 	return ('special', '');
 }

 sub handle_page_supplType_special
 {
 	my ($self, $page, $command, $dlgHtml) = @_;
	my $consult = $page->field('person_id');
      	my $ServiceData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selServiceRequestData', $consult);

	if (($ServiceData eq '' && $command eq 'add') || $command ne 'add' )
	{
 		$page->addContent(qq{
 			<TABLE ALIGN="Center">
 				<TR>
 					<TD>$dlgHtml</TD>
 				</TR>
 			</TABLE>
 		});
	}

	elsif ($ServiceData ne '')
	{
		$page->addContent(qq{
 			<TABLE ALIGN="Center">
 				<TR VALIGN=TOP>
 					<TD COLSPAN=2 ALIGN="Center">
 						<b style="font-size:15pt; color=Darkred; font-family:Tahoma">Copy Of An Existing Service Request</b>
 					</TD>
 				</TR>
 			<TR><TD COLSPAN=1>&nbsp;</TD></TR>
 				<TR>
 					<TD>$dlgHtml</TD>
 				</TR>
 			</TABLE>
 		});
	}
 }


 sub customValidate
 {
 	my ($self, $page) = @_;

	my $coordId = $self->getField('coord_status')->{fields}->[0];
	my $stausId = $self->getField('coord_status')->{fields}->[1];
	my $coordinator = $page->field('intake_coordinator');
	my $status = $page->field('status');
 	if ($coordinator ne '' and $status eq 'UnAssigned')
 	{
 		$stausId->invalidate($page, "Status should be other than 'UnAssigned' if the Intake Coordinator field isn't blank");
 	}

 	if ($coordinator eq '' and $status ne 'Unassigned')
  	{
  		$coordId->invalidate($page, "Coordinator field cannot be blank if the 'Status' is $status");
 	}
 }


 sub populateData_add
 {
       my ($self, $page, $command, $activeExecMode, $flags) = @_;

       return unless ($flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL);

       my $personSessionId = $page->session('person_id');
       $page->field('intake_coordinator',$personSessionId);
       my $personId = $page->field('person_id');

       my $ServiceData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selServiceRequestData', $personId);

       if ($ServiceData ne '' && $command eq 'add')
       {
		my $icdCodes = $ServiceData->{'code'};
		my $cptCodes = $ServiceData->{'related_data'};
		my @icd = split(', ', $icdCodes);
		$page->field('icd_code1', $icd[0]);
		#$page->field('icd_code2', $icd[1]);
		my @cpt = split(', ', $cptCodes);
		$page->field('cpt_code1', $cpt[0]);
		$page->field('cpt_code2', $cpt[1]);

		$page->field('trans_end_stamp', $ServiceData->{'trans_end_stamp'});
		$page->field('trans_begin_stamp', $ServiceData->{'trans_begin_stamp'});
		$page->field('intake_coordinator', $personSessionId);
		#$page->field('status', $ServiceData->{'trans_substatus_reason'});
		$page->field('referral_type', $ServiceData->{'trans_expire_reason'});
		$page->field('contact_org', $ServiceData->{'modifier'});
		$page->field('mdfirstname', $ServiceData->{'auth_by'});
		$page->field('mdlastname', $ServiceData->{'auth_ref'});
		$page->field('icd_desc', $ServiceData->{'data_text_a'});
		$page->field('cpt_desc', $ServiceData->{'data_text_b'});
		$page->field('hcspcs_desc', $ServiceData->{'data_text_c'});

		my $parentTransId = $ServiceData->{'trans_id'};
		my $insAndClaimData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $parentTransId, 'Referral Insurance');

		$page->field('plan', $insAndClaimData->{'name_sort'});
		$page->field('employer', $insAndClaimData->{'value_text'});
		$page->field('claim_number', $insAndClaimData->{'value_textb'});

		my $caseManagerData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $parentTransId, 'Case Manager Info');
		$page->field('case_mgr_name', $caseManagerData->{'value_text'});
		$page->field('case_mgr_phone', $caseManagerData->{'value_textb'});

		my $orgContactData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $parentTransId, 'Work');
		$page->field('org_phone', $orgContactData->{'value_text'});
		$page->field('org_phone_ext', $orgContactData->{'value_textB'});
		$page->field('org_name', $orgContactData->{'name_sort'});

		my $orgContactAddress = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransAddressByName', $parentTransId, 'Mailing');
		$page->field('addr_line1', $orgContactAddress->{'line1'});
		$page->field('addr_line2', $orgContactAddress->{'line2'});
		$page->field('addr_city', $orgContactAddress->{'city'});
		$page->field('addr_state', $orgContactAddress->{'state'});
		$page->field('addr_zip', $orgContactAddress->{'zip'});
	}
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	# Populating the fields while updating the dialog
	return unless ($flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL);
	my $referralData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByTransId', $page->param('trans_id'));

	my $icdCodes = $referralData->{'code'};
	my $cptCodes = $referralData->{'related_data'};
	my @icd = split(', ', $icdCodes);
	$page->field('icd_code1', $icd[0]);
	#$page->field('icd_code2', $icd[1]);
	my @cpt = split(', ', $cptCodes);
	$page->field('cpt_code1', $cpt[0]);
	$page->field('cpt_code2', $cpt[1]);

	$page->field('person_id', $referralData->{'consult_id'});
	$page->field('trans_end_stamp', $referralData->{'trans_end_stamp'});
	$page->field('trans_begin_stamp', $referralData->{'trans_begin_stamp'});
	$page->field('intake_coordinator', $referralData->{'trans_subtype'});
	$page->field('status', $referralData->{'trans_substatus_reason'});
	$page->field('referral_type', $referralData->{'trans_expire_reason'});
	$page->field('icd_desc', $referralData->{'data_text_a'});
	$page->field('contact_org', $referralData->{'modifier'});
	$page->field('comments', $referralData->{'display_summary'});
	$page->field('details', $referralData->{'detail'});
	$page->field('cpt_desc', $referralData->{'data_text_b'});
	$page->field('hcspcs_desc', $referralData->{'data_text_c'});
	$page->field('mdfirstname', $referralData->{'auth_by'});
	$page->field('mdlastname', $referralData->{'auth_ref'});

	my $insAndClaimData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $page->param('trans_id'), 'Referral Insurance');

	$page->field('ins_item_id', $insAndClaimData->{'item_id'});
	$page->field('plan', $insAndClaimData->{'name_sort'});
	$page->field('employer', $insAndClaimData->{'value_text'});
	$page->field('claim_number', $insAndClaimData->{'value_textb'});

	my $caseManagerData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $page->param('trans_id'), 'Case Manager Info');

	$page->field('case_mgr_name', $caseManagerData->{'value_text'});
	$page->field('case_mgr_phone', $caseManagerData->{'value_textb'});
	$page->field('case_item_id', $caseManagerData->{'item_id'});

	my $orgContactData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $page->param('trans_id'), 'Work');
	$page->field('org_phone', $orgContactData->{'value_text'});
	$page->field('org_phone_ext', $orgContactData->{'value_textb'});
	$page->field('org_name', $orgContactData->{'name_sort'});
	$page->field('work_item_id', $orgContactData->{'item_id'});

	my $orgContactAddress = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransAddressByName', $page->param('trans_id'), 'Mailing');
	$page->field('addr_item_id', $orgContactAddress->{'item_id'});
	$page->field('addr_line1', $orgContactAddress->{'line1'});
	$page->field('addr_line2', $orgContactAddress->{'line2'});
	$page->field('addr_city', $orgContactAddress->{'city'});
	$page->field('addr_state', $orgContactAddress->{'state'});
	$page->field('addr_zip', $orgContactAddress->{'zip'});
}

sub populateData_remove
{
	populateData_update(@_);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $transaction = $self->{transaction};
	my $transacId = $page->param('_trne_trans_id') || $page->param('trans_id');
	my $transOwnerType = App::Universal::ENTITYTYPE_ORG;
	my $icd1 = $page->field('icd_code1');
	my $icd2 = $page->field('icd_code2');
	my $cpt1 = $page->field('cpt_code1');
	my $cpt2 = $page->field('cpt_code2');
	my @cpt = ();
	my @icd = ();

	push(@icd, $icd1) if $icd1 ne '';
	push(@icd, $icd2) if $icd2 ne '';
	my $dataTextB = join (', ', @icd);
	push(@cpt, $cpt1) if $cpt1 ne '';
	push(@cpt, $cpt2) if $cpt2 ne '';;
	my $dataTextC = join (', ', @cpt);
	my $orgId = $page->param('org_id');
	my $ownerOrgId = $page->session('org_internal_id');
	my $orgInternalId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrgId, $orgId);
	my $transType = App::Universal::TRANSTYPEPROC_REFERRAL;

	my $transId = $page->schemaAction(
				'Transaction',
				$command,
				trans_owner_type => defined $transOwnerType ? $transOwnerType : undef,
				trans_owner_id => $orgInternalId,
				trans_id => $transacId || undef,
				trans_type => $transType || undef,
				trans_begin_stamp => $page->field('trans_begin_stamp') || undef,
				trans_end_stamp => $page->field('trans_end_stamp') || undef,
				display_summary => $page->field('comments') || undef,
				trans_substatus_reason => $page->field('request_service') || undef,
				trans_status_reason => $page->field('payer') || undef,
				provider_id => $page->field('provider_id') || undef,
				care_provider_id => $page->field('referral_id') || undef,
				trans_expire_reason => $page->field('referral_type') || undef,
				data_text_a=>  $page->field('icd_desc') || undef,
				data_text_b =>  $page->field('cpt_desc') || undef,
				data_text_c => $page->field('hcspcs_desc') || undef,
				auth_by =>  $page->field('mdfirstname') || undef,
				auth_ref => $page->field('mdlastname') || undef,
				consult_id => $page->field('person_id') || undef,
				detail => $page->field('details') || undef,
				caption => $page->field('int_ext_flag') || undef,
				initiator_id => $orgId || undef,
				trans_subtype => $page->field('intake_coordinator') || undef,
				trans_substatus_reason => $page->field('status') || undef,
				modifier               => $page->field('contact_org') || undef,
				code => $dataTextB || undef,
				related_data =>  $dataTextC || undef,
				_debug => 0
	);

	$page->field('parent_referral_id', $transId);

	my $parentTransId = $command eq 'add' ? $transId : $transacId;

	$page->schemaAction(
			'Trans_Attribute',
			$command,
			parent_id =>   $parentTransId,
			item_name =>   'Referral Insurance',
			item_id =>     $page->field('ins_item_id') || undef,
			value_type =>  App::Universal::ATTRTYPE_TEXT,
			name_sort =>   $page->field('plan') || undef,
			value_text =>  $page->field('employer') || undef,
			value_textB => $page->field('claim_number') || undef,
			_debug => 0
	);


	my $caseCommand = $page->field('case_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Trans_Attribute',
			$caseCommand,
			parent_id =>   $parentTransId,
			item_name =>   'Case Manager Info',
			item_id =>     $page->field('case_item_id') || undef,
			value_type =>  App::Universal::ATTRTYPE_TEXT,
			value_text =>  $page->field('case_mgr_name') || undef,
			value_textB => $page->field('case_mgr_phone') || undef,
			_debug => 0
	);

	my $workCommand = $page->field('work_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Trans_Attribute', $workCommand,
			parent_id => $parentTransId,
			item_name => 'Work',
			item_id => $page->field('work_item_id') || undef,
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $page->field('org_phone') || undef,
			value_textB => $page->field('org_phone_ext') || undef,
			name_sort   => $page->field('org_name') || undef,
			_debug => 0
		);

	my $addrCommand = $page->field('addr_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Trans_Address', $addrCommand,
			parent_id => $parentTransId,
			address_name => 'Mailing',
			item_id => $page->field('addr_item_id') || undef,
			line1 => $page->field('addr_line1'),
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city'),
			state => $page->field('addr_state'),
			zip => $page->field('addr_zip'),
			_debug => 0
	) if $page->field('addr_line1') ne '';


	if ($command eq 'update')
	{
		 $STMTMGR_TRANSACTION->execute($page, STMTMGRFLAG_NONE, 'selUpdateTransByParentId', $page->field('claim_number'), $page->field('person_id'), $transacId);
		# $self->handlePostExecute($page, $command, $flags);
		#$page->param('_dialogreturnurl', "/worklist/referral");
	}


	if ($command eq 'remove')
	{
		my $childTransId = $STMTMGR_TRANSACTION->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selByParentTransId',$transacId);

		foreach my $child (@{$childTransId})
		{
			my $referralId = $child->{'trans_id'};
			$STMTMGR_TRANSACTION->execute($page, STMTMGRFLAG_NONE, 'selRemoveChildReferralAttr', $referralId);
		}

		$STMTMGR_TRANSACTION->execute($page, STMTMGRFLAG_NONE, 'selRemoveChildReferrals', $transacId);
	}

	$self->handlePostExecute($page, $command, $flags);

	return "\u$command completed.";
}

1;
