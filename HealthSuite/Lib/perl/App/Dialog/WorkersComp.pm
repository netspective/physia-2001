##############################################################################
package App::Dialog::WorkersComp;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Insurance;

use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Insurance;
use App::Dialog::Field::Address;
use App::Universal;

use Date::Manip;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, heading => '$Command Workers Compensation', id => 'workerscomp');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'phone_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'fax_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'address_item_id'),

		new App::Dialog::Field::Insurance::ID::New(caption => 'Workers Compensation Plan ID',
						name => 'ins_id',
						options => FLDFLAG_REQUIRED),

		new App::Dialog::Field::Organization::ID(caption => 'Insurance Org ID',
						name => 'ins_org_id',
						options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field::TableColumn(caption => 'Remittance Type',
						name => 'remit_type',
						schema => $schema,
						column => 'Insurance.Remit_Type'),

		new CGI::Dialog::Field::TableColumn(caption => 'E-Remittance Payer ID',
						hints=> '(Only for non-Paper types)',
						name => 'remit_payer_id',
						schema => $schema,
						column => 'REF_Envoy_Payer.ID',
						findPopup => '/lookup/insurance/envoyid'),

		new CGI::Dialog::Subhead(heading => 'Contact Information', name => 'contact_heading'),

		new App::Dialog::Field::Address(caption=>'Billing Address', name => 'billing_addr',
							options => FLDFLAG_REQUIRED),

		new CGI::Dialog::MultiField(caption =>'Phone/Fax', name => 'phone_fax',
			fields => [
					new CGI::Dialog::Field(type=>'phone',
							caption => 'Phone',
							name => 'phone',
							options => FLDFLAG_REQUIRED,
							invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
					new CGI::Dialog::Field(type=>'phone',
							caption => 'Fax',
							name => 'fax',
							invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
			]),

	);
	$self->{activityLog} =
	{
		scope =>'insurance',
		key => "#field.ins_org_id#",
		data => "Workers Comp Plan '#field.ins_id#' to <a href='/org/#field.ins_org_id#/profile'>#field.ins_org_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $insIntId = $page->param('ins_internal_id');
	$STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId);
	$STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsuranceAddr', $insIntId);

	my $insPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Contact Method/Telephone/Primary');
	$page->field('phone_item_id', $insPhone->{item_id});
	$page->field('phone', $insPhone->{value_text});

	my $insFax = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insIntId, 'Contact Method/Fax/Primary');
	$page->field('fax_item_id', $insFax->{item_id});
	$page->field('fax', $insFax->{value_text});

	my $insAddr = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAddr', $insIntId);
	$page->field('address_item_id', $insAddr->{item_id});
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	if(my $wrkcompId = $page->param('ins_id'))
	{
		$page->field('ins_id', $wrkcompId);
	}
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my $orgId = $page->param('org_id');
	my $remitType = $page->field('remit_type');
	my $insId = $page->field('ins_id');
	my $insOrgId = $page->field('ins_org_id');

	my $insIntId = $page->schemaAction(
			'Insurance', 'add',
			ins_id => $insId || undef,
			ins_org_id => $insOrgId || undef,
			ins_type => App::Universal::CLAIMTYPE_WORKERSCOMP || undef,
			remit_type => defined $remitType ? $remitType : undef,
			remit_payer_id => $page->field('remit_payer_id') || undef,
			remit_payer_name => $page->field('remit_payer_name') || undef,
			record_type => App::Universal::RECORDTYPE_INSURANCEPLAN || undef,
			_debug => 0
		);

	#add contact info
	$page->schemaAction(
			'Insurance_Address', 'add',
			parent_id => $insIntId,
			address_name => 'Billing',
			line1 => $page->field('addr_line1') || undef,
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city') || undef,
			state => $page->field('addr_state') || undef,
			zip => $page->field('addr_zip') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Insurance_Attribute', 'add',
			parent_id => $insIntId,
			item_name => 'Contact Method/Telephone/Primary',
			value_type => App::Universal::ATTRTYPE_PHONE || undef,
			value_text => $page->field('phone') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Insurance_Attribute', 'add',
			parent_id => $insIntId,
			item_name => 'Contact Method/Fax/Primary',
			value_type => App::Universal::ATTRTYPE_FAX || undef,
			value_text => $page->field('fax') || undef,
			_debug => 0
		);

	$self->attachWCPlanToOrg($page, $flags, $insIntId);
}

