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
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'billinginfo' => {
		valueType => App::Universal::ATTRTYPE_BILLING_INFO,
		heading => '$Command Billing Information',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_BILLING_INFO()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Billing Information');

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Person ID',
			name => 'parent_id',
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
	);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	$self->updateFieldFlags('parent_id', FLDFLAG_READONLY, 1) if (($command eq 'update') or ($command eq 'remove'));
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

#	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');
	my $billingInfo;
	my $billingExists = 0;
	$billingExists = $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId) if ($itemId);

	if ($billingExists) {
		$billingInfo = $STMTMGR_PERSON->getRowAsArray($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

		$page->field ('parent_id', $billingInfo->[2]);
		$page->field ('billing_id_type', $billingInfo->[9]);
		$page->field ('billing_id', $billingInfo->[6]);
		$page->field ('billing_effective_date', $billingInfo->[13]);
		$page->field ('billing_active', $billingInfo->[7]);
	} else {
		$page->field ('parent_id', $page->param('person_id'));
		$page->field ('billing_id_type', 5);
		$page->field ('billing_effective_date', $page->getDate());
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $valueType = $self->{valueType};
	my $billingActive = $page->field ('billing_active') ? 1 : 0;
	
	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->field('parent_id'),
		item_name => 'Physician',
		item_id => $page->param('item_id') || undef,
		value_type => $valueType || undef,
		value_text => $page->field('billing_id') || undef,
		value_textB => $billingActive,
		value_int => $page->field('billing_id_type') || undef,
		value_date => $page->field('billing_effective_date') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);

	return "\u$command completed.";
}

1;
