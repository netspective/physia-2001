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
		_arl_add => ['entity_id', 'entity_type'],
		_arl_modify => ['item_id', 'entity_type'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_BILLING_INFO()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Clearing House Billing Information');

	$self->addContent(
		new App::Dialog::Field::Person::ID(caption => 'Physician ID',
			name => 'person_id',
			types => ['Physician'],
			options => FLDFLAG_REQUIRED,
		),
		new App::Dialog::Field::Organization::ID(caption => 'Organization ID',
			name => 'org_id',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(caption => 'Clearing House',
			name => 'billing_id_type',
			type => 'select',
			selOptions => 'Per-Se:0; THINet:2; Other:3',
		),
		new CGI::Dialog::Field(caption => 'Billing ID',
			name => 'billing_id',
			size => 16,
			options => FLDFLAG_REQUIRED,
		),
		new App::Dialog::Field::Scheduling::Date(caption => 'Effective Date',
			name => 'billing_effective_date',
		),
		new CGI::Dialog::Field(caption => 'Process Live Claims',
			name => 'billing_active',
			type => 'bool',
			style => 'check',
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	$self->updateFieldFlags('person_id', FLDFLAG_READONLY, 1)
		if (($command eq 'update') or ($command eq 'remove'));
	$self->updateFieldFlags('person_id', FLDFLAG_INVISIBLE, $page->param('entity_type'));

	$self->updateFieldFlags('org_id', FLDFLAG_READONLY, 1)
		if (($command eq 'update') or ($command eq 'remove'));
	$self->updateFieldFlags('org_id', FLDFLAG_INVISIBLE, ! $page->param('entity_type'));
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	$page->field('person_id', $page->param('person_id'));
	$page->field('org_id', $page->param('org_id'));
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $stmtMgr = $page->param('entity_type') ? $STMTMGR_ORG : $STMTMGR_PERSON;

	my $attribute = $stmtMgr->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeById',
		$page->param('item_id'));

	$page->field('person_id', $page->param('person_id') || $attribute->{parent_id});
	$page->field('org_id', $page->param('org_id'));
	$page->field('billing_id_type', $attribute->{value_int});
	$page->field('billing_id', $attribute->{value_text});
	$page->field('billing_effective_date', $attribute->{value_date});
	$page->field('billing_active', $attribute->{value_intb} || 0);
}

sub populateData_remove
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$self->populateData_update($page, $command, $activeExecMode, $flags);
}

sub customValidate
{
	my ($self, $page) = @_;

	if ($page->param('entity_type'))
	{
		my $activeCheck = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_ActiveOrgBillingIds',
			$page->session('org_internal_id'));

		if ($activeCheck->{item_id} && $page->field('billing_active') &&
			$page->param('item_id') != $activeCheck->{item_id})
		{
			my $field = $self->getField('org_id');
			$field->invalidate($page, qq{Only One Billing ID can be Active for Processing Live Claims per Org.});
		}
	}
	else
	{
		my $activeCheck = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_ActivePersonBillingIds',
			$page->field('person_id'));

		if ($activeCheck->{item_id} && $page->field('billing_active') &&
			$page->param('item_id') != $activeCheck->{item_id})
		{
			my $field = $self->getField('person_id');
			$field->invalidate($page, qq{Only One Billing ID can be Active for Processing Live Claims per Physician.});
		}
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $valueType = $self->{valueType};
	my $billingActive = $page->field ('billing_active') ? 1 : 0;

	if ($page->param ('entity_type')) {
		my $orgRecord = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selOwnerOrgId',
			$page->param ('org_id'));
		my $orgIntId = $orgRecord->{org_internal_id};

		# Add an org's global billing information record...
		$page->schemaAction(
			'Org_Attribute', $command,
			parent_id => $orgIntId,
			item_id => $page->param('item_id') || undef,
			item_name => 'Organization Default Clearing House ID',
			value_type => App::Universal::ATTRTYPE_BILLING_INFO || undef,
			value_text => $page->field('billing_id') || undef,
			value_int => $page->field('billing_id_type') || 0,
			value_intB => $billingActive || 0,
			value_date => $page->field('billing_effective_date') || undef,
			_debug => 0
		);
	}
	else
	{
		$page->schemaAction(
			'Person_Attribute',	$command,
			parent_id => $page->field('person_id'),
			item_name => 'Physician Clearing House ID',
			item_id => $page->param('item_id') || undef,
			value_type => $valueType || undef,
			value_text => $page->field('billing_id') || undef,
			value_int => $page->field('billing_id_type') || 0,
			value_intB => $billingActive || 0,
			value_date => $page->field('billing_effective_date') || undef,
			_debug => 0
		);
	}

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);

	return "\u$command completed.";
}

1;
