##############################################################################
package App::Dialog::Report::Org::General::Accounting::AccountHistory;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use Number::Format;
use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use Data::Publish;
use App::Statements::Report::ClaimStatus;
use App::Dialog::Field::Person;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-account-history', heading => 'Account History');

	$self->addContent(
			new App::Dialog::Field::Person::ID(
				caption => 'Patient ID',
				name => 'patient_id',
				types => ['Patient'],
				options => FLDFLAG_REQUIRED,
			),
			new CGI::Dialog::Field::Duration(
				name => 'service',
				caption => 'Start/End Service Date',
				begin_caption => 'Service Begin Date',
				end_caption => 'Service End Date',
				options => FLDFLAG_REQUIRED,
			),
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('service_begin_date', $startDate);
	$page->field('service_end_date', $startDate);

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $pub = {
		columnDefn => [
			{ colIdx => 0,	head => 'Invoice #',				hAlign => 'center',	dAlign => 'left',		dataFmt => '#0#', groupBy => '#0#' },
			{ colIdx => 1,	head => 'Transaction Date',	hAlign => 'center',	dAlign => 'left',		dataFmt => '#1#' },
			{ colIdx => 2,	head => 'Service Provider',	hAlign => 'center',	dAlign => 'left',		dataFmt => '#2#' },
			{ colIdx => 3,	head => 'ICD-9',						hAlign => 'center',	dAlign => 'left',		dataFmt => '#3#' },
			{ colIdx => 4,	head => 'CPT',							hAlign => 'center',	dAlign => 'left',		dataFmt => '#4#' },
			{ colIdx => 5,	head => 'Description',			hAlign => 'center',	dAlign => 'left',		dataFmt => '#5#' },
			{ colIdx => 6,	head => 'Charges',					hAlign => 'center',	dAlign => 'right',	dataFmt => '#6#',	dformat => 'currency', summarize => 'sum' },
			{ colIdx => 7,	head => 'Adjustment',				hAlign => 'center',	dAlign => 'right',	dataFmt => '#7#',	dformat => 'currency', summarize => 'sum' },
			{ colIdx => 8,	head => 'Description',			hAlign => 'center', dAlign => 'left',		dataFmt => '#8#' },
			{ colIdx => 9,	head => 'Balance',					hAlign => 'center',	dAlign => 'right',	dataFmt => '#9#',	dformat => 'currency', summarize => 'sum' },
		],
	};

	my $serviceBeginDate = $page->field('service_begin_date');
	my $serviceEndDate = $page->field('service_end_date');
	my $patientID = $page->field('patient_id');

	my $sqlStmt = qq{
					select
						distinct i.invoice_id,
						p.complete_name doctor,
						i.balance balance
					from
						invoice i, transaction t, person p, invoice_item ii
					where
						i.main_transaction = t.trans_id
						and t.care_provider_id = p.person_id
						and i.invoice_status <> 16
						and i.data_text_b is null
						and i.client_id = '$patientID'
						and i.invoice_id = ii.parent_id
						and ii.service_begin_date >= to_date('$serviceBeginDate', 'mm/dd/yyyy')
						and ii.service_end_date <= to_date('$serviceEndDate', 'mm/dd/yyyy')

					order by
						1
					};

	my $rows = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmt);
	my @data = ();

	foreach my $row (@$rows)
	{

		$sqlStmt = qq{

						select
							service_begin_date tr_date,
							ii.rel_diags diags,
							ii.code cpt ,
							ii.caption description,
							ii.extended_cost charges,
							0 adjustment,
							0 adjustment_id,
							null adj_desc,
							1 flag
						from
							invoice_item ii
						where
							ii.parent_id = $row->{invoice_id}
							and ii.item_type <> 7
							and ii.item_type <> 5
							and ii.data_text_b is null
						union

						select
							i.submit_date,
							null,
							null,
							null,
							0,
							0,
							0,
							null,
							2
						from
							invoice i
						where
							i.invoice_id = $row->{invoice_id}
							and i.invoice_status >= 4

						union

						select
							iia.pay_date,
							null,
							null,
							null,
							0,
							iia.net_adjust,
							iia.adjustment_id,
							null,
							3
						from
							invoice_item ii, invoice_item_adjust iia
						where
							ii.parent_id = $row->{invoice_id}
							and ii.item_id = iia.parent_id

						order by
							1
						};

		my $rows1 = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmt);
