##############################################################################
package App::Page::PatientBill;
##############################################################################

use strict;

use App::Page::Invoice;
use App::Universal;
use Devel::ChangeLog;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Invoice;
use App::Statements::Scheduling;
use Data::Publish;

use App::Billing::Claims;
use App::Billing::Input::DBI;
use App::Billing::Validators;

use Date::Manip;
use constant FORMATTER => new Number::Format(INT_CURR_SYMBOL => '$');
use constant DATEFORMAT_USA => 1;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page);
%RESOURCE_MAP = (
	'patientbill' => {},
	);

sub prepare
{
	my ($self) = @_;

	my $claim = $self->property('activeClaim');
	my $invoiceId = $claim->{id};
	my $serviceProvider = "$claim->{renderingProvider}->{firstName} $claim->{renderingProvider}->{middleInitial} $claim->{renderingProvider}->{lastName} ($claim->{renderingProvider}->{id})";
	my $patientHtml = $self->getPatientHtml($claim->{careReceiver});
	my $orgHtml = $self->getOrgHtml($claim);

	my $previousBalance = $STMTMGR_INVOICE->getRowAsHash($self, STMTMGRFLAG_CACHE,
		'sel_previousBalance', $invoiceId, $invoiceId);

	my @data = ();
	for my $i (0..(@{$claim->{procedures}} -1))
	{
		my $procedure = $claim->{procedures}->[$i];
		my $description = $procedure->{caption};
		unless ($description)
		{
			my $cptData = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE,
				'selGenericCPTCode', $procedure->{cpt});
			$description = $cptData->{name};
		}
		my @rowData = (
			$self->formatDate($procedure->{dateOfServiceFrom} || $procedure->{paymentDate}),
			$description,
			$procedure->{extendedCost} || 0,
			undef,
		);

		push(@data, \@rowData);

		for my $x (0..(@{$procedure->{adjustments}} -1))
		{
			my $adjustment = $procedure->{adjustments}->[$x];
			my $payDate = $adjustment->getPayDate(DATEFORMAT_USA);
			my $adjTypeCaption = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selAdjTypeCaption', $adjustment->{adjustType});
			my $payMethodCaption = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selPayMethodCaption', $adjustment->{payMethod});
			my $payRef = $adjustment->{payMethod} == App::Universal::ADJUSTMENTPAYMETHOD_CHECK || 
						$adjustment->{payMethod} == App::Universal::ADJUSTMENTPAYMETHOD_MONEYORDER ||
						$adjustment->{payMethod} == App::Universal::ADJUSTMENTPAYMETHOD_TRAVELERSCHECK ? $adjustment->{payRef} : undef;
			my $desrc = $payMethodCaption ? "$adjTypeCaption - $payMethodCaption $payRef" : $adjTypeCaption;
			my @rowAdjData = ($payDate, $desrc, undef, $adjustment->{netAdjust});			
			push(@data, \@rowAdjData);
		}
	}

	for my $i (0..(@{$claim->{voidItems}} -1))
	{
		my $procedure = $claim->{voidItems}->[$i];
		my @rowData = (
			$self->formatDate($procedure->{paymentDate}),
			$procedure->{caption} ? $procedure->{caption} . ' (Voided)' : decodeType($procedure->{itemType}),			
			undef,
			$procedure->{extendedCost},
		);
		
		push(@data, \@rowData);
	}
	
	for my $i (0..(@{$claim->{otherItems}} -1))
	{
		my $procedure = $claim->{otherItems}->[$i];
		my @rowData = (
			$self->formatDate($procedure->{paymentDate}),
			$procedure->{caption} || decodeType($procedure->{itemType}),
			$procedure->{extendedCost},
			undef,
		);
		
		push(@data, \@rowData);

		for my $x (0..(@{$procedure->{adjustments}} -1))
		{
			my $adjustment = $procedure->{adjustments}->[$x];
			my $payDate = $adjustment->getPayDate(DATEFORMAT_USA);
			my $adjTypeCaption = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selAdjTypeCaption', $adjustment->{adjustType});
			my $payMethodCaption = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selPayMethodCaption', $adjustment->{payMethod});
			my $payRef = $adjustment->{payMethod} == App::Universal::ADJUSTMENTPAYMETHOD_CHECK || 
						$adjustment->{payMethod} == App::Universal::ADJUSTMENTPAYMETHOD_MONEYORDER ||
						$adjustment->{payMethod} == App::Universal::ADJUSTMENTPAYMETHOD_TRAVELERSCHECK ? $adjustment->{payRef} : undef;
			my $desrc = $payMethodCaption ? "$adjTypeCaption - $payMethodCaption $payRef" : $adjTypeCaption;
			my @rowAdjData = ($payDate, $desrc, undef, $adjustment->{netAdjust});			
			push(@data, \@rowAdjData);
		}
	}

	my $totalCoPay = 0;
	for my $i (0..(@{$claim->{copayItems}} -1))
	{
		my $procedure = $claim->{copayItems}->[$i];
		my @rowData = (
			$self->formatDate($procedure->{paymentDate}),
			$procedure->{caption} || decodeType($procedure->{itemType}),
			$procedure->{extendedCost},
			undef,
		);
		
		$totalCoPay += ($procedure->{extendedCost} + $procedure->{totalAdjustments});
		
		push(@data, \@rowData);

		for my $x (0..(@{$procedure->{adjustments}} -1))
		{
			my $adjustment = $procedure->{adjustments}->[$x];
			my $payDate = $adjustment->getPayDate(DATEFORMAT_USA);
			my $adjTypeCaption = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selAdjTypeCaption', $adjustment->{adjustType});
			my $payMethodCaption = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 'selPayMethodCaption', $adjustment->{payMethod});
			my $payRef = $adjustment->{payMethod} == App::Universal::ADJUSTMENTPAYMETHOD_CHECK || 
						$adjustment->{payMethod} == App::Universal::ADJUSTMENTPAYMETHOD_MONEYORDER ||
						$adjustment->{payMethod} == App::Universal::ADJUSTMENTPAYMETHOD_TRAVELERSCHECK ? $adjustment->{payRef} : undef;
			my $desrc = $payMethodCaption ? "$adjTypeCaption - $payMethodCaption $payRef" : $adjTypeCaption;
			my @rowAdjData = ($payDate, $desrc, undef, $adjustment->{netAdjust});			
			push(@data, \@rowAdjData);
		}
	}
	
	for my $i (0..(@{$claim->{adjItems}} -1))
	{
		my $procedure = $claim->{adjItems}->[$i];
		my @rowData = (
			$self->formatDate($procedure->{paymentDate}),
			$procedure->{caption} || decodeType($procedure->{itemType}),
			$procedure->{extendedCost},
			$procedure->{totalAdjustments} || 0,
		);
		
		push(@data, \@rowData);
	}
	
	my $totalDue = $previousBalance->{balance} + $claim->{balance};
	
	my $html = createHtmlFromData($self, 0, \@data, $App::Statements::Invoice::PATIENT_BILL_PUBLISH_DEFN);
	my $sysdate = UnixDate('today', '%m/%d/%Y');
	
	my $gmtDayOffset = $self->session('GMT_DAYOFFSET');
	my $futureAppts = $STMTMGR_SCHEDULING->getRowsAsHashList($self, STMTMGRFLAG_CACHE,
		'sel_futureAppointments', $gmtDayOffset, $claim->{careReceiver}->{id}, 
		$self->session('org_internal_id'));
		
	my $apptHtml = qq{
		<b><u>Next Appointments</u>:</b><br>
	};
	
	for (@{$futureAppts})
	{
		$apptHtml .= qq{
			$_->{appt_time} --
			$_->{physician} --
			$_->{subject}
			<br>
		};
	}
	
	my $pageContent = qq{
		<SPAN style="font-family:Verdana; font-size:10pt">
			<CENTER>
				$orgHtml<br><br><br>
	
				<TABLE width=80%>
					<TR>
						<TD align=left>$patientHtml</TD>
						<TD align=center valign=top>&nbsp;</TD>
						<TD align=right valign=top><b>Invoice: $claim->{id}</b> <br> $sysdate </TD>
					</TR>
				
					<TR>
						<TD>&nbsp;</TD>
					</TR>
					<TR>
						<TD colspan=3 align=center>
							$html
						</TD>
					</TR>

					<TR>
						<TD>&nbsp;</TD>
					</TR>
					
					<TR>
						<TD colspan=3 align=center>
							<TABLE>
								<TR>
									<TD>Previous Balance:</TD>
									<TD align=right>@{[ FORMATTER->format_price($previousBalance->{balance}, 2) ]}</TD>
								</TR>
								<TR>
									<TD>Today's Total:</TD>
									<TD align=right>@{[ FORMATTER->format_price($claim->{totalInvoiceCharges}, 2) ]}</TD>
								</TR>
								<TR>
									<TD>Total Due:</TD>
									<TD align=right>@{[ FORMATTER->format_price($totalDue, 2) ]}</TD>
								</TR>
								<TR>
									<TD>Total Due From Patient:</TD>
									<TD align=right>@{[ FORMATTER->format_price($totalCoPay, 2) ]}</TD>
								</TR>
							</TABLE>
						</TD>
					</TR>
					
					<TR>
						<TD>&nbsp;</TD>
					</TR>
					
					<TR>
						<TD colspan=3>
							<TABLE cellspacing=5>
								<TR>
									<TD>$apptHtml</TD>
								</TR>
							</TABLE>
						</TD>
					</TR>
				</TABLE>
		
			</CENTER>
		</SPAN>
	};
	
	
	$self->addContent(qq{
		<center>
		<table bgcolor='#DDDDDD' cellspacing=1 width=100%>
			<tr><td>
				<table width=100% bgcolor=white>
					<tr>
						<td>$pageContent</td>
					</tr>
				</table>
			</td></tr>
		</table>
		
		</center>
	});

	return 1;
}

