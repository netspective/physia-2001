##############################################################################
package App::Dialog::ReferralPPMS;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Insurance;
use App::Statements::Catalog;
use App::Statements::ReferralPPMS;
use App::Dialog::Field::Person;
use App::Statements::IntelliCode;


use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use Date::Manip;
use Text::Abbrev;
use App::Universal;

use constant FAKESELFPAY_INSINTID => -1111;
use constant FAKENEW3RDPARTY_INSINTID => -2222;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'referral-ppms' => {
		_arl_add => ['person_id'],
		_arl_modify => ['referral_id','person_id']
	},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'referral-ppms', heading => '$Command Referral Dialog');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Field(name => 'request_date',
			caption => 'Date of Request',
			type => 'date',
			options => FLDFLAG_REQUIRED,
		),

		new CGI::Dialog::Field(type => 'select',
			name => 'referral_urgency',
			style => 'radio',
			caption => 'Referral Urgency',
			options => FLDFLAG_REQUIRED,
			fKeyStmtMgr => $STMTMGR_REFERRAL_PPMS,
			fKeyStmt => 'selReferralUrgency',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
		),

		new App::Dialog::Field::Person::ID(caption => 'User ID',
			name => 'user_id',
			options => FLDFLAG_REQUIRED,
			types => ['Staff']
		),

		new App::Dialog::Field::Person::ID(caption => 'Patient',
			name => 'patient_id',
			options => FLDFLAG_REQUIRED,
			types => ['Patient']
		),

		new CGI::Dialog::Field(type => 'hidden', name => 'old_person_id'),		#if user changes patient id, need to refresh payer list for the new patient id

		new CGI::Dialog::Field(caption => 'Primary Payer',
			type => 'select',
			name => 'payer',
			options => FLDFLAG_REQUIRED,
		),

		new CGI::Dialog::Subhead(heading => 'ICD Information', name => 'icd_heading'),
		new CGI::Dialog::Field(caption => 'ICD Code',
					name => 'icd_code1',
					findPopup => '/lookup/icd',
					secondaryFindField => '_f_icd_desc1',
					options => FLDFLAG_TRIM,
					size => 6,
					options => FLDFLAG_REQUIRED
					),
		new CGI::Dialog::Field(
					caption => 'ICD Description',
					name => 'icd_desc1',
					type => 'memo'
					),
		new CGI::Dialog::Field(caption => 'ICD Code', name => 'icd_code2',
					secondaryFindField => '_f_icd_desc2', size => 6,
					findPopup => '/lookup/icd', options => FLDFLAG_TRIM,  ),
		new CGI::Dialog::Field(
						caption => 'ICD Description',
						name => 'icd_desc2',
						type => 'memo'
					),

		new CGI::Dialog::Subhead(heading => 'Reason', name => 'reason_heading'),
		new CGI::Dialog::Field(caption => 'Reason for Referral',
					name => 'referral_reason',
					options => FLDFLAG_REQUIRED
					),

		new CGI::Dialog::Subhead(heading => 'Service Requested', name => 'reason_heading'),
		new CGI::Dialog::MultiField(caption=>'Code/Modf',name=>"code_mod_desc1",
			fields=>[
				new CGI::Dialog::Field(caption=>'Code', type=>'text',size=>9, options => FLDFLAG_REQUIRED,
				name=>"cpt_code1",findPopup => '/lookup/cpt',  secondaryFindField => '_f_cpt_desc1'),
				new CGI::Dialog::Field(caption=>'Modf',type=>'text',size=>5,name=>"modf1"),
				],
		),
		new CGI::Dialog::Field(caption=>'Description',
			type=>'memo',
			name=>'cpt_desc1',
		),

		new CGI::Dialog::MultiField(caption=>'Code/Modf',name=>"code_mod_desc2",
			fields=>[
				new CGI::Dialog::Field(caption=>'Code', type=>'text',size=>9,
				name=>"cpt_code2",findPopup => '/lookup/cpt',  secondaryFindField => '_f_cpt_desc2'),
				new CGI::Dialog::Field(caption=>'Modf',type=>'text',size=>5,name=>"modf2"),
				],
		),
		new CGI::Dialog::Field(caption=>'Description',
			type=>'memo',
			name=>'cpt_desc2',
		),

		new App::Dialog::Field::Person::ID(caption => 'Requesting Physician',
			name => 'requesting_physician',
			options => FLDFLAG_REQUIRED,
			types => ['Physician'],
			incSimpleName => 1,
		),

		new App::Dialog::Field::Person::ID(caption => 'Referring to',
			name => 'referring_physician',
			types => ['Referring-Doctor'],
			incSimpleName => 1,
		),

		new CGI::Dialog::Field(caption => 'Speciality', name => 'speciality'),
		new CGI::Dialog::Field(caption => 'Referral Type',
			name => 'referral_type',
			type => 'select',
			fKeyStmtMgr => $STMTMGR_REFERRAL_PPMS,
			fKeyStmt => 'selReferralType',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			options => FLDFLAG_PREPENDBLANK,
		),

		new CGI::Dialog::Field(caption => 'Number of Visits Allowed', name => 'allowed_visits'),
		new CGI::Dialog::Field(caption => 'Authorization Number', name => 'auth_number'),

		new CGI::Dialog::Field::Duration(
			name => 'referral',
			caption => 'Referral Begin/End Date',
			begin_caption => 'Begin Date',
			end_caption => 'End Date',
		),

		new CGI::Dialog::Field(type => 'select',
			style => 'select',
			fKeyStmtMgr => $STMTMGR_REFERRAL_PPMS,
			fKeyStmt => 'selReferralCommunication',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			caption => 'Referral Communicate',
			name => 'communication',
			style => 'radio',
		),

		new CGI::Dialog::Field(caption => 'Date of Completion',
			name => 'completion_date',
			type => 'date',
			defaultValue => ''
		),

		new CGI::Dialog::MultiField(caption=>'Referral Status',name=>"inactive_fields",
			fields=>[
				new CGI::Dialog::Field(type => 'select',
					style => 'radio',
					caption => 'Make Inactive',
					name => 'referral_status',
					selOptions => 'Active:0;Inactive:1',
					defaultValue => 0
				),
				new CGI::Dialog::Field(caption => 'Date ',
					name => 'referral_status_date',
					type => 'date',
					defaultValue => '',
					flags => FLDFLAG_INLINECAPTION
				),
			]
		),

		new CGI::Dialog::Field(caption=>'Comments',
			type=>'memo',
			name=>'comments',
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);
	$self;

}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('user_id', $page->session('user_id'));

	#if person id, create drop down of his/her payers
	if( my $personId = $page->field('patient_id') || $page->param('person_id'))
	{
		if($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selPersonData', $personId))
		{
			createPayerDropDown($self, $page, $command, $activeExecMode, $flags, $personId);
		}
		$page->field('old_person_id', $personId);
	}

}

