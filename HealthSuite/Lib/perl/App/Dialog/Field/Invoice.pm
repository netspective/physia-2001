##############################################################################
package App::Dialog::Field::ProcedureLine;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;

	my $nameSuffix = $params{nameSuffix} || '';
	$params{fields} = [
		new CGI::Dialog::Field(
				caption => 'Procedure',
				name => "procedure$nameSuffix",
				#type => 'integer', 
				size => 8,
				options => FLDFLAG_REQUIRED,
				findPopup => '/lookup/feeprocedure/itemValue', 
				findPopupControlField => '_f_fee_schedules'),
				#findPopup => '/lookup/cpt'),
		new CGI::Dialog::Field(
				caption => 'Modifier',
				name => "procmodifier$nameSuffix",
				findPopup => '/lookup/modifier', 
				type => 'text', size => 4),
		#new CGI::Dialog::Field(
		#		caption => 'Diagnoses',
		#		name => "procdiags$nameSuffix",
		#		type => 'text', size => 12, maxLength => 64,
		#		findPopup => 'catalog,code'),
	];

	return CGI::Dialog::MultiField::new($type, %params);
}

##############################################################################
package App::Dialog::Field::ServicePlaceType;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;

	my $nameSuffix = $params{nameSuffix} || '';
	$params{fields} = [
		new CGI::Dialog::Field(
				caption => 'Service Place',
				name => "servplace$nameSuffix",
				size => 6, options => FLDFLAG_REQUIRED,
				defaultValue => 11,
				findPopup => '/lookup/serviceplace'),
		new CGI::Dialog::Field(
				caption => 'Service Type',
				name => "servtype$nameSuffix",
				size => 6,
				findPopup => '/lookup/servicetype'),
		#new CGI::Dialog::Field(type => 'bool',
		#		style => 'check',
		#		caption => 'Lab',
		#		name => 'lab_indicator'),
	];

	return CGI::Dialog::MultiField::new($type, %params);
}

##############################################################################
package App::Dialog::Field::ProcedureChargeUnits;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;

	my $nameSuffix = $params{nameSuffix} || '';
	$params{fields} = [
		new CGI::Dialog::Field(caption => 'Charge', name => "proccharge$nameSuffix", type => 'currency'),
		new CGI::Dialog::Field(caption => 'Units', name => "procunits$nameSuffix", type => 'integer', size => 6, minValue => 1, value => 1, options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption => 'EMG', name => "emg$nameSuffix", type => 'bool', style => 'check'),
	];

	return CGI::Dialog::MultiField::new($type, %params);
}

##############################################################################
package App::Dialog::Field::Diagnoses;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	return CGI::Dialog::Field::new($type, name => 'diagcodes', findPopup => '/lookup/icd', findPopupAppendValue => ', ', options => FLDFLAG_TRIM, %params);
}

##############################################################################
package App::Dialog::Field::DiagnosesCheckbox;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Invoice;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;
	return CGI::Dialog::Field::new($type, type => 'select', style => 'multicheck', choiceDelim => '[,\s]+', name => 'procdiags', %params);
}

