##############################################################################
package App::Dialog::Field::BatchDateID;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Org;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use Date::Manip;
use App::Statements::Invoice;
use App::Universal;

#use Schema::Utilities;
my $CLOSE_ATTRR_TYPE = App::Universal::ATTRTYPE_DATE;
use vars qw(@ISA);
@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;
	
	die 'If using the BatchDateID Field, then either listInvoiceFieldName,invoiceIdFieldName or orgInternalIdFieldName parameter is required.'  unless ( defined $params{orgInternalIdFieldName} ||defined $params{invoiceIdFieldName}|| defined $params{listInvoiceFieldName});
	
	$params{options} = FLDFLAG_REQUIRED unless exists $params{options};
	$params{readOnlyWhen} = CGI::Dialog::DLGFLAG_UPDORREMOVE unless exists $params{readOnlyWhen};
	$params{fields} = [
				new CGI::Dialog::Field(caption => 'Batch ID', name => 'batch_id', options => $params{options},
					 readOnlyWhen => $params{readOnlyWhen}, size => 12),
				new CGI::Dialog::Field(type => 'date', caption => 'Batch Date', name => 'batch_date', 
					options => $params{options}, readOnlyWhen => $params{readOnlyWhen}),				
			];	
	return CGI::Dialog::MultiField::new($type, %params);

}

sub isValid
{
	my ($self, $page, $validator) = @_;
	my $orgInternalId;
	if ($self->{orgInternalIdFieldName})
	{
		#Get org internal ID from dialog field
		#For Create Batch Dates
		$orgInternalId =$page->field($self->{orgInternalIdFieldName});
	}
	elsif ($self->{invoiceIdFieldName})
	{
		#Get org internal ID from invoice
		#For Payment Batch Dates
		my $invoiceId = $page->field($self->{invoiceIdFieldName});
		$orgInternalId = $STMTMGR_INVOICE->getSingleValue($page,STMTMGRFLAG_NONE,'selServiceOrgByInvoiceId',$invoiceId);
		
	}
	elsif ($self->{listInvoiceFieldName})
	{
		#Special case for list of invoice Id
		#Check service facility and then close date of each invoice in the list
		my $checkDate = Date_SetTime ($page->field('batch_date'));
		my @list = split ",", $page->field($self->{listInvoiceFieldName}) ;
		foreach my $invoiceId (@list)
		{
			$orgInternalId = $STMTMGR_INVOICE->getSingleValue($page,STMTMGRFLAG_NONE,'selServiceOrgByInvoiceId',$invoiceId);
			my $item = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selValueDateByItemNameAndValueTypeAndParent', $orgInternalId,'Retire Batch Date',$CLOSE_ATTRR_TYPE);
			next unless $item->{value_date};
			my $closeDate = Date_SetTime ($item->{value_date});
			$self->invalidate($page, "Close Date is <b>$item->{value_date}</b> for Invoice $invoiceId. Batch Date must be greater than Close Date ") if ($closeDate >=$checkDate);
		}
		return;
	}
	
	my $item = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selValueDateByItemNameAndValueTypeAndParent', $orgInternalId,'Retire Batch Date',$CLOSE_ATTRR_TYPE);
	return unless $item->{value_date};
	my $checkDate = Date_SetTime ($page->field('batch_date'));
	my $closeDate = Date_SetTime ($item->{value_date});
	$self->invalidate($page, "Close Date is <b>$item->{value_date}</b>. Batch Date must be greater than Close Date ") if ($closeDate >=$checkDate);
	
	
}

1;