sub createPayerDropDown
{
	my ($self, $page, $command, $activeExecMode, $flags, $personId) = @_;
	#this function called from populateData

	my $insurRecs = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selPayerChoicesByOwnerPersonId', $personId);
	my @tempInsurPlans = ();
	my @insurIntIds = ();
	my @wkCompPlans = ();
	my @thirdParties = ();
	my @planIds  = ();
	my $prevSeq = 0;
	my $insSeq;
	my $badSeq;
	foreach my $ins (@{$insurRecs})
	{
		if($ins->{group_name} eq 'Insurance')
		{
			$insSeq = $ins->{bill_seq_id};
			if($insSeq == $prevSeq + 1)
			{
				push(@tempInsurPlans, "$ins->{bill_seq}($ins->{plan_name})");
				push(@insurIntIds, $ins->{ins_internal_id});
				$prevSeq = $insSeq;
			}
			else
			{
				$badSeq = 1;
			}

			#Added to store plan internal Ids for getFS if insurance is primary
			push(@planIds,$ins->{ins_internal_id}) if $insSeq == App::Universal::INSURANCE_PRIMARY;
		}
		elsif($ins->{group_name} eq 'Workers Compensation')
		{
			push(@wkCompPlans, "Work Comp($ins->{plan_name}):$ins->{ins_internal_id}");

			#Added to store plan internal Ids for getFS
			push(@planIds,$ins->{ins_internal_id});
		}
		elsif($ins->{group_name} eq 'Third-Party')
		{
			#here the plan_name is actually the guarantor_id (the query says "select guarantor_id as plan_name, ...")
			my $thirdPartyId = $ins->{plan_name};
			if($ins->{guarantor_type} == App::Universal::ENTITYTYPE_ORG)
			{
				my $org = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $thirdPartyId);
				$thirdPartyId = $org->{org_id};
			}
			push(@thirdParties, "$ins->{group_name}($thirdPartyId):$ins->{ins_internal_id}");
		}
	}

	#if insurance sequence is out of order, do not include in payer drop down
	my @insurPlans = ();
	unless($badSeq)
	{
		@insurIntIds = join(',', @insurIntIds);
		@tempInsurPlans = join(' / ', @tempInsurPlans);
		push(@insurPlans, "@tempInsurPlans:@insurIntIds");
	}

	#create payer drop down
	my @payerList = ();

	my $insurances = join(' / ', @insurPlans) if @insurPlans;
	$insurances = "$insurances" if $insurances;
	push(@payerList, $insurances) if $insurances;

	my $workComp = join(';', @wkCompPlans) if @wkCompPlans;
	push(@payerList, $workComp) if $workComp;

	my $thirdParty = join(';', @thirdParties) if @thirdParties;
	push(@payerList, $thirdParty) if $thirdParty;

	my $thirdPartyOther = "Third-Party Payer:@{[FAKENEW3RDPARTY_INSINTID]}";
	push(@payerList, $thirdPartyOther);

	my $selfPay = "Self-Pay:@{[FAKESELFPAY_INSINTID]}";
	push(@payerList, $selfPay);

	@payerList = join(';', @payerList);

	$self->getField('payer')->{selOptions} = "@payerList";

	my $payer = $page->field('payer');
	$page->field('payer', $payer);
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
#	$command ||= 'add';

	#keep third party other invisible unless it is chosen (see customValidate)