sub parseChoices
{
	my ($self, $page) = @_;

	$self->{selOptions} = $STMTMGR_INVOICE->getSingleValue($page, 0, 'selClaimDiags', $page->param('invoice_id'));
	return $self->SUPER::parseChoices($page);
}

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

	my $payType = $page->field('pay_type');
	return if $payType == App::Universal::ADJUSTMENTPAYTYPE_PREPAY || $payType == App::Universal::ADJUSTMENTPAYTYPE_COPAYPREPAY;

	my $totalPayRcvd = $page->field('total_amount');					#total amount paid
	my $totalAmtEntered = 0;
	my $totalBalance = $page->param('_f_total_balance');				#total patient balance
	my $creditWarned = $page->field('credit_warning_flag');


	#validation for each invoice listed
	#calculate the total amount entered for each oustanding invoice
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $payAmt = $page->param("_f_invoice_$line\_payment");
		my $invoiceBalance = $page->param("_f_invoice_$line\_invoice_balance");
		my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");
		next if $payAmt eq '';

		#no validation needed for overpayments - overpayments are allowed
		if($payAmt > $totalPayRcvd)
		{
			my $amtDiff = $payAmt - $totalPayRcvd;
			$self->invalidate($page, "Line $line (Invoice $invoiceId) - Amount entered exceeds 'Total Payment Received' by \$$amtDiff");
		}

		$totalAmtEntered += $payAmt;
	}


	#validation  - no validation needed for overpayments - overpayments are allowed
	if($totalAmtEntered > $totalPayRcvd)
	{
		my $amtExceeded = $totalAmtEntered - $totalPayRcvd;
		$self->invalidate($page, "The total amount applied exceeds the 'Total Payment Received' by \$$amtExceeded. Please reconcile.");
	}
	elsif($totalAmtEntered < $totalPayRcvd)
	{
		my $payRcvdAndPayAppliedDiff = $totalPayRcvd - $totalAmtEntered;
		if($totalAmtEntered < $totalBalance)
		{
			my $balanceRemain = $totalBalance - $totalAmtEntered;
			$self->invalidate($page, "Remaining balance: \$$balanceRemain. There is a payment remainder of \$$payRcvdAndPayAppliedDiff.");
		}
		else
		{
			$self->invalidate($page, "There is a payment remainder of \$$payRcvdAndPayAppliedDiff.");
		}
	}
	elsif($totalAmtEntered > $totalBalance && ! $creditWarned)
	{
		my $credit = $totalBalance - $totalAmtEntered;
		$self->invalidate($page, "WARNING: This payment will put a credit of \$$credit on this patient's account balance (excluding non-Self-Pay invoices). Click 'OK' to continue.");
		$page->field('credit_warning_flag', 1);
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
	my $sessOrgIntId = $page->session('org_internal_id');
	my $isBatch = $page->param('_p_batch_id');
	my $outstandInvoices = $isBatch ? $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selAllOutstandingInvoicesByClient', $personId, $sessOrgIntId)
								: $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selSelfPayOutstandingInvoicesByClient', $personId, $sessOrgIntId);
	my $totalInvoices = scalar(@{$outstandInvoices});
	my $totalBalance = 0;
	for(my $line = 1; $line <= $totalInvoices; $line++)
	{
		my $invoice = $outstandInvoices->[$line-1];
		my $invoiceId = $invoice->{invoice_id};
		my $invoiceBalance = $invoice->{balance};
		my $invStatCaption = $invoice->{status_caption};
		$totalBalance += $invoiceBalance;

		my $itemServDates = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selServiceDateRangeForAllItems', $invoiceId);
		my $endDateDisplay = '';
		if($itemServDates->{service_end_date})
		{
			$endDateDisplay = $itemServDates->{service_end_date} ne  $itemServDates->{service_begin_date} ? "- $itemServDates->{service_end_date}" : '';
		}
		my $dateDisplay = "$itemServDates->{service_begin_date} $endDateDisplay";

		$page->param("_f_invoice_$line\_invoice_id", $invoiceId);

		$linesHtml .= qq{
			<INPUT TYPE="HIDDEN" NAME="_f_invoice_$line\_invoice_id" VALUE="$invoiceId"/>
			<INPUT TYPE="HIDDEN" NAME="_f_invoice_$line\_invoice_balance" VALUE="$invoiceBalance"/>
			<TR VALIGN=TOP>
				<TD ALIGN=RIGHT><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs> $invoiceId </TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><FONT $textFontAttrs>$dateDisplay</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><FONT $textFontAttrs>$invStatCaption</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$invoiceBalance</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_invoice_$line\_payment' TYPE='text' size=10 VALUE='@{[ $page->param("_f_invoice_$line\_payment") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_invoice_$line\_comments' TYPE='text' size=30 VALUE='@{[ $page->param("_f_invoice_$line\_comments") ]}'></TD>
			</TR>
		};
	}

	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD colspan=2>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$totalInvoices"/>
					<INPUT TYPE="HIDDEN" NAME="_f_total_balance" VALUE="$totalBalance"/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Claim #</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Svc Date(s)</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Status</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Balance</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Payment</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Comments</FONT></TD>
					</TR>
					$linesHtml
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD COLSPAN=7><FONT $textFontAttrsForTotalBalRow><b>Total Patient Balance:</b></FONT></TD>
						<TD COLSPAN=1 ALIGN=RIGHT><FONT $textFontAttrsForTotalBalRow><b>\$$totalBalance</b></FONT></TD>
					</TR>
				</TABLE>
			</TD>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

##############################################################################
package App::Dialog::Field::RefundInvoices;
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

	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $refundAmt = $page->param("_f_invoice_$line\_refund");
		next if $refundAmt eq '';

		my $invoiceBalance = $page->param("_f_invoice_$line\_invoice_balance");
		my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");

		my $newTotal = $invoiceBalance + $refundAmt;

		#following was commented out on 5/15 because refunds that give the patient a positive balance are allowed
		#if($newTotal > 0)
		#{
		#	$self->invalidate($page, "Line $line (Invoice $invoiceId): New balance is \$$newTotal. Please re-enter refund amount.");
		#}
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

	my $sessOrgIntId = $page->session('org_internal_id');
	my $linesHtml = '';
	my $personId = $page->param('person_id') || $page->field('payer_id');
	my $refundInvoices = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selAllNonVoidedInvoicesByClient', $personId, $sessOrgIntId);
	my $totalPatientBalance = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_CACHE, 'selTotalPatientBalance', $personId, $sessOrgIntId);
	my $totalPossibleRefund = $totalPatientBalance * (-1);
	#Removed on 8/9/00 because we want to show all invoices (excluding voided ones) - MAF
	#my $totalPossibleRefundMsg = $totalPatientBalance < 0 ? "(Amount refunded cannot exceed \$$totalPossibleRefund)" : "(There is no credit on this patient's balance)";
	my $totalPossibleRefundMsg = $totalPatientBalance < 0 ? '' : "(There is no credit on this patient's balance)";

	my $totalInvoices = scalar(@{$refundInvoices});
	for(my $line = 1; $line <= $totalInvoices; $line++)
	{
		my $invoice = $refundInvoices->[$line-1];
		my $invoiceId = $invoice->{invoice_id};
		my $invoiceBalance = $invoice->{balance};
		my $invoiceStatus = $invoice->{invoice_status};
		my $invStatCaption = $invoice->{status_caption};

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
			<INPUT TYPE="HIDDEN" NAME="_f_invoice_$line\_invoice_status" VALUE="$invoiceStatus"/>
			<TR VALIGN=TOP>
				<TD ALIGN=RIGHT><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs> $invoiceId </TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><FONT $textFontAttrs>$dateDisplay</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><FONT $textFontAttrs>$invStatCaption</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$invoiceBalance</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_invoice_$line\_refund' TYPE='text' size=10 VALUE='@{[ $page->param("_f_invoice_$line\_refund") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_invoice_$line\_refund_to_id' TYPE='text' size=15 VALUE='@{[ $page->param("_f_invoice_$line\_refund_to_id") ]}'>
					<a href="javascript:doFindLookup(document.dialog, document.dialog._f_invoice_$line\_refund_to_id, '/lookup/itemValue', '', false, null, document.dialog._f_invoice_$line\_refund_to_type);"><img src='/resources/icons/magnifying-glass-sm.gif' border=0></a>
				</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					<SELECT NAME='_f_invoice_$line\_refund_to_type'>
						<OPTION value='person'>Person</OPTION>
						<OPTION value='org'>Organization</OPTION>
					</SELECT>
				</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_invoice_$line\_comments' TYPE='text' size=30 VALUE='@{[ $page->param("_f_invoice_$line\_comments") ]}'></TD>
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
						<TD ALIGN=CENTER><FONT $textFontAttrs>Status</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Balance</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Refund</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Refund To ID</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Refund To Type</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Comments</FONT></TD>
					</TR>
					$linesHtml
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD COLSPAN=7><FONT $textFontAttrsForTotalBalRow><b>Patient's Total Balance:</b></FONT></TD>
						<TD COLSPAN=1 ALIGN=RIGHT><FONT $textFontAttrsForTotalBalRow><b>\$$totalPatientBalance</b></FONT></TD>
						<TD COLSPAN=4><FONT $textFontAttrs>$totalPossibleRefundMsg</FONT></TD>
					</TR>
				</TABLE>
			</TD>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

##############################################################################
package App::Dialog::Field::AllInvoices;
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

use vars qw(@ISA);

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
	my $sessOrgIntId = $page->session('org_internal_id');

	my $personId = $page->param('person_id') || $page->field('payer_id');
	my $creditInvoices = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selCreditInvoicesByClient', $personId, $sessOrgIntId);
	if($creditInvoices->[0]->{invoice_id} eq '')
	{
		$self->invalidate($page, "Cannot perform a transfer. There are no invoices with a credit for this patient.");	
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

	my $sessOrgIntId = $page->session('org_internal_id');
	my $linesHtml = '';
	my $personId = $page->param('person_id') || $page->field('payer_id');
	my $transferInvoices = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selAllNonZeroBalanceInvoicesByClient', $personId, $sessOrgIntId);
	my $totalPatientBalance = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_CACHE, 'selTotalPatientBalance', $personId, $sessOrgIntId);

	my $totalInvoices = scalar(@{$transferInvoices});
	for(my $line = 1; $line <= $totalInvoices; $line++)
	{
		my $invoice = $transferInvoices->[$line-1];
		my $invoiceId = $invoice->{invoice_id};
		my $invoiceBalance = $invoice->{balance};
		my $invStatCaption = $invoice->{status_caption};

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
				<TD ALIGN=RIGHT><FONT $textFontAttrs> $invoiceId </TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><FONT $textFontAttrs>$dateDisplay</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><FONT $textFontAttrs>$invStatCaption</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$invoiceBalance</TD>
			</TR>
		};
	}

	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD colspan=2>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$totalInvoices"/>
					<INPUT TYPE="HIDDEN" NAME="_f_total_patient_balance" VALUE="$totalPatientBalance"/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Claim #</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Svc Date(s)</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Status</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Balance</FONT></TD>
					</TR>
					$linesHtml
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD COLSPAN=7><FONT $textFontAttrsForTotalBalRow><b>Total Patient Balance:</b></FONT></TD>
						<TD COLSPAN=1 ALIGN=RIGHT><FONT $textFontAttrsForTotalBalRow><b>\$$totalPatientBalance</b></FONT></TD>
					</TR>
				</TABLE>
			</TD>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

##############################################################################
package App::Dialog::Field::InvoiceItems;
##############################################################################

use strict;
use Carp;
use CGI::Validator;
use CGI::Validator::Field;
use CGI::Dialog;
use DBI::StatementManager;

use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Catalog;
use App::Statements::Insurance;
use App::Universal;

use Date::Manip;
use Date::Calc qw(:all);

use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	$params{name} = 'items_list' unless exists $params{name};
	$params{type} = 'invoice_items';
	$params{lineCount} = 4 unless exists $params{count};
	$params{allowComments} = 1 unless exists $params{allowComments};

	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	return 1;
}

sub isValid
{
	my ($self, $page, $validator, $valFlags) = @_;

	my $sessUser = $page->session('user_id');
	my $personId = $page->field('client_id');

	if($page->param('_f_item_1_code') eq '')
	{
		$self->invalidate($page, "[<B>P1</B>] Item code cannot be blank.");
	}
	if($page->param('_f_item_1_unit_cost') eq '')
	{
		$self->invalidate($page, "[<B>P1</B>] Item unit cost cannot be blank.");
	}
	if($page->param('_f_item_1_quantity') < 1)
	{
		my $quantity1 = $page->param('_f_item_1_quantity');
		$self->invalidate($page, "[<B>P1</B>] Item quantity must be 1 or more. ($quantity1)");
	}

	my $lineCount = $page->param('_f_line_count');
	for(my $line = 2; $line <= $lineCount; $line++)
	{
		my $quantity = $page->param("_f_item_$line\_quantity");
		my $code = $page->param("_f_item_$line\_code");
		my $unitCost = $page->param("_f_item_$line\_unit_cost");

		if($code ne '')
		{
			if($quantity < 1)
			{
				$self->invalidate($page, "[<B>P$line</B>] Quantity must be 1 or more");
			}
			if($unitCost eq '')
			{
				$self->invalidate($page, "[<B>P$line</B>] Unit cost cannot be blank");
			}
		}
		elsif($unitCost ne '')
		{
			if($quantity < 1)
			{
				$self->invalidate($page, "[<B>P$line</B>] Quantity must be 1 or more");
			}
			if($code eq '')
			{
				$self->invalidate($page, "[<B>P$line</B>] Item code cannot be blank");
			}
		}	
	}

	return $page->haveValidationErrors() ? 0 : 1;
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	my $bgColorAttr = '';
	my $spacerHtml = '&nbsp;';
	my $textFontAttrs = 'SIZE=1 FACE="Tahoma,Arial,Helvetica" STYLE="font-family:tahoma; font-size:8pt"';
	my $readOnly = $command eq 'remove' ? 'READONLY' : '';
	my ($dialogName, $lineCount, $allowComments, $allowRemove) = ($dialog->formName(), $self->{lineCount}, $self->{allowComments}, $dlgFlags & CGI::Dialog::DLGFLAG_UPDATE);
	my ($linesHtml, $numCellRowSpan, $removeChkbox) = ('', $allowComments ? 'ROWSPAN=2' : '', '');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		$removeChkbox = $allowRemove ? qq{<TD ALIGN=CENTER $numCellRowSpan><INPUT TYPE="CHECKBOX" NAME='_f_item_$line\_remove'></TD>} : '';

		$linesHtml .= qq{
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_id" VALUE='@{[ $page->param("_f_item_$line\_item_id")]}'/>
			<TR VALIGN=TOP>
				<SCRIPT>
					function onChange_dosBegin_$line(event, flags)
					{
						if(event.srcElement.value == 'From')
							event.srcElement.value = '0';
						event.srcElement.value = validateDate(event.srcElement.name, event.srcElement.value);
						if(document.$dialogName._f_item_$line\_dos_end.value == '' || document.$dialogName._f_item_$line\_dos_end.value == 'To')
							document.$dialogName._f_item_$line\_dos_end.value = event.srcElement.value;
					}
				</SCRIPT>
				<TD ALIGN=RIGHT $numCellRowSpan><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				$removeChkbox
				<TD><INPUT $readOnly CLASS='procinput' NAME='_f_item_$line\_dos_begin' TYPE='text' size=10 VALUE='@{[ $page->param("_f_item_$line\_dos_begin") || 'From' ]}' ONBLUR="onChange_dosBegin_$line(event)"><BR>
					<INPUT $readOnly CLASS='procinput' NAME='_f_item_$line\_dos_end' TYPE='text' size=10 VALUE='@{[ $page->param("_f_item_$line\_dos_end") || 'To' ]}' ONBLUR="validateChange_Date(event)"></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT $readOnly NAME='_f_item_$line\_quantity' TYPE='text' MAXLENGTH = 3 SIZE=3 VALUE='@{[ $page->param("_f_item_$line\_quantity") || 1 ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT $readOnly NAME='_f_item_$line\_code' SIZE=8 TYPE='text' VALUE='@{[ $page->param("_f_item_$line\_code") ]}'>
					<A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_item_$line\_code, '/lookup/miscprocedure', ',', false);"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR>
				</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT $readOnly  NAME='_f_item_$line\_unit_cost' TYPE='text' size=8 VALUE='@{[ $page->param("_f_item_$line\_unit_cost")  ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
			</TR>
		};
		$linesHtml .= qq{
			<TR>
				<TD COLSPAN=2 ALIGN=RIGHT><FONT $textFontAttrs><I>Comments:</I></FONT></TD>
				<TD COLSPAN=5><INPUT $readOnly NAME='_f_item_$line\_comments' TYPE='text' size=40 VALUE='@{[ $page->param("_f_item_$line\_comments") ]}'></TD>
			</TR>
		} if $allowComments;
	}

	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD COLSPAN=2>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$lineCount"/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						@{[ $allowRemove ? qq{<TD ALIGN=CENTER><FONT $textFontAttrs><IMG SRC="/resources/icons/action-edit-remove-x.gif"></FONT></TD>} : '' ]}
						<TD ALIGN=CENTER><FONT $textFontAttrs>Dates</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Qty</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Item Code</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Cost/Unit</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
					</TR>
					$linesHtml
				</TABLE>
			</TD>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

##############################################################################
package App::Dialog::Field::OutstandingItems;
##############################################################################

use strict;
use Carp;
use CGI::Validator;
use CGI::Validator::Field;
use CGI::Dialog;

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Invoice;
use App::Statements::Catalog;
use App::Universal;

use Number::Format;
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

	my $payType = $page->field('pay_type');
	my $paidBy = $page->param('paidBy') || 'personal';
	return if $payType == App::Universal::ADJUSTMENTPAYTYPE_PREPAY && $paidBy eq 'personal';

	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');
	#$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);

	my $sessOrgIntId = $page->session('org_internal_id');
	my $clientId = $page->field('client_id');
	my $totalPayRcvd = $page->field('check_amount') || $page->field('total_amount');
	my $totalAmtApplied = 0;
	my $totalInvoiceBalance = 0;
	my $totalPatientBalance = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_CACHE, 'selTotalPatientBalance', $clientId, $sessOrgIntId);
	my $creditWarned = $page->field('credit_warning_flag');

	#validation for each item listed
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $itemPayment = $page->param("_f_item_$line\_plan_paid") || $page->param("_f_item_$line\_amount_applied");
		my $itemCharge = $page->param("_f_item_$line\_item_charge");
		my $itemBalance = $page->param("_f_item_$line\_item_balance");
		$totalInvoiceBalance += $itemBalance;
		next if $itemPayment eq '';

		if($itemPayment > $itemCharge && $totalPayRcvd >= 0)
		{
			my $difference = $itemPayment - $itemCharge;
			$difference = $formatter->format_price($difference);
			$paidBy eq 'insurance' ? 
				$self->invalidate($page, "Line $line: 'Plan Paid' exceeds 'Charge' by $difference") 
				: $self->invalidate($page, "Line $line: 'Amount Paid' exceeds 'Charge' by $difference");
		}

		if($itemPayment > $totalPayRcvd && $totalPayRcvd >= 0)
		{
			my $amtDiff = $itemPayment - $totalPayRcvd;
			$amtDiff = $formatter->format_price($amtDiff);
			$paidBy eq 'insurance' ? 
				$self->invalidate($page, "Line $line: 'Plan Paid' exceeds 'Check Amount' by $amtDiff") 
				: $self->invalidate($page, "Line $line: 'Amount Paid' exceeds 'Total Amount' by $amtDiff");
		}

		$totalAmtApplied += $itemPayment;
	}


	#validation  - no validation needed for overpayments - overpayments are allowed
	#if($totalPayRcvd >= 0)
	#{
		if($totalAmtApplied - $totalPayRcvd > .01)
		{
			my $amtExceeded = $totalAmtApplied - $totalPayRcvd;
			$amtExceeded = $formatter->format_price($amtExceeded);
			$paidBy eq 'insurance' ? 
				$self->invalidate($page, "The total amount applied exceeds the 'Check Amount' by $amtExceeded. Please reconcile.")
				: $self->invalidate($page, "The total amount applied exceeds the total amount entered by $amtExceeded. Please reconcile.");
		}
		if($totalPayRcvd - $totalAmtApplied > .01)
		{
			my $payRcvdAndPayAppliedDiff = $totalPayRcvd - $totalAmtApplied;
			$payRcvdAndPayAppliedDiff = $formatter->format_price($payRcvdAndPayAppliedDiff);
			if($totalInvoiceBalance - $totalAmtApplied > .01)
			{
				my $balanceRemain = $totalInvoiceBalance - $totalAmtApplied;
				$balanceRemain = $formatter->format_price($balanceRemain);
				$self->invalidate($page, "Remaining balance: $balanceRemain. There is a payment remainder of $payRcvdAndPayAppliedDiff.");
			}
			else
			{
				$self->invalidate($page, "There is a payment remainder of $payRcvdAndPayAppliedDiff.");
			}
		}
		elsif($totalAmtApplied - $totalPatientBalance > .01 && ! $creditWarned)
		{
			my $credit = $totalPatientBalance - $totalAmtApplied;
			$credit = $formatter->format_price($credit);
			if($totalPatientBalance < 0)
			{
				$self->invalidate($page, "WARNING: This patient currently has a credit of \$$totalPatientBalance on their account balance. 
									This payment will increase the credit to $credit. Click 'OK' to continue.");
			}
			else
			{
				$self->invalidate($page, "WARNING: This payment will put a credit of $credit on this patient's account balance. Click 'OK' to continue.");
			}

			$page->field('credit_warning_flag', 1);
		}
	#}

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

	#get invoice items which can have payments applied to them
	my $linesHtml;
	my $invoiceId = $page->param('invoice_id') || $page->field('sel_invoice_id');
	my $paidBy = $page->param('paidBy') || 'personal';
	my $outstandItems = $paidBy eq 'insurance' ?
		$STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selInvoiceProcedureItems', $invoiceId, App::Universal::INVOICEITEMTYPE_SERVICE, App::Universal::INVOICEITEMTYPE_LAB)
		: $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selInvoiceItems', $invoiceId);

	my $itemSuppressHtml = '';

	my $totalItems = scalar(@{$outstandItems});
	my $totalInvoiceBalance = 0;
	for(my $line = 1; $line <= $totalItems; $line++)
	{
		my $item = $outstandItems->[$line-1];
		my $itemType = $item->{item_type};
		my $itemTypeCap = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_CACHE, 'selItemTypeCaption', $itemType);
		next if $itemType == App::Universal::INVOICEITEMTYPE_COINSURANCE 
			#|| $itemType == App::Universal::INVOICEITEMTYPE_ADJUST 
			|| $itemType == App::Universal::INVOICEITEMTYPE_VOID;
		next if $item->{data_text_b} eq 'void';

		my $itemId = $item->{item_id};
		my $itemCPT = $item->{code};
		my $itemBalance = $item->{balance};
		my $itemCharge = $item->{extended_cost} || '0';
		my $itemAdjs = $item->{total_adjust} || '0';
		$totalInvoiceBalance += $itemBalance;

		my $endDateDisplay = '';
		if(my $endDate = $item->{service_end_date})
		{
			$endDateDisplay = $endDate ne  $item->{service_begin_date} ? "- $endDate" : '';
		}
		my $dateDisplay = "$item->{service_begin_date} $endDateDisplay";

		my $amtApplied = $page->param("_f_item_$line\_amount_applied");
		my $planPaid = $page->param("_f_item_$line\_plan_paid");
		my $writeoffCode = $page->param("_f_item_$line\_writeoff_code");

		#create drop-down list of writeoff_types
		my $writeoffTypes = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selWriteoffTypes');
		my $writeoffTypesHtml = "<OPTION></OPTION>";
		foreach my $woType (@{$writeoffTypes})
		{
			$writeoffTypesHtml .= "<OPTION VALUE='$woType->{id}'>$woType->{caption}</OPTION>";
		}

		#display line item suppression checkboxes if paid by insurance
		my $planAllow = $page->param("_f_item_$line\_plan_allow");
		if($paidBy eq 'insurance')
		{
			#create html for suppressing line items
			my $isSuppressed = $page->param("_f_item_$line\_suppress") eq 'on' ? 'CHECKED' : '';
			$itemSuppressHtml = $itemType != App::Universal::INVOICEITEMTYPE_ADJUST ? 
				qq{<TD ALIGN=RIGHT><INPUT TYPE="CHECKBOX" NAME='_f_item_$line\_suppress' $isSuppressed></TD>}
				: qq{<TD><FONT SIZE=1>&nbsp;</FONT></TD>};

			#get plan allow
			unless($page->param("_f_item_$line\_plan_allow_is_set"))
			{
				my $getPlanAllow = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selPlanAllowedByProdAndCode', $page->field('product_ins_id') || undef, $page->session('org_internal_id'), $itemCPT);
				$planAllow = $page->param("_f_item_$line\_plan_allow", $getPlanAllow);
				$page->param("_f_item_$line\_plan_allow_is_set", 'test');
			}
		}

		$linesHtml .= qq{
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_id" VALUE="$itemId"/>
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_balance" VALUE="$itemBalance"/>
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_charge" VALUE="$itemCharge"/>
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_existing_adjs" VALUE="$itemAdjs"/>
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_cpt" VALUE="$itemCPT"/>
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_plan_allow_is_set" VALUE='@{[ $page->param("_f_item_$line\_plan_allow_is_set") ]}'/>
			<TR VALIGN=TOP>
				<TD ALIGN=RIGHT><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				$itemSuppressHtml
				<TD><FONT $textFontAttrs>$dateDisplay</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=LEFT><FONT $textFontAttrs>$itemTypeCap</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>$itemCPT</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$itemCharge</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$itemAdjs</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$itemBalance</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				@{[ $paidBy eq 'insurance' ? 
				"<TD><INPUT NAME='_f_item_$line\_plan_allow' TYPE='text' size=10 VALUE='$planAllow'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_plan_paid' TYPE='text' size=10 VALUE='$planPaid'></TD>"
				: '' ]}
				
				@{[ $paidBy eq 'personal' ? 
				"<TD><INPUT NAME='_f_item_$line\_amount_applied' TYPE='text' size=10 VALUE='$amtApplied'></TD>"
				: '' ]}

				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_writeoff_amt' TYPE='text' size=10 VALUE='@{[ $page->param("_f_item_$line\_writeoff_amt") ]}'></TD>

				@{[ $paidBy eq 'personal' ? 
				"<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					<SELECT NAME='_f_item_$line\_writeoff_code' TYPE='text'>
						$writeoffTypesHtml
					</SELECT>
				</TD>"
				: '' ]}

				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_comments' TYPE='text' size=25 VALUE='@{[ $page->param("_f_item_$line\_comments") ]}'></TD>
			</TR>
		} if $itemType != App::Universal::INVOICEITEMTYPE_ADJUST;

		$linesHtml .= qq{
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_id" VALUE="$itemId"/>
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_balance" VALUE="$itemBalance"/>
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_charge" VALUE="$itemCharge"/>
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_existing_adjs" VALUE="$itemAdjs"/>
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_cpt" VALUE="$itemCPT"/>
			<TR VALIGN=TOP>
				<TD ALIGN=RIGHT><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				$itemSuppressHtml
				<TD><FONT $textFontAttrs>$dateDisplay</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>$itemTypeCap</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>$itemCPT</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$itemCharge</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$itemAdjs</TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD ALIGN=RIGHT><FONT $textFontAttrs>\$$itemBalance</TD>
				<TD COLSPAN=7><FONT SIZE=1>&nbsp;</FONT></TD>
			</TR>
		} if $itemType == App::Universal::INVOICEITEMTYPE_ADJUST;
	}

	my $suppressHd = $paidBy eq 'insurance' ? 
		qq{<TD ALIGN=CENTER TITLE="Suppress Items for Resubmission"><FONT $textFontAttrs><IMG SRC="/resources/icons/action-edit-remove-x.gif"></FONT></TD>} : '';
	my $invBalColSpan = $suppressHd ? 'COLSPAN=12' : 'COLSPAN=11';

	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD colspan=2>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$totalItems"/>
					<INPUT TYPE="HIDDEN" NAME="_f_invoice_balance" VALUE="$totalInvoiceBalance"/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						$suppressHd
						<TD ALIGN=CENTER><FONT $textFontAttrs>Svc Date(s)</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Type</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>CPT</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Charge</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Adjs</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Balance</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						@{[ $paidBy eq 'insurance' ? 
						"<TD ALIGN=CENTER><FONT $textFontAttrs>Plan Allow</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Plan Paid</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Writeoff Amount</FONT></TD>"
						:
						"<TD ALIGN=CENTER><FONT $textFontAttrs>Amount Paid</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Writeoff Amount</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Writeoff Code</FONT></TD>" ]}
						
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Comments</FONT></TD>
					</TR>
					$linesHtml
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD $invBalColSpan><FONT $textFontAttrsForTotalBalRow><b>Invoice Balance:</b></FONT></TD>
						<TD COLSPAN=1 ALIGN=RIGHT><FONT $textFontAttrsForTotalBalRow><b>\$$totalInvoiceBalance</b></FONT></TD>
					</TR>
				</TABLE>
			</TD>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

