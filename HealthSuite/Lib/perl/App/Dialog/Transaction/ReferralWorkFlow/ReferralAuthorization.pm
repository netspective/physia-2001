##############################################################################
package App::Dialog::Transaction::ReferralWorkFlow::ReferralAuthorization;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;

use Mail::Sendmail;

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Transaction;
use App::Statements::Component::Person;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Transaction::ReferralWorkFlow);

%RESOURCE_MAP = (
	'referral-auth' => {
		transId => ['parent_trans_id'],
		heading => '$Command Referral',
		_arl => ['org_id'],
		_arl_add => ['parent_trans_id'],
		_arl_modify => ['trans_id'],
		_idSynonym => 'trans-' . App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION()
		},
	);
sub initialize
{
	my $self = shift;
	$self->SUPER::initialize();
	#my $self = CGI::Dialog::new(@_, id => 'referral-auth', heading => 'Add Referral Authorization');

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'name_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'provider_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'prev_intake_form'),
		new CGI::Dialog::Field(caption => 'Service Request ID',  name => 'ref_id', size => '6'),
		new App::Dialog::Field::Person::ID(caption => 'Person/Patient ID',types => ['Patient'],	name => 'person_id', options => FLDFLAG_REQUIRED, preHtml => qq{<a href="javascript:doActionPopup('/person/#param.person_id#/profile')">}),
		new CGI::Dialog::Subhead(heading => 'Tracking'),
		#new CGI::Dialog::MultiField(
		#	fields => [
				new App::Dialog::Field::Person::ID(caption =>'Intake Coordinator ', name => 'coordinator'),
				new CGI::Dialog::Field(caption => 'Referral Date',  type => 'date', name => 'ref_date'),
				new CGI::Dialog::Field(caption => 'Source of Service Request',  name => 'source_referral', size => '7', type=>'currency',options => FLDFLAG_READONLY,),

			#	]),
		new CGI::Dialog::Subhead(heading => 'Assign provider'),
		new CGI::Dialog::Field(caption => 'Provider Contact', name => 'contact_provider'),
		new CGI::Dialog::MultiField(
			fields => [
				new CGI::Dialog::Field(caption => 'Provider Phone', name => 'provider_phone', type => 'phone'),
				new CGI::Dialog::Field(caption => 'Ext', name => 'provider_phone_ext', size =>'4'),
			]),
		new CGI::Dialog::Field(caption =>'Provider Org', name => 'provider',findPopup => '/directory-p/ServiceDrillDownLookup', secondaryFindField => '_f_provider_name'),
		new CGI::Dialog::Field(caption => 'Provider Name', name => 'provider_name'),

		new CGI::Dialog::Subhead(heading => 'Fee Negotiation'),
		new CGI::Dialog::Field(caption => 'Point of Service Rate', name => 'charge', size => '7', type => 'currency'),
		new CGI::Dialog::Field(caption => 'Percent of Usual Customary',  name => 'percent_usual', size => '3'),
		new CGI::Dialog::Field(caption => 'Percent of Fee Schedule', name => 'percent_actual', size => '3'),
		new CGI::Dialog::Field(caption =>'Referral Result',
					name => 'ref_result',
					options => FLDFLAG_PREPENDBLANK,
					fKeyStmtMgr => $STMTMGR_TRANSACTION,
					fKeyStmt => 'selReferralResult',
					fKeyDisplayCol => 1,
					fKeyValueCol => 0),

		new CGI::Dialog::Subhead(heading => 'Service'),
		new CGI::Dialog::MultiField(caption =>'Service Begin/End Date',name => 'begin_end_date',
			fields => [
					new CGI::Dialog::Field(caption => 'Begin Date',  type => 'date', name => 'begin_date', defaultValue => '', futureOnly => 0),
					new CGI::Dialog::Field(caption => 'End Date',  type => 'date', name => 'end_date', defaultValue => '')

				]),
		new CGI::Dialog::Field(caption =>'Service',
					name => 'service',
					options => FLDFLAG_PREPENDBLANK,
					fKeyStmtMgr => $STMTMGR_TRANSACTION,
					fKeyStmt => 'selReferralServiceDesc',
					fKeyDisplayCol => 1,
					fKeyValueCol => 0),
		#new CGI::Dialog::Field(caption =>'Detail',
		#			name => 'detail',
		#			options => FLDFLAG_PREPENDBLANK,
		#			fKeyStmtMgr => $STMTMGR_TRANSACTION,
		#			fKeyStmt => 'selIntakeDetail',
		#			fKeyDisplayCol => 1,
		#			fKeyValueCol => 0),
		#new CGI::Dialog::Field(caption => 'Procedure Code', name => 'procedure_code'),
		new CGI::Dialog::MultiField(
			fields => [
					new CGI::Dialog::Field(caption => 'Units',  name => 'units', size => '4'),
					new CGI::Dialog::Field(caption =>'Unit Detail',
								name => 'unit_detail',
								options => FLDFLAG_PREPENDBLANK,
								fKeyStmtMgr => $STMTMGR_TRANSACTION,
								fKeyStmt => 'selReferralUnitType',
								fKeyDisplayCol => 1,
								fKeyValueCol => 0),
				]),
		new CGI::Dialog::Field(caption => 'Code',  name => 'code', size => '7',options => FLDFLAG_READONLY,),
		new CGI::Dialog::Field(caption => 'Description',  type => 'memo',name=>'code_description',options => FLDFLAG_READONLY,),
		new CGI::Dialog::Field(caption => 'Comment',  type => 'memo',name=>'code_comment',options => FLDFLAG_READONLY,),
		new CGI::Dialog::Field(caption => 'Service Request Charge',  name => 'service_rate', size => '7', type=>'currency',options => FLDFLAG_READONLY,),

		new CGI::Dialog::Subhead(heading => 'Authorization'),
		new CGI::Dialog::MultiField(name => 'clientid_num', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		fields => [
				new CGI::Dialog::Field(caption =>'Client',
							name => 'client',
							options => FLDFLAG_PREPENDBLANK,
							fKeyStmtMgr => $STMTMGR_TRANSACTION,
							fKeyStmt => 'selIntakeClient',
							fKeyDisplayCol => 1,
							fKeyValueCol => 0),
				#new App::Dialog::Field::Organization::ID(caption =>'Client ', name => 'client'),
				new CGI::Dialog::Field(caption => 'Case #', name => 'claim_num', size => '7'),
			]),
		new CGI::Dialog::MultiField(
		fields => [
				new CGI::Dialog::Field(caption =>'Authorized By ', name => 'provider_id'),
				new CGI::Dialog::Field(caption => 'Authorization Date',  type => 'date', name => 'auth_date', defaultValue => ''),
			]),


			new CGI::Dialog::MultiField(
			fields => [
				new CGI::Dialog::Field(caption => 'Auth Phone', name => 'auth_phone', type => 'phone'),
				new CGI::Dialog::Field(caption => 'Ext', name => 'auth_phone_ext', size =>'4'),
			]),
		new CGI::Dialog::Subhead(heading => 'Follow Up'),
		new CGI::Dialog::MultiField(
			fields => [
					new CGI::Dialog::Field(caption =>'Follow Up',
								name => 'follow_up',
								options => FLDFLAG_PREPENDBLANK,
								fKeyStmtMgr => $STMTMGR_TRANSACTION,
								fKeyStmt => 'selReferralFollowStatus',
								fKeyDisplayCol => 1,
								fKeyValueCol => 0),
					new CGI::Dialog::Field(caption => 'Date',
								type => 'date',
								name => 'followup_date',
								defaultValue => '')
				]),

		new CGI::Dialog::MultiField(
			fields => [
					new CGI::Dialog::Field(caption => 'HDS Claim Number',  name => 'hds_num'),
					new CGI::Dialog::Field(caption => 'Confirm Delivery Date',  type => 'date', name => 'delivery_date', defaultValue => '')

				]),
		new CGI::Dialog::Field(name => 'comments', caption => 'Comments', type => 'memo'),

	);

	$self->addFooter(new CGI::Dialog::Buttons(
							nextActions => [
								['Add New Similar Referral', "/org/%param.org_id%/dlg-add-trans-6010/%param.parent_trans_id%?_f_prev_intake_form=%field.prev_intake_form%"],
								['Go to Referral Work List', "/worklist/referral?user=physician", 1],
								['Go to Service Request Work List', "/worklist/referral"],
								['Add New Service Request', "/org/%param.org_id%/dlg-add-referral"],
								['Go to Patient Summary', "/person/%field.person_id%/profile"],
								],
							cancelUrl => $self->{cancelUrl} || undef)

		);

	$self->addPostHtml(qq{
			<script language="JavaScript1.2">
				function clickMenu(url)
				{
					var urlNext = '/' + url;
					window.location.href= urlNext;
					//document.dialog._f_on_submit_goto.value	= urlNext;
					//document.dialog.submit();
				}
			</script>
		});
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $sessionPersonId = $page->session('person_id');
	$self->setFieldFlags('idcodes', FLDFLAG_READONLY);
	$page->field('coordinator') eq '' ? $page->field('coordinator', $sessionPersonId) : $page->field('coordinator');

	#my $coordId = $self->getField('referral_date_intake')->{fields}->[0];
	$self->setFieldFlags('coordinator', FLDFLAG_READONLY);
	$self->setFieldFlags('ref_id', FLDFLAG_READONLY);
	#$self->setFieldFlags('name', FLDFLAG_READONLY);
	$self->setFieldFlags('person_id', FLDFLAG_READONLY);

	#$page->field('provider') = $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);
}

