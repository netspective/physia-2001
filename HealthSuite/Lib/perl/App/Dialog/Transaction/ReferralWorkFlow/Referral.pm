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
use App::Statements::IntelliCode;

use CGI::ImageManager;
use App::Statements::Catalog;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Transaction::ReferralWorkFlow);

%RESOURCE_MAP = ('referral' => {heading => '$Command Service Request',
				_arl => ['org_id'],
				_arl_modify => ['trans_id'],
				_idSynonym => 'trans-' . App::Universal::TRANSTYPEPROC_REFERRAL()},
		);


use constant MAXROWS => 15;

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize();
	my @request=();
	my $sqlStmt = qq{
		select distinct serv_category,name
		from REF_SERVICE_CATEGORY
		order by  name
		};	
	my $maxrows=MAXROWS;
	for (my $loop=0;$loop<MAXROWS;$loop++)
	{
		my $next=$loop+1;
		push(@request,new CGI::Dialog::Field::Duration(caption=>'Date From/To',name=>"date_proc$loop"));
		push(@request,new CGI::Dialog::MultiField(caption=>'Code/Modf',name=>"code_mod_desc$loop",
					fields=>[
						new CGI::Dialog::Field(caption=>'Code', type=>'text',size=>9,name=>"code$loop",findPopup => '/lookup/cpt', secondaryFindField => "_f_description$loop"
							#onChangeJS=>"setRequestStyle($next,'block');"
							),
						new CGI::Dialog::Field(caption=>'Modf',type=>'text',size=>5,name=>"modf$loop"),
						],
						));
		push(@request,new CGI::Dialog::Field(caption=>'Description', type=>'memo',name=>"description$loop",rows=>2,cols=>45));
		push(@request,new CGI::Dialog::MultiField(caption=>'Units/Charge',name=>"unit_charge$loop",
					fields=>[
						new CGI::Dialog::Field(caption=>'Units',type=>'integer',size=>5,name=>"unit$loop"),
						new CGI::Dialog::Field(caption=>'Charge',type=>'currency',size=>9,name=>"charge$loop"),
						]
						));
		push(@request,new CGI::Dialog::Field(name=>"comment$loop", caption=>'Comments',type=>'text',size=>55,
				postHtml=>qq{<A HREF = javascript:setRequestStyle($next,'block');>$IMAGETAGS{'icons/arrow-down-blue'}</A>
						<BR> </BR>}
				)

				);
		push(@request,new CGI::Dialog::Field(name=>"procedure_id$loop", type=>'hidden'));
	}



	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'addr_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'work_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'ins_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'parent_referral_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'case_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'ins_type_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'adjust_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'group_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'custom_item_id'),

		new CGI::Dialog::Subhead(heading => 'Patient Information', name => 'patient_info_heading'),
		new App::Dialog::Field::Person::ID(caption => 'Person/Patient ID',types => ['Patient'],	name => 'person_id', options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Subhead(heading => 'Insurance Information', name => 'insurance_heading'),
		new CGI::Dialog::Field(
										name => 'ins_type',
										caption => 'Insurance Type',
										selOptions => "Workers Comp;Group Health",
										type => 'select',
										style => 'radio',
										choiceDelim =>';'
										),
		new CGI::Dialog::Field(type=> 'text', caption => 'Client', name => 'ins_client'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Plan', name => 'plan'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Employer', name => 'employer'),

		new CGI::Dialog::Subhead(heading => 'Workers Comp Insurance Info', name => 'insurance_work_heading'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Claim Number', name => 'claim_number'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Case Manager Name', name => 'case_mgr_name'),
		new CGI::Dialog::Field(type => 'phone', caption => 'Case Mgr Phone', name => 'case_mgr_phone'),
		new CGI::Dialog::Field(type => 'text', caption => 'Adjuster Name', name => 'adjuster_name'),
		new CGI::Dialog::Field(type => 'phone', caption => 'Adjuster Phone', name => 'adjuster_phone'),

		new CGI::Dialog::Subhead(heading => 'Group/HMO/PPO Info', name => 'group_info_heading'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Member ID', name => 'member_id'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Group No', name => 'group_num'),
		new CGI::Dialog::Field(type=> 'text', caption => 'Policy No', name => 'policy_num'),
		new CGI::Dialog::Field(type=> 'phone', caption => 'Customer Service Phone', name => 'customer_service_ph'),

		new CGI::Dialog::Subhead(heading => 'Problem Information', name => 'problem_heading'),
		new CGI::Dialog::Field(caption => 'ICD Code', name => 'icd_code1',
					findPopup => '/lookup/icd', options => FLDFLAG_TRIM, size => 6, secondaryFindField => '_f_icd_desc' ),
		new CGI::Dialog::Field(
						caption => 'ICD Description',
						name => 'icd_desc',
						type => 'memo'
					),
		new CGI::Dialog::Field(caption => 'Date Of Injury', name => 'trans_begin_stamp', type => 'date', pastOnly => 0, defaultValue => ''),
		new CGI::Dialog::Field(name => 'comments', caption => 'Comments', type => 'memo',rows=>2),

		new CGI::Dialog::Subhead(heading => 'Submitter Information', name => 'submit_info'),
		new CGI::Dialog::Field(caption =>'Contact', name => 'contact_org'),
		new CGI::Dialog::Field(caption =>'Organization', name => 'org_name'),
		new App::Dialog::Field::Address(caption =>'Org Address', name => 'org_address'),
		new CGI::Dialog::MultiField(
			fields => [
				new CGI::Dialog::Field(caption => 'Phone', name => 'org_phone', type => 'phone'),
				new CGI::Dialog::Field(caption => 'Ext', name => 'org_phone_ext', size =>'4'),
			]),
		new CGI::Dialog::Subhead(heading => 'Procedure Information', name => 'procedure_heading'),

		@request,


		new CGI::Dialog::Subhead(heading => 'Referral Information', name => 'referral_heading'),
		new CGI::Dialog::MultiField(caption =>'Referring Doctor Name',name => 'mdname',
									fields => [
										new CGI::Dialog::Field(type=> 'text', caption => 'MD First name', name => 'mdfirstname'),
										new CGI::Dialog::Field(type=> 'text', caption => 'Last name', name => 'mdlastname'),
				]),
	
	new CGI::Dialog::Field(caption =>'Source of Referral',
					name => 'source',
					#options => FLDFLAG_PREPENDBLANK,
					fKeyStmtMgr => $STMTMGR_TRANSACTION,
					fKeyStmt => 'selReferralSourceType',
					fKeyDisplayCol => 1,
					fKeyValueCol => 0),
		new CGI::Dialog::Field(caption =>'Referral Type ',
					name => 'referral_type',
					#options => FLDFLAG_PREPENDBLANK,
					fKeyStmtMgr => $STMTMGR_TRANSACTION,
					fKeyStmtFlags => STMTMGRFLAG_DYNAMICSQL,
					fKeyStmt => $sqlStmt,
					fKeyDisplayCol => 1,
					fKeyValueCol => 0),

		new CGI::Dialog::Field(caption =>'Date Of Request ', name => 'trans_end_stamp', type => 'date', pastOnly => 1),
		new CGI::Dialog::MultiField(name => 'coord_status',
			fields => [
					new App::Dialog::Field::Person::ID(caption => 'Intake Coordinator', name => 'intake_coordinator', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
					new CGI::Dialog::Field(caption => 'Status',
								name => 'status',
								options => FLDFLAG_REQUIRED,
								type => 'select',
								readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
								selOptions => "Assigned;Unassigned;Done",
								defaultValue => 'Assigned'),
				]),

	);

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions_add => [
							['View Summary', "/org/%param.org_id%/profile"],
							['Go to Service Request Work List', "/worklist/referral"],
							['Go to Referral Work List', "/worklist/referral/?user=physician",1],
							['Go to Referral Form', "/org/%session.org_id%/dlg-update-trans-6010/%param.refer_id%", 1],
							['Go to Menu', "/worklist/menu"],
							],
						nextActions_update => [
							['View Summary', "/person/%param.person_id%/profile"],
							['Go to Service Request Work List', "/worklist/referral", 1],
							['Go to Referral Work List', "/worklist/referral/?user=physician"],
							['Go to Referral Form', "/person/%field.person_id%/dlg-update-trans-6010/%param.refer_id%"],
							['Go to Menu', "/worklist/menu"],
							],
						cancelUrl => $self->{cancelUrl} || undef)

	);

	$self->addPostHtml(qq{
			<script language="JavaScript1.2">
				function clickMenuRef(url)
				{
					var urlNext = url;
					window.location.href= '/' + urlNext;
				}
			</script>
	});

}
 sub makeStateChanges
 {
       	my ($self, $page, $command, $dlgFlags) = @_;
       	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
       	my  $otherPayer = $self->getField('other_payer_fields');
       	$self->updateFieldFlags('other_payer_fields', FLDFLAG_INVISIBLE, 1);
      	my $personSessionId = $page->session('person_id');
  	$page->field('intake_coordinator',$personSessionId);

  	my $maxrows=MAXROWS;
  	my $ServiceData=undef;
  	if ($command eq 'add' and  $page->field('person_id'))
  	{
  		$ServiceData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selServiceRequestData', $page->field('person_id'))
  	}
 	#Populate the Procedure Information
 	my $count=0;
 	if($page->param('trans_id') ||$ServiceData )
 	{
 		my $transId =  $page->param('trans_id')|| $ServiceData->{'trans_id'};
      		my $serviceProcedures =  $STMTMGR_TRANSACTION->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selServiceProcedureData',$transId);
      		foreach (@$serviceProcedures)
      		{
  			$count++;
  		}
	};
	$count=$count||1; #always show at least one line
       	$self->addPostHtml(
       	qq{
		<script language="JavaScript1.2">
		for(loop=$count;loop<$maxrows;loop++)
		{
			setRequestStyle(loop,'none');
		};
		function setRequestStyle(line,styleValue)
		{
			setIdDisplay("code_mod_desc"+line,styleValue);
			setIdDisplay("date_proc"+line,styleValue);
			setIdDisplay("unit_charge"+line,styleValue);
			setIdDisplay("comment"+line,styleValue);
			setIdDisplay("description"+line,styleValue);
		}
		</script>
	});


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
	$page->addContent(qq{

		<TABLE>

			<TR VALIGN=TOP>
				<TD COLSPAN=2>

					<input type="button" value="Menu" onClick="javascript:clickMenuRef('menu');">
					<input type='button' value='Followup Worklist' onClick="javascript:clickMenuRef('worklist/referral?user=physician');">
					<input type='button' value='Lookup Patient' onClick="javascript:clickMenuRef('search/patient');">
					<input type='button' value='Add Patient' onClick="javascript:clickMenuRef('org/#session.org_id#/dlg-add-patient');">
					<input type='button' value='Edit Patient' onClick="javascript:clickMenuRef('search/patient');">
					<input type='button' value='Edit Service Request' onClick="javascript:clickMenuRef('worklist/referral');">
					<input type='button' value='Add Service Request' onClick="javascript:clickMenuRef('worklist/referral');">
					<input type='button' value='Add Referral' onClick="javascript:clickMenuRef('worklist/referral');">
					<input type='button' value='Edit Referral' onClick="javascript:clickMenuRef('worklist/referral?user=physician');">

				</TD>
			</TR>
		</TABLE>
	});
	my $comp='';
	if ($command eq 'update')
	{
		$comp = qq{#component.stpt-person.childReferral#};
	}
	if (($ServiceData eq '' && $command eq 'add') || $command ne 'add' )
	{
 		$page->addContent(qq{
 			<TABLE ALIGN="Center">
 				<TR VALIGN=TOP>
 					<TD>$dlgHtml</TD>
	 				<TD>
	 				$comp
	 				</TD>
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
 	#Check to make sure that the user code provided are valid HCPS/CPT/Misc Procedure codes
 	for (my $loop=0;$loop<MAXROWS;$loop++)
	{

		my $code = $page->field("code$loop");
		next unless ($code);
		my $data = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selFindDescByCode',$code,$page->session('org_internal_id') );
		my $field = $self->getField("code_mod_desc$loop")->{fields}->[0];
		$field->invalidate($page, "Invoice Procedure Code '$code' ") if ($data->{description} eq '' or ! defined $data->{description});

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
		my $icd = $page->field('icd_code1');
		 my $icdData = $STMTMGR_INTELLICODE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selIcdData', $icd);


		$page->field('trans_end_stamp', $ServiceData->{'trans_end_stamp'});
		$page->field('trans_begin_stamp', $ServiceData->{'trans_begin_stamp'});
		$page->field('intake_coordinator', $personSessionId);
		#$page->field('status', $ServiceData->{'trans_substatus_reason'});
		$page->field('referral_type', $ServiceData->{'trans_expire_reason'});
		$page->field('contact_org', $ServiceData->{'modifier'});
		$page->field('mdfirstname', $ServiceData->{'auth_by'});
		$page->field('mdlastname', $ServiceData->{'auth_ref'});
		$page->field('icd_desc', $icdData->{'descr'});
		#$page->field('cpt_desc', $ServiceData->{'data_text_b'});
		#$page->field('hcspcs_desc', $ServiceData->{'data_text_c'});
		$page->field('source', $ServiceData->{'caption'});

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
		$page->field('org_phone_ext', $orgContactData->{'value_textb'});
		$page->field('org_name', $orgContactData->{'name_sort'});

		my $insuranceTypeData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $parentTransId, 'Insurance Type');
		my @insType = split(',', $insuranceTypeData->{'value_text'});
		$page->field('ins_type', @insType);
		$page->field('ins_client', $insuranceTypeData->{'value_textb'});

		my $adjusterData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $parentTransId, 'Adjuster Information');
		$page->field('adjuster_name', $adjusterData->{'value_text'});
		$page->field('adjuster_phone', $adjusterData->{'value_textb'});

		my $groupData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $parentTransId, 'Group Information');
		$page->field('member_id', $groupData->{'value_text'});
		$page->field('group_num', $groupData->{'value_textb'});
		$page->field('policy_num', $groupData->{'name_sort'});

		my $customerData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $parentTransId, 'Customer Phone');
		$page->field('customer_service_ph', $customerData->{'value_text'});

		my $orgContactAddress = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransAddressByName', $parentTransId, 'Mailing');
		$page->field('addr_line1', $orgContactAddress->{'line1'});
		$page->field('addr_line2', $orgContactAddress->{'line2'});
		$page->field('addr_city', $orgContactAddress->{'city'});
		$page->field('addr_state', $orgContactAddress->{'state'});
		$page->field('addr_zip', $orgContactAddress->{'zip'});
		#Populate the Procedure Information
		my $serviceProcedures =  $STMTMGR_TRANSACTION->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selServiceProcedureData',$parentTransId);

		my $count=0;
		foreach (@$serviceProcedures)
		{
			$page->field("code$count",$_->{code});
			$page->field("modf$count",$_->{modifier});
			$page->field("description$count",$_->{caption});
			$page->field("comment$count",$_->{detail});
			$page->field("charge$count",$_->{unit_cost});
			$page->field("unit$count",$_->{quantity});
			#$page->field("procedure_id$count",$_->{trans_id});
			$page->field('date_proc'.$count.'_begin_date',$_->{data_date_a});
			$page->field('date_proc'.$count.'_end_date',$_->{data_date_b});

			$count++;
		}
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

	my $icd = $page->field('icd_code1');
	my $icdData = $STMTMGR_INTELLICODE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selIcdData', $icd);

	$page->field('person_id', $referralData->{'consult_id'});
	$page->field('trans_end_stamp', $referralData->{'trans_end_stamp'});
	$page->field('trans_begin_stamp', $referralData->{'trans_begin_stamp'});
	$page->field('intake_coordinator', $referralData->{'trans_subtype'});
	$page->field('status', $referralData->{'trans_substatus_reason'});
	$page->field('referral_type', $referralData->{'trans_expire_reason'});
	$page->field('icd_desc', $icdData->{'descr'});
	$page->field('contact_org', $referralData->{'modifier'});
	$page->field('comments', $referralData->{'display_summary'});
	$page->field('details', $referralData->{'detail'});
	#$page->field('cpt_desc', $referralData->{'data_text_b'});
	#$page->field('hcspcs_desc', $referralData->{'data_text_c'});
	$page->field('mdfirstname', $referralData->{'auth_by'});
	$page->field('mdlastname', $referralData->{'auth_ref'});
	$page->field('source', $referralData->{'caption'});


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

	my $insuranceTypeData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $page->param('trans_id'), 'Insurance Type');
	my @insType = split(',', $insuranceTypeData->{'value_text'});
	$page->field('ins_type', @insType);
	$page->field('ins_client', $insuranceTypeData->{'value_textb'});
	$page->field('ins_type_item_id', $insuranceTypeData->{'item_id'});

	my $adjusterData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $page->param('trans_id'), 'Adjuster Information');
	$page->field('adjuster_name', $adjusterData->{'value_text'});
	$page->field('adjuster_phone', $adjusterData->{'value_textb'});
	$page->field('adjust_item_id', $adjusterData->{'item_id'});

	my $groupData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $page->param('trans_id'), 'Group Information');
	$page->field('member_id', $groupData->{'value_text'});
	$page->field('group_num', $groupData->{'value_textb'});
	$page->field('policy_num', $groupData->{'name_sort'});
	$page->field('group_item_id', $groupData->{'item_id'});

	my $customerData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $page->param('trans_id'), 'Customer Phone');
	$page->field('customer_service_ph', $customerData->{'value_text'});
	$page->field('custom_item_id', $customerData->{'item_id'});

	my $orgContactAddress = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransAddressByName', $page->param('trans_id'), 'Mailing');
	$page->field('addr_item_id', $orgContactAddress->{'item_id'});
	$page->field('addr_line1', $orgContactAddress->{'line1'});
	$page->field('addr_line2', $orgContactAddress->{'line2'});
	$page->field('addr_city', $orgContactAddress->{'city'});
	$page->field('addr_state', $orgContactAddress->{'state'});
	$page->field('addr_zip', $orgContactAddress->{'zip'});

	#Populate the Procedure Information
	my $serviceProcedures =  $STMTMGR_TRANSACTION->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selServiceProcedureData',$page->param('trans_id'));

	my $count=0;
	foreach (@$serviceProcedures)
	{
		$page->field("code$count",$_->{code});
		$page->field("modf$count",$_->{modifier});
		$page->field("description$count",$_->{caption});
		$page->field("comment$count",$_->{detail});
		$page->field("charge$count",$_->{unit_cost});
		$page->field("unit$count",$_->{quantity});
		$page->field("procedure_id$count",$_->{trans_id});
		$page->field('date_proc'.$count.'_begin_date',$_->{data_date_a});
		$page->field('date_proc'.$count.'_end_date',$_->{data_date_b});

		$count++;
	}

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
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;
	my $transId = $page->schemaAction(
				'Transaction',
				$command,
				trans_owner_type 			=>  $transOwnerType ,
				trans_owner_id 			=> $orgInternalId,
				trans_id 					=> $transacId || undef,
				trans_type 					=> $transType || undef,
				trans_begin_stamp 		=> $page->field('trans_begin_stamp') || undef,
				trans_end_stamp 			=> $page->field('trans_end_stamp') || undef,
				display_summary 			=> $page->field('comments') || undef,
				trans_status_reason 		=> $page->field('payer') || undef,
				trans_status 				=> $transStatus,
				provider_id 				=> $page->field('provider_id') || undef,
				care_provider_id 			=> $page->field('referral_id') || undef,
				trans_expire_reason 		=> $page->field('referral_type') || undef,
				#data_text_a 				=> $page->field('icd_desc') || undef,
				#data_text_b 				=> $page->field('cpt_desc') || undef,
				#data_text_c 				=> $page->field('hcspcs_desc') || undef,
				auth_by 						=> $page->field('mdfirstname') || undef,
				auth_ref 					=> $page->field('mdlastname') || undef,
				consult_id 					=> $page->field('person_id') || undef,
				detail 						=> $page->field('details') || undef,
				caption 						=> $page->field('source') || undef,
				initiator_id 				=> $orgId || undef,
				trans_subtype 				=> $page->field('intake_coordinator') || undef,
				trans_substatus_reason 	=> $page->field('status') || undef,
				modifier               	=> $page->field('contact_org') || undef,
				code 							=> $dataTextB || undef,
				related_data 				=>  $dataTextC || undef,
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

	my $insCommand = $page->field('ins_type_item_id') eq '' ? 'add' : $command;
	my @insType = $page->field('ins_type');
	$page->schemaAction(
			'Trans_Attribute', $insCommand,
			parent_id => $parentTransId,
			item_name => 'Insurance Type',
			item_id => $page->field('ins_type_item_id') || undef,
			value_type => App::Universal::ATTRTYPE_TEXT,
			value_text => join(',', @insType) || undef,
			value_textB => $page->field('ins_client') || undef,
			_debug => 0
		);

	my $adjustCommand = $page->field('adjust_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Trans_Attribute', $adjustCommand,
			parent_id => $parentTransId,
			item_name => 'Adjuster Information',
			item_id => $page->field('adjust_item_id') || undef,
			value_type => App::Universal::ATTRTYPE_TEXT,
			value_text => $page->field('adjuster_name') || undef,
			value_textB => $page->field('adjuster_phone') || undef,
			_debug => 0
		);

	my $groupCommand = $page->field('group_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Trans_Attribute', $groupCommand,
			parent_id => $parentTransId,
			item_name => 'Group Information',
			item_id => $page->field('group_item_id') || undef,
			value_type => App::Universal::ATTRTYPE_TEXT,
			value_text => $page->field('member_id') || undef,
			value_textB => $page->field('group_num') || undef,
			name_sort   => $page->field('policy_num') || undef,
			_debug => 0
		);

	my $customCommand = $page->field('custom_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Trans_Attribute', $customCommand,
			parent_id => $parentTransId,
			item_name => 'Customer Phone',
			item_id => $page->field('custom_item_id') || undef,
			value_type => App::Universal::ATTRTYPE_TEXT,
			value_text => $page->field('customer_service_ph') || undef,
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




	my $transProcedure = App::Universal::TRANSTYPEPROC_SERVICE_REQUEST_PROCEDURE;
	my $first=0;
	for (my $loop=0;$loop<MAXROWS;$loop++)
	{
		my $code = $page->field("code$loop");
		my $modf = $page->field("modf$loop");
		my $desc = $page->field("description$loop");
		my $comment = $page->field("comment$loop");
		my $charge = $page->field("charge$loop");
		my $units = $page->field("unit$loop");
		my $startDate = $page->field('date_proc'.$loop.'_begin_date');
		my $endDate = $page->field('date_proc'.$loop.'_end_date');
		my $transRequestId =$page->field("procedure_id$loop");
		next unless $code;
		#If a description is not provided try to find one
		unless ($desc)
		{
			my $data = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selFindDescByCode',$code,$page->session('org_internal_id') ) unless $desc;
			$desc = $data->{description};
		}
		#Create Service Request
		my $transService = $page->schemaAction(
			'Transaction',$transRequestId ? 'update' : 'add',
			parent_trans_id =>   $parentTransId,
			trans_owner_type => $transOwnerType,
			trans_owner_id =>  $orgInternalId,
			#trans_status =>$transType,
			trans_id => $transRequestId ,
			trans_type => $transProcedure ,
			trans_status => $transStatus,
			code=>$code,
			modifier => $modf,
			detail=>$comment,
			unit_cost => $charge,
			quantity => $units,
			caption=>$desc,
			data_date_a =>$startDate,
			data_date_b =>$endDate,
		);

		my $transRef=undef;

		#If service request is already created then get linked referral
		if($transRequestId)
		{
			$transRef =  $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selReferralProcedureData',$transRequestId);
		}

		#Populate the Procedure Information
		#Create Referral for each service request line Copy information from request to referral
		my $transTypeRef = App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION;
		my $referId = $page->schemaAction
		(
			'Transaction' , $transRef->{trans_id} ? 'update' : 'add',
			parent_trans_id => $transRequestId ||$transService  ,
			trans_owner_type => $transOwnerType,
			trans_owner_id =>$orgInternalId,
			trans_status => $transStatus,
			trans_id =>$transRef->{trans_id},
			trans_type => $transTypeRef,
			care_provider_id =>$page->session('user_id'),
			consult_id =>$page->field('person_id'),
			trans_begin_stamp      => $startDate,
			trans_end_stamp        => $endDate,
			quantity               => $units,
			initiator_id           => $page->session('org_id'),
			data_text_a=>$parentTransId,
		);
		$page->param('refer_id',$transRef->{trans_id} || $referId) unless $first;
		$first++;
	}

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
