##############################################################################
package App::Dialog::Report::Org::General::Accounting::Capitation;
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
use App::Statements::Org;
use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;
use App::Dialog::Field::BatchDateID;
use App::Dialog::Field::Insurance;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-capitation', heading => 'Capitation/Utilization Report');

	$self->addContent(
		new CGI::Dialog::Field::Duration(
			name => 'batch',
			caption => 'Batch Date',
			begin_caption => 'Batch Begin Date',
			end_caption => 'Batch End Date',
		),
		new CGI::Dialog::MultiField(
			caption => 'Batch ID Range',
			name => 'batch_fields',
			fields => [
				new CGI::Dialog::Field(
				caption => 'Batch ID From',
				name => 'batch_id_from',
				size => 12
				),
				new CGI::Dialog::Field(
				caption => 'Batch ID To',
				name => 'batch_id_to',
				size => 12
				),
			]
		),
		new App::Dialog::Field::OrgType(
			caption => 'Org ID',
			name => 'org_id',
			options => FLDFLAG_PREPENDBLANK,
			types => "'PRACTICE', 'CLINIC', 'FACILITY/SITE'"
			),
		new App::Dialog::Field::Person::ID(
			caption => 'Physician ID',
			name => 'provider_id',
			types => ['Physician']
			),
		new App::Dialog::Field::Insurance::Product(
			caption => 'Insurance Product',
			name => 'product_id',
			findPopup => '/lookup/insproduct/insorgid',
			),
		new App::Dialog::Field::Insurance::Plan(
			caption => 'Insurance Plan',
			name => 'plan_id',
			findPopup => '/lookup/insplan/product/itemValue',
			findPopupControlField => '_f_product_name',
			),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

}

