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
use App::Dialog::PostGeneralPayment;
use App::Dialog::PostInvoicePayment;
use App::Dialog::PostRefund;
use App::Dialog::PostTransfer;
#use App::Billing::Universal;
use App::Billing::Output::PDF;
use App::Billing::Output::HTML;
use App::IntelliCode;
use App::Utilities::Invoice;
use App::Page::Search;

use constant DATEFORMAT_USA => 1;
use constant PHONEFORMAT_USA => 1;
use constant NSFDEST_ARRAY => 0;
use constant NSFDEST_FILE => 1;
use constant DEFAULT_VFLAGS => 0;

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
					{caption => 'Close', name => 'close',},
					{caption => 'Intellicode', name => 'intellicode',},
					{caption => 'Error', name => 'error',},
					{caption => 'Adjustment', name => 'adjustment',},
			],
		},
	);


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

sub createLineItemsTableHtml
{
	my ($self, $claim) = @_;
	my $invType = $claim->getInvoiceType();
	my $isHcfa = $invType == App::Universal::INVOICETYPE_HCFACLAIM;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	my @rows = ();
	push(@rows, qq{ @{[ $self->createProcedureItemsHtml($claim) ]} });
	push(@rows, qq{ @{[ $self->createSuppressedItemsHtml($claim) ]} });
	push(@rows, qq{ @{[ $self->createCopayItemsHtml($claim) ]} });
	push(@rows, qq{ @{[ $self->createCoinsuranceItemsHtml($claim) ]} });
	push(@rows, qq{ @{[ $self->createAdjItemsHtml($claim) ]} });
	push(@rows, qq{ @{[ $self->createVoidItemsHtml($claim) ]} });
	push(@rows, qq{ @{[ $self->createOtherItemsHtml($claim) ]} });


	my $balColor = $claim->{balance} >= 0 ? 'Green' : 'Darkred';
	return qq{
		<TABLE>
			<TR VALIGN=TOP>
				@{[ $isHcfa ? $self->createAddlHcfaHtml($claim) : '' ]}
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=1>
						@{[ $self->createLineItemsHeadingHtml($claim) ]}
						@rows
						<TR BGCOLOR=DDEEEE>
							<TD COLSPAN=8><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Navy"><B>Balance:</B></FONT> <FONT FACE="Arial,Helvetica" SIZE=2 COLOR="$balColor"><B>@{[ $formatter->format_price($claim->{balance}) ]}</B></FONT></TD>
							<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred"><B>Totals:</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green"><B>@{[ $formatter->format_price($claim->{totalInvoiceCharges}) ]}</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred"><B>@{[ $formatter->format_price($claim->{amountPaid}) ]}</B></TD>
							@{[ $isHcfa ? "<TD COLSPAN=4>&nbsp;</TD>" : '' ]}
						</TR>
					</TABLE>
				</TD>
			</TR>
		</TABLE>
	};
}

sub createAddlHcfaHtml
{
	my ($self, $claim) = @_;

	#DIAGS AND THEIR CAPTIONS:
	my @allDiags = ();
	foreach (@{$claim->{diagnosis}})
	{
		push(@allDiags, $_->getDiagnosis());
	}

	my $icdCaption;
	foreach my $diag (@allDiags)
	{
		$icdCaption .= "$diag: ";
		my $icdInfo = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericICDCode', $diag);

		my $icdDescr = $icdInfo->{descr};
		$icdDescr =~ s/\'/&quot;/g;
		$icdCaption .= $icdDescr;
		$icdCaption .= "\n";
	}

	return qq{
		<TD>
			<TABLE CELLPADDING=1 CELLSPACING=0 BGCOLOR=999999>
				<TR VALIGN=TOP>
					<TD BGCOLOR=EEDDEE ALIGN=CENTER><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><NOBR>Current Illness</NOBR></TD>
				</TR>
				<TR>
					<TD BGCOLOR=WHITE ALIGN=CENTER><FONT FACE="Arial,Helvetica" SIZE=2>@{[ $claim->{treatment}->getDateOfIllnessInjuryPregnancy(DATEFORMAT_USA) ]}</TD>
				</TR>
				<TR VALIGN=TOP>
					<TD BGCOLOR=EEDDEE ALIGN=CENTER><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><NOBR>Similar Illness</NOBR></TD>
				</TR>
				<TR>
					<TD BGCOLOR=WHITE ALIGN=CENTER><FONT FACE="Arial,Helvetica" SIZE=2>@{[ $claim->{treatment}->getDateOfSameOrSimilarIllness(DATEFORMAT_USA) ]}</TD>
				</TR>
				<TR VALIGN=TOP>
					<TD BGCOLOR=EEDDEE ALIGN=CENTER><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><NOBR>Diagnoses</NOBR></TD>
				</TR>
				<TR>
					<TD BGCOLOR=WHITE ALIGN=CENTER TITLE='$icdCaption'><FONT FACE="Arial,Helvetica" SIZE=2>@allDiags</TD>
				</TR>
			</TABLE>
		</TD>
	};
}

