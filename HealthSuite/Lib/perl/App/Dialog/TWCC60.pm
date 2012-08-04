##############################################################################
package App::Dialog::TWCC60;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Address;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'twcc60' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'twcc60', heading => 'TWCC Form 60');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(		
		new CGI::Dialog::Field(type => 'hidden', name => 'field1_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field2_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field3_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field4_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field5_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field6_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field22_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field23_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field24_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field25_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field26_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field27_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field28_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field29_item_id'),

		######### Part I
		new CGI::Dialog::Subhead(heading => 'Part I: Requestor Information (requestor completes this section)', name => 'part1_heading'),

		#1
		new CGI::Dialog::Field(type => 'select',  name => 'requestor_type', style => 'radio',
				selOptions => 'HCP:1;IC:2;IE:3', 
				caption => 'Type of Requestor',
				options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'select',  name => 'dispute_type', 
				selOptions => 'TWCC Refund Order Appeal:1;Medical Necessity:2;Carrier Request for Refund:3;Fee Reimbursement:4;Preauthorization:5', 
				caption => 'Type of Dispute',
				options => FLDFLAG_REQUIRED),

		#2
		new CGI::Dialog::Field(caption => "Requestor's Name", name => 'requestor_name'),

		#3
		#new App::Dialog::Field::Address(caption => "Requestor's Address", name => 'requestor_addr'),
		new CGI::Dialog::Field(caption => "Requestor's Address", name => 'requestor_addr1'),
		new CGI::Dialog::Field(caption => "Requestor's City, State, ZIP", name => 'requestor_addr2'),

		#4
		new CGI::Dialog::Field(caption => "Contact Person's Name", name => 'contact1_name'),
		
		#4 and 5
		new CGI::Dialog::MultiField(name => 'contact2_phone_fax', caption => "Contact's Phone/Fax #",
			fields => [
				new CGI::Dialog::Field(type => 'phone', caption => "Contact's Telephone #", name => 'contact1_phone'),
				new CGI::Dialog::Field(type => 'phone', caption => "Contact's Fax #", name => 'contact1_fax'),
			]),

		#5
		new CGI::Dialog::Field(type => 'email', caption => "Contact's E-mail", name => 'contact1_email'),

		#6
		new CGI::Dialog::Field(caption => 'FEIN', name => 'fein1'),
		new CGI::Dialog::Field(caption => 'Professional License # (if applicable)', name => 'prof_license1'),


		######### Part II
		new CGI::Dialog::Subhead(heading => 'Part II: General Claim Information (requestor completes this section; respondent supplements information)', name => 'part2_heading'),

		#22
		new CGI::Dialog::Field(type => 'select',  name => 'denial_notice', style => 'radio',
				selOptions => 'Yes:1;No:2', 
				caption => 'Carrier filed notice of denial relating to liability for or compensability of the injury that has not yet been resolved',
				options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'select',  name => 'dispute_notice', style => 'radio',
				selOptions => 'Yes:1;No:2', 
				caption => 'Carrier filed notice of dispute relating to extent of injury that has not yet been resolved and is related to this dispute',
				options => FLDFLAG_REQUIRED),


		######### Part III
		new CGI::Dialog::Subhead(heading => 'Part III: Respondent Information (respondent completes this section)', name => 'part3_heading'),

		#23
		new CGI::Dialog::Field(type => 'select',  name => 'respondent_type', style => 'radio', selOptions => 'HCP:1;IC:2;IE:3', caption => 'Type of Respondent', options => FLDFLAG_REQUIRED),

		#24
		new CGI::Dialog::Field(caption => "Respondent's Name", name => 'respondent_name'),

		#25
		#new App::Dialog::Field::Address(caption => "Respondent's Address", name => 'respondent_addr'),
		new CGI::Dialog::Field(caption => "Respondent's Address", name => 'respondent_addr1'),
		new CGI::Dialog::Field(caption => "Respondent's City, State, ZIP", name => 'respondent_addr2'),

		#26
		new CGI::Dialog::Field(caption => "Contact Person's Name", name => 'contact2_name'),

		#26 and 27
		new CGI::Dialog::MultiField(name => 'contact2_phone_fax', caption => "Contact's Phone/Fax #",
			fields => [
				new CGI::Dialog::Field(type => 'phone', caption => "Contact's Telephone #", name => 'contact2_phone'),
				new CGI::Dialog::Field(type => 'phone', caption => "Contact's Fax #", name => 'contact2_fax'),
			]),

		#27
		new CGI::Dialog::Field(type => 'email', caption => "Contact's E-mail", name => 'contact2_email'),

		#28
		new CGI::Dialog::Field(caption => 'FEIN', name => 'fein2'),
		new CGI::Dialog::Field(caption => 'Professional License # (if applicable)', name => 'prof_license2'),

		#29
		new CGI::Dialog::Field(type => 'select',  name => 'issue_resolved', style => 'radio',
				selOptions => 'Yes:1;No:2', 
				caption => 'Has the issue(s) been resolved?',
				options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'memo', caption => 'If yes, describe how it was resolved and attach documents', name => 'issue_resolved_reason'),

		#30
		new CGI::Dialog::Subhead(heading => 'Table of Disputed Services', name => 'disputed_services_heading'),
		new App::Dialog::Field::TWCC60(name => 'disputed_services', lineCount => 16),

	);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $invoiceId = $page->param('invoice_id');

	#populate field 1
	my $field1 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/1');
	$page->field('field1_item_id', $field1->{item_id});
	$page->field('requestor_type', $field1->{value_int});
	$page->field('dispute_type', $field1->{value_intb});


	#populate field 2
	my $field2 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/2');
	$page->field('field2_item_id', $field2->{item_id});
	$page->field('requestor_name', $field2->{value_text});


	#populate field 3
	my $field3 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/3');
	$page->field('field3_item_id', $field3->{item_id});
	$page->field('requestor_addr1', $field3->{value_text});
	$page->field('requestor_addr2', $field3->{value_textb});


	#populate field 4
	my $field4 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/4');
	$page->field('field4_item_id', $field4->{item_id});
	$page->field('contact1_name', $field4->{value_text});
	$page->field('contact1_phone', $field4->{value_textb});


	#populate field 5
	my $field5 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/5');
	$page->field('field5_item_id', $field5->{item_id});
	$page->field('contact1_fax', $field5->{value_text});
	$page->field('contact1_email', $field5->{value_textb});


	#populate field 6
	my $field6 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/6');
	$page->field('field6_item_id', $field6->{item_id});
	$page->field('fein1', $field6->{value_text});
	$page->field('prof_license1', $field6->{value_textb});


	#populate field 22
	my $field22 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/22');
	$page->field('field22_item_id', $field22->{item_id});
	$page->field('denial_notice', $field22->{value_int});
	$page->field('dispute_notice', $field22->{value_intb});


	#populate field 23
	my $field23 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/23');
	$page->field('field23_item_id', $field23->{item_id});
	$page->field('respondent_type', $field23->{value_int});


	#populate field 24
	my $field24 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/24');
	$page->field('field24_item_id', $field24->{item_id});
	$page->field('respondent_name', $field24->{value_text});


	#populate field 25
	my $field25 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/25');
	$page->field('field25_item_id', $field25->{item_id});
	$page->field('respondent_addr1', $field25->{value_text});
	$page->field('respondent_addr2', $field25->{value_textb});


	#populate field 26
	my $field26 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/26');
	$page->field('field26_item_id', $field26->{item_id});
	$page->field('contact2_name', $field26->{value_text});
	$page->field('contact2_phone', $field26->{value_textb});


	#populate field 27
	my $field27 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/27');
	$page->field('field27_item_id', $field27->{item_id});
	$page->field('contact2_fax', $field27->{value_text});
	$page->field('contact2_email', $field27->{value_textb});


	#populate field 28
	my $field28 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/28');
	$page->field('field28_item_id', $field28->{item_id});
	$page->field('fein2', $field28->{value_text});
	$page->field('prof_license2', $field28->{value_textb});


	#populate field 29
	my $field29 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/29');
	$page->field('field29_item_id', $field29->{item_id});
	$page->field('issue_resolved_reason', $field29->{value_text});
	$page->field('issue_resolved', $field29->{value_int});


	#populate field 30
	my $field30;
	for(my $line = 1; $line <= 16; $line++)
	{
		$field30 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, "Invoice/TWCC60/30/$line");
		my @first4 = split('//', $field30->{value_text});
		my @second4 = split('//', $field30->{value_textb});

		$page->param("_f_item_$line\_item_id", $field30->{item_id});
		$page->param("_f_item_$line\_disputed_dos", $first4[0]);
		$page->param("_f_item_$line\_cpts", $first4[1]);
		$page->param("_f_item_$line\_amt_billed", $first4[2]);
		$page->param("_f_item_$line\_med_fee", $first4[3]);
		$page->param("_f_item_$line\_amt_paid", $second4[0]);
		$page->param("_f_item_$line\_amt_disputed", $second4[1]);
		$page->param("_f_item_$line\_refund_rationale", $second4[2]);
		$page->param("_f_item_$line\_denial_rationale", $second4[3]);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field1_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC60/1',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => $page->field('requestor_type') || undef,
			value_intB => $page->field('dispute_type') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field2_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC60/2',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('requestor_name') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field3_item_id') || undef,
			item_name => 'Invoice/TWCC60/3',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('requestor_addr1') || undef,
			value_textB => $page->field('requestor_addr2') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field4_item_id') || undef,
			item_name => 'Invoice/TWCC60/4',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('contact1_name') || undef,
			value_textB => $page->field('contact1_phone') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field5_item_id') || undef,
			item_name => 'Invoice/TWCC60/5',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('contact1_fax') || undef,
			value_textB => $page->field('contact1_email') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field6_item_id') || undef,
			item_name => 'Invoice/TWCC60/6',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('fein1') || undef,
			value_textB => $page->field('prof_license1') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field22_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC60/22',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => $page->field('denial_notice') || undef,
			value_intB => $page->field('dispute_notice') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field23_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC60/23',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_int => $page->field('respondent_type') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field24_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC60/24',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('respondent_name') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field25_item_id') || undef,
			item_name => 'Invoice/TWCC60/25',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('respondent_addr1') || undef,
			value_textB => $page->field('respondent_addr2') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field26_item_id') || undef,
			item_name => 'Invoice/TWCC60/26',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('contact2_name') || undef,
			value_textB => $page->field('contact2_phone') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field27_item_id') || undef,
			item_name => 'Invoice/TWCC60/27',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('contact2_fax') || undef,
			value_textB => $page->field('contact2_email') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field28_item_id') || undef,
			item_name => 'Invoice/TWCC60/28',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('fein2') || undef,
			value_textB => $page->field('prof_license2') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field29_item_id') || undef,
			item_name => 'Invoice/TWCC60/29',
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $page->field('issue_resolved_reason') || undef,
			value_int => $page->field('issue_resolved') || undef,
			_debug => 0
	);

	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $itemId = $page->param("_f_item_$line\_item_id");
		$command = $itemId ? 'update' : 'add';

		my $disputedDos = $page->param("_f_item_$line\_disputed_dos");
		next unless $disputedDos;
		my $cptCodes = $page->param("_f_item_$line\_cpts");
		my $amtBilled = $page->param("_f_item_$line\_amt_billed");
		my $medicalFee = $page->param("_f_item_$line\_med_fee");

		my $amtPaid = $page->param("_f_item_$line\_amt_paid");
		my $amtDispute = $page->param("_f_item_$line\_amt_disputed");
		my $refundRationale = $page->param("_f_item_$line\_refund_rationale");
		my $denialRationale = $page->param("_f_item_$line\_denial_rationale");

		$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $itemId || undef,
			item_name => "Invoice/TWCC60/30/$line",
			value_type => defined $textValueType ? $textValueType : undef,			
			value_text => $disputedDos . '//' . $cptCodes . '//' . $amtBilled . '//' . $medicalFee,
			value_textB => $amtPaid . '//' . $amtDispute . '//' . $refundRationale . '//' . $denialRationale,
			_debug => 0
		);
	}

	$page->redirect("/invoice/$invoiceId/summary");
}

1;