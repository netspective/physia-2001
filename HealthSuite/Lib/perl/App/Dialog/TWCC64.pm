##############################################################################
package App::Dialog::TWCC64;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Person;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Invoice;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'twcc64' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'twcc64', heading => 'TWCC Form 64');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(		
		new CGI::Dialog::Field(type => 'hidden', name => 'field17_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field18_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field20_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field21_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field23_item_id'),

		#17
		new CGI::Dialog::Field(type => 'select',  name => 'reason_for_report', 
				selOptions => 'Subsequent Medical Report (due every 60 days after initial medical report):1;Released to Return to Work:2;Changing Treating Doctors:3;Discharged From Hospital:4', 
				caption => 'Reason for Report',
				options => FLDFLAG_REQUIRED | FLDFLAG_PREPENDBLANK,
				onChangeJS => qq{showFieldsOnValues(event, [2], ['activity_fields']); showFieldsOnValues(event, [3], ['provider_fields']); showFieldsOnValues(event, [4], ['hospital_fields']);},),

		new CGI::Dialog::MultiField(caption => 'Activity Type', name => 'activity_fields',
			fields => [
				new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Limited Activity:1;Normal Activity:2', name => 'activity'),
				new CGI::Dialog::Field(type => 'date', caption => 'Date Report Mailed to Employee', name => 'activity_date', defaultValue => ''),
			]),
		
		new CGI::Dialog::MultiField(caption => 'New Treating Provider', name => 'provider_fields',
			fields => [
				new CGI::Dialog::Field(
						caption => 'Treating Provider',
						name => 'provider',
						fKeyStmtMgr => $STMTMGR_PERSON,
						fKeyStmt => 'selPersonBySessionOrgAndCategory',
						fKeyDisplayCol => 0,
						fKeyValueCol => 0
						),
				new CGI::Dialog::Field(type => 'date', caption => 'Discharge Date', name => 'provider_date', defaultValue => ''),
			]),

		new CGI::Dialog::MultiField(caption => 'Hospital Name and Date', name => 'hospital_fields',
			fields => [
				new CGI::Dialog::Field(name => 'hospital'),
				new CGI::Dialog::Field(type => 'date', caption => 'Discharge Date', name => 'discharge_date', defaultValue => ''),
			]),

		
		#18
		new CGI::Dialog::Field(type => 'memo', caption => "Changes in Injured Employee's Condition, Including Clinical Assessment and Test Results", name => 'change_in_condition'),

		#20
		new CGI::Dialog::Field(type => 'memo', caption => 'Referrals', name => 'referrals'),
		
		#21
		new CGI::Dialog::Field(type => 'memo', caption => 'Medications or Durable Medical Equipment', name => 'equipment'),
		
		#23
		new CGI::Dialog::Field(type => 'memo', caption => 'Compliance by Injured Employee with Recommended Treatment', name => 'compliance_by_employee'),
		
		#24 - is doctor's signature and address
		);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	#Populate provider id field and org fields with session org's providers
	my $sessOrgIntId = $page->session('org_internal_id');
	$self->getField('provider_fields')->{fields}->[0]->{fKeyStmtBindPageParams} = [$sessOrgIntId, 'Physician'];
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $invoiceId = $page->param('invoice_id');

	#populate field 17
	my $field17 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC64/17');
	$page->field('field17_item_id', $field17->{item_id});

	my $reason = $field17->{value_int};
	$page->field('reason_for_report', $reason);
	my $field17Text = $field17->{value_text};
	my $field17Date = $field17->{value_date};
	if($reason == 2)
	{
		$page->field('activity', $field17Text);
		$page->field('activity_date', $field17Date);
	}
	elsif($reason == 3)
	{
		$page->field('provider', $field17Text);
		$page->field('provider_date', $field17Date);
	}
	elsif($reason == 4)
	{
		$page->field('hospital', $field17Text);
		$page->field('discharge_date', $field17Date);
	}


	#populate field 18
	my $field18 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC64/18');
	$page->field('field18_item_id', $field18->{item_id});
	$page->field('change_in_condition', $field18->{value_text});


	#populate field 20
	my $field20 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC64/20');
	$page->field('field20_item_id', $field20->{item_id});
	$page->field('referrals', $field20->{value_text});


	#populate field 21
	my $field21 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC64/21');
	$page->field('field21_item_id', $field21->{item_id});
	$page->field('equipment', $field21->{value_text});


	#populate field 23
	my $field23 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC64/23');
	$page->field('field23_item_id', $field23->{item_id});
	$page->field('compliance_by_employee', $field23->{value_text});

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	my $field17 = '';
	my $field17Date = '';
	my $reason = $page->field('reason_for_report');
	if($reason == 2)
	{
		$field17 = $page->field('activity');
		$field17Date = $page->field('activity_date');
	}
	elsif($reason == 3)
	{
		$field17 = $page->field('provider');
		$field17Date = $page->field('provider_date');
	}
	elsif($reason == 4)
	{
		$field17 = $page->field('hospital');
		$field17Date = $page->field('discharge_date');
	}
	
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC64/17',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $field17 || undef,
			value_date => $field17Date || undef,
			value_int => $reason || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field18_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC64/18',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('change_in_condition') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field20_item_id') || undef,
			item_name => 'Invoice/TWCC64/20',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('referrals') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field21_item_id') || undef,
			item_name => 'Invoice/TWCC64/21',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('equipment') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field23_item_id') || undef,
			item_name => 'Invoice/TWCC64/23',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('compliance_by_employee') || undef,
			_debug => 0
	);

	$page->redirect("/invoice/$invoiceId/summary");
}

1;