sub createLineItemsHeadingHtml
{
	my ($self, $claim) = @_;
	my $invType = $claim->getInvoiceType();

	if($invType == App::Universal::INVOICETYPE_HCFACLAIM)
	{
		return qq{
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
		};
	}
	elsif($invType == App::Universal::INVOICETYPE_SERVICE)
	{
		return qq{
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
		};
	}
}

sub createProcedureItemsHtml
{
	my ($self, $claim, $itemId, $inactive) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');
	my $invoiceId = $self->param('invoice_id');
	my $invStatus = $claim->getStatus();

	my $procedure;
	my @rows = ();
	foreach my $itemIdx (0..scalar(@{$claim->{procedures}})-1)
	{
		$procedure = $claim->{procedures}->[$itemIdx];
		next if defined $itemId && $itemId != $procedure->{itemId};

		my $lineSeq = $itemIdx + 1;

		my $itemId = $procedure->{itemId};
		my $emg = $procedure->{emergency} eq 'Y' ? "<img src='/resources/icons/checkmark.gif' border=0>" : '';

		my $editProcImg;
		my $voidProcImg;
		if($invStatus < App::Universal::INVOICESTATUS_SUBMITTED && $procedure->{itemStatus} ne 'void' && ! defined $inactive)
		{
			$editProcImg = $procedure->{explosion} ne 'explosion' ? "<a href='/invoice/$invoiceId/dialog/procedure/update,$itemId'><img src='/resources/icons/edit_update.gif' border=0 title='Edit Item'></a>" : '';
			$voidProcImg = $procedure->{explosion} ne 'explosion' ? "<a href='/invoice/$invoiceId/dialog/procedure/remove,$itemId'><img src='/resources/icons/edit_remove.gif' border=0 title='Void Item'></a>" : '';
		}

		my $itemExtCost = $formatter->format_price($procedure->{extendedCost});
		my $itemAdjustmentTotal = $formatter->format_price($procedure->{totalAdjustments});
		my $viewPaymentHtml = ! defined $inactive ? "<a href=javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId,$itemIdx');>$itemAdjustmentTotal</a>" : $itemAdjustmentTotal;

		my $cmtRow;
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

		my $unitCostHtml = $procedure->{daysOrUnits} > 1 ? qq{ <BR>(\$$procedure->{charges} x $procedure->{daysOrUnits}) } : '';

		#GET CAPTION FOR SERVICE PLACE/TYPE, MODIFIER, CPT CODE
		my $servPlaceCode = $procedure->{placeOfService};
		my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $servPlaceCode);
		my $servTypeCode = $procedure->{typeOfService};
		my $servTypeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceType', $servTypeCode);
		my $servPlaceAndTypeTitle = "Service Place: $servPlaceCaption" . "\n" . "Service Type: $servTypeCaption";

		my $modifierCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericModifier', $procedure->{modifier});
		my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $procedure->{cpt});
		my $codeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selCatalogEntryTypeCapById', $procedure->{codeType});
		my $cptAndModTitle = "$codeCaption: $cptCaption->{name}" . "\n" . "Modifier: $modifierCaption";

		my $serviceFromDate = $procedure->getDateOfServiceFrom(DATEFORMAT_USA);	#$procedure->{dateOfServiceFrom};
		my $serviceToDate = $procedure->getDateOfServiceTo(DATEFORMAT_USA);		#$procedure->{dateOfServiceTo};

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
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost$unitCostHtml</TD>
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

	return @rows;
}