sub attachWCPlanToOrg
{
	my ($self, $page, $flags, $insIntId) = @_;

	my $orgId = $page->param('org_id');

	my $insData = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId);
	my $insOrgId = $insData->{ins_org_id};
	my $insId = $insData->{ins_id};

	my $primaryName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $insOrgId);

	if($orgId)
	{
		$page->schemaAction(
			'Org_Attribute', 'add',
			parent_id => $orgId,
			item_name => $insOrgId,
			value_type => App::Universal::ATTRTYPE_INSGRPWORKCOMP || undef,
			value_text => $insId,
			value_textB => $primaryName,
			value_int => $insIntId,
			_debug => 0
		);
	}

	if($insOrgId ne $orgId)
	{
		$page->schemaAction(
			'Org_Attribute', 'add',
			parent_id => $insOrgId,
			item_name => $insOrgId,
			value_type => App::Universal::ATTRTYPE_INSGRPWORKCOMP || undef,
			value_text => $insId,
			value_textB => $primaryName,
			value_int => $insIntId,
			_debug => 0
		);
	}

	$self->handlePostExecute($page, 'add', $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return 'Add completed.';
}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $insIntId = $page->param('ins_internal_id');
	my $remitType = $page->field('remit_type');

	$page->schemaAction(
			'Insurance', 'update',
			ins_internal_id => $insIntId || undef,
			ins_id => $page->field('ins_id') || undef,
			ins_org_id => $page->field('ins_org_id') || undef,
			remit_type => defined $remitType ? $remitType : undef,
			remit_payer_id => $page->field('remit_payer_id') || undef,
			remit_payer_name => $page->field('remit_payer_name') || undef,
			_debug => 0
		);

	#update contact info
	$page->schemaAction(
			'Insurance_Address', 'update',
			item_id => $page->field('address_item_id') || undef,
			line1 => $page->field('addr_line1') || undef,
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city') || undef,
			state => $page->field('addr_state') || undef,
			zip => $page->field('addr_zip') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Insurance_Attribute', 'update',
			item_id => $page->field('phone_item_id') || undef,
			value_text => $page->field('phone') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Insurance_Attribute', 'update',
			item_id => $page->field('fax_item_id') || undef,
			value_text => $page->field('fax') || undef,
			_debug => 0
		);

	$self->updateChildrenPlans($page, $flags, $insIntId);
}

sub updateChildrenPlans
{
	my ($self, $page, $flags, $insIntId) = @_;

	my $insData = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId);
	my $remitType = $insData->{remit_type};
	my $insId = $insData->{ins_id};
	my $insOrgId = $insData->{ins_org_id};

	my $childPlans = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selChildrenPlans', $insIntId);
	foreach (@{$childPlans})
	{
		$page->schemaAction(
			'Insurance', 'update',
 			ins_internal_id => $_->{ins_internal_id} || undef,
 			ins_id => $insId || undef,
 			ins_org_id => $insOrgId || undef,
 			remit_type => defined $remitType ? $remitType : undef,
 			remit_payer_id => $insData->{remit_payer_id} || undef,
 			remit_payer_name => $insData->{remit_payer_name} || undef,
 			_debug => 0
 		);
	}

	my $primaryName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $insOrgId);
	my $attachedWrkCompAttrs = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAllWrkCmpAttr', $insIntId, App::Universal::ATTRTYPE_INSGRPWORKCOMP);
	foreach (@{$attachedWrkCompAttrs})
	{
		$page->schemaAction(
			'Org_Attribute', 'update',
			item_id => $_->{item_id} || undef,
			item_name => $insOrgId || undef,
			value_text => $insId || undef,
			value_textB => $primaryName || undef,
			_debug => 0
		);
	}

	$self->handlePostExecute($page, 'update', $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return 'Update completed.';
}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $insIntId = $page->param('ins_internal_id');

	$page->schemaAction(
			'Insurance', 'remove',
			ins_internal_id => $insIntId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Insurance_Address', 'remove',
			item_id => $page->field('address_item_id') || undef,
			_debug => 0
		);

	$self->removeChildrenPlans($page, $flags, $insIntId);
}

sub removeChildrenPlans
{
	my ($self, $page, $flags, $insIntId) = @_;

	my $childPlans = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selChildrenPlans', $insIntId);
	foreach (@{$childPlans})
	{
		$page->schemaAction(
			'Insurance', 'remove',
 			ins_internal_id => $_->{ins_internal_id} || undef,
 			_debug => 0
 		);
	}

	my $attachedWrkCompAttrs = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAllWrkCmpAttr', $insIntId, App::Universal::ATTRTYPE_INSGRPWORKCOMP);
	foreach (@{$attachedWrkCompAttrs})
	{
		$page->schemaAction(
			'Org_Attribute', 'remove',
			item_id => $_->{item_id} || undef,
			_debug => 0
		);
	}

	$self->handlePostExecute($page, 'remove', $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return 'Remove completed.';
}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hierarchies
# 4: any text notes about the actual change/action
#
use constant WORKCOMP_DIALOG => 'Dialog/Workers Comp';

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'MAF',
		WORKCOMP_DIALOG,
		'Added contact information section.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '12/29/1999', 'RK',
		WORKCOMP_DIALOG,
		'Updated the code in execute subroutine so that the child plans will be updated if a Workers Comp plan is updated. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '03/07/2000', 'MAF',
		WORKCOMP_DIALOG,
		'Fixed attribute types.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '03/15/2000', 'MAF',
		WORKCOMP_DIALOG,
		'Reconstructed entire workers comp dialog. Added new functions for updating/deleting children plans and attached org attributes.'],
);

1;
