##############################################################################
package App::Dialog::Report::Org::General::Accounting::AccountHistory;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

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
			{ colIdx => 0,	head => 'Transaction Date',	hAlign => 'center',	dAlign => 'left',	dataFmt => '#0#' },
			{ colIdx => 1,	head => 'Service Provider',	hAlign => 'center',	dAlign => 'left',	dataFmt => '#1#' },
			{ colIdx => 2,	head => 'ICD-9',			hAlign => 'center',	dAlign => 'left',	dataFmt => '#2#' },
			{ colIdx => 3,	head => 'CPT',				hAlign => 'center',	dAlign => 'left',	dataFmt => '#3#' },
			{ colIdx => 4,	head => 'Description',		hAlign => 'center',	dAlign => 'left',	dataFmt => '#4#' },
			{ colIdx => 5,	head => 'Charges',			hAlign => 'center',	dAlign => 'right',	dataFmt => '#5#',	dformat => 'currency' },
			{ colIdx => 6,	head => 'Adjustment',		hAlign => 'center',	dAlign => 'right',	dataFmt => '#6#',	dformat => 'currency' },
			{ colIdx => 7,	head => 'Description',		hAlign => 'center', dAlign => 'left',	dataFmt => '#7#' },
			{ colIdx => 8,	head => 'Balance',			hAlign => 'center',	dAlign => 'right',	dataFmt => '#8#',	dformat => 'currency' },
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
				$row1->{tr_date},
				($row1->{diags} ne '') ? $doctor : undef,
				$row1->{diags},
				$row1->{cpt},
				$row1->{description},
				$row1->{charges} == 0 ? undef : $row1->{charges},
				$row1->{adjustment} == 0 ? undef : $row1->{adjustment},
				$desc,
				undef
			);
			push(@data, \@rowData);
		}

		my @rowData = (
			undef,
			undef,
			undef,
			undef,
			undef,
			undef,
			undef,
			undef,
			$row->{balance}
		);
		push(@data, \@rowData);
	}

	my $orgId = $page->session('org_internal_id');

	my $query = qq {select name_primary from org where org_internal_id = $orgId};
	my $org = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);
	$query = qq {select complete_addr_html from org_address where parent_id = $orgId};
	my $orgAddress = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);
	$query = qq {select value_text from org_attribute where parent_id = $orgId and value_type = 10};
	my $orgPhone = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);
	$query = qq {select value_text from org_attribute where parent_id = $orgId and value_type = 600 and item_name = 'State#'};
	my $orgTax = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);

	$query = qq {select complete_name from person where person_id = \'$patientID\'};
	my $patientName = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);
	$query = qq {select complete_addr_html from person_address where parent_id = \'$patientID\'};
	my $patientAddress = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$query);

	my $html = qq
	{
		<center>
			<table border=0 cellspacing=0 cellpadding=0>
				<tr><td><font face=\'arial,helvetica\' size=\'2\' color=navy><b>$org</b></font></td></tr>
				<tr><td><font face=\'arial,helvetica\' size=\'2\' color=navy>$orgAddress</font></td></tr>
				<tr><td><font face=\'arial,helvetica\' size=\'2\' color=navy>$orgPhone</font></td></tr>
				<tr><td><font face=\'arial,helvetica\' size=\'2\' color=navy>$orgTax</font></td></tr>
			</table>
		</center>

		<table border=0 cellspacing=0 cellpadding=0 width=\'100%\'>
			<tr><td><font face=\'arial,helvetica\' size=\'2\' color=navy><b>$patientName ($patientID)</b></font></td></tr>
			<tr>
				<td><font face=\'arial,helvetica\' size=\'2\' color=navy>$patientAddress</font></td>
				<td rowspan=\'2\' valign=\'bottom\'><font face=\'arial,helvetica\' size=\'2\' color=navy><b>@{[$page->getDate]}</b></font></td>
			</tr>
		</table>
		<p>
	};

	$html .= createHtmlFromData($page, 0, \@data, $pub);
	return $html;

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;