sub decodeType
{
	my ($type) = @_;
	
	$type = App::Schedule::Utilities::Trim($type);
	
	SWITCH: {
		if ($type == 3) {
			return 'Co-Pay';
			last SWITCH;
		}
		if ($type == 4) {
			return 'Co-Insurance';
			last SWITCH;
		}
		if ($type == 5) {
			return 'Payment - Thank You';
			last SWITCH;
		}
		if ($type == 6) {
			return 'Deductible';
			last SWITCH;
		}
		if ($type == 7) {
			return 'Void';
			last SWITCH;
		}
	}
}

sub formatDate
{
	my ($self, $date, $itemId) = @_;
	
	if ($itemId)
	{
		$date = $STMTMGR_INVOICE->getSingleValue($self, STMTMGRFLAG_NONE, 
			'sel_defaultInvoiceItemDate', $itemId);
	}
	else
	{
		$date ||= 'today';
	}
	return UnixDate(ParseDate($date), '%m/%d/%Y');
}

sub formatPhone
{
	my ($phone) = @_;
	
	my ($area, $ph3, $ph4);
	
	$area = substr($phone, 0, 3);
	$ph3  = substr($phone, 3, 3);
	$ph4  = substr($phone, 6, 4);
	
	return "($area) $ph3-$ph4" if $area && $ph3 && $ph4;
}

