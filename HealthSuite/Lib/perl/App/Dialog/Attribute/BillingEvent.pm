##############################################################################
package App::Dialog::Attribute::BillingEvent;
##############################################################################

use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Person;
use App::Universal;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'org-billing-event' => {
		valueType => App::Universal::ATTRTYPE_BILLINGEVENT,
		heading => '$Command Org Billing Event',
		table => 'Org_Attribute',
		_arl => ['org_id'] ,
		_arl_modify => ['item_id'],
		},
	'person-billing-event' => {
		valueType => App::Universal::ATTRTYPE_BILLINGEVENT,
		heading => '$Command Person Billing Event',
		table => 'Person_Attribute',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		},
);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'org-notes');
	my $schema = $self->{schema};
	my $table = $self->{table};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Billing Cycle',
			hints => 'Day of Month (1..28)',
			name => 'value_int', size => 2, maxLength => 2, type => 'integer',
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::MultiField(caption => 'Name From',
			name => 'name_from',
			fields => [
				new CGI::Dialog::Field(name => 'value_text', size => 1, maxLength => 1, 
					options => FLDFLAG_UPPERCASE),
				new CGI::Dialog::Field(name => 'value_textb', size => 1, caption => 'to ', 
					maxLength => 1,
					options => FLDFLAG_INLINECAPTION | FLDFLAG_UPPERCASE),
			],
		),
		new CGI::Dialog::MultiField(caption => 'Balance is',
			name => 'balance_criteria',
			fields => [
				new CGI::Dialog::Field(name => 'value_intb', type => 'select', 
					selOptions => 'Greater Than:1;Less Than:-1'),
				new CGI::Dialog::Field(name => 'value_float', type => 'currency', defaultValue => 0),
			],
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}


sub customValidate
{
	my ($self, $page) = @_;

	if ($page->field('value_text') gt $page->field('value_textb'))
	{
		my $nameField = $self->getField('name_from');
		$nameField->invalidate($page, "Second field cannot be alphabetically less than first");
	}

	if ($page->field('value_int') > 28)
	{
		my $dayField = $self->getField('value_int');
		$dayField->invalidate($page, "Day of month cannot be greater than 28");
	}
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $table = $self->{table};
	my $itemId = $page->param('item_id');

	if ($table eq 'Person_Attribute')
	{
		$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
	}
	elsif ($table eq 'Org_Attribute')
	{
		$STMTMGR_ORG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
	}
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;
	my $table = $self->{table};

	my $parentId = $page->param('person_id');
	if ($page->param('org_id'))
	{
		$parentId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id'));
	}

	$page->schemaAction(
		$table, $command,
		parent_id => $parentId || undef,
		item_id => $page->param('item_id') || undef,
		item_name => 'Billing Event',
		value_type => App::Universal::ATTRTYPE_BILLINGEVENT,
		value_text => $page->field('value_text') || 'A',
		value_textB => $page->field('value_textb') || 'Z',
		value_int => $page->field('value_int') || 1,
		value_intB => $page->field('value_intb') || 1,
		value_float => $page->field('value_float') || 0,
		_debug => 0
	);
	return "\u$command completed.";
}

1;