#start here
		my $firstTime = 1;
		foreach my $row1 (@$rows1)
		{
			my $desc;
			my $doctor;
			if ($row1->{flag} == 1)
			{
				$doctor = $row->{doctor};
			}

			elsif ($row1->{flag} == 2)
			{
				$doctor = undef;
				my $sql = qq{
								select bill_party_type, bill_to_id
								from invoice i, invoice_billing ib
								where i.billing_id = ib.bill_id
								and i.invoice_id = $row->{invoice_id}
							};
				my $rowBill = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sql);
				if (($rowBill->[0]->{bill_party_type} == 2 or $rowBill->[0]->{bill_party_type} == 3) and $row1->{tr_date} ne '')
				{
					$sql = qq{select org_id from org  where org_internal_id = $rowBill->[0]->{bill_to_id}};
					$desc = "Claim Filed to " . $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$sql);
				}
				elsif($rowBill->[0]->{bill_party_type} == 1)
				{
					$desc = "Claim Filed to " . $rowBill->[0]->{bill_to_id};
				}
				else
				{
					$desc = undef;
				}
			}
			elsif ($row1->{flag} == 3)
			{
				$doctor = undef;
				my $sql = qq{
								select pay_method, pay_type,
								adjustment_type, pay_ref, payer_type
								writeoff_code, writeoff_amount
								from invoice_item_adjust
								where adjustment_id = $row1->{adjustment_id}
							};
				my $rowAdj = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sql);

				my ($adjustmentType, $paymentType, $paymentMethod);

				if ($rowAdj->[0]->{adjustment_type} ne '')
				{
					$sql = qq{
							select caption from adjust_method
							where id = $rowAdj->[0]->{adjustment_type}
						};
					$adjustmentType = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$sql);
				}

				if ($rowAdj->[0]->{pay_type} ne '')
				{
					$sql = qq{
							select caption from payment_type
							where id = $rowAdj->[0]->{pay_type}
						};
					$paymentType = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$sql);
				}

				if ($rowAdj->[0]->{pay_method} ne '')
				{
					$sql = qq{
							select caption from payment_method
							where id = $rowAdj->[0]->{pay_method}
						};
					$paymentMethod = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$sql);
				}

				$desc = "$paymentMethod Payment";
				if($paymentMethod eq 'Check')
				{
					$desc .= ", # $rowAdj->[0]->{pay_ref}";
				}

			}

			my @rowData = (
				$row->{invoice_id},
				$row1->{tr_date},
				$firstTime ? (($row1->{diags} ne '') ? $doctor : undef) : undef,
				$row1->{diags},
				$row1->{cpt},
				$row1->{description},
				$row1->{charges} == 0 ? undef : $row1->{charges},
				$row1->{adjustment} == 0 ? undef : $row1->{adjustment},
				$desc,
				$firstTime ? $row->{balance} : undef,
			);
			push(@data, \@rowData);
			$firstTime = undef;
		}

		my @rowData = (
			$row->{invoice_id}, #undef,
			undef,
			undef,
			undef,
			undef,
			undef,
			undef,
			undef,
			undef,
			$row->{balance}, #undef
		);