sub createSuppressedItemsHtml
{
	my ($self, $claim, $itemId, $inactive) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');
	my $invoiceId = $self->param('invoice_id');
	my $invStatus = $claim->getStatus();

	my $suppressedItem;
	my @rows = ();
	foreach my $itemIdx (0..scalar(@{$claim->{suppressedItems}})-1)
	{
		$suppressedItem = $claim->{suppressedItems}->[$itemIdx];
		next if defined $itemId && $itemId != $suppressedItem->{itemId};

		my $itemId = $suppressedItem->{itemId};
		my $emg = $suppressedItem->{emergency} eq 'Y' ? "<img src='/resources/icons/checkmark.gif' border=0>" : '';

		my $editProcImg;
		my $voidProcImg;
		if($invStatus < App::Universal::INVOICESTATUS_SUBMITTED && $suppressedItem->{itemStatus} ne 'void' && ! defined $inactive)
		{
			$editProcImg = $suppressedItem->{explosion} ne 'explosion' ? "<a href='/invoice/$invoiceId/dialog/procedure/update,$itemId'><img src='/resources/icons/edit_update.gif' border=0 title='Edit Item'></a>" : '';
			$voidProcImg = $suppressedItem->{explosion} ne 'explosion' ? "<a href='/invoice/$invoiceId/dialog/procedure/remove,$itemId'><img src='/resources/icons/edit_remove.gif' border=0 title='Void Item'></a>" : '';
		}

		my $itemExtCost = $formatter->format_price($suppressedItem->{extendedCost});
		my $itemAdjustmentTotal = $formatter->format_price($suppressedItem->{totalAdjustments});
		my $viewPaymentHtml = ! defined $inactive ? "<a href=javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId');>$itemAdjustmentTotal</a>" : $itemAdjustmentTotal;

		my $cmtRow;
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

		my $unitCostHtml = $suppressedItem->{daysOrUnits} > 1 ? qq{ <BR>(\$$suppressedItem->{charges} x $suppressedItem->{daysOrUnits}) } : '';

		#GET CAPTION FOR SERVICE PLACE/TYPE, MODIFIER, CPT CODE
		my $servPlaceCode = $suppressedItem->{placeOfService};
		my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $servPlaceCode);
		my $servTypeCode = $suppressedItem->{typeOfService};
		my $servTypeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceType', $servTypeCode);
		my $servPlaceAndTypeTitle = "Service Place: $servPlaceCaption" . "\n" . "Service Type: $servTypeCaption";

		my $modifierCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericModifier', $suppressedItem->{modifier});
		my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $suppressedItem->{cpt});
		my $codeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selCatalogEntryTypeCapById', $suppressedItem->{codeType});
		my $cptAndModTitle = "$codeCaption: $cptCaption->{name}" . "\n" . "Modifier: $modifierCaption";

		my $serviceFromDate = $suppressedItem->getDateOfServiceFrom(DATEFORMAT_USA);	#$suppressedItem->{dateOfServiceFrom};
		my $serviceToDate = $suppressedItem->getDateOfServiceTo(DATEFORMAT_USA);		#$suppressedItem->{dateOfServiceTo};

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
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost$unitCostHtml</TD>
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

	return @rows;
}

