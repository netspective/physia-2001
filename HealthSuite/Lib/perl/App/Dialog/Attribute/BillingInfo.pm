##############################################################################
package App::Dialog::Attribute::BillingInfo;
##############################################################################

use DBI::StatementManager;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use App::Statements::Person;
use App::Statements::Org;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'billinginfo' => {
		valueType => App::Universal::ATTRTYPE_BILLING_INFO,
		heading => '$Command Electronic Billing Information',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_BILLING_INFO()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Electronic Billing Information');

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Person ID',
			name => 'parent_id',
		),
		
		new CGI::Dialog::Field(caption => 'Org ID',
			name => 'org_id',
		),

		new CGI::Dialog::Field(caption => 'ID Type',
			name => 'billing_id_type',
			type => 'select',
			selOptions => 'Unknown:5;Per Se:1;THINnet:2;Other:3',
			value => '5',
		),
		
		new CGI::Dialog::Field(caption => 'Billing ID',
			#type => 'foreignKey',
			name => 'billing_id',
#			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		),

		new CGI::Dialog::Field(caption => 'Effective Date',
			#type => 'foreignKey',
			name => 'billing_effective_date',
			type => 'date',
#			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		),
	
		new CGI::Dialog::Field(
			name => 'billing_active',
			type => 'bool',
			style => 'check',
			caption => 'Active',
			defaultValue => 0),
			
		new CGI::Dialog::Field(
			name => 'org_billing_item_id',
			type => 'hidden'
		),
		
		new CGI::Dialog::Field(
			name => 'org_billing_internal_id',
			type => 'hidden'
		),
		
		new CGI::Dialog::Field(
			name => 'debug_info',
			type => 'text'
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	$self->updateFieldFlags('parent_id', FLDFLAG_READONLY, 1) if (($command eq 'update') or ($command eq 'remove'));
	$self->updateFieldFlags('parent_id', FLDFLAG_INVISIBLE, 1) if ((defined $page->param('org_id')) and not defined $page->param('item_id'));
	$self->updateFieldFlags('org_id', FLDFLAG_READONLY, 1) if (($command eq 'update') or ($command eq 'remove'));
	$self->updateFieldFlags('org_id', FLDFLAG_INVISIBLE, 1) if ((defined $page->param('person_id')) and not defined $page->param('item_id'));
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

#	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');
	my $orgId = $page->param('org_id');
	my $billingInfo;
	my $billingExists = 0;
	my $orgBillingExists = 0;
	my $orgRecord = $STMTMGR_ORG->getRowAsArray($page, STMTMGRFLAG_NONE, 'selOwnerOrgId', $orgId) if ($orgId);
	my $orgIntId = ($orgId ? $orgRecord->[0] : 0);
	$billingExists = $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId) if ($itemId);

	# Does a new-style clearing house billing record exist for this org?
	my $newClearHouseDataExists = $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,
		'selAttributeByItemNameAndValueTypeAndParent', $orgIntId, 'Organization Default Clearing House ID',
		App::Universal::ATTRTYPE_BILLING_INFO
	);
	my $oldClearHouseDataExists = $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,
		'selAttributeByItemNameAndValueTypeAndParent', $orgIntId, 'Clearing House ID',
		App::Universal::ATTRTYPE_TEXT
	);

	$page->field ('org_id', $page->param ('org_id'));
	$page->field ('debug_info', $page->param ('org_id')."($orgIntId)");
	my $clearHouseData;
	if ($billingExists) {
		$billingInfo = $STMTMGR_PERSON->getRowAsArray($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

		$page->field ('parent_id', $billingInfo->[2]);
		$page->field ('billing_id_type', $billingInfo->[9]);
		$page->field ('billing_id', $billingInfo->[6]);
		$page->field ('billing_effective_date', $billingInfo->[13]);
		$page->field ('billing_active', $billingInfo->[7]);
	} elsif ($newClearHouseDataExists) {
		# Read the new-style clearing house billing record...
		$clearHouseData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE,
			'selAttributeByItemNameAndValueTypeAndParent', $orgIntId, 'Organization Default Clearing House ID',
			App::Universal::ATTRTYPE_BILLING_INFO
		);

		# Populate the fields with data from the appropriate columns...
		$page->field('billing_id_type', $clearHouseData->{value_int});
		$page->field('billing_id', $clearHouseData->{value_text});
		$page->field('billing_active', $clearHouseData->{value_textB});
		$page->field('billing_effective_date', $clearHouseData->{value_date});
#		$page->field('org_billing_item_id', $clearHouseData->{item_id});
		$page->field ('parent_id', $page->param('person_id'));
		$page->field ('org_id', $page->param ('org_id'));
		$page->field ('org_billing_internal_id', $orgIntId);
	} elsif ($oldClearHouseDataExists) {
		# Read the new-style clearing house billing record...
		$clearHouseData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE,
			'selAttributeByItemNameAndValueTypeAndParent', $orgIntId, 'Clearing House ID',
			App::Universal::ATTRTYPE_TEXT
		);

		# Setup the translation mechanism for old-style fields to new-style values...
		my %clearingHouse = ( 'perse' => 1, 'thinet' => 2 );

		# Populate the fields with data from the appropriate columns...
		$page->field('billing_id_type', $clearingHouse {lc ($clearHouseData->{value_text})});
		$page->field('billing_id', $clearHouseData->{value_textB});
		$page->field('billing_active', 0);
		$page->field('billing_effective_date', $page->getDate());
#		$page->field('org_billing_item_id', $clearHouseData->{item_id});
		$page->field ('parent_id', $page->param('person_id'));
		$page->field ('org_id', $page->param ('org_id'));
		$page->field ('org_billing_internal_id', $orgIntId);
	} else {
		$page->field ('parent_id', $page->param('person_id'));
		$page->field ('billing_id_type', 5);
		$page->field ('billing_effective_date', $page->getDate());
	}


#		my $clearHouseData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE,
#			'selAttributeByItemNameAndValueTypeAndParent', $orgIntId, 'Organization Default Clearing House ID',
#			App::Universal::ATTRTYPE_BILLING_INFO
#		);
		
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $valueType = $self->{valueType};
	my $billingActive = $page->field ('billing_active') ? 1 : 0;
	
	if (defined $page->param ('person_id')) {
		# Add a person's billing information record...
		$page->schemaAction(
			'Person_Attribute',	$command,
			parent_id => $page->field('parent_id'),
			item_name => 'Physician Clearing House ID',
			item_id => $page->param('item_id') || undef,
			value_type => $valueType || undef,
			value_text => $page->field('billing_id') || undef,
			value_textB => $billingActive,
			value_int => $page->field('billing_id_type') || undef,
			value_date => $page->field('billing_effective_date') || undef,
			_debug => 0
		);
	}
	
	if (defined $page->param ('org_id')) {
		my $orgRecord = $STMTMGR_ORG->getRowAsArray($page, STMTMGRFLAG_NONE, 'selOwnerOrgId', $page->param ('org_id'));
		my $orgIntId = $orgRecord->[0];
		
		# Add an org's global billing information record...
		$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_id => $page->param('item_id') || undef,
			item_name => 'Organization Default Clearing House ID',
			value_type => App::Universal::ATTRTYPE_BILLING_INFO || undef,
			value_text => $page->field('billing_id') || undef,
			value_textB => ($page->field('billing_active') ? 1 : 0),
			value_int => $page->field('billing_id_type') || undef,
			value_date => $page->field('billing_effective_date') || undef,
			_debug => 0
		);
	}
	
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);

	return "\u$command completed.";
}

1;