sub customValidate
 {
 	my ($self, $page) = @_;

	my $perUsual = $self->getField('percent_usual');
	my $perActual = $self->getField('percent_actual');
 	if ($page->field('percent_usual') > 100)
 	{
 		$perUsual->invalidate($page, "'$perUsual->{'caption'}' cannot be greater than 100");
 	}

 	if ($page->field('percent_actual') > 100)
  	{
  		$perActual->invalidate($page, "'$perActual->{'caption'}' cannot be greater than 100");
 	}


 }

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless ($flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL);
	my $transId = $page->param('parent_trans_id');
	my $personId = $page->session('person_id');

	my $parentTransData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByTransId', $transId);
	my $claimNum = $STMTMGR_TRANSACTION->getSingleValue($page, STMTMGRFLAG_NONE, 'selClaimNumByParentId', $transId);

	$page->field('claim_num', $claimNum);
	$page->field('ref_id', $transId);
	$page->field('coordinator', $transId);
	$page->field('person_id', $parentTransData->{'consult_id'});

	my $sourceOfServiceData = $STMTMGR_TRANSACTION->getSingleValue($page, STMTMGRFLAG_NONE, 'selServiceSourceTypeByTransId', $transId);
	$page->field('source_referral', $sourceOfServiceData);

	$parentTransData->{'trans_subtype'} ne '' ? $page->field('coordinator', $parentTransData->{'trans_subtype'}) : $page->field('coordinator', $personId);

	my $prevIntake = $page->field('prev_intake_form');
	if ($prevIntake ne '')
	{
		my $prevIntakeData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByTransId', $prevIntake);

		#my $clientData = $prevIntakeData->{'billing_facility_id'};
		my $providerData = $prevIntakeData->{'service_facility_id'};
		#my $clientId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $clientData);
		my $provider = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $providerData);
		$page->field('provider_id', $prevIntakeData->{'data_text_c'});
		$page->field('auth_date', $prevIntakeData->{'auth_date'});
		$page->field('auth_phone', $prevIntakeData->{'data_text_b'});
		$page->field('coordinator', $prevIntakeData->{'care_provider_id'});
		$page->field('ref_id', $prevIntakeData->{'data_text_a'});
		$page->field('follow_up', $prevIntakeData->{'trans_status_reason'});
		$page->field('followup_date', $prevIntakeData->{'data_date_b'});
		$page->field('ref_date', $prevIntakeData->{'data_date_a'});
		$page->field('contact_provider', $prevIntakeData->{'trans_substatus_reason'});
		$page->field('provider_phone', $prevIntakeData->{'receiver_id'});
		$page->field('percent_usual', $prevIntakeData->{'data_num_a'});
		$page->field('percent_actual', $prevIntakeData->{'data_num_b'});
		$page->field('begin_date', $prevIntakeData->{'trans_begin_stamp'});
		$page->field('end_date', $prevIntakeData->{'trans_end_stamp'});
		$page->field('service', $prevIntakeData->{'caption'});
		#$page->field('detail', $prevIntakeData->{'detail'});
		#$page->field('procedure_code', $prevIntakeData->{'code'});
		$page->field('units', $prevIntakeData->{'quantity'});
		$page->field('charge', $prevIntakeData->{'unit_cost'});
		$page->field('unit_detail', $prevIntakeData->{'modifier'});
		#$page->field('client', $authData->{'auth_by'});
		$page->field('provider', $provider);
		$page->field('claim_num', $prevIntakeData->{'auth_ref'});
		$page->field('provider_id', $prevIntakeData->{'data_text_c'});
		$page->field('ref_result', $prevIntakeData->{'related_data'});
	}

}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	# Populating the fields while updating the dialog
	return unless ($flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL);
	my $authData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByTransId', $page->param('trans_id'));
	my $providerData = $authData->{'service_facility_id'};
	#my $clientId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $clientData);
	my $provider = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $providerData);

	my $providerInfo = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByParentIdItemName', $page->param('trans_id'), 'Provider Phone');

	my $sourceOfServiceData = $STMTMGR_TRANSACTION->getSingleValue($page, STMTMGRFLAG_NONE, 'selServiceSourceTypeByTransId', $authData->{'data_text_a'});
	$page->field('source_referral', $sourceOfServiceData);

	$page->field('provider_phone', $providerInfo->{'name_sort'});
	$page->field('provider_phone_ext', $providerInfo->{'value_text'});
	$page->field('provider_item_id', $providerInfo->{'item_id'});

	$page->field('person_id', $authData->{'consult_id'});
	$page->field('provider_id', $authData->{'data_text_c'});
	$page->field('auth_date', $authData->{'auth_date'});
	$page->field('auth_phone', $authData->{'data_text_b'});
	$page->field('auth_phone_ext', $authData->{'code'});
	$page->field('coordinator', $authData->{'care_provider_id'});
	$page->field('ref_id', $authData->{'data_text_a'});
	$page->field('follow_up', $authData->{'trans_status_reason'});
	$page->field('hds_num', $authData->{'trans_expire_reason'});
	$page->field('delivery_date', $authData->{'auth_expire'});
	$page->field('followup_date', $authData->{'data_date_b'});
	$page->field('ref_date', $authData->{'data_date_a'});
	$page->field('contact_provider', $authData->{'trans_substatus_reason'});
	$page->field('provider_name', $authData->{'receiver_id'});
	#$page->field('provider_phone_ext', $authData->{'trans_seq'});
	$page->field('percent_usual', $authData->{'data_num_a'});
	$page->field('percent_actual', $authData->{'data_num_b'});
	$page->field('begin_date', $authData->{'trans_begin_stamp'});
	$page->field('end_date', $authData->{'trans_end_stamp'});
	$page->field('service', $authData->{'caption'});
	#$page->field('detail', $authData->{'detail'});
	#$page->field('procedure_code', $authData->{'code'});
	$page->field('units', $authData->{'quantity'});
	$page->field('charge', $authData->{'unit_cost'});
	$page->field('unit_detail', $authData->{'modifier'});
	$page->field('client', $authData->{'auth_by'});
	$page->field('provider', $provider);
	$page->field('claim_num', $authData->{'auth_ref'});
	$page->field('provider_id', $authData->{'data_text_c'});
	$page->field('ref_result', $authData->{'related_data'});
	$page->field('comments', $authData->{'display_summary'});

	#Get Code and Description from service Request

	my $serviceRequest = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE,'selServiceProcedureDataByTransId',$authData->{parent_trans_id});
	$page->field('code',$serviceRequest->{code});
	$page->field('code_description',$serviceRequest->{caption});
	$page->field('code_comment',$serviceRequest->{detail});
	my $rate=$serviceRequest->{unit_cost} * $serviceRequest->{quantity};
	$page->field('service_rate',$rate);
}

