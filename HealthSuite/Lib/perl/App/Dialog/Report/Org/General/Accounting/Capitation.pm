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
		new App::Dialog::Field::BatchDateID(
			caption => 'Batch ID Date',
			name => 'batch_fields',
			orgInternalIdFieldName => 'org_id'
			),
		new App::Dialog::Field::OrgType(
			caption => 'Org ID',
			name => 'org_id',
			options => FLDFLAG_REQUIRED,
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
			{ colIdx => 4, head => 'Month', dAlign => 'right',dataFmt => '#4#' },
			{ colIdx => 5, head => 'Monthly Ck Amt',summarize => 'sum',dformat => 'currency', dAlign => 'center',dataFmt => '#5#' },
			{ colIdx => 6, head => 'Copay Exp',summarize => 'sum',dformat => 'currency', dAlign => 'center' ,dataFmt => '#6#' },
			{ colIdx => 7, head => 'Copay Rcvd',summarize => 'sum',dformat => 'currency', dAlign => 'right' ,dataFmt => '#7#' },
			{ colIdx => 8, head => '# of Pts seen',summarize => 'sum',dAlign => 'right' ,dataFmt => '#8#' },
		],
	};

	my $batchDate = $page->field('batch_date');
	my $batchID = $page->field('batch_id');
	my $planID = $page->field('plan_id');
	my $productID = $page->field('product_id');
	my $physicianID = $page->field('provider_id');
	my $orgID = $page->field('org_id');

	my $batchIDClause1 =qq { and  ta.value_text = \'$batchID\'} if($batchID ne '');
#	my $batchDateClause1 =qq { and ta.value_date = to_date('$batchDate', 'mm/dd/yyyy')} if($batchDate ne '');
	my $batchDateClause1 =qq { and ta.value_date = \'$batchDate\'} if($batchDate ne '');
	my $planClause1 =qq { and t.data_text_b = \'$planID\'} if($planID ne '');
	my $productClause1 =qq { and t.data_text_a = \'$productID\'} if($productID ne '');
	my $physicianClause1 =qq { and t.provider_id = \'$physicianID\'} if($physicianID ne '');
	my $orgClause1 =qq { and t.receiver_id = $orgID} if($orgID ne '');

	my $batchIDClause2 =qq { and  ia.value_text = \'$batchID\'} if($batchID ne '');
	my $batchDateClause2 =qq { and ia.value_date = to_date('$batchDate', 'mm/dd/yyyy')} if($batchDate ne '');
	my $planClause2 =qq { and ins.plan_name = \'$planID\'} if($planID ne '');
	my $productClause2 =qq { and ins.product_name = \'$productID\'} if($productID ne '');
	my $physicianClause2 =qq { and t.care_provider_id = \'$physicianID\'} if($physicianID ne '');
	my $orgClause2 =qq { and t.service_facility_id = $orgID} if($orgID ne '');

	my $sqlStmt = qq {select
					ta.value_text batchid,
					ta.value_date batchdate,
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
					$batchIDClause1
					$batchDateClause1
					$planClause1
					$productClause1
					$physicianClause1
					$orgClause1
				union

				select
					ia.value_text batchid,
					ia.value_date batchdate,
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
					$batchIDClause2
					$batchDateClause2
					$planClause2
					$productClause2
					$physicianClause2
					$orgClause2
				};

	my $activity = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmt);
	my ($query0, $query1, $query2, $row0, $row1, $row2, $org_id, $amount, $month, $copay_expected, $copay_received, $patients_seen, @rowData);
	my @data = ();

	foreach my $x (@$activity)
	{
		my $batchIDClauseA =qq { and  ta.value_text = \'$x->{batchid}\'} if($x->{batchid} ne '');
		my $batchDateClauseA =qq { and ta.value_date = \'$x->{batchdate}\'} if($x->{batchdate} ne '');
		my $planClauseA =qq { and t.data_textb = \'$x->{plan}\'} if($x->{plan} ne '');
		my $productClauseA =qq { and t.data_text_a = \'$x->{product}\'} if($x->{product} ne '');
		my $physicianClauseA =qq { and t.provider_id = \'$x->{provider}\'} if($x->{provider} ne '');
		my $orgClauseA =qq { and t.receiver_id = $x->{org_id}} if($x->{org_id} ne '');

		my $batchIDClauseB =qq { and  ia.value_text = \'$x->{batchid}\'} if($x->{batchid} ne '');
		my $batchDateClauseB =qq { and ia.value_date =  \'$x->{batchdate}\'} if($x->{batchdate} ne '');
		my $planClauseB =qq { and ins.plan_name = \'$x->{plan}\'} if($x->{plan} ne '');
		my $productClauseB =qq { and ins.product_name = \'$x->{product}\'} if($x->{product} ne '');
		my $physicianClauseB =qq { and t.care_provider_id = \'$x->{provider}\'} if($x->{provider} ne '');
		my $orgClauseB =qq { and t.service_facility_id = $x->{org_id}} if($x->{org_id} ne '');

		$query0 = qq{
						select org_id
						from org
						where org_internal_id = $x->{org_id}
					};

		$row0 = $STMTMGR_RPT_CLAIM_STATUS->getRowAsHash($page,STMTMGRFLAG_DYNAMICSQL,$query0);
		if ($row0 ne '')
		{
			$org_id = $row0->{org_id};
		}

		$query1 = qq{
						select
							ta.value_text batchid,
							ta.value_date batchdate,
							t.data_text_b plan,
							t.data_text_a product,
							t.provider_id provider,
							t.receiver_id org,
							t.data_num_a month,
							sum(t.unit_cost) cap_amount
						from
							transaction t,
							trans_attribute ta
						where
							t.trans_type = 9030
							and t.trans_status = 7
							and t.trans_id = ta.parent_id
							and ta.item_name = 'Monthly Cap/Payment/Batch ID'
							$batchIDClauseA
							$batchDateClauseA
							$planClauseA
							$productClauseA
							$physicianClauseA
							$orgClauseA
						group by
							ta.value_text,
							ta.value_date,
							t.data_text_b,
							t.data_text_a,
							t.provider_id,
							t.receiver_id,
							t.data_num_a
					};

		$row1 = $STMTMGR_RPT_CLAIM_STATUS->getRowAsHash($page,STMTMGRFLAG_DYNAMICSQL,$query1);
		if ($row1 ne '')
		{
			$amount = $row1->{cap_amount};
			$month = $row1->{month};
		}

		$query2 = qq{
					select
						ia.value_text,
						ia.value_date,
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
						$batchIDClauseB
						$batchDateClauseB
						$planClauseB
						$productClauseB
						$physicianClauseB
						$orgClauseB
					group by
						ia.value_text,
						ia.value_date,
						ins.plan_name,
						ins.product_name,
						t.care_provider_id,
						t.service_facility_id
					};

		$row2 = $STMTMGR_RPT_CLAIM_STATUS->getRowAsHash($page,STMTMGRFLAG_DYNAMICSQL,$query2);
		if ($row2 ne '')
		{
			$copay_expected = $row2->{copay_expected};
			$copay_received = $row2->{copay_received};
			$patients_seen = $row2->{patients_seen};
		}

		my @rowData = (
		$x->{provider},
		$org_id,
		$x->{product},
		$x->{plan},
		$month,
		$amount,
		$copay_expected,
		$copay_received,
		$patients_seen,
		);
		push(@data, \@rowData);
	};

	my $html = createHtmlFromData($page, 0, \@data, $pub);
	return $html;

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;