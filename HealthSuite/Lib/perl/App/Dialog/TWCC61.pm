##############################################################################
package App::Dialog::TWCC61;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Invoice;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'twcc61' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'twcc61', heading => 'TWCC Form 61');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(		
		new CGI::Dialog::Field(type => 'hidden', name => 'field16_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field17_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field18_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field20_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field21_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field22_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field23_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field24_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field26_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field27_item_id'),

		#16
		new CGI::Dialog::Field(type => 'date', caption => 'Return to limited type of work', name => 'return_to_lmtd_work', defaultValue => ''),
		new CGI::Dialog::Field(type => 'date', caption => 'Achieve maximum medical improvement', name => 'max_medical_improve', defaultValue => ''),
		new CGI::Dialog::Field(type => 'date', caption => 'Return to full-time work', name => 'return_to_full_time', defaultValue => ''),

		#17
		new CGI::Dialog::Field(type => 'memo', caption => 'History of Occupational Injury or Illness', name => 'injury_history'),

		#18
		new CGI::Dialog::Field(type => 'memo', caption => 'Significant Past Medical History', name => 'med_history'),

		#19
		new CGI::Dialog::Field(type => 'memo', caption => 'Clinical Assessment Findings', name => 'clinical_assessment'),

		#20
		new CGI::Dialog::Field(type => 'memo', caption => 'Laboratory, Radiographic, and/or Imaging Tests Ordered and Results', name => 'lab_tests'),

		#21
		new CGI::Dialog::Field(type => 'memo', caption => 'Treatment Plan', name => 'treatment_plan'),

		#22
		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Referrals:1;Change of Treating Doctor:2', caption => 'Referrals or Change of Treating Doctor', 
				name => 'referrals_select'),
		new CGI::Dialog::Field(type => 'memo', caption => 'Details', name => 'referrals_details'),

		#23
		new CGI::Dialog::Field(type => 'memo', caption => 'Medications or Durable Medical Equipment', name => 'medications'),

		#24
		new CGI::Dialog::Field(type => 'memo', caption => 'Prognosis', name => 'prognosis'),
		
		#25 - is doctor's signature and address
		
		#26
		new CGI::Dialog::Field(type => 'date', caption => 'Date Report Mailed to Employee', name => 'mailed_to_employee', defaultValue => ''),

		#27
		new CGI::Dialog::Field(type => 'date', caption => 'Date Report Mailed to Workers Compensation Insurance Carrier', name => 'mailed_to_insurance', defaultValue => ''),
		);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $invoiceId = $page->param('invoice_id');

	#populate field 16
	my $field16 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/16');
	$page->field('field16_item_id', $field16->{item_id});
	$page->field('return_to_lmtd_work', $field16->{value_date});
	$page->field('max_medical_improve', $field16->{value_datea});
	$page->field('return_to_full_time', $field16->{value_dateb});	

	#populate field 17
	my $field17 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/17');
	$page->field('field17_item_id', $field17->{item_id});
	$page->field('injury_history', $field17->{value_text});

	#populate field 18
	my $field18 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/18');
	$page->field('field18_item_id', $field18->{item_id});
	$page->field('med_history', $field18->{value_text});

	#populate field 19
	my $field19 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/19');
	$page->field('field19_item_id', $field19->{item_id});
	$page->field('clinical_assessment', $field19->{value_text});

	#populate field 20
	my $field20 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/20');
	$page->field('field20_item_id', $field20->{item_id});
	$page->field('lab_tests', $field20->{value_text});

	#populate field 21
	my $field21 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/21');
	$page->field('field21_item_id', $field21->{item_id});
	$page->field('treatment_plan', $field21->{value_text});

	#populate field 22
	my $field22 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/22');
	$page->field('field22_item_id', $field22->{item_id});
	$page->field('referrals_details', $field22->{value_text});
	$page->field('referrals_select', $field22->{value_int});

	#populate field 23
	my $field23 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/23');
	$page->field('field23_item_id', $field23->{item_id});
	$page->field('medications', $field23->{value_text});

	#populate field 24
	my $field24 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/24');
	$page->field('field24_item_id', $field24->{item_id});
	$page->field('prognosis', $field24->{value_text});

	#populate field 26
	my $field26 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/26');
	$page->field('field26_item_id', $field26->{item_id});
	$page->field('mailed_to_employee', $field26->{value_date});

	#populate field 27
	my $field27 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/27');
	$page->field('field27_item_id', $field27->{item_id});
	$page->field('mailed_to_insurance', $field27->{value_date});
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $dateValueType = App::Universal::ATTRTYPE_DATE;

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field16_item_id') || undef,
			parent_id => $invoiceId,			
			item_name => 'Invoice/TWCC61/16',
			value_type => defined $dateValueType ? $dateValueType : undef,			
			value_date => $page->field('return_to_lmtd_work') || undef,
			value_dateA => $page->field('max_medical_improve') || undef,
			value_dateB => $page->field('return_to_full_time') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/17',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('injury_history') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field18_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/18',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('med_history') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field19_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/19',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('clinical_assessment') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field20_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/20',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('lab_tests') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field21_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/21',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('treatment_plan') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field22_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/22',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('referrals_details') || undef,
			value_int => $page->field('referrals_select') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field23_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/23',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('medications') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field24_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/24',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('prognosis') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field26_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/26',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_date => $page->field('mailed_to_employee') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field27_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC61/27',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_date => $page->field('mailed_to_insurance') || undef,
			_debug => 0
	);

	$page->redirect("/invoice/$invoiceId/summary");
}

1;
