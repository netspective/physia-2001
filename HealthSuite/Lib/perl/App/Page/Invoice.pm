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

use App::Billing::Claims;
use App::Billing::Input::DBI;
use App::Billing::Output::NSF;
use App::Billing::Validators;

use App::Dialog::Procedure;
use App::Dialog::Adjustment;
use App::Dialog::OnHold;
use App::Dialog::Diagnoses;
use App::Dialog::ClaimProblem;
use App::Dialog::PostGeneralPayment;
use App::Dialog::PostInsurancePayment;
use App::Dialog::PostRefund;
use App::Dialog::PostTransfer;
#use App::Billing::Output::tPdfCLaim;
use App::Billing::Output::PDF;
use App::Billing::Output::HTML;
use App::IntelliCode;

use App::Page::Search;

use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Page);

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
	return qq{
		$person->{firstName} $person->{middleInitial} $person->{lastName} ($person->{id})<br>
		$addr->{address1}<br>
		@{[ $addr->{address2} ? "$addr->{address2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zipCode}<br>
		$addr->{telephoneNo}
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
	return qq{
		$org->{name} ($org->{id})<br>
		$addr->{address1}<br>
		@{[ $addr->{address2} ? "$addr->{address2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zipCode}<br>
		$addr->{telephoneNo}
	};
}

sub getProcedureHtml
{
	my ($self, $claim, $itemIdx) = @_;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	my $invoiceId = $self->param('invoice_id');
	my $invStatus = $claim->getStatus();

	my @rows = ();

	my $procedure = $claim->{procedures}->[$itemIdx];

	my $lineSeq = $itemIdx + 1;

	my $emg = $procedure->{emergency} eq 'Y' ? "<img src='/resources/icons/checkmark.gif' border=0>" : '';
	my $itemId = $procedure->{itemId};
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
	my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $procedure->{placeOfService});
	my $modifierCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericModifier', $procedure->{modifier});
	my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $procedure->{cpt});

	my $cptAndModTitle = "CPT: $cptCaption->{name}" . "\n" . "Modifier: $modifierCaption";

	push(@rows, qq{
		<TR>
			<TD><FONT FACE="Arial,Helvetica" SIZE=3><B>$lineSeq</B></FONT></TD>
			<TD>&nbsp;</TD>
			<TD><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{dateOfServiceFrom} @{[ $procedure->{dateOfServiceTo} ne $procedure->{dateOfServiceFrom} ? " - $procedure->{dateOfServiceTo}" : '']} </TD>
			<TD>&nbsp;</TD>
			<TD TITLE="$servPlaceCaption"><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{placeOfService} @{[$procedure->{typeOfService} ? "($procedure->{typeOfService})" : '']}</TD>
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
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>CPT/HCPCS</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Diag</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Chg</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Adj</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>EMG</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Reference</B></TD>
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

		#next unless $procedure->{cpt}; # because we can have "phantom" items for payments

		my $lineSeq = $itemIdx + 1;

		my $emg = $procedure->{emergency} eq 'Y' ? "<img src='/resources/icons/checkmark.gif' border=0>" : '';
		my $itemId = $procedure->{itemId};

		my $editProcHref = "/invoice/$invoiceId/dialog/procedure/update,$itemId,$lineSeq";
		my $voidProcHref = "/invoice/$invoiceId/dialog/procedure/remove,$itemId,$lineSeq";
		my $addInsPayHref = "/invoice/$invoiceId/dialog/adjustment/insurance,$itemId";
		my $addPersPayHref = "/invoice/$invoiceId/dialog/adjustment/personal,$itemId";

		my $editProcImg = '';
		my $voidProcImg = '';
		if($invStatus < App::Universal::INVOICESTATUS_SUBMITTED)
		{
			$editProcImg = "<a href='$editProcHref'><img src='/resources/icons/edit_update.gif' border=0></a>";
			$voidProcImg = "<a href='$voidProcHref'><img src='/resources/icons/edit_remove.gif' border=0></a>";
		}
		my $persPayImg = "<a href='$addPersPayHref'><font face='Arial,Helvetica' color=green size=2>P</font></a>";

		my $insPayImg = '';
		my $itemAdjustmentTotal = $procedure->{totalAdjustments};
		my $itemExtCost = $procedure->{extendedCost};

		if($itemAdjustmentTotal < $procedure->{balance} && $claimType != $selfPay)
		{
			$insPayImg = "<a href='$addInsPayHref'><font face='Arial,Helvetica' color=green size=2>\$</font></a>";
		}

		$itemAdjustmentTotal = $formatter->format_price($itemAdjustmentTotal);
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/dialog/adjustment/adjview,$itemId,$itemIdx');";
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
		my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $procedure->{placeOfService});
		my $modifierCaption = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selGenericModifier', $procedure->{modifier});
		my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $procedure->{cpt});

		my $cptAndModTitle = "CPT: $cptCaption->{name}" . "\n" . "Modifier: $modifierCaption";

		push(@rows, qq{
			<TR>
				<TD><FONT FACE="Arial,Helvetica" SIZE=3>$insPayImg&nbsp;$persPayImg&nbsp;$editProcImg&nbsp;$voidProcImg<B>$lineSeq</B></FONT></TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{dateOfServiceFrom} @{[ $procedure->{dateOfServiceTo} ne $procedure->{dateOfServiceFrom} ? " - $procedure->{dateOfServiceTo}" : '']} </TD>
				<TD>&nbsp;</TD>
				<TD TITLE="$servPlaceCaption"><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{placeOfService} @{[$procedure->{typeOfService} ? "($procedure->{typeOfService})" : '']}</TD>
				<TD>&nbsp;</TD>
				<TD TITLE="$cptAndModTitle"><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{cpt} @{[$procedure->{modifier} ? "($procedure->{modifier})" : '']}</TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{diagnosis}</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost$unitCost</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="DARKRED">@{[ $itemAdjustmentTotal ne '$0.00' ? $viewPaymentHtml : $itemAdjustmentTotal ]}</TD>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center">$emg</td>
				<TD>&nbsp;</TD>
				<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$procedure->{reference}</FONT></td>
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
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/dialog/adjustment/adjview,$itemId,$itemIdx,$itemType');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";
		push(@rows, qq{
			<TR>
				<TD COLSPAN=10><FONT FACE="Arial,Helvetica" SIZE=2>$itemNum: Copay - $copayItem->{comments}</TD>
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
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/dialog/adjustment/adjview,$itemId,$itemIdx,$itemType');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";
		push(@rows, qq{
			<TR>
				<TD COLSPAN=10><FONT FACE="Arial,Helvetica" SIZE=2>$itemNum: Coinsurance - $coinsuranceItem->{comments}</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2>$itemExtCost</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Green">&nbsp;</FONT></TD>
				<!-- <TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$itemAdjustmentTotal</TD> -->
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
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

		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/dialog/adjustment/adjview,$itemId,$itemIdx,$itemType');";
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
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/dialog/adjustment/adjview,$adjItem->{itemId},$itemIdx,$adjItem->{itemType}');";
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
	my $simDate = $claim->{treatment}->{dateOfSameOrSimilarIllness};
	my $currDate = $claim->{treatment}->{dateOfIllnessInjuryPregnancy};

	#DIAGS AND THEIR CAPTIONS:
	my @allDiags = ();
	foreach (@{$claim->{diagnosis}})
	{
		push(@allDiags, $_->getDiagnosis());
	}

	my $icdCaption = '';

	foreach my $diag (@allDiags)
	{
		#next if $diag eq '';

		$icdCaption .= "$diag: ";
		my $icdInfo = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericICDCode', $diag);
		$icdCaption .= $icdInfo->{descr};
		$icdCaption .= "\n";
	}


	#INVOICE TOTALS
	my $invoiceTotal = $claim->{totalCharge};
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
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>CPT/HCPCS</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Diag</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Chg</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Adj</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>EMG</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Reference</B></TD>
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

		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/dialog/adjustment/adjview,$itemId,$itemIdx,$itemType');";
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
				<TD><FONT FACE="Arial,Helvetica" SIZE=3><B>$itemNum</B></TD>
				<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2>$otherItem->{daysOrUnits}</TD>
				<TD>&nbsp;</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$otherItem->{caption}</TD>
				<TD>&nbsp;</TD>
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
		my $viewPaymentHref = "javascript:doActionPopup('/invoice-p/$invoiceId/dialog/adjustment/adjview,$adjItem->{itemId},$itemIdx,$adjItem->{itemType}');";
		my $viewPaymentHtml = "<a href=$viewPaymentHref>$itemAdjustmentTotal</a>";

		push(@rows, qq{
			<TR>
				<TD COLSPAN=3>&nbsp;</TD>
				<TD COLSPAN=4><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$adjTypeCaption - $adjComments</TD>
				<TD ALIGN="Right"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Darkred">$viewPaymentHtml</TD>
			</TR>
			<TR><TD COLSPAN=17><IMG SRC='/resources/design/bar.gif' HEIGHT=1 WIDTH=100%></TD></TR>
		});
	}


	#INVOICE TOTALS
	my $invoiceTotal = $claim->{totalCharge};
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
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Qty</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Description</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Charge</B></TD>
							<TD>&nbsp;</TD>
							<TD ALIGN="Center"><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=777777><B>Adj</B></TD>
						</TR>
						@rows
						<TR BGCOLOR=DDEEEE>
							<TD COLSPAN=3><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="Navy"><B>Balance:</B></FONT> <FONT FACE="Arial,Helvetica" SIZE=2 COLOR="$balColor"><B>$invoiceBalance</B></FONT></TD>
							<!-- <TD><FONT FACE="Arial,Helvetica" SIZE=2 COLOR="$balColor"><B>$invoiceBalance</B></FONT></TD> -->							
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

sub getPayerHtml
{
	my ($self, $payer) = @_;

	my @info = ();
	foreach (sort keys %$payer)
	{
		push(@info, "$_ = $payer->{$_}<BR>");
	}

	my $addr = $payer->{address};

	return qq{
		$payer->{name} ($payer->{id})<br>
		$addr->{address1}<br>
		@{[ $addr->{address2} ? "$addr->{address2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zipCode}<br>
		$addr->{telephoneNo}
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
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$statusHistory->{action}</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$statusHistory->{cr_user_id}</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>&nbsp;</FONT></TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$statusHistory->{comments}</TD>
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

	my $patient = $claim->getCareReceiver();
	my @diags = ();

	foreach (@{$claim->{diagnosis}})
	{
		push(@diags, $_->{diagnosis});
		#push(@diags, $_->{diagnosis}) if $_->{diagnosis};
	}

	my @procs = ();
	foreach (@{$claim->{procedures}})
	{
		#next unless $_->{cpt}; # because we can have "phantom" items for payments
		push(@procs, [$_->{cpt}, $_->{modifier} || undef, split(/,/, $_->{diagnosis})]);
	}

	my @errors = App::IntelliCode::validateCodes
		(
			$self, 0,
			sex => $patient->getSex(),
			dateOfBirth => $patient->getDateOfBirth(),
			diags => \@diags,
			procs => \@procs,
		);

	return @errors ? ('<UL><LI>' . join('<LI>', @errors) . '</UL>') : 'No discrepancies found';
}

#-----------------------------------------------------------------------------
# DIALOG MANAGEMENT METHODS
#-----------------------------------------------------------------------------

sub prepare_dialog_procedure
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');
	my $claim = $self->property('activeClaim');

	my $dialogCmd = $self->param('_pm_dialog_cmd') || 'add';
	my ($action, $itemId, $itemSeq) = split(/,/, $dialogCmd);
	$self->param('item_id', $itemId);
	$self->param('item_seq', $itemSeq);

	$self->addContent('<center><p>', $self->getProceduresHtml($claim), '</p></center>');

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::Procedure(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $action);

	#$self->addContent('<p>', App::Page::Search::getSearchBar($self, 'catalog/cpt'));
	$self->addContent('<p>');
	return $self->prepare_view_summary();
}

sub prepare_dialog_adjustment
{
	my $self = shift;

	my $adjItemType = App::Universal::INVOICEITEMTYPE_ADJUST;

	my $invoiceId = $self->param('invoice_id');
	my $dialogCmd = $self->param('_pm_dialog_cmd');
	my ($payType, $itemId, $idx, $itemType) = split(/,/, $dialogCmd);
	$self->param('item_id', $itemId);
	$self->param('payment', $payType);

	if($payType ne 'adjview')
	{
		my $cancelUrl = "/invoice/$invoiceId/summary";
		my $dialog = new App::Dialog::Adjustment(schema => $self->getSchema(), cancelUrl => $cancelUrl);
		$dialog->handle_page($self, 'add');

		$self->addContent('<p>');
		return $self->prepare_view_summary();
	}
	else
	{
		my $itemAdjs = $STMTMGR_INVOICE->getRowsAsHashList($self, STMTMGRFLAG_NONE, 'selItemAdjustments', $itemId);
		my $claim = $self->property('activeClaim');
		$self->setFlag(PAGEFLAG_IGNORE_BODYHEAD | PAGEFLAG_IGNORE_BODYFOOT);

		my $invoice = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAndClaimType', $invoiceId);
		my $heading = "Type: $invoice->{claim_type_caption}</B>, Status: $invoice->{invoice_status_caption}<BR>" || "Unknown ID: $invoiceId";
		my $procNum = $idx + 1;

		push(@{$self->{page_content}}, qq{
			<TABLE WIDTH=100% BGCOLOR=BEIGE CELLSPACING=0 CELLPADDING=3 BORDER=0>
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
						<B>Adjustments for Claim $invoiceId @{[ $itemType != $adjItemType ? ", Procedure $procNum" : '' ]}</B>
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
			push(@{$self->{page_content}}, qq{
					<TR VALIGN=TOP>
						<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{pay_date}</TD>
						<TD><FONT FACE="Arial,Helvetica" SIZE=2>$adj->{payer_id}</TD>
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

		if($itemType != $adjItemType)
		{
			push(@{$self->{page_content}}, qq{
				</TABLE>
				<BR><BR>
				@{[ $self->getProcedureHtml($claim, $idx) ]}
			});
		}
	}

	return 1;
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

sub prepare_dialog_invoice
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');
	my $dialogCmd = $self->param('_pm_dialog_cmd') || 'add';
	my ($action) = split(/,/, $dialogCmd);

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::Invoice(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $action);

	$self->addContent('<p>');
	return $self->prepare_view_summary();
}

sub prepare_dialog_postinspayment
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');

	my $dialogCmd = $self->param('_pm_dialog_cmd') || 'add';
	#my ($action, $invoiceId) = split(/,/, $dialogCmd);
	#$self->param('invoice_id', $invoiceId);
	#$self->param('posting_action', $action);
	#$self->addDebugStmt($payType);

	my $cancelUrl = "/invoice/$invoiceId/summary";
	my $dialog = new App::Dialog::PostInsurancePayment(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $dialogCmd);

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

sub prepare_view_summary1
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');

	$self->addLocatorLinks(['Summary', "/invoice/$invoiceId/summary"]);

	my $claim = $self->property('activeClaim');

	my $patient = $self->getPersonHtml($claim->{careReceiver});
	my $provider = $self->getPersonHtml($claim->{renderingProvider});
	my $service = $self->getOrgHtml($claim->{renderingOrganization});
	my $payer = $self->getPayerHtml($claim->{payer});
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $invStatus = $claim->getStatus();
	my @allDiags = ();
	foreach (@{$claim->{diagnosis}})
	{
		push(@allDiags, $_->getDiagnosis());
	}

	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $submitted = App::Universal::INVOICESTATUS_SUBMITTED;
	my $onHold = App::Universal::INVOICESTATUS_ONHOLD;
	my $hcfaInvoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $genericInvoiceType = App::Universal::INVOICETYPE_SERVICE;
	my $totalItems = $invoiceInfo->{total_items};

	my $payerPane = "<TD><FONT FACE='Arial,Helvetica' SIZE=2>$payer</TD>";
	my $payerPaneHeading = "<TD BGCOLOR=EEEEEE><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=333333><B>Payer</B></TD>";

	my $quickLinks = '';
	unless($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP))
	{
		$quickLinks = qq{
					<TR>
						@{[ $allDiags[0] ne '' ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/procedure/add'>Add Procedure</a>
							</FONT>
						</TD>" :
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/diagnoses/add'>Add Diagnosis Codes</a>
							</FONT>
						</TD>" ]}

						@{[ $totalItems > 0 ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/submit'>Submit Claim for Transfer</a>
							</FONT>
						</TD>" : '' ]}

						@{[ $invStatus != $onHold ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/hold'>Place Claim On Hold</a>
							</FONT>
						</TD>" : '' ]}
					</TR>
			};
	}

	push(@{$self->{page_content}}, qq{
		<CENTER>
		<p>
		<TABLE>
			<TR VALIGN=TOP>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333><B>Patient</B></TD>
				<TD BGCOLOR=EEEEEE><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=333333><B>Provider/Facility</B></TD>
				@{[ $invoiceInfo->{invoice_subtype} != $selfPay ? $payerPaneHeading : '' ]}
			</TR>
			<TR VALIGN=TOP>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$patient</TD>
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$provider<br>$service</TD>
				@{[ $invoiceInfo->{invoice_subtype} != $selfPay ? $payerPane : '' ]}
			</TR>
		</TABLE>
		<p>
			@{[ $invStatus < $submitted ? "<TABLE CELLSPACING=1 CELLPADDING=2 BORDER=0>$quickLinks</TABLE>" : '' ]}
		</p>
		<p>
			@{[ $self->getProceduresHtml($claim) ]}
		</p>
		<TABLE BGCOLOR='#EEEEEE' CELLSPACING=1 CELLPADDING=2 BORDER=0>
			<TR BGCOLOR='#EEEEEE'>
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<b>IntelliCode Results</b>
					</FONT>
				</TD>
				<TD ALIGN='RIGHT'>
					@{[ $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP) ? '' : "<a href='/invoice/$invoiceId/intellicode'><img src='/resources/icons/details.gif' border=0></a>" ]}
				</TD>
			</TR>
			<TR BGCOLOR=WHITE>
				<TD COLSPAN=2>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					@{[ $self->getIntelliCodeResultsHtml($claim) ]}
					</FONT>
				</TD>
			</TR>
		</TABLE>
		});

	return 1;
}

sub prepare_view_summary
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');

	$self->addLocatorLinks(['Summary', "/invoice/$invoiceId/summary"]);

	my $claim = $self->property('activeClaim');

	my $patient = $self->getPersonHtml($claim->{careReceiver});
	my $provider = $self->getPersonHtml($claim->{renderingProvider});
	my $service = $self->getOrgHtml($claim->{renderingOrganization});
	my $payer = $self->getPayerHtml($claim->{payer});
	my $invStatus = $claim->getStatus();
	my $invType = $claim->getInvoiceType();
	my $claimType = $claim->getInvoiceSubtype();
	my $totalItems = $claim->getTotalItems();
	my @allDiags = ();
	foreach (@{$claim->{diagnosis}})
	{
		push(@allDiags, $_->getDiagnosis());
	}

	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $submitted = App::Universal::INVOICESTATUS_SUBMITTED;
	my $onHold = App::Universal::INVOICESTATUS_ONHOLD;
	my $hcfaInvoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $genericInvoiceType = App::Universal::INVOICETYPE_SERVICE;

	my $payerPane = "<TD><FONT FACE='Arial,Helvetica' SIZE=2>$payer</TD>";
	my $payerPaneHeading = "<TD BGCOLOR=EEEEEE><FONT FACE='Arial,Helvetica' SIZE=2 COLOR=333333><B>Payer</B></TD>";

	my $quickLinks = '';
	unless($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP))
	{
		if($invType == $hcfaInvoiceType)
		{
			$quickLinks = qq{
					<TR>
						@{[ $allDiags[0] ne ''  ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/procedure/add'>Add Procedure </a>
							</FONT>
						</TD>" :
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/diagnoses/add'>Add Diagnosis Codes</a>
							</FONT>
						</TD>" ]}

						@{[ $totalItems > 0 ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/submit'>Submit Claim for Transfer</a>
							</FONT>
						</TD>" : '' ]}

						@{[ $invStatus != $onHold ?
						"<TD>
							<FONT FACE='Arial,Helvetica' SIZE=2>
							<a href='/invoice/$invoiceId/dialog/hold'>Place Claim On Hold</a>
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
				<TD><FONT FACE="Arial,Helvetica" SIZE=2>$provider<br>$service</TD>
				@{[ $claimType != $selfPay ? $payerPane : '' ]}
			</TR>
		</TABLE>
		<p>
			@{[ $invStatus < $submitted ? "<TABLE CELLSPACING=1 CELLPADDING=2 BORDER=0>$quickLinks</TABLE>" : '' ]}
		</p>
		<p>
			@{[ $invType == $hcfaInvoiceType ? $self->getProceduresHtml($claim) : $self->getItemsHtml($claim) ]}
		</p>
		@{[ $invType == $hcfaInvoiceType ? $intellicodeHtml : '' ]}
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
	#return $self->prepare_view_summary();
}

sub prepare_view_submit
{
	my $self = shift;
	my $invoiceId = $self->param('invoice_id');

	my $handler = \&{'App::Dialog::Procedure::execAction_submit'};
	eval
	{
		&{$handler}($self, 'add');
	};
	$self->addError($@) if $@;

	$self->redirect("/invoice/$invoiceId/summary");
	#return $self->prepare_view_summary();
}

sub prepare_view_history
{
	my $self = shift;

	$self->addLocatorLinks(['History', 'history']);

	my $claim = $self->property('activeClaim');

	my $patient = $self->getPersonHtml($claim->{careReceiver});
	my $provider = $self->getPersonHtml($claim->{renderingProvider});
	my $service = $self->getOrgHtml($claim->{renderingOrganization});
	my $payer = $self->getPayerHtml($claim->{payer});

	push(@{$self->{page_content}}, qq{
		<CENTER>
		<p>
		@{[ $self->getHistoryHtml($claim) ]}
	});

	return $self->prepare_view_summary();
}

sub prepare_view_nsf
{
	my $self = shift;

	$self->addLocatorLinks(['NSF', 'nsf']);

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');

	eval
	{
		my $output = new App::Billing::Output::NSF();
		$output->registerValidators($valMgr);
		$valMgr->validateClaim('Output', DEFAULT_VFLAGS, $claimList);

		my @outArray = ();
		$output->processClaims(destination => NSFDEST_ARRAY, outArray => \@outArray, claimList => $claimList, validationMgr => $valMgr);

		push(@{$self->{page_content}}, '<pre>', join("\n", @outArray), '</pre>');

		my $errors = $valMgr->getErrors();
		foreach my $error (@$errors)
		{
			push(@{$self->{page_content}}, '<li>', join(', ', @$error), '</li>');
		}
	};
	$self->addError('Problem in sub prepare_view_nsf', $@) if $@;

	return 1;
}

sub prepare_view_1500
{
	my $self = shift;

	$self->addLocatorLinks(['HCFA 1500', '1500']);

	# these values are set in "initialize()" method
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

	$self->addLocatorLinks(['1500 PDF', '1500pdf']);

	# these values are set in "initialize()" method
	my $claimList = $self->property('claimList');
	my $valMgr = $self->property('valMgr');
	my $invoiceId = $self->param('invoice_id');
	my $pdfName = "1500_$invoiceId.pdf";
	my $pdfHref = File::Spec->catfile($CONFDATA_SERVER->path_PDFOutputHREF, $pdfName);

	eval
	{
#		my $output = new pdflib;
		my $output = new App::Billing::Output::PDF;
		$output->processClaims(outFile => File::Spec->catfile($CONFDATA_SERVER->path_PDFOutput, $pdfName), claimList => $claimList);
	};
	$self->redirect($pdfHref);
	#$self->addContent("<a href='$pdfHref' target='$pdfName'>View HCFA PDF File for Claim $invoiceId</a><script>window.location.href = '$pdfHref';</script>");
	$self->addError('Problem in sub prepare_view_1500pdf', $@) if $@;

	return 1;
}

sub prepare_view_errors
{
	my $self = shift;

	$self->addLocatorLinks(['Errors', 'errors']);

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
	eval
	{
		$input->populateClaims($claimList, dbiHdl => $self->getSchema()->{dbh},
					invoiceIds => [$invoiceId], valMgr => $valMgr);
		my $st = $claimList->getStatistics;
		if($valMgr->haveErrors())
		{
			my $errors = $valMgr->getErrors();
			push(@{$self->{page_content}}, join('<li>', @$errors));
		}
		else
		{
			my $claim = $claimList->{claims}->[0];
			$self->property('activeClaim', $claim);
		}
	};
	$self->addError($@) if $@;

	$self->addLocatorLinks(
			['Claims', '/search/claim'],
			#[$invoiceId, '', undef, App::Page::MENUITEMFLAG_FORCESELECTED],
			[$invoiceId, "/invoice/$invoiceId"],
		);

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

	$self->SUPER::prepare_page_content_header(@_);

	my ($colors, $fonts) = ($self->getThemeColors(), $self->getThemeFontTags());

	my $created = App::Universal::INVOICESTATUS_CREATED;
	my $onHold = App::Universal::INVOICESTATUS_ONHOLD;
	my $pending = App::Universal::INVOICESTATUS_PENDING;
	my $submitted = App::Universal::INVOICESTATUS_SUBMITTED;
	my $selfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $hcfaInvoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $genericInvoiceType = App::Universal::INVOICETYPE_SERVICE;

	my $claim = $self->property('activeClaim');
	my $invType = $claim->getInvoiceType();
	my $invStatus = $claim->getStatus();;
	my $claimType = $claim->getInvoiceSubtype();
	my $totalItems = $claim->getTotalItems();

	my @allDiags = ();
	foreach (@{$claim->{diagnosis}})
	{
		push(@allDiags, $_->getDiagnosis());
	}


	my $invoiceId = $self->param('invoice_id');
	my $invoice = undef;
	my $heading = 'No invoice_id parameter provided';
	if($invoiceId)
	{
		$invoice = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInvoiceAndClaimType', $invoiceId);
		$heading = "Type: $invoice->{claim_type_caption}</B>, Status: $invoice->{invoice_status_caption}<BR>" || "Unknown ID: $invoiceId";
	}
	my $clientId = uc($invoice->{client_id});



	my $urlPrefix = "/invoice/$invoiceId";
	my $functions = $self->getMenu_Simple(App::Page::MENUFLAG_SELECTEDISLARGER | App::Page::MENUFLAG_TARGETTOP,
		'_pm_view',
		[
			['Summary', "$urlPrefix/summary", 'summary'],
			['HCFA 1500', "$urlPrefix/1500", '1500'],
			['1500 PDF', "/invoice-f/$invoiceId/1500pdf", '1500pdf'],
			['Errors', "$urlPrefix/errors", 'errors'],
			['History', "$urlPrefix/history", 'history'],
			['NSF', "$urlPrefix/nsf", 'nsf'],
		], ' | ');

	push(@{$self->{page_content_header}},
	qq{
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE BORDER=0 CELLPADDING=0 CELLSPACING=1>
		<TR><TD>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					<B>Claim $invoiceId</B>
				</FONT>
			</TD>
			<TD ALIGN=RIGHT>
				<FONT FACE="Arial,Helvetica" SIZE=2>
				$functions
				</FONT>
			</TD>
		</TABLE>
		</TD></TR>
		</TABLE>
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE CELLSPACING=0 CELLPADDING=0 BORDER=0>
			<TR>
				<TD>
					<FONT FACE="Arial,Helvetica" SIZE=2 COLOR=DARKRED>
						<B>$heading</B>
					</FONT>
				</TD>
			<FORM>
				<TD COLSPAN=1><FONT FACE="Arial,Helvetica" SIZE=4 STYLE="font-family: tahoma; font-size: 14pt">&nbsp;</TD>
				<TD ALIGN=RIGHT>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<SELECT style="font-family: tahoma,arial,helvetica; font-size: 8pt" onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
						<OPTION>Choose Action</OPTION>
						@{[ $allDiags[0] ne '' && $invStatus < $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/procedure/add'>Add Procedure</option>" : '' ]}
						@{[ $allDiags[0] eq '' && $invStatus < $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/diagnoses/add'>Add Diagnoses</option>" : '' ]}
						@{[ $allDiags[0] ne '' && $invStatus < $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/diagnoses/update'>Update Diagnoses</option>" : '' ]}
						@{[ $claimType != $selfPay && $invStatus >= $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/postinspayment'>Post Insurance Payment</option>" : '' ]}
						<!-- @{[ $claimType != $selfPay && $invStatus >= $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/adjustment/insurance'>Post Insurance Payment</option>" : '' ]} -->
						<option value="/person/$clientId/dialog/postpayment/payment,$invoiceId">Post Personal Payment</option>
						<option value="/person/$clientId/dialog/postrefund/refund">Post Refund</option>
						<option value="/person/$clientId/dialog/posttransfer/transfer">Post Transfer</option>
						<option value="/person/$clientId/account">View All Claims for the Patient</option>
						@{[ $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/claim/update'>Edit Claim</option>" : '' ]}
						@{[ $invType == $genericInvoiceType ? "<option value='/invoice/$invoiceId/dialog/invoice/update'>Edit Invoice</option>" : '' ]}
						@{[ $invStatus < $submitted && $totalItems > 0 && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/submit'>Submit Claim for Transfer</option>" : '' ]}
						<!-- @{[ $invStatus != $pending && $invStatus < $submitted && $totalItems > 0 && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/review'>Submit Claim for Review</option>" : '' ]} -->
						@{[ $invStatus != $onHold && $invStatus < $submitted ? "<option value='/invoice/$invoiceId/dialog/hold'>Place Claim On Hold</option>" : '' ]}
						@{[ $invStatus < $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/claim/remove'>Delete Claim</option>" : '' ]}
						@{[ $invStatus < $submitted && $invType == $genericInvoiceType ? "<option value='/invoice/$invoiceId/dialog/invoice/remove'>Delete Invoice</option>" : '' ]}
						@{[ $invStatus >= $submitted && $invType == $hcfaInvoiceType ? "<option value='/invoice/$invoiceId/dialog/problem'>Report Problems with this Claim</option>" : '' ]}
						@{[ $invStatus >= $submitted ? qq{<option value='javascript:doActionPopup("/patientbill/$invoiceId")'>Print Patient Bill</option>} : '' ]}
						<option value="/invoice/$invoiceId/summary">View Claim</option>
					</SELECT>
					</FONT>
				<TD>
			</FORM>
			</TR>
			<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		});

	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;

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
	#$self->addError($pathItems->[0]);
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
