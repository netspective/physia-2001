##############################################################################
package App::Dialog::Field::OutstandingInvoices;
##############################################################################

use strict;
use Carp;
use CGI::Validator;
use CGI::Validator::Field;
use CGI::Dialog;
use DBI::StatementManager;

use App::Statements::Person;
use App::Statements::Invoice;
use App::Universal;

use Date::Manip;
use Date::Calc qw(:all);

use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	$params{name} = 'invoices_list' unless exists $params{name};
	$params{type} = 'invoices';
	#$params{lineCount} = 4 unless exists $params{count};
	#$params{allowComments} = 1 unless exists $params{allowComments};

	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	return 1;
}

sub isValid
{
	my ($self, $page, $validator, $valFlags) = @_;

	my $totalAmtPaid = $page->field('total_amount');					#total amount paid
	my $totalAmtEntered = $page->field('adjustment_amount');			#amount paid for today's visit
	my $totalPatientBalance = $page->param('_f_total_patient_balance');	#total patient balance

	#calculate the total amount entered for each oustanding invoice in addition to amount paid for today's visit
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $payAmt = $page->param("_f_invoice_$line\_payment");
		my $invoiceBalance = $page->param("_f_invoice_$line\_invoice_balance");
		my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");
		next if $payAmt eq '';

		if($payAmt > $invoiceBalance)
		{
			$self->invalidate($page, "Line $line (Invoice $invoiceId): Amount entered exceeds balance.");
		}

		$totalAmtEntered += $payAmt;
	}


	#validate
	if($totalAmtPaid > $totalPatientBalance)
	{
		my $amtLeft = $totalAmtPaid - $totalPatientBalance;
		$self->invalidate($page, "Patient has overpaid balance by \$$amtLeft.");
	}
	elsif($totalAmtEntered > $totalAmtPaid)
	{
		my $amtExceeded = $totalAmtEntered - $totalAmtPaid;
		$self->invalidate($page, "The total amount applied exceeds the amount paid by \$$amtExceeded. Please reconcile.");
	}
	elsif($totalAmtEntered < $totalAmtPaid)
	{
		my $paidEnteredDiff = $totalAmtPaid - $totalAmtEntered;
		if($totalAmtEntered == $totalPatientBalance)
		{
			$self->invalidate($page, "Patient has overpaid by \$$paidEnteredDiff.");
		}
		elsif($totalAmtEntered > $totalPatientBalance)
		{
			my $amtOver = $totalAmtPaid - $totalPatientBalance;
			$self->invalidate($page, "There is \$$amtOver left.");
		}
		elsif($totalAmtEntered < $totalPatientBalance)
		{
			my $balanceRemain = $totalPatientBalance - $totalAmtEntered;
			$self->invalidate($page, "Remaining balance: \$$balanceRemain. There is a payment remainder of \$$paidEnteredDiff left.");
		}
	}

	return $page->haveValidationErrors() ? 0 : 1;
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	my $errorMsgsHtml = '';
	my $bgColorAttr = '';
	my $spacerHtml = '&nbsp;';
	my $textFontAttrs = 'SIZE=1 FACE="Tahoma,Arial,Helvetica" STYLE="font-family:tahoma; font-size:8pt"';
	my $textFontAttrsForTotalBalRow = 'SIZE=2 FACE="Tahoma,Arial,Helvetica" STYLE="font-family:tahoma; font-size:10pt"';

	if(my @messages = $page->validationMessages($self->{name}))
	{
		$spacerHtml = '<img src="/resources/icons/arrow_right_red.gif" border=0>';
		$bgColorAttr = "bgcolor='$dialog->{errorBgColor}'";
		$errorMsgsHtml = "<br><font $dialog->{bodyFontErrorAttrs}>" . join("<br>", @messages) . "</font>";
	}


	my $linesHtml = '';
	my $personId = $page->param('person_id') || $page->field('payer_id');
	my $outstandInvoices = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selOutstandingInvoicesByClient', $personId);
	my $totalInvoices = scalar(@{$outstandInvoices});
	my $totalPatientBalance = 0;
	for(my $line = 1; $line <= $totalInvoices; $line++)
	{
		my $invoice = $outstandInvoices->[$line-1];
		my $invoiceId = $invoice->{invoice_id};
		my $invoiceBalance = $invoice->{balance};
		$totalPatientBalance += $invoiceBalance;

		next if $invoiceId == $page->param('invoice_id');	#param(invoiceid) is the invoice for the current visit,
															#it has it's own payment section

		my $itemServDates = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selServiceDateRangeForAllItems', $invoiceId);
		my $endDateDisplay = '';
		if($itemServDates->{service_end_date})
		{
			$endDateDisplay = $itemServDates->{service_end_date} ne  $itemServDates->{service_begin_date} ? "- $itemServDates->{service_end_date}" : '';
		}
		my $dateDisplay = "$itemServDates->{service_begin_date} $endDateDisplay";

		$page->param('_f_invoice_$line\_invoice_id', $invoiceId);

		$linesHtml .= qq{
			<INPUT TYPE="HIDDEN" NAME="_f_invoice_$line\_invoice_id" VALUE="$invoiceId"/>
			<INPUT TYPE="HIDDEN" NAME="_f_invoice_$line\_invoice_balance" VALUE="$invoiceBalance"/>
			<TR VALIGN=TOP>
				<TD ALIGN=RIGHT><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				<TD><FONT $textFontAttrs> $invoiceId </TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><FONT $textFontAttrs>$dateDisplay</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$invoiceBalance</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_invoice_$line\_payment' TYPE='text' size=10 VALUE='@{[ $page->param("_f_invoice_$line\_payment") ]}'></TD>
			</TR>
		};
	}

	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$totalInvoices"/>
					<INPUT TYPE="HIDDEN" NAME="_f_total_patient_balance" VALUE="$totalPatientBalance"/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Claim #</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Svc Date(s)</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Balance</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Payment</FONT></TD>
					</TR>
					$linesHtml
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD COLSPAN=5><FONT $textFontAttrsForTotalBalRow><b>Balance:</b></FONT></TD>
						<TD COLSPAN=1 ALIGN=RIGHT><FONT $textFontAttrsForTotalBalRow><b>\$$totalPatientBalance</b></FONT></TD>
					</TR>
				</TABLE>
			</TD>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

1;