##############################################################################
package App::Dialog::Field::TWCC60;
##############################################################################

use strict;
use Carp;
use CGI::Validator;
use CGI::Validator::Field;
use CGI::Dialog;

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Invoice;
use App::Statements::Catalog;
use App::Universal;

use Number::Format;
use Date::Manip;
use Date::Calc qw(:all);

use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	$params{name} = 'disputed_services' unless exists $params{name};
	#$params{type} = 'invoices';
	#$params{lineCount} = 4 unless exists $params{count};
	#$params{allowComments} = 1 unless exists $params{allowComments};

	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	return 0;
}

sub isValid
{
	my ($self, $page, $validator, $valFlags) = @_;

	#return $page->haveValidationErrors() ? 0 : 1;
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

	#get invoice items which can have payments applied to them
	my $linesHtml;
	my $invoiceId = $page->param('invoice_id');
	my $lineCount = $self->{lineCount};
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		$linesHtml .= qq{
			<INPUT TYPE="HIDDEN" NAME="_f_item_$line\_item_id" VALUE='@{[ $page->param("_f_item_$line\_item_id") ]}'/>
			<TR VALIGN=TOP>
				<TD ALIGN=RIGHT><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_disputed_dos' SIZE=10 VALUE='@{[ $page->param("_f_item_$line\_disputed_dos") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_cpts' SIZE=10 VALUE='@{[ $page->param("_f_item_$line\_cpts") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_amt_billed' SIZE=10 VALUE='@{[ $page->param("_f_item_$line\_amt_billed") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_med_fee' SIZE=10 VALUE='@{[ $page->param("_f_item_$line\_med_fee") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_amt_paid' SIZE=10 VALUE='@{[ $page->param("_f_item_$line\_amt_paid") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_amt_disputed' SIZE=10 VALUE='@{[ $page->param("_f_item_$line\_amt_disputed") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT NAME='_f_item_$line\_refund_rationale' TYPE='text' size=25 VALUE='@{[ $page->param("_f_item_$line\_refund_rationale") ]}'></TD>
				<TD><INPUT NAME='_f_item_$line\_denial_rationale' TYPE='text' size=25 VALUE='@{[ $page->param("_f_item_$line\_denial_rationale") ]}'></TD>
			</TR>
		};
	}

	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD colspan=2>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$lineCount"/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Disputed<BR>DOS</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>CPT Code(s)</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Amount<BR>Billed</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Medical Fee<BR>Guideline<BR>MAR</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Total<BR>Amount<BR>Paid</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Amount in<BR>Dispute</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=LEFT><FONT $textFontAttrs>Requestor's Rationale for<BR>Incr Reimbursement or Refund</FONT></TD>
						<TD ALIGN=LEFT><FONT $textFontAttrs>Requestor's Rationale for<BR>Maintaining the Reduction or Denial</FONT></TD>
					</TR>
					$linesHtml
					<!-- <TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><FONT $textFontAttrsForTotalBalRow><b>Totals:</b></FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><INPUT NAME='_f_item_total_cpts' SIZE=10 VALUE='@{[ $page->param("_f_item_total_cpts") ]}'></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><INPUT NAME='_f_item_total_amt_billed' SIZE=10 VALUE='@{[ $page->param("_f_item_total_amt_billed") ]}'></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><INPUT NAME='_f_item_total_med_fee' SIZE=10 VALUE='@{[ $page->param("_f_item_total_med_fee") ]}'></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><INPUT NAME='_f_item_total_amt_paid' SIZE=10 VALUE='@{[ $page->param("_f_item_total_amt_paid") ]}'></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD COLSPAN=4><INPUT NAME='_f_item_total_amt_disputed' SIZE=10 VALUE='@{[ $page->param("_f_item_total_amt_disputed") ]}'></TD>
					</TR> -->
				</TABLE>
			</TD>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

1;