#		push(@data, \@rowData);
	}

	$sqlStmt = qq{ select * from agedpatientdata where patient = '$patientID'};
	my $rowsF = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmt);
	my ($total, $current, $period1, $period2, $period3, $period4, $period5, $period6, $copay, $insurance);

	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	foreach my $rowF (@$rowsF)
	{
		$total += $rowF->{total};
		$current = $formatter->format_price($rowF->{ageperiod1}) if ($rowF->{ageperiod1} != 0);
		$period2 = $formatter->format_price($rowF->{ageperiod2}) if ($rowF->{ageperiod2} != 0);
		$period3 = $formatter->format_price($rowF->{ageperiod3}) if ($rowF->{ageperiod3} != 0);
		$period4 = $formatter->format_price($rowF->{ageperiod4}) if ($rowF->{ageperiod4} != 0);
		$period5 = $formatter->format_price($rowF->{ageperiod5}) if ($rowF->{ageperiod5} != 0);
		$period6 = $formatter->format_price($rowF->{ageperiod6}) if ($rowF->{ageperiod6} != 0);
		$copay = $formatter->format_price($rowF->{copay}) if ($rowF->{copay} != 0);
		$insurance = $rowF->{insurance} if ($rowF->{insurance} != 0);
	}

	my $patientBalance = $total - $insurance;
	$insurance = $formatter->format_price($insurance);
	$patientBalance = $formatter->format_price($patientBalance);
	$total = $formatter->format_price($total);
	my $footer = qq{<BR><table style='border: solid navy 1px' bgcolor='beige' border=0 cellspacing=0 cellpadding=1 width='30%'>};
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'>Current</td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'>$current</td></tr>} if ($current ne '');
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'>30-60 days</td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'>$period2</td></tr>} if ($period2 ne '');
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'>61-90 days</td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'>$period3</td></tr>} if ($period3 ne '');
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'>91-120 days</td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'>$period4</td></tr>} if ($period4 ne '');
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'>121-150 days</td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'>$period5</td></tr>} if ($period5 ne '');
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'>151-180 days</td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'>$period6</td></tr>} if ($period6 ne '');
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'>Copay</td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'>$copay</td></tr>} if ($copay ne '');
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'><B>Total Balance</B></td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'><B>$total</B></td></table>};

	$footer .= qq{<table style='border: solid navy 1px' bgcolor='beige' border=0 cellspacing=0 cellpadding=1 width='30%'};
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'>Patient Balance</td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'>$patientBalance</td></tr>};
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'>Insurance Balance</td><td align=right><font face='verdana,arial,helvetica' size='2' color='navy'>$insurance</td></tr><BR>};
	$footer .= qq{<tr><td><font face='verdana,arial,helvetica' size='2' color='navy'><B>Total Balance</B></td><td align=right><B><font face='verdana,arial,helvetica' size='2' color='navy'>$total</B></td></tr></table></font>};

	my $orgId = $page->session('org_internal_id');

	my $query = qq {select name_primary from org where org_internal_id = $orgId};
	my $org = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);
	$query = qq {select complete_addr_html from org_address where parent_id = $orgId};
	my $orgAddress = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);
	$query = qq {select value_text from org_attribute where parent_id = $orgId and value_type = 10};
	my $orgPhone = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);
	$query = qq {select tax_id from org where org_internal_id = $orgId};
	my $orgTax = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);

	$query = qq {select complete_name from person where person_id = '$patientID'};
	my $patientName = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);
	$query = qq {select complete_addr_html from person_address where parent_id = '$patientID'};
	my $patientAddress = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);

	my $html = qq
	{
		<center>
			<table border=0 cellspacing=0 cellpadding=0>
				<tr><td><font face='arial,helvetica' size='2' color=navy><b>$org</b></font></td></tr>
				<tr><td><font face='arial,helvetica' size='2' color=navy>$orgAddress</font></td></tr>
				<tr><td><font face='arial,helvetica' size='2' color=navy>$orgPhone</font></td></tr>
				<tr><td><font face='arial,helvetica' size='2' color=navy>$orgTax</font></td></tr>
			</table>
		</center>

		<table border=0 cellspacing=0 cellpadding=0 width='100%'>
			<tr><td><font face='arial,helvetica' size='2' color=navy><b>$patientName ($patientID)</b></font></td></tr>
			<tr>
				<td><font face='arial,helvetica' size='2' color=navy>$patientAddress</font></td>
				<td rowspan='2' valign='bottom'><font face='arial,helvetica' size='2' color=navy><b>@{[$page->getDate]}</b></font></td>
			</tr>
		</table>
		<p>
	};

	$html .= createHtmlFromData($page, 0, \@data, $pub);
	$html .= $footer;
	return $html;

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;