##############################################################################
package App::Page::Invoice;
##############################################################################

use strict;
use File::Spec;
use App::Page;
use App::Universal;
use App::Configuration;
use Number::Format;
use Date::Manip;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Catalog;
use App::Statements::Org;

use App::Billing::Claims;
use App::Billing::Input::DBI;
use App::Billing::Output::NSF;
use App::Billing::Output::TWCC;
use App::Billing::Validators;

use App::Dialog::Procedure;
use App::Dialog::OnHold;
use App::Dialog::Diagnoses;
use App::Dialog::ClaimProblem;
use App::Dialog::PostGeneralPayment;
use App::Dialog::PostInvoicePayment;
use App::Dialog::PostRefund;
use App::Dialog::PostTransfer;
#use App::Billing::Universal;
use App::Billing::Output::PDF;
use App::Billing::Output::HTML;
use App::IntelliCode;
use App::InvoiceUtilities;
use App::Page::Search;

use constant DATEFORMAT_USA => 1;
use constant PHONEFORMAT_USA => 1;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page);
%RESOURCE_MAP = (
	'invoice' => {
		_views => [
					{caption => 'Summary', name => 'summary',},
					{caption => 'HCFA 1500', name => '1500',},
					{caption => '1500 PDF', name => '1500pdf',},
					{caption => '1500 PDF Plain', name => '1500pdfplain',},
					{caption => 'TWCC 60 PDF', name => 'twcc60pdf',},
					{caption => 'TWCC 61 PDF', name => 'twcc61pdf',},
					{caption => 'TWCC 64 PDF', name => 'twcc64pdf',},
					{caption => 'TWCC 69 PDF', name => 'twcc69pdf',},
					{caption => 'TWCC 73 PDF', name => 'twcc73pdf',},
					{caption => 'Errors', name => 'errors',},
					{caption => 'History', name => 'history',},
					{caption => 'Notes', name => 'notes',},
					{caption => 'THIN NSF', name => 'thin_nsf',},
					{caption => 'Halley NSF', name => 'halley_nsf',},
					{caption => 'Dialog', name => 'dialog',},
					{caption => 'Submit', name => 'submit',},
					{caption => 'Review', name => 'review',},
					{caption => 'Intellicode', name => 'intellicode',},
					{caption => 'Adjustment', name => 'adjustment',},
			],
		},
	);

use constant NSFDEST_ARRAY => 0;
use constant NSFDEST_FILE => 1;
use constant DEFAULT_VFLAGS => 0;


#-----------------------------------------------------------------------------
# UTILITY METHODS
#-----------------------------------------------------------------------------