sub getPatientHtml
{
	my ($self, $person) = @_;

	my $addr = $person->{address};
	return qq{
		<b>$person->{firstName} $person->{middleInitial} $person->{lastName}</b> ($person->{id})<br>
		$addr->{address1}<br>
		@{[ $addr->{address2} ? "$addr->{address2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zipCode}<br>
	};
}

sub getOrgHtml
{
	my ($self, $claim) = @_;

	my $serviceProvider = "$claim->{renderingProvider}->{firstName} $claim->{renderingProvider}->{middleInitial} $claim->{renderingProvider}->{lastName} ($claim->{renderingProvider}->{id})";
	my $org = $claim->{renderingOrganization};
	my $org1 = $claim->{payToOrganization};
	
	my $addr = $org->{address};
	my $addr1 = $org1->{address};

	return qq{
		<b style="font-size:13pt">$org->{name} ($org->{id})</b><br>
		$serviceProvider<br>
		$addr->{address1}<br>
		@{[ $addr->{address2} ? "$addr->{address2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zipCode}<br>
		@{[ formatPhone($addr->{telephoneNo} || $addr1->{telephoneNo}) ]}
		</b>
	};
}

sub prepare_page_content_footer
{
	my $self = shift;
	return 1;
}

sub prepare_page_content_header
{
	my $self = shift;
	return 1;
}

sub initialize
{
	my $self = shift;
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
		
		#push(@{$self->{page_content}}, "YO");
		
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


	# Check user's permission to page
	my $activeView = $self->param('_pm_view');
	if ($activeView) 
	{
		unless($self->hasPermission("page/patientbill/$activeView"))
		{
			$self->disable(
					qq{
						<br>
						You do not have permission to view this information. 
						Permission page/patientbill/$activeView is required.

						Click <a href='javascript:history.back()'>here</a> to go back.
					});
		}
	}	


	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->param('invoice_id', $pathItems->[0]);
	$self->param('event_id', $pathItems->[1]);
	$self->param('org_id', $pathItems->[2]);
	$self->param('patient_id', $pathItems->[3]);

	$self->printContents();
	return 0;
}

1;