sub populateData_remove
{
	populateData_update(@_);
}

sub getSupplementaryHtml
{
	return ('special', '');
}

sub handle_page_supplType_special
{
	my ($self, $page, $command, $dlgHtml) = @_;
	my $parentData = $STMTMGR_TRANSACTION->getRowAsHash($page,STMTMGRFLAG_NONE, 'selByTransId', $page->param('trans_id')) if $command ne 'add';
	my $parentTransId = $parentData->{'parent_trans_id'};
	my $test = $page->param('parent_trans_id');
	my $personId = $page->field('person_id');
	my $transId = $command eq 'add' ? $page->param('parent_trans_id') : $parentTransId;
	if ($personId ne '')
	{
		$page->param('person_id', $personId);
		my $prevIntake = $page->field('prev_intake_form');
		if ($prevIntake ne '' & $command eq 'add')
		{
			$page->addContent(qq{
				<TABLE>
					<TR VALIGN=TOP>
						<TD COLSPAN=2>

							<input type="button" value="Menu" onClick="javascript:clickMenu('menu');">
							<input type='button' value='Referral Followup Worklist' onClick="javascript:clickMenu('worklist/referral?user=physician');">
							<input type='button' value='Lookup Patient' onClick="javascript:clickMenu('search/patient');">
							<input type='button' value='Add Patient' onClick="javascript:clickMenu('org/#session.org_id#/dlg-add-patient');">
							<input type='button' value='Edit Patient' onClick="javascript:clickMenu('search/patient');">
							<input type='button' value='Edit Service Request' onClick="javascript:clickMenu('org/ACS/dlg-update-trans-6000/$transId');">
							<input type='button' value='Add Service Request' onClick="javascript:clickMenu('org/ACS/dlg-add-referral?_f_person_id=$personId');">
							<input type='button' value='Add Referral' onClick="javascript:clickMenu('worklist/referral?user=physician');">
							<input type='button' value='Edit Referral' onClick="javascript:clickMenu('worklist/referral?user=physician');">

						</TD>
					</TR>
					<TR><TD COLSPAN=2>&nbsp;</TD></TR>
					<TR VALIGN=TOP>
						<TD>$dlgHtml</TD>
						<TD>
							#component.stpt-person.referralAndIntake#<BR>
							#component.stpt-person.referralAndIntakeCount#<BR>
							#component.stpd-person.contactMethodsAndAddresses#
						</TD>
					</TR>
				</TABLE>
			});
		}


		else
		{
			$page->addContent(qq{

				<TABLE>

					<TR VALIGN=TOP>
						<TD COLSPAN=2>

							<input type="button" value="Menu" onClick="javascript:clickMenu('menu');">
							<input type='button' value='Referral Followup Worklist' onClick="javascript:clickMenu('worklist/referral?user=physician');">
							<input type='button' value='Lookup Patient' onClick="javascript:clickMenu('search/patient');">
							<input type='button' value='Add Patient' onClick="javascript:clickMenu('org/#session.org_id#/dlg-add-patient');">
							<input type='button' value='Edit Patient' onClick="javascript:clickMenu('search/patient');">
							<input type='button' value='Edit Service Request' onClick="javascript:clickMenu('org/ACS/dlg-update-trans-6000/$transId');">
							<input type='button' value='Add Service Request' onClick="javascript:clickMenu('org/ACS/dlg-add-referral?_f_person_id=$personId');">
							<input type='button' value='Add Referral' onClick="javascript:clickMenu('worklist/referral?user=physician');">
							<input type='button' value='Edit Referral' onClick="javascript:clickMenu('worklist/referral?user=physician');">

						</TD>
					</TR>
					<TR><TD COLSPAN=2>&nbsp;</TD></TR>
					<TR VALIGN=TOP>
						<TD>$dlgHtml</TD>
						<TD>

							#component.stpt-person.patientInfo#<BR>
							#component.stpt-person.referralAndIntake#<BR>
							#component.stpt-person.referralAndIntakeCount#<BR>
							#component.stpd-person.contactMethodsAndAddresses#
						</TD>
					</TR>
				</TABLE>
			});
		}

	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	#my $transaction = $self->{transaction};
	my $transactionId = $page->param('trans_id');
	my $parentId = $STMTMGR_TRANSACTION->getRowAsHash($page,STMTMGRFLAG_NONE, 'selByTransId', $transactionId);

	my $transId = $command eq 'add' ? $page->param('parent_trans_id') : $parentId->{'parent_trans_id'};
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;
	my $transOwnerType = App::Universal::ENTITYTYPE_PERSON;
	my $transType = App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION;
	my $previousChildRecs = $STMTMGR_TRANSACTION->recordExists($page,STMTMGRFLAG_NONE, 'selByParentTransId', $transId);
	$STMTMGR_TRANSACTION->execute($page,STMTMGRFLAG_NONE, 'selUpdateTransStatus', $transId) if ($previousChildRecs == 1) ;

	#my $personId = $page->param('person_id');
	#my $getPerson = $STMTMGR_TRANSACTION->getRowAsHash($page,STMTMGRFLAG_NONE, 'selByTransId', $transId);
	#my $referredTo = $getPerson->{'care_provider_id'};
	#my $referredBy = $getPerson->{'provider_id'};

	#my $referredToData = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selPrimaryMail', $referredTo);
	#my $referredToMail = $referredToData->{'value_text'};

	#my $referredByData = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selPrimaryMail', $referredBy);
	#my $referredByMail = $referredByData->{'value_text'};

	#my $patientData = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selPrimaryMail', $personId);
	#my $patientMail = $patientData->{'value_text'};


	#$page->addDebugStmt("PATIENT, RefferedBy, ReferredTo: $patientMail , $referredByMail, $referredToMail");
	my $authProvider = $page->field('provider');
	my $ownerOrgId = $page->session('org_internal_id');
	my $providerInternalId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrgId, $authProvider);
	#my $clientInternalId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrgId, $page->field('client'));
#	my $ownerOrgId = $page->session('org_internal_id');
	my $orgId = $page->param('org_id') ne '' ? $page->param('org_id') : $page->session('org_id');
	my $orgInternalId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrgId, $orgId);

	$STMTMGR_TRANSACTION->execute($page,STMTMGRFLAG_NONE, 'selUpdateReferralStatus', $transId);

	my $newTransId = $page->schemaAction(
				'Transaction',
				$command,
				parent_trans_id        => $transId || undef,
				trans_id               => $page->param('trans_id') || undef,
				trans_owner_type       => defined $transOwnerType ? $transOwnerType : undef,
				trans_owner_id         => $orgInternalId,
				trans_type             => $transType || undef,
				trans_status           => $transStatus || undef,
				data_text_a            => $page->field('ref_id') || undef,
				data_date_a            => $page->field('ref_date') || undef,
				care_provider_id       => $page->field('coordinator') || undef,
				consult_id             => $page->field('person_id') || undef,
				#trans_subtype          => $page->field('source') || undef,
				trans_substatus_reason => $page->field('contact_provider') || undef,
				receiver_id            => $page->field('provider_name') || undef,
				service_facility_id    => $providerInternalId || undef,
				unit_cost              => $page->field('charge') || undef,
				data_num_a             => $page->field('percent_usual') || undef,
				data_num_b             => $page->field('percent_actual') || undef,
				trans_begin_stamp      => $page->field('begin_date') || undef,
				trans_end_stamp        => $page->field('end_date') || undef,
				caption                => $page->field('service') || undef,
				#detail                 => $page->field('detail') || undef,
				#code                   => $page->field('procedure_code') || undef,
				quantity               => $page->field('units') || undef,
				modifier               => $page->field('unit_detail') || undef,
				#billing_facility_id    => $clientInternalId || undef,
				auth_by                => $page->field('client') || undef,
				auth_ref               => $page->field('claim_num') || undef,
				data_text_c	       => $page->field('provider_id') || undef,
				auth_date              => $page->field('auth_date') || undef,
				data_text_b               => $page->field('auth_phone') || undef,
				code                   => $page->field('auth_phone_ext') || undef,
				trans_status_reason    => $page->field('follow_up') || undef,
				data_date_b            => $page->field('followup_date') || undef,
				related_data           => $page->field('ref_result') || undef,
				trans_expire_reason    => $page->field('hds_num') || undef,
				auth_expire            => $page->field('delivery_date') || undef,
				display_summary        => $page->field('comments') || undef,
				initiator_id           => $orgId || undef,
				_debug => 0
		);

	$page->field('prev_intake_form', $newTransId);

	my $prdCommand = $page->field('provider_item_id') eq '' ? 'add' : $command;

	$page->schemaAction(
			'Trans_Attribute',
			$prdCommand,
			parent_id => $newTransId,
			item_name => 'Provider Phone',
			item_id => $page->field('provider_item_id') || undef,
			value_type => App::Universal::ATTRTYPE_TEXT,
			name_sort => $page->field('provider_phone') || undef,
			value_text =>$page->field('provider_phone_ext') || undef,
			_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);
	$page->param('_dialogreturnurl', "/worklist/referral?user=physician");
	return "\u$command completed.";

	#my %mail;

	#my $patientMail = 'snshah@physia.com';
	#my $referredByMail = 'snshah@physia.com';
	#my $referredToMail = 'snshah@physia.com';

	#my $strFrom = 'lloyd_brodsky@physia.com';

	#if ($patientMail ne '')
	#{
	#	%mail =
	#		(To => $patientMail,
	#		From => $strFrom,
	#		Subject => "Your doctor's referral has been just processed",
	#		Message => "http://tokyo.physia.com:8515/org/$orgId/dlg-update-trans-6010/$newTransId"
	#		);
	#	sendmail(%mail) or die $Mail::Sendmail::error;
	#}

	#if ($referredByMail ne '')
	#{
	#	%mail =
	#		(To => $referredByMail,
	#		From => $strFrom,
	#		Subject => "Your doctor's referral has been just processed",
	#		Message => "http://tokyo.physia.com:8515/org/$orgId/dlg-update-trans-6010/$newTransId"
	#		);
	#	sendmail(%mail) or die $Mail::Sendmail::error;
	#}

	#if ($referredToMail ne '')
	#{
	#	%mail =
	#		(To => $referredToMail,
	#		From => $strFrom,
	#		Subject => "Your doctor's referral has been just processed",
	##		);
	#	sendmail(%mail) or die $Mail::Sendmail::error;
	#}

}

1;