sub getPersonHtml
{
	my ($self, $person) = @_;

	my @info = ();
	foreach (sort keys %$person)
	{
		push(@info, "$_ = $person->{$_}<BR>");
	}

	my $addr = $person->{address};
	my $phone = $addr->getTelephoneNo(PHONEFORMAT_USA);
	return qq{
		$person->{firstName} $person->{middleInitial} $person->{lastName} ($person->{id})<br>
		$addr->{address1}<br>
		@{[ $addr->{address2} ? "$addr->{address2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zipCode}<br>
		$phone
	};
}

sub getOrgHtml
{
	my ($self, $org) = @_;

	my @info = ();
	foreach (sort keys %$org)
	{
		push(@info, "$_ = $org->{$_}<BR>");
	}

	my $addr = $org->{address};
	my $phone = $addr->getTelephoneNo(PHONEFORMAT_USA);
	return qq{
		$org->{name} ($org->{id})<br>
		$addr->{address1}<br>
		@{[ $addr->{address2} ? "$addr->{address2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zipCode}<br>
		$phone
	};
}

sub getPayerHtml
{
	my ($self, $payer, $planOrProductName) = @_;

	my @info = ();
	foreach (sort keys %$payer)
	{
		push(@info, "$_ = $payer->{$_}<BR>");
	}

	my $addr = $payer->{address};
	my $phone = $addr->getTelephoneNo(PHONEFORMAT_USA);
	return qq{
		@{[ $planOrProductName ? $planOrProductName : $payer->{name} ]} ($payer->{id})<br>
		$addr->{address1}<br>
		@{[ $addr->{address2} ? "$addr->{address2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zipCode}<br>
		$phone
	};
}

sub getProcedureHtml
{
	my ($self, $claim, $itemId) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	my $invoiceId = $self->param('invoice_id');
	my $invStatus = $claim->getStatus();

	my @rows = ();

	my $lineSeq;
	my $procedure = undef;
	my $totalItems = scalar(@{$claim->{procedures}});
	foreach my $itemIdx (0..$totalItems-1)
	{
		next if $itemId != $claim->{procedures}->[$itemIdx]->{itemId};
		$procedure = $claim->{procedures}->[$itemIdx];
		$lineSeq = $itemIdx + 1;
	}


	#my $procedure = $claim->{procedures}->[$itemIdx];

	#my $lineSeq = $itemIdx + 1;

	my $emg = $procedure->{emergency} eq 'Y' ? "<img src='/resources/icons/checkmark.gif' border=0>" : '';
	#my $itemId = $procedure->{itemId};
	my $itemType = $procedure->{itemType};
	my $comments = $procedure->{comments};

	my $itemAdjustmentTotal = $procedure->{totalAdjustments};
	my $itemExtCost = $procedure->{extendedCost};

	$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);

	$itemExtCost = $formatter->format_price($itemExtCost);

	my ($cmtRow, $unitCost) = ('', '');
	if(my $comments = $procedure->{comments})
	{
		$cmtRow = qq{
			<TR>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD COLSPAN=15><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=NAVY>$comments</FONT></TD>
			</TR>
		}
	}
	if($procedure->{daysOrUnits} > 1)
	{
		$unitCost = "<BR>(\$$procedure->{charges} x $procedure->{daysOrUnits})";
	}

	#GET CAPTION FOR SERVICE PLACE, MODIFIER, CPT CODE
	#my $servPlaceCode = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlaceById', $procedure->{placeOfService});
	my $servPlaceCode = $procedure->{placeOfService};
	my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $servPlaceCode);

	#my $servTypeCode = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceTypeById', $procedure->{typeOfService});
	my $servTypeCode = $procedure->{typeOfService};
	my $servTypeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceType', $servTypeCode);

	my $servPlaceAndTypeTitle = "Service Place: $servPlaceCaption" . "\n" . "Service Type: $servTypeCaption";

	my $modifierCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericModifier', $procedure->{modifier});
	my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $procedure->{cpt});
	my $cptAndModTitle = "CPT: $cptCaption->{name}" . "\n" . "Modifier: $modifierCaption";

	my $serviceFromDate;
	my $serviceToDate;
	if($itemType == App::Universal::INVOICEITEMTYPE_SERVICE || $itemType == App::Universal::INVOICEITEMTYPE_LAB)
	{
		$serviceFromDate = $procedure->getDateOfServiceFrom(DATEFORMAT_USA);	#$otherItem->{dateOfServiceFrom};
		$serviceToDate = $procedure->getDateOfServiceTo(DATEFORMAT_USA);	#$otherItem->{dateOfServiceTo};
	}


	push(@rows, qq{
		<TR>
			<TD><FONT FACE="Arial,Helvetica" SIZE=3><B>$lineSeq</B></FONT></TD>
			<TD>&nbsp;</TD>
			<TD><FONT FACE="Arial,Helvetica" SIZE=2>$serviceFromDate @{[ $procedure->{dateOfServiceTo} ne $procedure->{dateOfServiceFrom} ? " - $serviceToDate" : '']} </TD>
			<TD>&nbsp;</TD>
			<TD TITLE="$servPlaceAndTypeTitle"><FONT FACE="Arial,Helvetica" SIZE=2>$servPlaceCode @{[$servTypeCode ? "($servTypeCode)" : '']}</TD>
			<TD>&nbsp;</TD>
			<TD TITLE="$cptAndModTitle"><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{cpt} @{[$procedure->{modifier} ? "($procedure->{modifier})" : '']}</TD>
			<TD>&nbsp;</TD>
			<TD><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{diagnosis}</TD>
			<TD>&nbsp;</TD>
			<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost$unitCost</TD>
			<TD>&nbsp;</TD>
			<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="DARKRED">$itemAdjustmentTotal</TD>
			<TD>&nbsp;</TD>
			<TD ALIGN="Center">$emg</td>
			<TD>&nbsp;</TD>
			<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{reference}</FONT></td>
		</TR>
		$cmtRow
		<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
	});

	return qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=1>
						<TR BGCOLOR=EEEEEE>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>#</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Date</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Svc</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Code</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Diag</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Chg</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Adj</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>EMG</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Expl Code</B></TD>
						</TR>
						@rows
					</TABLE>
				</TD>
			</TR>
		</TABLE>
		};
}

sub getProceduresHtml
{
	my ($self, $claim) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	my @rows = ();

	my $created = App::Universal::INVOICESTATUS_CREATED;
	my $onHold = App::Universal::INVOICESTATUS_ONHOLD;
	my $pending = App::Universal::INVOICESTATUS_PENDING;
	my $submitted = App::Universal::INVOICESTATUS_SUBMITTED;
	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;

	my $invoiceId = $self->param('invoice_id');
	my $invType = $claim->getInvoiceType();
	my $claimType = $claim->getInvoiceSubtype();
	my $invStatus = $claim->getStatus();
	my $totalItems = scalar(@{$claim->{procedures}});

	foreach my $itemIdx (0..$totalItems-1)
	{
		my $procedure = $claim->{procedures}->[$itemIdx];
		my $lineSeq = $itemIdx + 1;
		my $itemId = $procedure->{itemId};
		my $itemStatus = $procedure->{itemStatus};
		my $emg = $procedure->{emergency} eq 'Y' ? "<img src='/resources/icons/checkmark.gif' border=0>" : '';

		my $editProcHref = "/invoice/$invoiceId/dialog/procedure/update,$itemId";
		my $voidProcHref = "/invoice/$invoiceId/dialog/procedure/remove,$itemId";
		my $editProcImg = '';
		my $voidProcImg = '';
		if($invStatus < $submitted && $itemStatus ne 'void')
		{
			$editProcImg = $procedure->{explosion} ne 'explosion' ? "<a href='$editProcHref'><img src='/resources/icons/edit_update.gif' border=0 title='Edit Item'></a>" : '';
			$voidProcImg = $procedure->{explosion} ne 'explosion' ? "<a href='$voidProcHref'><img src='/resources/icons/edit_remove.gif' border=0 title='Void Item'></a>" : '';
		}

		my $itemAdjustmentTotal = $procedure->{totalAdjustments};
		my $itemExtCost = $procedure->{extendedCost};

		$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId,$itemIdx');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";

		$itemExtCost = $formatter->format_price($itemExtCost);

		my ($cmtRow, $unitCost) = ('', '');
		if(my $comments = $procedure->{comments})
		{
			$cmtRow = qq{
				<TR>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
					<TD COLSPAN=15><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=NAVY>$comments</FONT></TD>
				</TR>
			}
		}
		if($procedure->{daysOrUnits} > 1)
		{
			$unitCost = "<BR>(\$$procedure->{charges} x $procedure->{daysOrUnits})";
		}

		#GET CAPTION FOR SERVICE PLACE, MODIFIER, CPT CODE
		#my $servPlaceCode = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlaceById', $procedure->{placeOfService});
		my $servPlaceCode = $procedure->{placeOfService};
		my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $servPlaceCode);

		#my $servTypeCode = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceTypeById', $procedure->{typeOfService});
		my $servTypeCode = $procedure->{typeOfService};
		my $servTypeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceType', $servTypeCode);

		my $servPlaceAndTypeTitle = "Service Place: $servPlaceCaption" . "\n" . "Service Type: $servTypeCaption";

		my $modifierCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericModifier', $procedure->{modifier});
		my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $procedure->{cpt});
		my $codeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selCatalogEntryTypeCapById', $procedure->{codeType});
		my $cptAndModTitle = "$codeCaption: $cptCaption->{name}" . "\n" . "Modifier: $modifierCaption";

		my $serviceFromDate = $procedure->getDateOfServiceFrom(DATEFORMAT_USA);	#$procedure->{dateOfServiceFrom};
		my $serviceToDate = $procedure->getDateOfServiceTo(DATEFORMAT_USA);	#$procedure->{dateOfServiceTo};
		push(@rows, qq{
			<TR>
				<TD><FONT FACE="Arial,Helvetica" SIZE=3>$editProcImg&nbsp;$voidProcImg<B>$lineSeq</B></FONT></TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$serviceFromDate @{[ $procedure->{dateOfServiceTo} ne $procedure->{dateOfServiceFrom} ? " - $serviceToDate" : '']} </TD>
				<TD>&nbsp;</TD>
				<TD TITLE="$servPlaceAndTypeTitle"><FONT FACE="Arial,Helvetica" SIZE=2>$servPlaceCode @{[$servTypeCode ? "($servTypeCode)" : '']}</TD>
				<TD>&nbsp;</TD>
				<TD TITLE="$cptAndModTitle"><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{cpt} @{[$procedure->{modifier} ? "($procedure->{modifier})" : '']}</TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{diagnosis}</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost$unitCost</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="DARKRED">$viewPaymentHtml</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center">$emg</td>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{reference}</FONT></td>
			</TR>
			$cmtRow
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	my $suppressedItems = scalar(@{$claim->{suppressedItems}});
	foreach my $itemIdx (0..$suppressedItems-1)
	{
		my $suppressedItem = $claim->{suppressedItems}->[$itemIdx];
		my $lineSeq = $itemIdx + 1;
		my $itemId = $suppressedItem->{itemId};
		my $itemStatus = $suppressedItem->{itemStatus};
		my $emg = $suppressedItem->{emergency} eq 'Y' ? "<img src='/resources/icons/checkmark.gif' border=0>" : '';

		my $editProcHref = "/invoice/$invoiceId/dialog/procedure/update,$itemId";
		my $voidProcHref = "/invoice/$invoiceId/dialog/procedure/remove,$itemId";
		my $editProcImg = '';
		my $voidProcImg = '';
		if($invStatus < $submitted && $itemStatus ne 'void')
		{
			$editProcImg = $suppressedItem->{explosion} ne 'explosion' ? "<a href='$editProcHref'><img src='/resources/icons/edit_update.gif' border=0 title='Edit Item'></a>" : '';
			$voidProcImg = $suppressedItem->{explosion} ne 'explosion' ? "<a href='$voidProcHref'><img src='/resources/icons/edit_remove.gif' border=0 title='Void Item'></a>" : '';
		}

		my $itemAdjustmentTotal = $suppressedItem->{totalAdjustments};
		my $itemExtCost = $suppressedItem->{extendedCost};

		$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";

		$itemExtCost = $formatter->format_price($itemExtCost);

		my ($cmtRow, $unitCost) = ('', '');
		if(my $comments = $suppressedItem->{comments})
		{
			$cmtRow = qq{
				<TR>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
					<TD COLSPAN=15><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=NAVY>$comments</FONT></TD>
				</TR>
			}
		}
		if($suppressedItem->{daysOrUnits} > 1)
		{
			$unitCost = "<BR>(\$$suppressedItem->{charges} x $suppressedItem->{daysOrUnits})";
		}

		#GET CAPTION FOR SERVICE PLACE, MODIFIER, CPT CODE
		#my $servPlaceCode = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlaceById', $suppressedItem->{placeOfService});
		my $servPlaceCode = $suppressedItem->{placeOfService};
		my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $servPlaceCode);

		#my $servTypeCode = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceTypeById', $suppressedItem->{typeOfService});
		my $servTypeCode = $suppressedItem->{typeOfService};
		my $servTypeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceType', $servTypeCode);

		my $servPlaceAndTypeTitle = "Service Place: $servPlaceCaption" . "\n" . "Service Type: $servTypeCaption";

		my $modifierCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericModifier', $suppressedItem->{modifier});
		my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $suppressedItem->{cpt});
		my $codeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selCatalogEntryTypeCapById', $suppressedItem->{codeType});
		my $cptAndModTitle = "$codeCaption: $cptCaption->{name}" . "\n" . "Modifier: $modifierCaption";

		my $serviceFromDate = $suppressedItem->getDateOfServiceFrom(DATEFORMAT_USA);	#$suppressedItem->{dateOfServiceFrom};
		my $serviceToDate = $suppressedItem->getDateOfServiceTo(DATEFORMAT_USA);	#$suppressedItem->{dateOfServiceTo};

		push(@rows, qq{
			<TR bgcolor="lightsteelblue">
				<TD><FONT FACE="Arial,Helvetica" SIZE=3>$editProcImg&nbsp;$voidProcImg<B>&nbsp;</B></FONT></TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$serviceFromDate @{[ $suppressedItem->{dateOfServiceTo} ne $suppressedItem->{dateOfServiceFrom} ? " - $serviceToDate" : '']} </TD>
				<TD>&nbsp;</TD>
				<TD TITLE="$servPlaceAndTypeTitle"><FONT FACE="Arial,Helvetica" SIZE=2>$servPlaceCode @{[$servTypeCode ? "($servTypeCode)" : '']}</TD>
				<TD>&nbsp;</TD>
				<TD TITLE="$cptAndModTitle"><FONT FACE="Arial,Helvetica" SIZE=2>$suppressedItem->{cpt} @{[$suppressedItem->{modifier} ? "($suppressedItem->{modifier})" : '']}</TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$suppressedItem->{diagnosis}</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost$unitCost</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="DARKRED">$viewPaymentHtml</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center">$emg</td>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$suppressedItem->{reference}</FONT></td>
			</TR>
			$cmtRow
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	my $copayItems = scalar(@{$claim->{copayItems}});
	foreach my $itemIdx (0..$copayItems-1)
	{
		my $copayItem = $claim->{copayItems}->[$itemIdx];
		my $itemId = $copayItem->{itemId};
		my $itemType = $copayItem->{itemType};
		my $itemNum = $itemIdx + 1;

		my $itemExtCost = $copayItem->{extendedCost};
		$itemExtCost = $formatter->format_price($itemExtCost);
		my $itemAdjustmentTotal = $copayItem->{totalAdjustments};
		$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";
		push(@rows, qq{
			<TR>
				<TD COLSPAN=10><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">Copay - $copayItem->{comments}</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
				<!-- <TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$itemAdjustmentTotal</TD> -->
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	my $coinsuranceItems = scalar(@{$claim->{coInsuranceItems}});
	foreach my $itemIdx (0..$coinsuranceItems-1)
	{
		my $coinsuranceItem = $claim->{coinsuranceItems}->[$itemIdx];
		my $itemId = $coinsuranceItem->{itemId};
		my $itemType = $coinsuranceItem->{itemType};
		my $itemNum = $itemIdx + 1;

		my $itemExtCost = $coinsuranceItem->{extendedCost};
		$itemExtCost = $formatter->format_price($itemExtCost);
		my $itemAdjustmentTotal = $coinsuranceItem->{totalAdjustments};
		$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";
		push(@rows, qq{
			<TR>
				<TD COLSPAN=10><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">Coinsurance - $coinsuranceItem->{comments}</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
				<!-- <TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$itemAdjustmentTotal</TD> -->
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	my $voidItems = scalar(@{$claim->{voidItems}});
	foreach my $itemIdx (0..$voidItems-1)
	{
		my $voidItem = $claim->{voidItems}->[$itemIdx];
		my $itemId = $voidItem->{itemId};
		my $itemType = $voidItem->{itemType};
		my $itemNum = $itemIdx + 1;
		my $emg = $voidItem->{emergency} eq 'Y' ? "<img src='/resources/icons/checkmark.gif' border=0>" : '';

		my $itemExtCost = $voidItem->{extendedCost};
		$itemExtCost = $formatter->format_price($itemExtCost);

		my $unitCost = '';
		if($voidItem->{daysOrUnits} > 1)
		{
			$unitCost = "<BR>(\$$voidItem->{charges} x $voidItem->{daysOrUnits})";
		}

		#GET CAPTION FOR SERVICE PLACE, MODIFIER, CPT CODE
		my $servPlaceCode = $voidItem->{placeOfService};
		my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $servPlaceCode);
		my $servTypeCode = $voidItem->{typeOfService};
		my $servTypeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceType', $servTypeCode);
		my $servPlaceAndTypeTitle = "Service Place: $servPlaceCaption" . "\n" . "Service Type: $servTypeCaption";

		my $modifierCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericModifier', $voidItem->{modifier});
		my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $voidItem->{cpt});
		my $codeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selCatalogEntryTypeCapById', $voidItem->{codeType});
		my $cptAndModTitle = "$codeCaption: $cptCaption->{name}" . "\n" . "Modifier: $modifierCaption";

		my $serviceFromDate = $voidItem->getDateOfServiceFrom(DATEFORMAT_USA);	#$voidItem->{dateOfServiceFrom};
		my $serviceToDate = $voidItem->getDateOfServiceTo(DATEFORMAT_USA);	#$voidItem->{dateOfServiceTo};

		push(@rows, qq{
			<TR>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">Void</TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$serviceFromDate @{[ $voidItem->{dateOfServiceTo} ne $voidItem->{dateOfServiceFrom} ? " - $serviceToDate" : '']} </TD>
				<TD>&nbsp;</TD>
				<TD TITLE="$servPlaceAndTypeTitle"><FONT FACE="Arial,Helvetica" SIZE=2>$servPlaceCode @{[$servTypeCode ? "($servTypeCode)" : '']}</TD>
				<TD>&nbsp;</TD>
				<TD TITLE="$cptAndModTitle"><FONT FACE="Arial,Helvetica" SIZE=2>$voidItem->{cpt} @{[$voidItem->{modifier} ? "($voidItem->{modifier})" : '']}</TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$voidItem->{diagnosis}</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost$unitCost</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="DARKRED">&nbsp;</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center">$emg</td>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$voidItem->{reference}</FONT></td>
			</TR>
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	my $totalOtherItems = scalar(@{$claim->{otherItems}});
	foreach my $itemIdx (0..$totalOtherItems-1)
	{
		my $otherItem = $claim->{otherItems}->[$itemIdx];
		my $itemId = $otherItem->{itemId};
		my $itemType = $otherItem->{itemType};

		my $itemNum = $itemIdx + 1;

		my $itemExtCost = $otherItem->{extendedCost};
		$itemExtCost = $formatter->format_price($itemExtCost);
		my $itemAdjustmentTotal = $otherItem->{totalAdjustments};
		$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);

		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";

		my $cmtRow = '';
		if(my $comments = $otherItem->{comments})
		{
			$cmtRow = qq{
				<TR>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
					<TD COLSPAN=15><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=NAVY>$comments</FONT></TD>
				</TR>
			}
		}

		push(@rows, qq{
			<TR>
				<TD COLSPAN=10><FONT FACE="Arial,Helvetica" SIZE=2>$itemNum: $otherItem->{caption}</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
				<!-- <TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$itemAdjustmentTotal</TD> -->
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			$cmtRow
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	my $totalAdjItems = scalar(@{$claim->{adjItems}});
	foreach my $itemIdx (0..$totalAdjItems-1)
	{
		my $adjItem = $claim->{adjItems}->[$itemIdx];
		my $itemNum = $itemIdx + 1;

		my $adjustment = $adjItem->{adjustments}->[0];
		my $adjComments = $adjustment->{comments};
		my $adjType = $adjustment->{adjustType};
		my $adjTypeCaption = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selAdjTypeCaption', $adjType);

		my $itemAdjustmentTotal = $adjItem->{totalAdjustments};
		$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$adjItem->{itemId},$itemIdx,$adjItem->{itemType}');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";

		push(@rows, qq{
			<TR>
				<TD COLSPAN=11><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$adjTypeCaption - $adjComments</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}


	#SIM/CURR ILLNESS DATES:
	my $simDate = $claim->{treatment}->getDateOfSameOrSimilarIllness(DATEFORMAT_USA);	#{dateOfSameOrSimilarIllness};
	my $currDate = $claim->{treatment}->getDateOfIllnessInjuryPregnancy(DATEFORMAT_USA);	#{dateOfIllnessInjuryPregnancy};

	#DIAGS AND THEIR CAPTIONS:
	my @allDiags = ();
	foreach (@{$claim->{diagnosis}})
	{
		push(@allDiags, $_->getDiagnosis());
	}

	my $icdCaption = '';

	foreach my $diag (@allDiags)
	{
		$icdCaption .= "$diag: ";
		my $icdInfo = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericICDCode', $diag);

		my $icdDescr = $icdInfo->{descr};
		$icdDescr =~ s/\'/&quot;/g;
		$icdCaption .= $icdDescr;
		#$icdCaption .= $icdInfo->{descr};
		$icdCaption .= "\n";
	}


	#INVOICE TOTALS
	my $invoiceTotal = $claim->{totalInvoiceCharges};
	$invoiceTotal = $formatter->format_price($invoiceTotal);

	my $invoiceAdjustmentTotal = $claim->{amountPaid};
	$invoiceAdjustmentTotal = $formatter->format_price($invoiceAdjustmentTotal);

	my $invoiceBalance = $claim->{balance};
	$invoiceBalance = $formatter->format_price($invoiceBalance);
	my $balColor = $invoiceBalance >= 0 ? 'Green' : 'Darkred';


	my $diagLink = '';
	if(@allDiags && $invStatus < $submitted)
	{
		$diagLink = "<A HREF='/invoice/$invoiceId/dialog/diagnoses/update'><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=777777>Diagnoses</FONT></A>";
	}
	elsif($invStatus < $submitted)
	{
		$diagLink = "<A HREF='/invoice/$invoiceId/dialog/diagnoses/add'><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=777777>Diagnoses</FONT></A>";
	}
	elsif($invStatus >= $submitted)
	{
		$diagLink = "<FONT FACE='Arial,Helvetica' SIZE=2 COLOR=777777>Diagnoses</FONT>";
	}

	return qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD>
					<TABLE CELLPADDING=1 CELLSPACING=0 BGCOLOR=999999>
						<TR VALIGN=TOP>
							<TD BGCOLOR=EEDDEE ALIGN=CENTER><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><NOBR>Current Illness</NOBR></TD>
						</TR>
						<TR>
							<TD BGCOLOR=WHITE ALIGN=CENTER><FONT FACE="Arial,Helvetica" SIZE=2>$currDate</TD>
						</TR>
						<TR VALIGN=TOP>
							<TD BGCOLOR=EEDDEE ALIGN=CENTER><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><NOBR>Similar Illness</NOBR></TD>
						</TR>
						<TR>
							<TD BGCOLOR=WHITE ALIGN=CENTER><FONT FACE="Arial,Helvetica" SIZE=2>$simDate</TD>
						</TR>
						<TR VALIGN=TOP>
							<TD BGCOLOR=EEDDEE ALIGN=CENTER>$diagLink</TD>
						</TR>
						<TR>
							<TD BGCOLOR=WHITE ALIGN=CENTER TITLE='$icdCaption'><FONT FACE="Arial,Helvetica" SIZE=2>@allDiags</TD>
						</TR>
					</TABLE>
				</TD>
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=1>
						<TR BGCOLOR=EEEEEE>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>#</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Date</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Svc</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Code</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Diag</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Chg</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Adj</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>EMG</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Expl Code</B></TD>
						</TR>
						@rows
						<TR BGCOLOR=DDEEEE>
							<TD COLSPAN=7><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Navy"><B>Balance:</B></FONT> <FONT FACE="Arial,Helvetica" SIZE=2 COLOR="$balColor"><B>$invoiceBalance</B></FONT></TD>
							<TD COLSPAN=2 ALIGN="Left"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred"><B>Totals:</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green"><B>$invoiceTotal</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred"><B>$invoiceAdjustmentTotal</B></TD>
							<TD COLSPAN=4><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>&nbsp;</B></TD>
						</TR>
					</TABLE>
				</TD>
			</TR>
		</TABLE>
		};
}

sub getItemHtml
{
	my ($self, $claim, $itemId) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	my @rows = ();

	my $created = App::Universal::INVOICESTATUS_CREATED;
	my $onHold = App::Universal::INVOICESTATUS_ONHOLD;
	my $pending = App::Universal::INVOICESTATUS_PENDING;
	my $submitted = App::Universal::INVOICESTATUS_SUBMITTED;
	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;

	my $invoiceId = $self->param('invoice_id');
	my $invType = $claim->getInvoiceType();
	my $claimType = $claim->getInvoiceSubtype();
	my $invStatus = $claim->getStatus();


	my $itemNum;
	my $otherItem = undef;
	my $totalOtherItems = scalar(@{$claim->{otherItems}});
	foreach my $itemIdx (0..$totalOtherItems-1)
	{
		next if $itemId != $claim->{otherItems}->[$itemIdx]->{itemId};
		$otherItem = $claim->{otherItems}->[$itemIdx];
		$itemNum = $itemIdx + 1;
	}

	#my $itemId = $otherItem->{itemId};
	my $itemType = $otherItem->{itemType};

	my $itemExtCost = $otherItem->{extendedCost};
	$itemExtCost = $formatter->format_price($itemExtCost);
	my $itemAdjustmentTotal = $otherItem->{totalAdjustments};
	$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);

	my $cmtRow = '';
	if(my $comments = $otherItem->{comments})
	{
		$cmtRow = qq{
			<TR>
				<TD COLSPAN=2><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD COLSPAN=11><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=NAVY>$comments</FONT></TD>
			</TR>
		}
	}

	my $serviceFromDate;
	my $serviceToDate;
	if($itemType == App::Universal::INVOICEITEMTYPE_INVOICE)
	{
		$serviceFromDate = $otherItem->getDateOfServiceFrom(DATEFORMAT_USA);	#$otherItem->{dateOfServiceFrom};
		$serviceToDate = $otherItem->getDateOfServiceTo(DATEFORMAT_USA);	#$otherItem->{dateOfServiceTo};
	}

	push(@rows, qq{
		<TR>
			<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=3><B>$itemNum</B></TD>
			<TD>&nbsp;</TD>
			<TD><FONT FACE="Arial,Helvetica" SIZE=2>$serviceFromDate @{[ $otherItem->{dateOfServiceTo} ne $otherItem->{dateOfServiceFrom} ? " - $serviceToDate" : '']} </TD>
			<TD>&nbsp;</TD>
			<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$otherItem->{daysOrUnits}</TD>
			<TD>&nbsp;</TD>
			<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$otherItem->{cpt}</TD>
			<TD>&nbsp;</TD>
			<TD ALIGN="Left"><FONT FACE="Arial,Helvetica" SIZE=2>$otherItem->{caption}</TD>
			<TD>&nbsp;</TD>
			<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost</TD>
			<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
			 <TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$itemAdjustmentTotal</TD>
		</TR>
		$cmtRow
		<TR><TD COLSPAN=13><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
	});


	#INVOICE TOTALS
	my $invoiceTotal = $claim->{totalInvoiceCharges};
	$invoiceTotal = $formatter->format_price($invoiceTotal);

	my $invoiceAdjustmentTotal = $claim->{amountPaid};
	$invoiceAdjustmentTotal = $formatter->format_price($invoiceAdjustmentTotal);

	my $invoiceBalance = $claim->{balance};
	$invoiceBalance = $formatter->format_price($invoiceBalance);
	my $balColor = $invoiceBalance >= 0 ? 'Green' : 'Darkred';


	return qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=1>
						<TR BGCOLOR=EEEEEE>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>#</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Dates</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Qty</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Code</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Description</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Charge</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Adj</B></TD>
						</TR>
						@rows
					</TABLE>
				</TD>
			</TR>
		</TABLE>
		};
}

sub getItemsHtml
{
	my ($self, $claim) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	my @rows = ();

	my $created = App::Universal::INVOICESTATUS_CREATED;
	my $onHold = App::Universal::INVOICESTATUS_ONHOLD;
	my $pending = App::Universal::INVOICESTATUS_PENDING;
	my $submitted = App::Universal::INVOICESTATUS_SUBMITTED;
	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;

	my $invoiceId = $self->param('invoice_id');
	my $invType = $claim->getInvoiceType();
	my $claimType = $claim->getInvoiceSubtype();
	my $invStatus = $claim->getStatus();

	my $totalOtherItems = scalar(@{$claim->{otherItems}});
	foreach my $itemIdx (0..$totalOtherItems-1)
	{
		my $otherItem = $claim->{otherItems}->[$itemIdx];
		my $itemId = $otherItem->{itemId};
		my $itemType = $otherItem->{itemType};

		my $itemNum = $itemIdx + 1;

		my $itemExtCost = $otherItem->{extendedCost};
		$itemExtCost = $formatter->format_price($itemExtCost);
		my $itemAdjustmentTotal = $otherItem->{totalAdjustments};
		$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);

		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId,$itemIdx,$itemType');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";

		my $cmtRow = '';
		if(my $comments = $otherItem->{comments})
		{
			$cmtRow = qq{
				<TR>
					<TD COLSPAN=2><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
					<TD COLSPAN=11><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=NAVY>$comments</FONT></TD>
				</TR>
			}
		}

		my $serviceFromDate = $otherItem->getDateOfServiceFrom(DATEFORMAT_USA);	#$otherItem->{dateOfServiceFrom};
		my $serviceToDate = $otherItem->getDateOfServiceTo(DATEFORMAT_USA);	#$otherItem->{dateOfServiceTo};

		push(@rows, qq{
			<TR>
				<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=3><B>$itemNum</B></TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$serviceFromDate @{[ $otherItem->{dateOfServiceTo} ne $otherItem->{dateOfServiceFrom} ? " - $serviceToDate" : '']} </TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$otherItem->{daysOrUnits}</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$otherItem->{cpt}</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Left"><FONT FACE="Arial,Helvetica" SIZE=2>$otherItem->{caption}</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
				<!-- <TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$itemAdjustmentTotal</TD> -->
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			$cmtRow
			<TR><TD COLSPAN=13><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	my $totalAdjItems = scalar(@{$claim->{adjItems}});
	foreach my $itemIdx (0..$totalAdjItems-1)
	{
		my $adjItem = $claim->{adjItems}->[$itemIdx];
		my $itemNum = $itemIdx + 1;

		my $adjustment = $adjItem->{adjustments}->[0];
		my $adjComments = $adjustment->{comments};
		my $adjType = $adjustment->{adjustType};
		my $adjTypeCaption = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selAdjTypeCaption', $adjType);

		my $itemAdjustmentTotal = $adjItem->{totalAdjustments};
		$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$adjItem->{itemId},$itemIdx,$adjItem->{itemType}');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";

		push(@rows, qq{
			<TR>
				<TD COLSPAN=2>&nbsp;</TD>
				<TD COLSPAN=10><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$adjTypeCaption - $adjComments</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			<TR><TD COLSPAN=13><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}


	#INVOICE TOTALS
	my $invoiceTotal = $claim->{totalInvoiceCharges};
	$invoiceTotal = $formatter->format_price($invoiceTotal);

	my $invoiceAdjustmentTotal = $claim->{amountPaid};
	$invoiceAdjustmentTotal = $formatter->format_price($invoiceAdjustmentTotal);

	my $invoiceBalance = $claim->{balance};
	$invoiceBalance = $formatter->format_price($invoiceBalance);
	my $balColor = $invoiceBalance >= 0 ? 'Green' : 'Darkred';


	return qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=1>
						<TR BGCOLOR=EEEEEE>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>#</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Dates</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Qty</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Code</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Description</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Charge</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Adj</B></TD>
						</TR>
						@rows
						<TR BGCOLOR=DDEEEE>
							<TD COLSPAN=8><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Navy"><B>Balance:</B></FONT> <FONT FACE="Arial,Helvetica" SIZE=2 COLOR="$balColor"><B>$invoiceBalance</B></FONT></TD>
							<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred"><B>Totals:</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green"><B>$invoiceTotal</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred"><B>$invoiceAdjustmentTotal</B></TD>
						</TR>
					</TABLE>
				</TD>
			</TR>
		</TABLE>
		};
}

sub getHistoryHtml
{
	my ($self, $claim) = @_;

	my $invoiceId = $self->param('invoice_id');
	my $allStatusHistory = $STMTMGR_INVOICE->getRowsAsHashList($self, STMTMGRFLAG_NONE, 'selAllHistoryItems', $invoiceId);

	my @rows = ();
	foreach my $statusHistory (@{$allStatusHistory})
	{
		push(@rows, qq{
			<TR VALIGN=TOP>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$statusHistory->{value_date}</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$statusHistory->{value_text}</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$statusHistory->{cr_user_id}</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$statusHistory->{value_textb}</TD>
			</TR>
		});
	}

	return qq{
				<TABLE border=0 CELLSPACING=0>
					<TR VALIGN=TOP BGCOLOR=EEEEEE>
						<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Date</B></TD>
						<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
						<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Action</B></TD>
						<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
						<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>By</B></TD>
						<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
						<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Comments</B></TD>
					</TR>
					@rows
				</TABLE>
			};
}

sub getIntelliCodeResultsHtml
{
	my ($self, $claim) = @_;

	my $invoiceId = $self->param('invoice_id');
	my $patient = $claim->getCareReceiver();
	my @diags = ();

	foreach (@{$claim->{diagnosis}})
	{
		push(@diags, $_->{diagnosis});
	}

	my @procs = ();
	foreach (@{$claim->{procedures}})
	{
		push(@procs, [$_->{cpt}, $_->{modifier} || undef, split(/,/, $_->{diagnosis})]);
	}

	my @errors = App::IntelliCode::validateCodes
		(
			$self, 0,
			sex => $patient->getSex(),
			dateOfBirth => $patient->getDateOfBirth(),
			diags => \@diags,
			procs => \@procs,
			invoiceId => $invoiceId,
			personId => $patient->getId(),
		);

	return @errors ? ('<UL><LI>' . join('<LI>', @errors) . '</UL>') : 'No discrepancies found';
}

#-----------------------------------------------------------------------------
# DIALOG MANAGEMENT METHODS
#-----------------------------------------------------------------------------

#using these instead of dlg-add-xxx because we want to show the invoice summary under dialog, otherwise dialog is shown alone.

sub prepare_dialog_procedure
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');
	my $claim = $self->property('activeClaim');

	my $dialogCmd = $self->param('_pm_dialog_cmd') || 'add';
	my ($action, $itemId) = split(/,/, $dialogCmd);
	$self->param('item_id', $itemId);

	$self->addContent('<center><p>', $self->getProceduresHtml($claim), '</p></center>');

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::Procedure(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $action);

	$self->addContent('<p>');
	return $self->prepare_view_summary();
}

sub prepare_dialog_diagnoses
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');
	my $dialogCmd = $self->param('_pm_dialog_cmd') || 'add';
	my ($action) = split(/,/, $dialogCmd);

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::Diagnoses(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $action);

	$self->addContent('<p>');
	return $self->prepare_view_summary();
}

sub prepare_dialog_hold
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::OnHold(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, 'add');

	$self->addContent('<p>');
	return $self->prepare_view_summary();
}

sub prepare_dialog_problem
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::ClaimProblem(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, 'add');

	$self->addContent('<p>');
	return $self->prepare_view_summary();
}

sub prepare_dialog_claim
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');
	my $dialogCmd = $self->param('_pm_dialog_cmd') || 'add';
	my ($action) = split(/,/, $dialogCmd);

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::Encounter::CreateClaim(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $action);

	$self->addContent('<p>');
	return $self->prepare_view_summary();
}

sub prepare_dialog_postinvoicepayment
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::PostInvoicePayment(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, 'add');

	$self->addContent('<p>');
	return $self->prepare_view_summary();
}


#-----------------------------------------------------------------------------
# VIEW-MANAGEMENT METHODS
#-----------------------------------------------------------------------------

sub prepare_view_dialog
{
	my $self = shift;
	my $dialog = $self->param('_pm_dialog');

	if(my $method = $self->can("prepare_dialog_$dialog"))
	{
		return &{$method}($self);
	}
	else
	{
		$self->addError("Can't find prepare_dialog_$dialog method");
	}
	return 1;
}

sub prepare_view_summary
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');

	my $claim = $self->property('activeClaim');
	my $patient = $self->getPersonHtml($claim->{careReceiver});
	my $serviceProvider = "$claim->{renderingProvider}->{firstName} $claim->{renderingProvider}->{middleInitial} $claim->{renderingProvider}->{lastName} ($claim->{renderingProvider}->{id})";
	my $serviceOrg = $self->getOrgHtml($claim->{renderingOrganization});
	my $billingProvider = "$claim->{payToProvider}->{firstName} $claim->{payToProvider}->{middleInitial} $claim->{payToProvider}->{lastName} ($claim->{payToProvider}->{id})";
	my $billingOrg = $self->getOrgHtml($claim->{payToOrganization});
	my $payer = $self->getPayerHtml($claim->{payer}, $claim->{insured}->[0]->{insurancePlanOrProgramName});
	my $invStatus = $claim->getStatus();
	my $invType = $claim->getInvoiceType();
	my $claimType = $claim->getInvoiceSubtype();
	my $totalItems = $claim->getTotalItems();
	my @allDiags = ();
	foreach (@{$claim->{diagnosis}})
	{
		push(@allDiags, $_->getDiagnosis());
	}

	#invoice statuses
	my $created = App::Universal::INVOICESTATUS_CREATED;
	my $onHold = App::Universal::INVOICESTATUS_ONHOLD;
	my $pending = App::Universal::INVOICESTATUS_PENDING;
	my $submitted = App::Universal::INVOICESTATUS_SUBMITTED;
	my $transferred = App::Universal::INVOICESTATUS_TRANSFERRED;
	my $rejectInternal = App::Universal::INVOICESTATUS_INTNLREJECT;
	my $electronic = App::Universal::INVOICESTATUS_ETRANSFERRED;
	my $paper = App::Universal::INVOICESTATUS_MTRANSFERRED;
	my $rejectExternal = App::Universal::INVOICESTATUS_EXTNLREJECT;
	my $awaitInsPayment = App::Universal::INVOICESTATUS_AWAITINSPAYMENT;
	my $paymentApplied = App::Universal::INVOICESTATUS_PAYAPPLIED;
	my $appealed = App::Universal::INVOICESTATUS_APPEALED;
	my $closed = App::Universal::INVOICESTATUS_CLOSED;
	my $void = App::Universal::INVOICESTATUS_VOID;
	my $paperPrinted = App::Universal::INVOICESTATUS_PAPERCLAIMPRINTED;
	my $awaitClientPayment = App::Universal::INVOICESTATUS_AWAITCLIENTPAYMENT;
	#--------------------

	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $workComp = App::Universal::CLAIMTYPE_WORKERSCOMP;
	my $hcfaInvoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $genericInvoiceType = App::Universal::INVOICETYPE_SERVICE;

	my $payerPane = "<TD><FONT FACE='Arial,Helvetica' SIZE=2>$payer</TD>";
	my $payerPaneHeading = "<TD BGCOLOR=EEEEEE><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=333333><B>Payer</B></TD>";

	my $quickLinks = '';
	unless($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP))
	{
		if($invType == $hcfaInvoiceType)
		{

			my $submissionOrder = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Submission Order');
			$quickLinks = qq{
					<TR>
						@{[ $allDiags[0] ne '' && $invStatus < $submitted && $submissionOrder->{value_int} == 0 ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/procedure/add'>Add Procedure </a>
							</FONT>
						</TD>" : '' ]}

						@{[ $allDiags[0] eq '' && $invStatus < $submitted && $submissionOrder->{value_int} == 0 ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/diagnoses/add'>Add Diagnosis Codes</a>
							</FONT>
						</TD>" : '' ]}

						@{[ $totalItems > 0 && $invStatus < $submitted && $claimType != $selfPay ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/submit'>Submit Claim for Transfer</a>
							</FONT>
						</TD>" : '' ]}

						<!-- @{[ $totalItems > 0 && $claimType != $selfPay &&
							( ($invStatus >= $rejectInternal && $invStatus <= $paper) || $invStatus == $rejectExternal || $invStatus == $paymentApplied || $invStatus == $paperPrinted ) ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/submit?resubmit=1'>Resubmit Claim for Transfer</a>
							</FONT>
						</TD>" : '' ]}

						@{[ $totalItems > 0 && $claimType != $selfPay &&
							($invStatus == $rejectInternal || $invStatus == $rejectExternal || $invStatus == $paymentApplied) ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/submit?resubmit=2'>Submit Claim for Transfer to Next Payer</a>
							</FONT>
						</TD>" : '' ]} -->

						@{[ $invStatus != $onHold && $invStatus < $transferred ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/hold'>Place Claim On Hold</a>
							</FONT>
						</TD>" : '' ]}

						@{[ $claimType != $selfPay && $invStatus > $submitted && $invStatus != $void && $invStatus != $awaitClientPayment ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/postinvoicepayment?paidBy=insurance'>Apply Insurance Payment</a>
							</FONT>
						</TD>" : '' ]}

						@{[ $invStatus != $void  ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/postinvoicepayment?paidBy=personal'>Apply Personal Payment</a>
							</FONT>
						</TD>" : '' ]}
					</TR>
			};
		}
		elsif($invType == $genericInvoiceType)
		{
			$quickLinks = qq{
					<TR>
						<!-- <TD>
							<FONT FACE="Arial,Helvetica" SIZE=2>
							<a href="/">Update Invoice</a>
							</FONT>
						</TD> -->

						@{[ $invStatus != $onHold ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/hold'>Place Claim On Hold</a>
							</FONT>
						</TD>" : '' ]}
						@{[ $invStatus != $void  ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/postinvoicepayment?paidBy=personal'>Apply Payment</a>
							</FONT>
						</TD>" : '' ]}
					</TR>
			};
		}
	}

	my $intellicodeHtml = qq{
			<TABLE BGCOLOR="#EEEEEE" CELLSPACING=1 CELLPADDING=2 BORDER=0>
				<TR BGCOLOR="#EEEEEE">
					<TD>
						<FONT FACE="Arial,Helvetica" SIZE=2>
						<b>IntelliCode Results</b>
						</FONT>
					</TD>
					<TD ALIGN="RIGHT">
						@{[ $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP) ? '' : "<a href='/invoice/$invoiceId/intellicode'><img src='/resources/icons/details.gif' border=0></a>" ]}
					</TD>
				</TR>
				<TR BGCOLOR="WHITE">
					<TD COLSPAN=2>
						<FONT FACE="Arial,Helvetica" SIZE=2>
						@{[ $self->getIntelliCodeResultsHtml($claim) ]}
						</FONT>
					</TD>
				</TR>
			</TABLE>
	};

	push(@{$self->{page_content}}, qq{
		<CENTER>
		<p>
		<TABLE>
			<TR VALIGN=TOP>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333><B>Patient</B></TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333><B>Provider/Facility</B></TD>
				@{[ $claimType != $selfPay ? $payerPaneHeading : '' ]}
			</TR>
			<TR VALIGN=TOP>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$patient</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>Billing:<br>$billingProvider<br>$billingOrg<br><br>Service:<br>$serviceProvider<br>$serviceOrg</TD>
				@{[ $claimType != $selfPay ? $payerPane : '' ]}
			</TR>
		</TABLE>
		<p>
			<TABLE CELLSPACING=1 CELLPADDING=2 BORDER=0>$quickLinks</TABLE>
		</p>
		<p>
			@{[ $invType == $hcfaInvoiceType ? $self->getProceduresHtml($claim) : $self->getItemsHtml($claim) ]}
		</p>
		@{[ $invType == $hcfaInvoiceType ? $intellicodeHtml : '' ]}
	});

	return 1;
}

sub prepare_view_adjustment
{
	my $self = shift;

	my $adjItemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $claim = $self->property('activeClaim');

	my $viewItem = $self->param('_pm_item');
	my ($itemId, $idx, $itemType) = split(/,/, $viewItem);
	my $itemAdjs = $STMTMGR_INVOICE->getRowsAsHashList($self, STMTMGRFLAG_NONE, 'selItemAdjustments', $itemId);

	$self->setFlag(PAGEFLAG_IGNORE_BODYHEAD | PAGEFLAG_IGNORE_BODYFOOT);

	my $invoiceId = $self->param('invoice_id');
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAndClaimType', $invoiceId);
	my $heading = "Type: $invoice->{claim_type_caption}</B>, Status: $invoice->{invoice_status_caption}<BR>" || "Unknown ID: $invoiceId";
	my $procNum = $idx + 1;

	push(@{$self->{page_content}}, qq{
		<TABLE WIDTH=100% BGCOLOR=BEIGE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					<B>Adjustments for Claim $invoiceId @{[ $itemType != $adjItemType && defined $idx ? ", Procedure $procNum" : '' ]}</B>
				</FONT>
			</TD>
			<TD><a href='javascript:window.close()'><img src='/resources/icons/done.gif' border=0></a></TD>
		</TABLE>
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE CELLSPACING=0 CELLPADDING=0 BORDER=0>
			<TR>
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=2 COLOR=DARKRED>
						<B>$heading</B>
					</FONT>
				</TD>
			</TR>
		</TABLE>

		<BR><BR>

		<CENTER>
		<TABLE>
	});

	push(@{$self->{page_content}}, qq{
			<TR VALIGN=TOP>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Date</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Payer</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Adj Type</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Pay Type</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Pay Method</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Pay Ref</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Auth Ref</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Payment</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Writeoff Amt</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Writeoff Code</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Net Adjust</TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333>Comments</TD>
			</TR>
	});

	foreach my $adj (@{$itemAdjs})
	{
		my $totalAdj = $adj->{adjustment_amount} + $adj->{plan_paid};
		my $payerId = $adj->{payer_type} == 0 ? $adj->{payer_id} : $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selId', $adj->{payer_id});
		push(@{$self->{page_content}}, qq{
				<TR VALIGN=TOP>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{pay_date}</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$payerId</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{adjustment_type}</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{pay_type}</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{pay_method}</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{pay_ref}</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{data_text_a}</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$totalAdj</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{writeoff_amount}</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{writeoff_code}</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{net_adjust}</TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{comments}</TD>
				</TR>
		});
	}

	if($itemType != $adjItemType && defined $idx)
	{
		push(@{$self->{page_content}}, qq{
			</TABLE>
			<BR><BR>
			@{[ $invoice->{invoice_type} == 0 ? $self->getProcedureHtml($claim, $itemId) : $self->getItemHtml($claim, $itemId) ]}
		});
	}

	return 1;
}

sub prepare_view_intellicode
{
	my $self = shift;
	my $claim = $self->property('activeClaim');

	push(@{$self->{page_content}}, qq{
			<style>
				ol {font-family: Tahoma; font-size: 9pt}
				ul {font-family: Tahoma; font-size: 9pt}
				h3 {font-family: Tahoma; font-size: 11pt}

			</style>

			<TABLE BGCOLOR='#EEEEEE' CELLSPACING=1 CELLPADDING=2 BORDER=0>
				<TR BGCOLOR='#EEEEEE'>
					<TD>
						<FONT FACE="Arial,Helvetica" SIZE=2>
						<b>IntelliCode Results</b>
						</FONT>
					</TD>
				</TR>
				<TR BGCOLOR=WHITE>
					<TD>
						<FONT FACE="Arial,Helvetica" SIZE=2>
						@{[ $self->getIntelliCodeResultsHtml($claim) ]}
						</FONT>
					</TD>
				</TR>
			</TABLE>

			<h3>IntelliCode Validation Procedure </h3>

			The IntelliCode routine performs a series of checks on the given ICD and CPT codes and reports
			the results.  Each result item reported may or may not indicate an error condition.  In many
			cases, IntelliCode simply reports a condition that is flagged as "True" in the database.
			<P>
			The following list details the checks performed by the IntelliCode routine.
			<ol>
				<li>Validate that each given diagnosis code is a valid ICD code in the database.
				<li>Validate that each given procedure code is a valid CPT code in the database.
				<li>Cross checks:  Validate that a procedure is allowed with the diagnosis.

				<li>ICD Edits
					<ul>
						<li>Validate that the ICD is valid for the patient's sex.
						<li>Validate that the ICD is valid for the patient's age.
						<li>Indicate that an ICD is a Comorbidity/Complication code.
						<li>Indicate that an ICD is a Medicare-Secondary-Payer code.
						<li>Indicate that an ICD is a Manifestation code.
						<li>Indicate that an ICD is a Questionable-Admission code.
						<li>Indicate that an ICD is an Unacceptable-Primary-Diagnosis-Without code.
						<li>Indicate that an ICD is an Unacceptable-Principal code.
						<li>Indicate that an ICD is an Unacceptable-Procedure code.
						<li>Indicate that an ICD is an Non-specific-Procedure code.
						<li>Indicate that an ICD is an Non-covered-Procedure code.
					</ul>

				<li>Mutually Exclusive CPTs Edit:  Find in the list of given CPTs all mutually exclusive
				procedures.

				<li>Comprehensive/Compound CPTs Edit:  Find in the list of given CPTs all comprehensive
				compound procedures.

				<li>Additional CPT Edits
					<ul>
						<li>Indicate that a CPT is an Unlisted procedure.
						<li>Indicate that a CPT is Questionable procedure.
						<li>Indicate that a CPT is an ASC procedure.
						<li>Indicate that a CPT is a Non-Rep procedure.
						<li>Indicate that a CPT is a Non-Covered procedure.
					</ul>
			</ol>
	});

	return 1;

}

sub prepare_view_review
{
	my $self = shift;

	my $invoiceId = $self->param('invoice_id');
	my $todaysDate = UnixDate('today', $self->defaultUnixDateFormat());

	$self->schemaAction(
			'Invoice', 'update',
			invoice_id => $invoiceId,
			invoice_status => App::Universal::INVOICESTATUS_PENDING,
			_debug => 0
		);

	## Then, create invoice attributes for history of invoice status
	$self->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => 'Pending',
			value_textB => $self->field('comments') || undef,
			value_date => $todaysDate,
			_debug => 0
	);

	$self->redirect("/invoice/$invoiceId/summary");
}

sub prepare_view_submit
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');
	my $claim = $self->property('activeClaim');
	my $resubmitFlag = $self->param('resubmit');
	my $printFlag = $self->param('print');
	my $patient = $claim->getCareReceiver();
	my $patientId = $patient->getId();

	if(my $errorCount = App::IntelliCode::getNSFerrorCount($self, $invoiceId, $patientId))
	{
		$self->addContent(q{<B style='color:red'>Cannot submit claim. Please check IntelliCode errors.</B>});
	}
	else
	{
		my $handler = \&{'App::Dialog::Procedure::execAction_submit'};
		eval
		{
			$invoiceId = &{$handler}($self, 'add', $invoiceId, $resubmitFlag, $printFlag);
		};
		$self->addError($@) if $@;

		if($printFlag)
		{
			$self->redirect("/invoice-f/$invoiceId/1500pdfplain");
		}
		else
		{
			$self->redirect("/invoice/$invoiceId/summary");
		}
	}
}

sub prepare_view_history
{
	my $self = shift;

	my $claim = $self->property('activeClaim');

	push(@{$self->{page_content}}, qq{
		<CENTER>
		<p>
		@{[ $self->getHistoryHtml($claim) ]}
	});

	return $self->prepare_view_summary();
}

sub prepare_view_notes
{
	my $self = shift;

	my $claim = $self->property('activeClaim');

	push(@{$self->{page_content}}, qq{
		<CENTER>
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stpt-invoice.claim-notes#<BR>
					</font>
				</TD>
			</TR>
		</TABLE>
		</CENTER>
	});

	return $self->prepare_view_summary();
}

sub prepare_view_thin_nsf
{
	my $self = shift;

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');

	eval
	{
		my $output = new App::Billing::Output::NSF();
		$output->registerValidators($valMgr);
		$valMgr->validateClaim('Output', DEFAULT_VFLAGS, $claimList);

		my @outArray = ();
		$output->processClaims(destination => NSFDEST_ARRAY, outArray => \@outArray, claimList => $claimList, validationMgr => $valMgr, nsfType => App::Billing::Universal::NSF_THIN);

		push(@{$self->{page_content}}, '<pre>', join("\n", @outArray), '</pre>');

		my $errors = $valMgr->getErrors();
		foreach my $error (@$errors)
		{
			push(@{$self->{page_content}}, '<li>', join(', ', @$error), '</li>');
		}
	};
	$self->addError('Problem in sub prepare_view_thin_nsf', $@) if $@;

	return 1;
}

sub prepare_view_halley_nsf
{
	my $self = shift;

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $invoiceId = $self->param('invoice_id');
	my $fileName = "Perse_$invoiceId.edi";

	eval
	{
		my $output = new App::Billing::Output::NSF();
		my @outArray = ();
		$output->processClaims(destination => NSFDEST_FILE, outArray => \@outArray, outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $fileName), claimList => $claimList, nsfType => App::Billing::Universal::NSF_HALLEY);
	};

	eval
	{
		my $output = new App::Billing::Output::NSF();
		$output->registerValidators($valMgr);
		$valMgr->validateClaim('Output', DEFAULT_VFLAGS, $claimList);

		my @outArray = ();
		$output->processClaims(destination => NSFDEST_ARRAY, outArray => \@outArray, claimList => $claimList, validationMgr => $valMgr, nsfType => App::Billing::Universal::NSF_HALLEY);

		push(@{$self->{page_content}}, '<pre>', join("\n", @outArray), '</pre>');

		my $errors = $valMgr->getErrors();
		foreach my $error (@$errors)
		{
			push(@{$self->{page_content}}, '<li>', join(', ', @$error), '</li>');
		}
	};
	$self->addError('Problem in sub prepare_view_halley_nsf', $@) if $@;

	return 1;
}

sub prepare_view_1500
{
	my $self = shift;

	# these values are set in "initialize()" method
	my $invoiceId = $self->param('invoice_id');
	my $todaysDate = UnixDate('today', $self->defaultUnixDateFormat());
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $html = [];

	eval
	{
#		my $output = new pdflib;
		my $output = new App::Billing::Output::HTML;
		$output->processClaims(outArray => $html, claimList => $claimList, TEMPLATE_PATH => File::Spec->catfile($CONFDATA_SERVER->path_BillingTemplate(), 'View1500.dat'));
	};
	$self->addContent(@$html) if $html;
	$self->addError('Problem in sub prepare_view_1500', $@) if $@;

	$self->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $invoiceId,
		item_name => 'Invoice/History/Item',
		value_type => App::Universal::ATTRTYPE_HISTORY,
		value_text => 'Claim viewed',
		value_date => $todaysDate,
		_debug => 0
	);

	return 1;
}

sub prepare_view_1500edit
{
	my $self = shift;

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $html = [];

	eval
	{
#		my $output = new pdflib;
		my $output = new App::Billing::Output::HTML;
		$output->processClaims(outArray => $html, claimList => $claimList, TEMPLATE_PATH => File::Spec->catfile($CONFDATA_SERVER->path_BillingTemplate(), 'Edit1500.dat'));
	};
	$self->addContent(@$html) if $html;
	$self->addError('Problem in sub prepare_view_1500', $@) if $@;

	return 1;
}

sub prepare_view_1500pdf
{
	my $self = shift;
	my $plain = shift;

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $invoiceId = $self->param('invoice_id');
	my $sessUser = $self->session('user_id');
	my $todaysDate = UnixDate('today', $self->defaultUnixDateFormat());
	my $pdfName = "1500@{[ $plain ? 'PP' : '' ]}_$invoiceId.pdf";
	my $pdfHref = File::Spec->catfile($CONFDATA_SERVER->path_PDFOutputHREF, $pdfName);

	eval
	{
#		my $output = new pdflib;
		my $output = new App::Billing::Output::PDF;
		$output->processClaims(outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName), claimList => $claimList, drawBackgroundForm => $plain ? 0 : 1);
	};
	$self->redirect($pdfHref);
	#$self->addContent("<a href='$pdfHref' target='$pdfName'>View HCFA PDF File for Claim $invoiceId</a><script>window.location.href = '$pdfHref';</script>");
	$self->addError('Problem in sub prepare_view_1500pdf', $@) if $@;

	my $claimPrintHistoryItem = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selClaimPrintHistoryItemByUser', $invoiceId, $sessUser);
	my $timeDiff = $claimPrintHistoryItem->{timenow} - $claimPrintHistoryItem->{cr_stamp};

	#$self->addError("Cr User Id: $claimPrintHistoryItem->{cr_user_id}");
	#$self->addError("Session User Id: $sessUser");
	#$self->addError("Time Now: $claimPrintHistoryItem->{timenow}");
	#$self->addError("Cr Stamp: $claimPrintHistoryItem->{cr_stamp}");
	#$self->addError("Time Diff: $timeDiff");

	return 1 if $claimPrintHistoryItem->{cr_user_id} eq $sessUser && $timeDiff < 10;

	$self->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $invoiceId,
		item_name => 'Invoice/History/Item',
		value_type => App::Universal::ATTRTYPE_HISTORY,
		value_text => 'Claim printed',
		value_date => $todaysDate,
		_debug => 0
	);

	return 1;
}

sub prepare_view_1500pdfplain
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');
	my $todaysDate = UnixDate('today', $self->defaultUnixDateFormat());

	$self->prepare_view_1500pdf(1);
}

sub prepare_view_twcc60pdf
{
	my $self = shift;

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $invoiceId = $self->param('invoice_id');
	my $pdfName = 'TWCC60.pdf';
	my $pdfHref = File::Spec->catfile($CONFDATA_SERVER->path_PDFOutputHREF, $pdfName);

	eval
	{
		my $twccForm = new App::Billing::Output::TWCC;
		$twccForm->processClaims($claimList, reportId => 'TWCC60', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName));
	};
	$self->redirect($pdfHref);
	$self->addError('Problem in sub prepare_view_twcc60pdf', $@) if $@;

	return 1;
}

sub prepare_view_twcc61pdf
{
	my $self = shift;

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $invoiceId = $self->param('invoice_id');
	my $pdfName = 'TWCC61.pdf';
	my $pdfHref = File::Spec->catfile($CONFDATA_SERVER->path_PDFOutputHREF, $pdfName);

	eval
	{
		my $twccForm = new App::Billing::Output::TWCC;
		$twccForm->processClaims($claimList, reportId => 'TWCC61', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName));
	};
	$self->redirect($pdfHref);
	$self->addError('Problem in sub prepare_view_twcc61pdf', $@) if $@;

	return 1;
}

sub prepare_view_twcc64pdf
{
	my $self = shift;

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $invoiceId = $self->param('invoice_id');
	my $pdfName = 'TWCC64.pdf';
	my $pdfHref = File::Spec->catfile($CONFDATA_SERVER->path_PDFOutputHREF, $pdfName);

	eval
	{
		my $twccForm = new App::Billing::Output::TWCC;
		$twccForm->processClaims($claimList, reportId => 'TWCC64', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName));
	};
	$self->redirect($pdfHref);
	$self->addError('Problem in sub prepare_view_twcc64pdf', $@) if $@;

	return 1;
}

sub prepare_view_twcc69pdf
{
	my $self = shift;

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $invoiceId = $self->param('invoice_id');
	my $pdfName = 'TWCC69.pdf';
	my $pdfHref = File::Spec->catfile($CONFDATA_SERVER->path_PDFOutputHREF, $pdfName);

	eval
	{
		my $twccForm = new App::Billing::Output::TWCC;
		$twccForm->processClaims($claimList, reportId => 'TWCC69', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName));
	};
	$self->redirect($pdfHref);
	$self->addError('Problem in sub prepare_view_twcc69pdf', $@) if $@;

	return 1;
}

sub prepare_view_twcc73pdf
{
	my $self = shift;

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $invoiceId = $self->param('invoice_id');
	my $pdfName = 'TWCC73.pdf';
	my $pdfHref = File::Spec->catfile($CONFDATA_SERVER->path_PDFOutputHREF, $pdfName);

	eval
	{
		my $twccForm = new App::Billing::Output::TWCC;
		$twccForm->processClaims($claimList, reportId => 'TWCC73', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName));
	};
	$self->redirect($pdfHref);
	$self->addError('Problem in sub prepare_view_twcc73pdf', $@) if $@;

	return 1;
}

sub prepare_view_errors
{
	my $self = shift;

	my @errors =
	(
		[
			q{
				This page is currently under construction. Please return at a later time. Thanks.
			},
		],
	);

	my @html = ();
	my $priority = 0;
	foreach my $list (@errors)
	{
		$priority++;
		push(@html, "<font size=+1 color=darkred><b>Errors</b></font>", join('<br><br><li>', @$list));
	}

	$self->addContent(@html);
	return 1;
}

#-----------------------------------------------------------------------------
# PAGE CREATION METHODS
#-----------------------------------------------------------------------------

sub initialize
{
	my ($self) = shift;
	$self->SUPER::initialize(@_);

	my $claimList = new App::Billing::Claims;
	my $valMgr = new App::Billing::Validators;

	$self->property('claimList', $claimList);
	$self->property('valMgr', $valMgr);

	my $input = new App::Billing::Input::DBI;
	$input->registerValidators($valMgr);

	my $invoiceId = $self->param('invoice_id');

	$input->populateClaims($claimList, dbiHdl => $self->getSchema()->{dbh},
		invoiceIds => [$invoiceId], valMgr => $valMgr);
	my $st = $claimList->getStatistics;

	if($valMgr->haveErrors())
	{
		my $errors = $valMgr->getErrors();
		#for (@$errors)
		#{
		#	$self->addError($_->[0], $_->[1], $_->[2]);
		#}
	}

	my $claim = $claimList->{claims}->[0];
	$self->property('activeClaim', $claim);

	$self->addLocatorLinks(
			['Claims', '/search/claim'],
			[$invoiceId, "/invoice/$invoiceId"],
		);

	# Check user's permission to page
	my $invOwner = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selInvoiceOwner', $invoiceId);
	my $activeView = $self->param('_pm_view');
	if ($activeView)
	{
		unless($self->hasPermission("page/invoice/$activeView")  && $invOwner == $self->session('org_internal_id'))
		{
			$self->disable(
					qq{
						<b>Invoice Owner: $invOwner</b>
						<br>
						You do not have permission to view this information.
						Permission page/invoice/$activeView is required.

						Click <a href='javascript:history.back()'>here</a> to go back.
					});
		}
	}

	return 1;
}

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=summary$');
}

sub prepare_page_content_header
{
	my $self = shift;
	return if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	my $invoiceId = $self->param('invoice_id');
	my $sessOrg = $self->session('org_id');
	my ($colors, $fonts) = ($self->getThemeColors(), $self->getThemeFontTags());

	#-------------------
	#invoice statuses
	my $created = App::Universal::INVOICESTATUS_CREATED;
	my $onHold = App::Universal::INVOICESTATUS_ONHOLD;
	my $pending = App::Universal::INVOICESTATUS_PENDING;
	my $submitted = App::Universal::INVOICESTATUS_SUBMITTED;
	my $transferred = App::Universal::INVOICESTATUS_TRANSFERRED;
	my $rejectInternal = App::Universal::INVOICESTATUS_INTNLREJECT;
	my $electronic = App::Universal::INVOICESTATUS_ETRANSFERRED;
	my $paper = App::Universal::INVOICESTATUS_MTRANSFERRED;
	my $rejectExternal = App::Universal::INVOICESTATUS_EXTNLREJECT;
	my $awaitInsPayment = App::Universal::INVOICESTATUS_AWAITINSPAYMENT;
	my $paymentApplied = App::Universal::INVOICESTATUS_PAYAPPLIED;
	my $appealed = App::Universal::INVOICESTATUS_APPEALED;
	my $closed = App::Universal::INVOICESTATUS_CLOSED;
	my $void = App::Universal::INVOICESTATUS_VOID;
	my $paperPrinted = App::Universal::INVOICESTATUS_PAPERCLAIMPRINTED;
	my $awaitClientPayment = App::Universal::INVOICESTATUS_AWAITCLIENTPAYMENT;

	#claim types
	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $workComp = App::Universal::CLAIMTYPE_WORKERSCOMP;
	my $thirdParty = App::Universal::CLAIMTYPE_CLIENT;

	#invoice types
	my $hcfaInvoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $genericInvoiceType = App::Universal::INVOICETYPE_SERVICE;
	#-------------------

	my $claim = $self->property('activeClaim');
	my $invType = $claim->getInvoiceType();
	my $invStatus = $claim->getStatus();
	my $claimType = $claim->getInvoiceSubtype();
	my $totalItems = $claim->getTotalItems();
	my $invoiceBalance = $claim->{balance};
	my $invoiceTotalAdj = $claim->{amountPaid};

	#check submission order of claim
	my $submissionOrder;
	my $orderCaption;
	if($invType == $hcfaInvoiceType)
	{
		$submissionOrder = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Submission Order');
		my $order = $submissionOrder->{value_int};
		$orderCaption = 'Primary' if $order == 0;
		$orderCaption = 'Secondary' if $order == 1;
		$orderCaption = 'Tertiary' if $order == 2;
		$orderCaption = 'Quaternary' if $order == 3;
	}


	#check if any diag codes exist
	my @allDiags = ();
	foreach (@{$claim->{diagnosis}})
	{
		push(@allDiags, $_->getDiagnosis());
	}


	#check if any adjustments exist for this invoice
	my $noAdjsExist = 0;
	my $adjustments = scalar($STMTMGR_INVOICE->getRowsAsHashList($self, STMTMGRFLAG_NONE, 'selItemAdjustmentsByInvoiceId', $invoiceId));
	my $adjCount = scalar(@{$adjustments});
	unless($adjCount > 0)
	{
		$noAdjsExist = 1;
	}


	#check if twcc form fields exist for work comp types
	my $twcc60Command = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC60/1') ? 'update' : 'add';
	my $twcc61Command = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC61/16') ? 'update' : 'add';
	my $twcc64Command = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC64/17') ? 'update' : 'add';
	my $twcc69Command = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC69/17') ? 'update' : 'add';
	my $twcc73Command = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/TWCC73/4') ? 'update' : 'add';


	my $invoice = undef;
	my $heading = 'No invoice_id parameter provided';
	if($invoiceId)
	{
		$invoice = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAndClaimType', $invoiceId);
		$heading = $invoice->{invoice_id} ? "$orderCaption Type: $invoice->{claim_type_caption}</B>, Status: $invoice->{invoice_status_caption}<BR>" : "Unknown ID: $invoiceId";
	}
	my $clientId = uc($invoice->{client_id});

	my $urlPrefix = "/invoice/$invoiceId";
	$self->{page_heading} = "Claim $invoiceId";
	$self->{page_menu_sibling} = [
			['Summary', "$urlPrefix/summary", 'summary'],
			['HCFA 1500', "$urlPrefix/1500", '1500'],
			['1500 PDF (PP)', "/invoice/$invoiceId/1500pdf", '1500pdf'],
			['1500 PDF', "/invoice/$invoiceId/1500pdfplain", '1500pdfplain'],
			$claimType == $workComp ? ['TWCC60 PDF', "/invoice-f/$invoiceId/twcc60pdf", 'twcc60pdf'] : undef,
			$claimType == $workComp ? ['TWCC61 PDF', "/invoice-f/$invoiceId/twcc61pdf", 'twcc61pdf'] : undef,
			$claimType == $workComp ? ['TWCC64 PDF', "/invoice-f/$invoiceId/twcc64pdf", 'twcc64pdf'] : undef,
			$claimType == $workComp ? ['TWCC69 PDF', "/invoice-f/$invoiceId/twcc69pdf", 'twcc69pdf'] : undef,
			$claimType == $workComp ? ['TWCC73 PDF', "/invoice-f/$invoiceId/twcc73pdf", 'twcc73pdf'] : undef,
			['Errors', "$urlPrefix/errors", 'errors'],
			['History', "$urlPrefix/history", 'history'],
			['Notes', "$urlPrefix/notes", 'notes'],
			['THIN NSF', "$urlPrefix/thin_nsf", 'thin_nsf'],
			['Halley NSF', "$urlPrefix/halley_nsf", 'halley_nsf'],
		];
	$self->{page_menu_siblingSelectorParam} = '_pm_view';

	my $view = $self->param('_pm_view');
	my $chooseActionMenu = '';
	if($view eq 'thin_nsf' || $view eq 'halley_nsf' || $view eq 'history')
	{
		$chooseActionMenu = qq{ <TD COLSPAN=2><FONT FACE="Arial,Helvetica" SIZE=4 STYLE="font-family: tahoma; font-size: 14pt">&nbsp;</TD> };
	}
	else
	{
		$chooseActionMenu =
		qq{
			<FORM>
				<TD COLSPAN=1><FONT FACE="Arial,Helvetica" SIZE=4 STYLE="font-family: tahoma; font-size: 14pt">&nbsp;</TD>
				<TD ALIGN=RIGHT>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<SELECT style="font-family: tahoma,arial,helvetica; font-size: 8pt" onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
						<OPTION>Choose Action</OPTION>
						@{[ $allDiags[0] ne '' && $invStatus < $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/procedure/add'>Add Procedure</option>" : '' ]}
						@{[ $allDiags[0] eq '' && $invStatus < $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/diagnoses/add'>Add Diagnoses</option>" : '' ]}
						@{[ $allDiags[0] ne '' && $invStatus < $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/diagnoses/update'>Update Diagnoses</option>" : '' ]}

						@{[ $claimType != $selfPay && $invStatus > $submitted && $invStatus != $awaitClientPayment && $invStatus != $void && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/postinvoicepayment?paidBy=insurance'>Post Insurance Payment</option>" : '' ]}
						<option value="/person/$clientId/dlg-add-postpersonalpayment">Post Personal Payment</option>
						<option value="/person/$clientId/dlg-add-postrefund">Post Refund</option>
						<option value="/person/$clientId/dlg-add-posttransfer">Post Transfer</option>
						<option value="/invoice/$invoiceId/dlg-add-printclaim">View/Print Claim</option>
						<option value="/person/$clientId/account">View All Claims for this Patient</option>

						@{[ $invType == $hcfaInvoiceType && ($submissionOrder->{value_int} == 0 || $invStatus > $submitted) && $invStatus != $submitted && $invStatus != $appealed && $invStatus != $void && $invStatus != $closed ? "<option value='/invoice/$invoiceId/dialog/claim/update'>Edit Claim</option>" : '' ]}
						@{[ $invType == $genericInvoiceType && $invStatus != $void && $invStatus != $closed ? "<option value='/invoice/$invoiceId/dlg-update-invoice'>Edit Invoice</option>" : '' ]}

						@{[ $invStatus < $submitted && ($claimType == $selfPay || $claimType == $thirdParty) && $totalItems > 0 ? "<option value='/invoice/$invoiceId/submit'>Submit for Billing</option>" : '' ]}
						@{[ $invStatus < $submitted && $claimType != $selfPay && $totalItems > 0 && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/submit'>Submit Claim for Transfer</option>" : '' ]}

						@{[ ( ($invStatus >= $rejectInternal && $invStatus <= $paper) || $invStatus == $rejectExternal || $invStatus == $paymentApplied || $invStatus == $paperPrinted ) && $claimType != $selfPay && $totalItems > 0 && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/submit?resubmit=1'>Resubmit Claim for Transfer to Current Payer</option>" : '' ]}
						@{[ ( ($invStatus >= $rejectInternal && $invStatus <= $paper) || $invStatus == $rejectExternal || $invStatus == $awaitInsPayment || $invStatus == $paymentApplied || $invStatus == $paperPrinted ) && $claimType != $selfPay && $totalItems > 0 && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/submit?resubmit=2'>Submit Claim for Transfer to Next Payer</option>" : '' ]}
						@{[ $invStatus == $appealed || ($invStatus != $onHold && $invStatus < $transferred) ? "<option value='/invoice/$invoiceId/dialog/hold'>Place Claim On Hold</option>" : '' ]}

						@{[ $invStatus < $submitted && $invType == $hcfaInvoiceType && ($noAdjsExist == 1 || $invoiceTotalAdj == 0) ? "<option value='/invoice/$invoiceId/dialog/claim/remove'>Void Claim</option>" : '' ]}
						@{[ $invStatus < $submitted && $invType == $genericInvoiceType && ($noAdjsExist == 1 || $invoiceTotalAdj == 0) ? "<option value='/invoice/$invoiceId/dlg-remove-invoice'>Void Invoice</option>" : '' ]}

						@{[ $claimType == $selfPay || $invStatus >= $submitted ? qq{<option value='javascript:doActionPopup("/patientbill/$invoiceId")'>Print Patient Bill</option>} : '' ]}
						<option value="/invoice/$invoiceId/summary">View Claim</option>

						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc60Command-twcc60'>\u$twcc60Command TWCC Form 60</option>} : '' ]}
						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc61Command-twcc61'>\u$twcc61Command TWCC Form 61</option>} : '' ]}
						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc64Command-twcc64'>\u$twcc64Command TWCC Form 64</option>} : '' ]}
						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc69Command-twcc69'>\u$twcc69Command TWCC Form 69</option>} : '' ]}
						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc73Command-twcc73'>\u$twcc73Command TWCC Form 73</option>} : '' ]}

						<!-- <option value="/person/$clientId/account">Adjs Exist: $noAdjsExist</option>
						<option value="/person/$clientId/account">Adjs Count: $adjCount</option>
						<option value="/person/$clientId/account">Adj Total: $invoiceTotalAdj</option> -->
					</SELECT>
					</FONT>
				<TD>
			</FORM>
		};
	}

	$self->SUPER::prepare_page_content_header(@_);
	push(@{$self->{page_content_header}},
	qq{
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE CELLSPACING=0 CELLPADDING=0 BORDER=0>
			<TR>
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=2 COLOR=DARKRED>
						<B>$heading</B>
					</FONT>
				</TD>
			$chooseActionMenu
			</TR>
			<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		});

	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;

	return 1 if $self->param('_stdAction') eq 'dialog';

	unless($self->flagIsSet(PAGEFLAG_ISPOPUP))
	{
		push(@{$self->{page_content_footer}}, '<P>', App::Page::Search::getSearchBar($self, 'claim'));
	}
	$self->SUPER::prepare_page_content_footer(@_);
	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	# invoice_id must be the first item in the path
	return 'UIE-003010' unless $pathItems->[0];

	$self->param('invoice_id', $pathItems->[0]);
	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1] || 'summary') if $pathItems->[1];
		$self->param('_pm_item', $pathItems->[2]) if defined $pathItems->[2] && $self->param('_pm_view') eq 'adjustment';
		$self->param('_pm_dialog', $pathItems->[2]) if defined $pathItems->[2] && $self->param('_pm_view') eq 'dialog';
		$self->param('_pm_dialog_cmd', $pathItems->[3]) if defined $pathItems->[3] && $self->param('_pm_view') eq 'dialog';
	}

	$self->printContents();

	return 0;
}

1;