sub createCopayItemsHtml
{
	my ($self, $claim, $itemId) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');
	my $invoiceId = $self->param('invoice_id');

	my $copayItem;
	my @rows = ();
	foreach my $itemIdx (0..scalar(@{$claim->{copayItems}})-1)
	{
		$copayItem = $claim->{copayItems}->[$itemIdx];
		next if defined $itemId && $itemId != $copayItem->{itemId};

		my $itemId = $copayItem->{itemId};
		my $itemExtCost = $formatter->format_price($copayItem->{extendedCost});
		my $itemAdjustmentTotal = $formatter->format_price($copayItem->{totalAdjustments});
		my $viewPaymentHtml = "<a href=javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId');>$itemAdjustmentTotal</a>";

		push(@rows, qq{
			<TR>
				<TD COLSPAN=10><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">Copay - $copayItem->{comments}</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	return @rows;
}

sub createCoinsuranceItemsHtml
{
	my ($self, $claim, $itemId) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');
	my $invoiceId = $self->param('invoice_id');

	my $coinsuranceItem;
	my @rows = ();
	foreach my $itemIdx (0..scalar(@{$claim->{coInsuranceItems}})-1)
	{
		$coinsuranceItem = $claim->{coInsuranceItems}->[$itemIdx];
		next if defined $itemId && $itemId != $coinsuranceItem->{itemId};

		my $itemId = $coinsuranceItem->{itemId};
		my $itemExtCost = $formatter->format_price($coinsuranceItem->{extendedCost});
		my $itemAdjustmentTotal = $formatter->format_price($coinsuranceItem->{totalAdjustments});
		my $viewPaymentHtml = "<a href=javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId');>$itemAdjustmentTotal</a>";

		push(@rows, qq{
			<TR>
				<TD COLSPAN=10><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">Coinsurance - $coinsuranceItem->{comments}</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	return @rows;
}

sub createAdjItemsHtml
{
	my ($self, $claim, $itemId) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');
	my $invoiceId = $self->param('invoice_id');

	my $adjItem;
	my @rows = ();
	foreach my $itemIdx (0..scalar(@{$claim->{adjItems}})-1)
	{
		$adjItem = $claim->{adjItems}->[$itemIdx];
		next if defined $itemId && $itemId != $adjItem->{itemId};

		my $itemId = $adjItem->{itemId};
		my $adjTypeCaption = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selAdjTypeCaption', $adjItem->{adjustments}->[0]->{adjustType});
		my $itemAdjustmentTotal = $formatter->format_price($adjItem->{totalAdjustments});
		my $viewPaymentHtml = "<a href=javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId,$itemIdx,$adjItem->{itemType}');>$itemAdjustmentTotal</a>";

		push(@rows, qq{
			<TR>
				<TD COLSPAN=11><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$adjTypeCaption - $adjItem->{comments}</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	return @rows;
}

sub createVoidItemsHtml
{
	my ($self, $claim, $itemId) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	my $voidItem;
	my @rows = ();
	foreach my $itemIdx (0..scalar(@{$claim->{voidItems}})-1)
	{
		$voidItem = $claim->{voidItems}->[$itemIdx];
		next if defined $itemId && $itemId != $voidItem->{itemId};

		my $itemId = $voidItem->{itemId};
		my $emg = $voidItem->{emergency} eq 'Y' ? "<img src='/resources/icons/checkmark.gif' border=0>" : '';
		my $itemExtCost = $formatter->format_price($voidItem->{extendedCost});
		my $unitCostHtml = $voidItem->{daysOrUnits} > 1 ? qq{ <BR>(\$$voidItem->{charges} x $voidItem->{daysOrUnits}) } : '';

		#GET CAPTION FOR SERVICE PLACE/TYPE, MODIFIER, CPT CODE
		my $servPlaceCode = $voidItem->{placeOfService};
		my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $servPlaceCode);
		my $servTypeCode = $voidItem->{typeOfService};
		my $servTypeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServiceType', $servTypeCode);
		my $servPlaceAndTypeTitle = "Service Place: $servPlaceCaption" . "\n" . "Service Type: $servTypeCaption";

		my $modifierCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericModifier', $voidItem->{modifier});
		my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $voidItem->{cpt});
		my $codeCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selCatalogEntryTypeCapById', $voidItem->{codeType});
		my $cptAndModTitle = "$codeCaption: $cptCaption->{name}" . "\n" . "Modifier: $modifierCaption";

		my $serviceFromDate = $voidItem->getDateOfServiceFrom(DATEFORMAT_USA);		#$voidItem->{dateOfServiceFrom};
		my $serviceToDate = $voidItem->getDateOfServiceTo(DATEFORMAT_USA);			#$voidItem->{dateOfServiceTo};

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
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost$unitCostHtml</TD>
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

	return @rows;
}

sub createOtherItemsHtml
{
	my ($self, $claim, $itemId, $inactive) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');
	my $invoiceId = $self->param('invoice_id');

	my $otherItem;
	my @rows = ();
	foreach my $itemIdx (0..scalar(@{$claim->{otherItems}})-1)
	{
		$otherItem = $claim->{otherItems}->[$itemIdx];
		next if defined $itemId && $itemId != $otherItem->{itemId};

		my $itemId = $otherItem->{itemId};
		my $itemType = $otherItem->{itemType};
		my $itemNum = $itemIdx + 1;
		my $itemExtCost = $formatter->format_price($otherItem->{extendedCost});
		my $itemAdjustmentTotal = $formatter->format_price($otherItem->{totalAdjustments});
		my $viewPaymentHtml = ! defined $inactive ? "<a href=javascript:doActionPopup('/invoice-p/$invoiceId/adjustment/$itemId,$itemIdx,$itemType');>$itemAdjustmentTotal</a>" : $itemAdjustmentTotal;

		my $cmtRow;
		if(my $comments = $otherItem->{comments})
		{
			$cmtRow = qq{
				<TR>
					<TD COLSPAN=2><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
					<TD COLSPAN=11><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=NAVY>$comments</FONT></TD>
				</TR>
			}
		}

		my $serviceFromDate = $otherItem->getDateOfServiceFrom(DATEFORMAT_USA);		#$otherItem->{dateOfServiceFrom};
		my $serviceToDate = $otherItem->getDateOfServiceTo(DATEFORMAT_USA);			#$otherItem->{dateOfServiceTo};

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
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			$cmtRow
			<TR><TD COLSPAN=13><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}

	return @rows;
}

sub getHistoryHtml
{
	my ($self, $claim) = @_;

	my $invoiceId = $self->param('invoice_id');
	my $historyItems = $claim->{invoiceHistoryItem};
	my $historyCount = $claim->{historyCount};

	my @rows = ();
	foreach my $idx (0..$historyCount-1)
	{
		push(@rows, qq{
			<TR VALIGN=TOP>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$historyItems->[$idx][0]</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$historyItems->[$idx][1]</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$historyItems->[$idx][2]</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$historyItems->[$idx][3]</TD>
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

	$self->addContent('<center><p>', $self->createLineItemsTableHtml($claim), '</p></center>');

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::Procedure(schema => $self->getSchema(), cancelUrl => $cancelUrl);
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
	my $invoiceFlags = $claim->{flags};
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

	#other constants
	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $workComp = App::Universal::CLAIMTYPE_WORKERSCOMP;
	my $thirdParty = App::Universal::CLAIMTYPE_CLIENT;
	my $hcfaInvoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $genericInvoiceType = App::Universal::INVOICETYPE_SERVICE;
	#--------------------


	my $payerPane = "<TD><FONT FACE='Arial,Helvetica' SIZE=2>$payer</TD>";
	my $payerPaneHeading = "<TD BGCOLOR=EEEEEE><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=333333><B>Payer</B></TD>";


	#check if the claim has already been transferred to a carrier
	my $beenTransferred = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selBeenTransferred', $invoiceId);

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

					@{[ $totalItems > 0 && ($claimType == $selfPay || $claimType == $thirdParty) && ($invStatus < $submitted || $invStatus == $paymentApplied) ?
					"<TD>
						<FONT FACE='Arial,Helvetica' SIZE=2>
						<a href='/invoice/$invoiceId/submit'>Submit Claim for Billing</a>
						</FONT>
					</TD>" : '' ]}

					@{[ $totalItems > 0 && $claimType != $selfPay && 
						! ($beenTransferred) && ($invStatus < $submitted || $invStatus == $paymentApplied) ?
					"<TD>
						<FONT FACE='Arial,Helvetica' SIZE=2>
						<a href='/invoice/$invoiceId/submit'>Submit Claim for Transfer</a>
						</FONT>
					</TD>" : '' ]}

					@{[ $totalItems > 0 && $claimType != $selfPay && 
						( ($invStatus >= $rejectInternal && $invStatus <= $paper) || ($invStatus == $onHold && $beenTransferred) || 
							$invStatus == $rejectExternal || ($invStatus == $paymentApplied && $invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) || $invStatus == $paperPrinted ) ?
					"<TD>
						<FONT FACE='Arial,Helvetica' SIZE=2>
						<a href='/invoice/$invoiceId/submit?resubmit=2'>Resubmit Claim for Transfer</a>
						</FONT>
					</TD>" : '' ]}

					@{[ $totalItems > 0 && $claimType != $selfPay && 
						( ($invStatus >= $rejectInternal && $invStatus <= $paper) || ($invStatus == $onHold && $beenTransferred) || 
							$invStatus == $rejectExternal || ($invStatus == $paymentApplied && $invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) || $invStatus == $paperPrinted || 
							$invStatus == $awaitInsPayment  ) ?
					"<TD>
						<FONT FACE='Arial,Helvetica' SIZE=2>
						<a href='/invoice/$invoiceId/submit?resubmit=3'>Submit Claim for Transfer to Next Payer</a>
						</FONT>
					</TD>" : '' ]}

					@{[ ($invStatus != $onHold && $invStatus < $transferred) || (! ($invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) && $invStatus == $paymentApplied) ?
					"<TD>
						<FONT FACE='Arial,Helvetica' SIZE=2>
						<a href='/invoice/$invoiceId/dialog/hold'>Place Claim On Hold</a>
						</FONT>
					</TD>" : '' ]}

					@{[ $invStatus == $rejectInternal || $invStatus == $rejectExternal || $invStatus == $appealed || ($invStatus == $paymentApplied && $invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) ?
					"<TD>
						<FONT FACE='Arial,Helvetica' SIZE=2>
						<a href='/invoice/$invoiceId/dialog/hold?transferred=1'>Place Claim On Hold</a>
						</FONT>
					</TD>" : '' ]}

					@{[ $claimType != $selfPay && $invStatus > $submitted && $invStatus != $void && $invStatus != $awaitClientPayment && 
						($beenTransferred || $invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) ?
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
			@{[ $self->createLineItemsTableHtml($claim) ]}
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
	#my $adjustment = $claim->{procedures}->[$i]->{adjustments}->[$x]->{ column };

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
					<B>Adjustments for Claim $invoiceId@{[ $itemType != $adjItemType && defined $idx ? ", Procedure $procNum" : '' ]}</B>
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
			<TABLE>
				<TR VALIGN=TOP>
					<TD>
						<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=1>
							@{[ $self->createLineItemsHeadingHtml($claim) ]}
							@{[ $invoice->{invoice_type} == 0 ? $self->createProcedureItemsHtml($claim, $itemId, 1) : $self->createOtherItemsHtml($claim, $itemId, 1) ]}
						</TABLE>
					</TD>
				</TR>
			</TABLE>
		});
	}

	return 1;
}

sub prepare_view_error
{
	my $self = shift;
	my $claim = $self->property('activeClaim');

	push(@{$self->{page_content}}, qq{
			<style>
				ol {font-family: Tahoma; font-size: 9pt}
				ul {font-family: Tahoma; font-size: 9pt}
				h3 {font-family: Tahoma; font-size: 11pt}

			</style>

			<b style="color:red">Please correct the following errors</b><br><br>
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
	});
	
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

sub prepare_view_submit
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');
	my $claim = $self->property('activeClaim');
	my $submitFlag = $self->param('resubmit') || App::Universal::SUBMIT_PAYER;
	my $printFlag = $self->param('print');
	my $patient = $claim->getCareReceiver();
	my $patientId = $patient->getId();
	my $claimType = $claim->getInvoiceSubtype();

	if(my $errorCount = App::IntelliCode::getNSFerrorCount($self, $invoiceId, $patientId) && ($claimType != App::Universal::CLAIMTYPE_SELFPAY && $claimType != App::Universal::CLAIMTYPE_CLIENT) )
	{
		$self->addContent(q{<B style='color:red'>Cannot submit claim. Please check IntelliCode errors.</B>});
	}
	else
	{
		my $handler = \&{'handleDataStorage'};
		eval
		{
			$invoiceId = &{$handler}($self, $invoiceId, $submitFlag, $printFlag);
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

sub prepare_view_close
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');

	handleDataStorage($self, $invoiceId);
	$self->schemaAction('Invoice', 'update', invoice_id => $invoiceId, invoice_status => App::Universal::INVOICESTATUS_CLOSED);
	addHistoryItem($self, $invoiceId, value_text => 'Closed');

	$self->redirect("/invoice/$invoiceId/summary");
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
		$output->processClaims(destination => NSFDEST_ARRAY, outArray => \@outArray, claimList => $claimList, validationMgr => $valMgr, nsfType => App::Billing::Universal::NSF_THIN, page => $self);

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
		$output->processClaims(destination => NSFDEST_FILE, outArray => \@outArray, outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $fileName), claimList => $claimList, nsfType => App::Billing::Universal::NSF_HALLEY, page => $self);
	};

	eval
	{
		my $output = new App::Billing::Output::NSF();
		$output->registerValidators($valMgr);
		$valMgr->validateClaim('Output', DEFAULT_VFLAGS, $claimList);

		my @outArray = ();
		$output->processClaims(destination => NSFDEST_ARRAY, outArray => \@outArray, claimList => $claimList, validationMgr => $valMgr, nsfType => App::Billing::Universal::NSF_HALLEY, page => $self);

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
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $html = [];

	eval
	{
#		my $output = new pdflib;
		my $output = new App::Billing::Output::HTML;
		$output->processClaims(outArray => $html, claimList => $claimList, TEMPLATE_PATH => File::Spec->catfile($CONFDATA_SERVER->path_BillingTemplate(), 'View1500.dat'), page => $self);
	};
	$self->addContent(@$html) if $html;
	$self->addError('Problem in sub prepare_view_1500', $@) if $@;

	addHistoryItem($self, $invoiceId, value_text => 'Claim viewed');

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
		#my $output = new pdflib;
		my $output = new App::Billing::Output::HTML;
		$output->processClaims(outArray => $html, claimList => $claimList, TEMPLATE_PATH => File::Spec->catfile($CONFDATA_SERVER->path_BillingTemplate(), 'Edit1500.dat'), page => $self);
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
		#my $output = new pdflib;
		my $output = new App::Billing::Output::PDF;
		$output->processClaims(outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName), claimList => $claimList, drawBackgroundForm => $plain ? 0 : 1, page => $self);
	};
	$self->redirect($pdfHref);
	#$self->addContent("<a href='$pdfHref' target='$pdfName'>View HCFA PDF File for Claim $invoiceId</a><script>window.location.href = '$pdfHref';</script>");
	$self->addError('Problem in sub prepare_view_1500pdf', $@) if $@;

	my $claimPrintHistoryItem = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selClaimPrintHistoryItemByUser', $invoiceId, $sessUser);
	my $timeDiff = $claimPrintHistoryItem->{timenow} - $claimPrintHistoryItem->{cr_stamp};

	return 1 if $claimPrintHistoryItem->{cr_user_id} eq $sessUser && $timeDiff < 10;

	addHistoryItem($self, $invoiceId, value_text => 'Claim printed');

	return 1;
}

sub prepare_view_1500pdfplain
{
	my $self = shift;
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
		$twccForm->processClaims($claimList, reportId => 'TWCC60', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName), page => $self);
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
		$twccForm->processClaims($claimList, reportId => 'TWCC61', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName), page => $self);
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
		$twccForm->processClaims($claimList, reportId => 'TWCC64', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName), page => $self);
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
		$twccForm->processClaims($claimList, reportId => 'TWCC69', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName), page => $self);
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
		$twccForm->processClaims($claimList, reportId => 'TWCC73', outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName), page => $self);
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
		invoiceIds => [$invoiceId], valMgr => $valMgr, page => $self);
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
	my $invoiceFlags = $claim->{flags};

	#check if the claim has already been transferred to a carrier
	my $beenTransferred = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selBeenTransferred', $invoiceId);

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
			['1500 PDF (PP)', "$urlPrefix/1500pdf", '1500pdf'],
			['1500 PDF', "$urlPrefix/1500pdfplain", '1500pdfplain'],
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
	my $chooseActionMenu;
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

						@{[ $claimType != $selfPay && $invStatus > $submitted && $invStatus != $awaitClientPayment && $invStatus != $void && $invType == $hcfaInvoiceType && ($beenTransferred || $invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) ? "<option value='/invoice/$invoiceId/dialog/postinvoicepayment?paidBy=insurance'>Post Insurance Payment to this Claim</option>" : '' ]}
						@{[ $invStatus != $void ? "<option value='/invoice/$invoiceId/dialog/postinvoicepayment?paidBy=personal'>Post Personal Payment to this Claim</option>" : '' ]}
						<option value="/person/$clientId/dlg-add-postpersonalpayment">Post Personal Payment to Self-Pay Claims</option>
						<option value="/person/$clientId/dlg-add-postrefund">Post Refund</option>
						<option value="/person/$clientId/dlg-add-posttransfer">Post Transfer</option>
						<option value="/person/$clientId/account">View Patient Account</option>
						<option value="/person/$clientId/profile">View Patient Profile</option>

						@{[ $invType == $hcfaInvoiceType && ($invStatus < $submitted || ($invStatus > $transferred && $invStatus < $awaitInsPayment) || $invStatus == $paymentApplied || $invStatus == $paperPrinted) ? "<option value='/invoice/$invoiceId/dialog/claim/update'>Edit Claim</option>" : '' ]}
						@{[ $invType == $genericInvoiceType && $invStatus != $void && $invStatus != $closed ? "<option value='/invoice/$invoiceId/dlg-update-invoice'>Edit Invoice</option>" : '' ]}

						@{[ ($invStatus < $submitted || $invStatus == $paymentApplied) && ($claimType == $selfPay || $claimType == $thirdParty) && $totalItems > 0 ? "<option value='/invoice/$invoiceId/submit'>Submit for Billing</option>" : '' ]}
						@{[ ! ($beenTransferred) && ($invStatus < $submitted || $invStatus == $paymentApplied) && $claimType != $selfPay && $totalItems > 0 && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/submit'>Submit Claim for Transfer</option>" : '' ]}

						@{[ ( ($invStatus >= $rejectInternal && $invStatus <= $paper) || ($invStatus == $onHold && $beenTransferred) || $invStatus == $rejectExternal || ($invStatus == $paymentApplied && $invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) || $invStatus == $paperPrinted ) && $claimType != $selfPay && $totalItems > 0 && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/submit?resubmit=2'>Resubmit Claim for Transfer to Current Payer</option>" : '' ]}
						@{[ ( ($invStatus >= $rejectInternal && $invStatus <= $paper) || ($invStatus == $onHold && $beenTransferred) || $invStatus == $rejectExternal || ($invStatus == $paymentApplied && $invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) || $invStatus == $paperPrinted || $invStatus == $awaitInsPayment  ) && $claimType != $selfPay && $totalItems > 0 && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/submit?resubmit=3'>Submit Claim for Transfer to Next Payer</option>" : '' ]}

						@{[ ($invStatus != $onHold && $invStatus < $transferred) || (! ($invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) && $invStatus == $paymentApplied) ? "<option value='/invoice/$invoiceId/dialog/hold'>Place Claim On Hold</option>" : '' ]}
						@{[ $invStatus == $rejectInternal || $invStatus == $rejectExternal || $invStatus == $appealed || ($invStatus == $paymentApplied && $invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR) ? "<option value='/invoice/$invoiceId/dialog/hold?transferred=1'>Place Claim On Hold</option>" : '' ]}

						@{[ $invStatus < $submitted && $invType == $hcfaInvoiceType && ($noAdjsExist == 1 || $invoiceTotalAdj == 0) ? "<option value='/invoice/$invoiceId/dialog/claim/remove'>Void Claim</option>" : '' ]}
						@{[ $invStatus < $submitted && $invType == $genericInvoiceType && ($noAdjsExist == 1 || $invoiceTotalAdj == 0) ? "<option value='/invoice/$invoiceId/dlg-remove-invoice'>Void Invoice</option>" : '' ]}

						@{[ $claimType == $selfPay || $invStatus >= $submitted ? qq{<option value='javascript:doActionPopup("/patientbill/$invoiceId");'>Print Patient Bill</option>} : '' ]}
						<option value="/invoice/$invoiceId/summary">View Claim</option>

						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc60Command-twcc60'>\u$twcc60Command TWCC Form 60</option>} : '' ]}
						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc61Command-twcc61'>\u$twcc61Command TWCC Form 61</option>} : '' ]}
						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc64Command-twcc64'>\u$twcc64Command TWCC Form 64</option>} : '' ]}
						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc69Command-twcc69'>\u$twcc69Command TWCC Form 69</option>} : '' ]}
						@{[ $claimType == $workComp && $invStatus != $void && $invStatus != $closed ? qq{<option value='/invoice/$invoiceId/dlg-$twcc73Command-twcc73'>\u$twcc73Command TWCC Form 73</option>} : '' ]}
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
