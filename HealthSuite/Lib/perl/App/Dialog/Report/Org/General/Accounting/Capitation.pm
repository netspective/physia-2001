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
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

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
			caption => 'Read Batch Report Date',
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
			types => ['Physician'],
			incSimpleName=>1,
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
			new CGI::Dialog::Field(
				name => 'printReport',
				type => 'bool',
				style => 'check',
				caption => 'Print report',
				defaultValue => 0
			),

			new CGI::Dialog::Field(
				caption =>'Printer',
				name => 'printerQueue',
				options => FLDFLAG_PREPENDBLANK,
				fKeyStmtMgr => $STMTMGR_DEVICE,
				fKeyStmt => 'sel_org_devices',
				fKeyDisplayCol => 0
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
		reportTitle => "Capitalization/Utilization Report",
		columnDefn => [
			{ colIdx => 0, head => 'Physician ID', hAlign => 'center',dAlign => 'left',dataFmt => '#0#'},
			{ colIdx => 1, head => 'Org ID',dAlign => 'left', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Product ID', dAlign => 'left',dataFmt => '#2#' },
			{ colIdx => 3, head => 'Plan ID', dAlign => 'left',dataFmt => '#3#' },
			{ colIdx => 4, head => '# of enrolees',dAlign => 'right' ,dataFmt => '#4#' },
			{ colIdx => 5, head => 'Month', dAlign => 'left',dataFmt => '#5#' },
			{ colIdx => 6, head => 'Monthly Ck Amt',summarize => 'sum',dformat => 'currency', dAlign => 'center',dataFmt => '#6#' },
			{ colIdx => 7, head => 'Copay Exp',summarize => 'sum',dformat => 'currency', dAlign => 'center' ,dataFmt => '#7#' },
			{ colIdx => 8, head => 'Copay Rcvd',summarize => 'sum',dformat => 'currency', dAlign => 'right' ,dataFmt => '#8#' },
			{ colIdx => 9, head => '# of Pts seen',summarize => 'sum',dAlign => 'right' ,dataFmt => '#9#' },
		],
	};
#
	my $hardCopy = $page->field('printReport');
	my $html;
	my $textOutputFilename;

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');
#
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


	my $sqlStmtEnr = qq {
		select product_name, plan_name, count(*) enrollees
		from insurance
		where ins_type <> 7
		and record_type = 3
		group by product_name, plan_name
	};
	my $rowsEnr = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmtEnr);


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
		my $enrollees = 0;

		foreach my $rowEnr (@$rowsEnr)
		{
			if(($row->{plan} eq $rowEnr->{plan_name}) && ($row->{product} eq $rowEnr->{product_name}))
			{
				$enrollees = $rowEnr->{enrollees}
			}
		};
		$row->{enrollees} = $enrollees;
	};

	foreach my $row (@$rows)
	{


#		my $batchIDClauseA = qq { and  ta.value_text = '$row->{batchid}'} if($row->{batchid} ne '');
#		my $batchDateClauseA = qq { and ta.value_date = to_date('$row->{batchdate}', 'mm/dd/yyyy')} if($row->{batchdate} ne '');
		my ($planClauseA, $productClauseA, $physicianClauseA, $orgClauseA);
		my ($planClauseB, $productClauseB, $physicianClauseB, $orgClauseB);

		if($row->{plan} ne '')
		{
			$planClauseA =qq { and t.data_text_b = '$row->{plan}' };
		}
		else
		{
			$planClauseA =qq { and t.data_text_b is null };
		}

		if($row->{product} ne '')
		{
			$productClauseA =qq { and t.data_text_a = '$row->{product}' };
		}
		else
		{
			$productClauseA =qq { and t.data_text_a is null }
		}

		if($row->{provider} ne '')
		{
			$physicianClauseA =qq { and t.provider_id = '$row->{provider}'};
		}
		else
		{
			$physicianClauseA =qq { and t.provider_id is null};
		}

		if($row->{org_id} ne '')
		{
			$orgClauseA =qq { and t.receiver_id = $row->{org_id}};
		}
		else
		{
			$orgClauseA =qq { and t.receiver_id is null};
		}

#		my $batchIDClauseB = qq { and  ia.value_text = '$row->{batchid}'} if($row->{batchid} ne '');
#		my $batchDateClauseB = qq { and ia.value_date =  to_date('$row->{batchdate}', 'mm/dd/yyyy')} if($row->{batchdate} ne '');

		if($row->{plan} ne '')
		{
			$planClauseB =qq { and ins.plan_name = '$row->{plan}'};
		}
		else
		{
			$planClauseB =qq { and ins.plan_name is null};
		}

		if($row->{product} ne '')
		{
			$productClauseB =qq { and ins.product_name = '$row->{product}'};
		}
		else
		{
			$productClauseB =qq { and ins.product_name is null};
		}

		if($row->{provider} ne '')
		{
			$physicianClauseB =qq { and t.care_provider_id = '$row->{provider}'};
		}
		else
		{
			$physicianClauseB =qq { and t.care_provider_id is null};
		}

		if($row->{org_id} ne '')
		{
			$orgClauseB =qq { and t.service_facility_id = $row->{org_id}} ;
		}
		else
		{
			$orgClauseB =qq { and t.service_facility_id is null} ;
		}

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
			$row->{enrollees},
			$month[$i],
			$amount[$i],
			$copay_expected[$i],
			$copay_received[$i],
			$patients_seen[$i],
			);
			push(@data, \@rowData);
		}
	};

	$html = createHtmlFromData($page, 0, \@data, $pub);
	$textOutputFilename =  createTextRowsFromData($page, 0, \@data, $pub);

	my $tempDir = $CONFDATA_SERVER->path_temp();
	my $Constraints = [
	{ Name => "Read Batch Report Date ", Value => $batchBeginDate."  ".$batchEndDate},
	{ Name => "Batch ID Range ", Value => $batchIDFrom."  ".$batchIDTo},
	{ Name => "Org ID ", Value => $orgID},
	{ Name => "Physician ID ", Value => $physicianID},
	{ Name => "Insurance Product ", Value => $productID},
	{ Name => "Insurance Plan ", Value => $planID},
	{ Name=> "Print Report ", Value => ($hardCopy) ? 'Yes' : 'No' },
	{ Name=> "Printer ", Value => $printerDevice},
	];
	my $FormFeed = appendFormFeed($tempDir.$textOutputFilename);
	my $fileConstraint = appendConstraints($page, $tempDir.$textOutputFilename, $Constraints);

	if ($hardCopy == 1 and $printerAvailable) {
		my $reportOpened = 1;
		open (ASCIIREPORT, $tempDir.$textOutputFilename) or $reportOpened = 0;

		if ($reportOpened) {
			while (my $reportLine = <ASCIIREPORT>) {
				print $printHandle $reportLine;
			}
		}
		close ASCIIREPORT;
	}

	return ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version</a> <br>} : "" ) . $html;
	#return $html;

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