sub buildSqlStmt
{

	my ($self, $page, $flags) = @_;

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $pub = {
		columnDefn => [
			{ colIdx => 0, head => 'Physician ID', hAlign => 'center',dAlign => 'left',dataFmt => '#0#'},
			{ colIdx => 1, head => 'Org ID',dAlign => 'left', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Product ID', dAlign => 'left',dataFmt => '#2#' },
			{ colIdx => 3, head => 'Plan ID', dAlign => 'left',dataFmt => '#3#' },
			{ colIdx => 4, head => 'Month', dAlign => 'left',dataFmt => '#4#' },
			{ colIdx => 5, head => 'Monthly Ck Amt',summarize => 'sum',dformat => 'currency', dAlign => 'center',dataFmt => '#5#' },
			{ colIdx => 6, head => 'Copay Exp',summarize => 'sum',dformat => 'currency', dAlign => 'center' ,dataFmt => '#6#' },
			{ colIdx => 7, head => 'Copay Rcvd',summarize => 'sum',dformat => 'currency', dAlign => 'right' ,dataFmt => '#7#' },
			{ colIdx => 8, head => '# of Pts seen',summarize => 'sum',dAlign => 'right' ,dataFmt => '#8#' },
		],
	};

	my $batchBeginDate = $page->field('batch_begin_date');
	my $batchEndDate = $page->field('batch_end_date');
	my $batchIDFrom = $page->field('batch_id_from');
	my $batchIDTo = $page->field('batch_id_to');
	my $planID = $page->field('plan_id');
	my $productID = $page->field('product_id');
	my $physicianID = $page->field('provider_id');
	my $orgID = $page->field('org_id');

	my $batchIDClause1 =qq { and ta.value_text between '$batchIDFrom' and '$batchIDTo'} if($batchIDFrom ne '' && $batchIDTo ne '');
	$batchIDClause1 =qq { and ta.value_text <= '$batchIDTo' } if($batchIDFrom eq '' && $batchIDTo ne '');
	$batchIDClause1 =qq { and ta.value_text >= '$batchIDFrom' } if($batchIDFrom ne '' && $batchIDTo eq '');

	my $batchDateClause1 =qq { and ta.value_date between to_date('$batchBeginDate', 'mm/dd/yyyy') and to_date('$batchEndDate', 'mm/dd/yyyy') } if($batchBeginDate ne '' && $batchEndDate ne '');
	$batchDateClause1 =qq { and ta.value_date <= to_date('$batchEndDate', 'mm/dd/yyyy')	} if($batchBeginDate eq '' && $batchEndDate ne '');
	$batchDateClause1 =qq { and ta.value_date >= to_date('$batchBeginDate', 'mm/dd/yyyy') } if($batchBeginDate ne '' && $batchEndDate eq '');

	my $planClause1 =qq { and t.data_text_b = '$planID'} if($planID ne '');
	my $productClause1 =qq { and t.data_text_a = '$productID'} if($productID ne '');
	my $physicianClause1 =qq { and t.provider_id = '$physicianID'} if($physicianID ne '');
	my $orgClause1 =qq { and t.receiver_id = $orgID} if($orgID ne '');

	my $batchIDClause2 =qq { and ia.value_text between '$batchIDFrom' and '$batchIDTo'} if($batchIDFrom ne '' && $batchIDTo ne '');
	$batchIDClause2 =qq { and ia.value_text <= '$batchIDTo' } if($batchIDFrom eq '' && $batchIDTo ne '');
	$batchIDClause2 =qq { and ia.value_text >= '$batchIDFrom' } if($batchIDFrom ne '' && $batchIDTo eq '');

	my $batchDateClause2 =qq { and ia.value_date between to_date('$batchBeginDate', 'mm/dd/yyyy') and to_date('$batchEndDate', 'mm/dd/yyyy') } if($batchBeginDate ne '' && $batchEndDate ne '');
	$batchDateClause2 =qq { and ia.value_date <= to_date('$batchEndDate', 'mm/dd/yyyy')	} if($batchBeginDate eq '' && $batchEndDate ne '');
	$batchDateClause2 =qq { and ia.value_date >= to_date('$batchBeginDate', 'mm/dd/yyyy') } if($batchBeginDate ne '' && $batchEndDate eq '');

	my $planClause2 =qq { and ins.plan_name = '$planID'} if($planID ne '');
	my $productClause2 =qq { and ins.product_name = '$productID'} if($productID ne '');
	my $physicianClause2 =qq { and t.care_provider_id = '$physicianID'} if($physicianID ne '');
	my $orgClause2 =qq { and t.service_facility_id = $orgID} if($orgID ne '');

	my $sqlStmt = qq {
		select distinct
			t.data_text_b plan,
			t.data_text_a product,
			t.provider_id provider,
			o.org_internal_id org_id
		from
			transaction t,
			trans_attribute ta,
			org o
		where
			t.trans_type = 9030
			and t.trans_status = 7
			and t.trans_id = ta.parent_id
			and ta.item_name = 'Monthly Cap/Payment/Batch ID'
			and t.receiver_id = o.org_internal_id
			and o.owner_org_id = @{[ $page->session('org_internal_id')]}
			$batchIDClause1
			$batchDateClause1
			$planClause1
			$productClause1
			$physicianClause1
			$orgClause1
		union
		select distinct
			ins.plan_name plan,
			ins.product_name product,
			t.care_provider_id provider,
			t.service_facility_id org_id
		from
			transaction t,
			insurance ins,
			invoice_billing ib,
			invoice_attribute ia,
			invoice_item ii,
			invoice i
		where
			i.invoice_subtype = 2
			and ii.parent_id = i.invoice_id
			and ii.item_type = 3
			and ia.parent_id = i.invoice_id
			and ia.item_name = 'Invoice/Creation/Batch ID'
			and ib.bill_id = i.billing_id
			and ib.bill_ins_id = ins.ins_internal_id
			and t.trans_id = i.main_transaction
			and t.billing_facility_id = @{[ $page->session('org_internal_id')]}
			$batchIDClause2
			$batchDateClause2
			$planClause2
			$productClause2
			$physicianClause2
			$orgClause2
		order by provider, org_id, product, plan
	};

	my $rows = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmt);
	my ($query0, $query1, $query2, $row0, $rows1, $rows2, $org_id, @rowData);
	my @data = ();

	foreach my $row (@$rows)
	{
#		my $batchIDClauseA = qq { and  ta.value_text = '$row->{batchid}'} if($row->{batchid} ne '');
#		my $batchDateClauseA = qq { and ta.value_date = to_date('$row->{batchdate}', 'mm/dd/yyyy')} if($row->{batchdate} ne '');
		my $planClauseA =qq { and t.data_text_b = '$row->{plan}'} if($row->{plan} ne '');
		my $productClauseA =qq { and t.data_text_a = '$row->{product}'} if($row->{product} ne '');
		my $physicianClauseA =qq { and t.provider_id = '$row->{provider}'} if($row->{provider} ne '');
		my $orgClauseA =qq { and t.receiver_id = $row->{org_id}} if($row->{org_id} ne '');

#		my $batchIDClauseB = qq { and  ia.value_text = '$row->{batchid}'} if($row->{batchid} ne '');
#		my $batchDateClauseB = qq { and ia.value_date =  to_date('$row->{batchdate}', 'mm/dd/yyyy')} if($row->{batchdate} ne '');
		my $planClauseB =qq { and ins.plan_name = '$row->{plan}'} if($row->{plan} ne '');
		my $productClauseB =qq { and ins.product_name = '$row->{product}'} if($row->{product} ne '');
		my $physicianClauseB =qq { and t.care_provider_id = '$row->{provider}'} if($row->{provider} ne '');
		my $orgClauseB =qq { and t.service_facility_id = $row->{org_id}} if($row->{org_id} ne '');

		$org_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId',$row->{org_id});

		$query1 = qq{
						select
							t.data_text_b plan,
							t.data_text_a product,
							t.provider_id provider,
							t.receiver_id org,
							m.caption month,
							sum(t.unit_cost) cap_amount
						from
							transaction t,
							trans_attribute ta,
							month m
						where
							t.trans_type = 9030
							and t.trans_status = 7
							and t.trans_id = ta.parent_id
							and ta.item_name = 'Monthly Cap/Payment/Batch ID'
							and m.id = t.data_num_a
							$batchIDClause1
							$batchDateClause1
							$planClauseA
							$productClauseA
							$physicianClauseA
							$orgClauseA
						group by
							t.data_text_b,
							t.data_text_a,
							t.provider_id,
							t.receiver_id,
							m.caption
					};

		$rows1 = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$query1);
		my (@amount, @month, @copay_expected, @copay_received, @patients_seen);
		my ($count1, $count2);
		foreach my $row1 (@$rows1)
		{
			$amount[$count1] = $row1->{cap_amount};
			$month[$count1] = $row1->{month};
			$count1++;
		}

		$query2 = qq{
					select
						t.care_provider_id provider_id,
						t.service_facility_id org_id,
						ins.product_name product_id,
						ins.plan_name plan_id,
						sum(ii.extended_cost) copay_expected,
						abs(sum(ii.total_adjust)) copay_received,
						count(i.invoice_id) patients_seen
					from
						transaction t,
						insurance ins,
						invoice_billing ib,
						invoice_attribute ia,
						invoice_item ii,
						invoice i
					where
						i.invoice_subtype = 2 and
						ii.parent_id = i.invoice_id and
						ii.item_type = 3 and
						ia.parent_id = i.invoice_id and
						ia.item_name = 'Invoice/Creation/Batch ID' and
						ib.bill_id = i.billing_id and
						ib.bill_ins_id = ins.ins_internal_id and
						t.trans_id = i.main_transaction
						$batchIDClause2
						$batchDateClause2
						$planClauseB
						$productClauseB
						$physicianClauseB
						$orgClauseB
					group by
						ins.plan_name,
						ins.product_name,
						t.care_provider_id,
						t.service_facility_id
					};

		$rows2 = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$query2);
		foreach my $row2 (@$rows2)
		{
			$copay_expected[$count2] = $row2->{copay_expected};
			$copay_received[$count2] = $row2->{copay_received};
			$patients_seen[$count2] = $row2->{patients_seen};
			$count2++;
		}

		my $maxCount = ($count1 > $count2) ? $count1 : $count2;
		for my $i(0..$maxCount - 1)
		{
			my @rowData = (
			$row->{provider},
			$org_id,
			$row->{product},
			$row->{plan},
			$month[$i],
			$amount[$i],
			$copay_expected[$i],
			$copay_received[$i],
			$patients_seen[$i],
			);
			push(@data, \@rowData);
		}
	};

	my $html = createHtmlFromData($page, 0, \@data, $pub);
	return $html;

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;