##############################################################################
package App::Dialog::Attribute::ClaimNotes;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Invoice;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);


%RESOURCE_MAP=('claim-notes' => { 
			valueType => App::Universal::ATTRTYPE_INVOICENOTES, 
			heading => '$Command Claim Notes',
			_arl => ['invoice_id'], _arl_modify => ['item_id'] ,
			_idSynonym => 'attr-' . App::Universal::ATTRTYPE_INVOICENOTES()
			},
);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'claim-notes', heading => '$Command Claim Notes');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'invoice_id', caption => 'Invoice ID', options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'value_text', caption => 'Notes', type => 'memo', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(name => 'value_date', caption => 'Date', type => 'date'),
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'invoice_attribute',
			key => "#param.invoice_id#",
			data => "Claim Notes for '#field.invoice_id#' to <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('invoice_id',$page->param('invoice_id'));
	my $itemId = $page->param('item_id');
	$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttributeById', $itemId) if $itemId;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	my $invoiceId = $page->field('invoice_id');
	my $itemId = $page->param('item_id');
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $itemId || undef,
			value_type => App::Universal::ATTRTYPE_INVOICENOTES,
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/Notes',
			value_text => $page->field('value_text') || undef,
			value_textB => $page->session('user_id') ||undef,
			value_date => $page->field('value_date') || undef,
			value_int => $page->session('org_internal_id') || undef,
			_debug => 0
	);

	$page->redirect("/invoice/$invoiceId/notes");
	return "\u$command completed.";
}


1;