#	$self->setFieldFlags('other_payer_fields', FLDFLAG_INVISIBLE, 1);
	$self->setFieldFlags('payer', FLDFLAG_INVISIBLE, 1);

	#Set patient_id field and make it read only if person_id exists
	if(my $personId = $page->param('person_id'))
	{
		$page->field('patient_id', $personId);
		$self->setFieldFlags('patient_id', FLDFLAG_READONLY);
		$self->updateFieldFlags('payer', FLDFLAG_INVISIBLE, 0);
	}
}

sub customValidate
{
	my ($self, $page) = @_;

	#VALIDATION FOR THIRD PARTY PERSON OR ORG
	my $payer = $page->field('payer');

	$self->updateFieldFlags('payer', FLDFLAG_INVISIBLE, 0);

	my $oldPersonId = $page->field('old_person_id');
	my $personId = $page->field('patient_id');
	if($personId ne $oldPersonId && $oldPersonId ne '')
	{
		my $payerField = $self->getField('payer');
		$payerField->invalidate($page, 'Please choose payer for Patient ID.');
		$page->field('old_person_id', $personId);
	}
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	# Populating the fields while updating the dialog
	return unless ($flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL);
	my $referralData = $STMTMGR_REFERRAL_PPMS->getRowAsHash($page, STMTMGRFLAG_NONE, 'selReferralById', $page->param('referral_id'));

	my $icdCodes = $referralData->{'rel_diags'};
	my $cptCodes = $referralData->{'code'};
	my @icd = split(', ', $icdCodes);
	$page->field('icd_code1', $icd[0]);
	$page->field('icd_code2', $icd[1]);
	my @cpt = split(', ', $cptCodes);
	$page->field('cpt_code1', $cpt[0]);
	$page->field('cpt_code2', $cpt[1]);

	my $icdData = $STMTMGR_INTELLICODE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selIcdData', $icd[0]);
	$page->field('icd_desc1', $icdData->{'descr'});

	$icdData = $STMTMGR_INTELLICODE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selIcdData', $icd[1]);
	$page->field('icd_desc2', $icdData->{'descr'});

#	my $cptData = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selFindDescByCode', $cpt[0] ,$page->session('org_internal_id') );
#	$page->field('cpt_desc1', $icdData->{'description'});

#	$cptData = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selFindDescByCode', $cpt[1] ,$page->session('org_internal_id') );
#	$page->field('cpt_desc2', $icdData->{'description'});

	$page->field('request_date', $referralData->{request_date});
	$page->field('referral_type', $referralData->{referral_type});
	$page->field('referral_urgency', $referralData->{referral_urgency});
	$page->field('referral_reason', $referralData->{referral_reason});
	$page->field('patient_id', $referralData->{person_id});
	$page->field('user_id', $referralData->{user_id});
	$page->field('requesting_physician', $referralData->{requester_id});
	$page->field('referring_physician', $referralData->{provider_id});
	$page->field('speciality', $referralData->{speciality});
	$page->field('allowed_visits', $referralData->{allowed_visits});
	$page->field('auth_number', $referralData->{auth_number});
	$page->field('referral_begin_date', $referralData->{referral_begin_date});
	$page->field('referral_end_date', $referralData->{referral_end_date});
	$page->field('communication', $referralData->{communication});
	$page->field('completion_date', $referralData->{completion_date});
	$page->field('referral_status', $referralData->{referral_status});
	$page->field('referral_status_date', $referralData->{referral_status_date});
	$page->field('comments', $referralData->{comments});

#	$self->setFieldFlags('payer', FLDFLAG_INVISIBLE, 0);
#	if( my $personId =  $page->param('person_id') || $page->field('patient_id'))
#	{
#		if($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selPersonData', $personId))
#		{
			createPayerDropDown($self, $page, $command, $activeExecMode, $flags,  $page->param('person_id'));
#		}
#		$page->field('old_person_id', $personId);
#	}

	$self->setFieldFlags('patient_id', FLDFLAG_READONLY);

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	$command ||= 'add';

	my ($insOrgId, $insProduct);
	my $payer = $page->field('payer');
	if($payer == FAKESELFPAY_INSINTID)
	{
		# self pay
	}
	elsif($payer == FAKENEW3RDPARTY_INSINTID)
	{
		# 3rd party
	}
	else
	{
		my @insurIntIds = split(/\s*,\s*/, $payer);
		my $insRecord = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insurIntIds[0]);
		$insOrgId = $insRecord->{ins_org_id};
		$insProduct =  $insRecord->{product_ins_id};
	}

	my $icd1 = $page->field('icd_code1');
	my $icd2 = $page->field('icd_code2');
	my @icd = ();
	push(@icd, $icd1) if $icd1 ne '';
	push(@icd, $icd2) if $icd2 ne '';
	my $relDiags = join (', ', @icd);

	my $code1 = $page->field('cpt_code1');
	my $code2 = $page->field('cpt_code2');
	my @cpt = ();
	push(@cpt, $code1) if $code1 ne '';
	push(@cpt, $code2) if $code2 ne '';
	my $codes = join (', ', @cpt);

	my $newId = $page->schemaAction(
		'Person_Referral', $command,
		referral_id => $page->param('referral_id') || undef,
		request_date => $page->field('request_date') || undef,
		user_id => $page->field('user_id'),
		referral_urgency => $page->field('referral_urgency'),
		referral_reason => $page->field('referral_reason'),
		referral_type => $page->field('referral_type') || undef,
		person_id => $page->field('patient_id') || undef,
		ins_org_internal_id => $insOrgId,
		product_internal_id => $insProduct,
		rel_diags => $relDiags,
		code => $codes,
		requester_id => $page->field('requesting_physician') || undef,
		provider_id => $page->field('referring_physician') || undef,
		speciality => $page->field('speciality') || undef,
		allowed_visits => $page->field('allowed_visits') || undef,
		auth_number => $page->field('auth_number') || undef,
		referral_begin_date  =>$page->field('referral_begin_date')||undef,
		referral_end_date => $page->field('referral_end_date') ||undef,
		communication => $page->field('communication') || undef,
		completion_date => $page->field('completion_date') || undef,
		referral_status => $page->field('referral_status') || undef,
		referral_status_date => $page->field('referral_status_date') || undef,
		comments => $page->field('comments') || undef,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);

}

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;


	return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
				#component.stpd-person.contactMethodsAndAddresses#<BR>
				#component.stpd-person.extendedHealthCoverage#<BR>
				#component.stpd-person.careProviders#<BR>
		});
}


1;