##############################################################################
package App::Dialog::TWCC69;
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
	'twcc69' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'twcc69', heading => 'TWCC Form 69');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(		
		new CGI::Dialog::Field(type => 'hidden', name => 'field17_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field18_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field19_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'field22_item_id'),

		#17
		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Yes:1;No:0', caption => 'Employee has reached maximum medical improvement', 
				name => 'max_medical_improvement'),
		new CGI::Dialog::Field(type => 'date', 
				caption => "Date of Medical Improvement", 
				defaultValue => '',
				name => 'max_medical_date', 
				hints => "If 'No', give the estimated date on which employee is expected to reach maximum medical improvement"),

		#18
		new CGI::Dialog::Field(type => 'percentage', caption => 'I certify that the employee has a whole body impairment rating of:', name => 'impairment_rating'),

		#19
		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Treating:1;Other:2;Designated:3', caption => 'Doctor Type', name => 'doc_type'),
		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Carrier Selected:1;Commission Selected:2', caption => 'Required Medical Examination Doctor', name => 'exam_doc'),

		#20 - is doctor's signature
		#21 - date of this report
		
		#22
		new CGI::Dialog::Subhead(
				heading => "Treating Doctor's Review of Certification of Maximum Medical Improvement and Assigned Impairment Rating (See TWCC Form 69 for Instructions)", 
				name => 'review_heading'),
		new CGI::Dialog::Field(type => 'select', 
				style => 'radio', 
				selOptions => 'I Agree:1;I Disagree:0', 
				caption => 'Certification of Maximum Medical Improvement', 
				name => 'max_med_improve_review'),
		new CGI::Dialog::Field(type => 'select', 
				style => 'radio', 
				selOptions => 'I Agree:1;I Disagree:0', 
				caption => 'Assigned Impairment Rating', 
				name => 'impairment_rating_review'),
		
		#23 - is signature of treating doctor
		#24 - is date signed
		);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $invoiceId = $page->param('invoice_id');

	#populate field 17
	my $field17 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC69/17');
	$page->field('field17_item_id', $field17->{item_id});
	$page->field('max_medical_improvement', $field17->{value_int} ? 1 : 0);
	$page->field('max_medical_date', $field17->{value_date});


	#populate field 18
	my $field18 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC69/18');
	$page->field('field18_item_id', $field18->{item_id});
	$page->field('impairment_rating', $field18->{value_int});
	

	#populate field 19
	my $field19 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC69/19');
	$page->field('field19_item_id', $field19->{item_id});
	$page->field('doc_type', $field19->{value_int});
	$page->field('exam_doc', $field19->{value_intb});


	#populate field 22
	my $field22 = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC69/22');
	$page->field('field22_item_id', $field22->{item_id});
	$page->field('max_med_improve_review', $field22->{value_int} ? 1: 0);
	$page->field('impairment_rating_review', $field22->{value_intb} ? 1 : 0);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $dateValueType = App::Universal::ATTRTYPE_DATE;
	my $intValueType = App::Universal::ATTRTYPE_INTEGER;
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field17_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC69/17',
			value_type => defined $dateValueType ? $dateValueType : undef,
			value_date => $page->field('max_medical_date') || undef,
			value_int => $page->field('max_medical_improvement') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('field18_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/TWCC69/18',
			value_type => defined $intValueType ? $intValueType : undef,			
			value_int => $page->field('impairment_rating') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field19_item_id') || undef,
			item_name => 'Invoice/TWCC69/19',
			value_type => defined $intValueType ? $intValueType : undef,			
			value_int => $page->field('doc_type') || undef,
			value_intB => $page->field('exam_doc') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_id => $page->field('field22_item_id') || undef,
			item_name => 'Invoice/TWCC69/22',
			value_type => defined $intValueType ? $intValueType : undef,			
			value_int => $page->field('max_med_improve_review') || undef,
			value_intB => $page->field('impairment_rating_review') || undef,
			_debug => 0
	);

	$page->redirect("/invoice/$invoiceId/summary");
}

1;