##############################################################################
package App::Statements::Report::Accounting;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_REPORT_ACCOUNTING $STMTFMT_SEL_RECEIPT_ANALYSIS $STMTRPTDEFN_DEFAULT $STMTMGR_AGED_PATIENT_ORG_PROV $STMTMGR_AGED_INSURANCE_ORG_PROV);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_ACCOUNTING $STMTMGR_AGED_PATIENT_ORG_PROV $STMTMGR_AGED_INSURANCE_ORG_PROV);

my $FILLED =App::Universal::TRANSSTATUS_FILLED;
my $PAYMENT	=App::Universal::TRANSTYPEACTION_PAYMENT;

$STMTMGR_AGED_PATIENT_ORG_PROV = qq
{
	SELECT
		p.simple_name person_name,
		a.person_id person_ID ,
		count(distinct a.invoice_id),
		sum(balance_0),
		sum(balance_31),
		sum(balance_61),
		sum(balance_91),
		sum(balance_121),
		sum(balance_151),
		sum(decode(item_type,3,total_pending,0)),
		sum(total_pending)
	FROM	agedpayments a, person p, transaction t, invoice i
	WHERE	(a.person_id = :1 or :1 is NULL)
	AND 	(a.invoice_item_id is NULL  or a.item_type in (3) )
	AND	a.bill_party_type in (0,1)
	AND a.balance <> 0
	AND p.person_id = a.person_id
	AND	a.person_id IN
	(
	 SELECT poc.person_id
	 FROM 	person_org_category poc
	 WHERE  org_internal_id = :2
	)
	and i.invoice_id = a.invoice_id
	and t.trans_id = i.main_transaction
	%whereClause%
	GROUP BY a.person_id, p.simple_name
	having sum(total_pending)> 0
};

$STMTMGR_AGED_INSURANCE_ORG_PROV = qq
{
	SELECT 	a.bill_to_id as insurance_ID , count (distinct(a.invoice_id)),
		sum(balance_0),
		sum(balance_31),
		sum(balance_61),
		sum(balance_91),
		sum(balance_121),
		sum(balance_151),
		sum(total_pending)
	FROM	agedpayments a,org, transaction t, invoice i
	WHERE	(a.bill_plain = :1 or :1 is NULL)
	AND	a.bill_party_type  in (2,3)
	AND	a.bill_plain = org.org_internal_id
	AND	org.owner_org_id = :2
	and i.invoice_id = a.invoice_id
	and t.trans_id = i.main_transaction
	%whereClause%
	GROUP BY bill_to_id
};

$STMTMGR_REPORT_ACCOUNTING = new App::Statements::Report::Accounting(
'procAnalysis' => {
	#sqlStmt => qq{
	#		select MAX((SELECT p.short_sortable_name FROM person p where p.person_id= provider)) as short_sortable_name,
	#		MAX((SELECT tt.caption FROM Transaction_type tt WHERE tt.id = trans_type)) as visit_type,
	#		nvl(i.code,'UNK') as code,
	#		MAX(NVL((SELECT r.name FROM ref_cpt r WHERE r.cpt=i.code),'N/A')) as proc,
	#		sum(i.unit_cost) as unit_cost,
	#		sum(i.units) units,
	#		i.invoice_date,
	#		trunc(invoice_date,'MM') as month_date,
	#		trunc(invoice_date,'YYYY') as year_date
	#		from invoice_charges i
	#		where (:1 IS NULL OR provider= :1 )
	#		AND (i.invoice_date) BETWEEN to_date(:2,'MM/DD/YYYY')
	#		AND to_date(:3,'MM/DD/YYYY')
	#		AND (:4 IS NULL OR :4 = i.facility)
	#		AND (:5 IS NULL OR :5 <=i.code)
	#		AND (:6 is NULL OR :6 >=i.code)
	#		AND owner_org_id = :7
	#		group by nvl(i.code,'UNK'),trunc(invoice_date,'MM') ,trunc(invoice_date,'YYYY') ,i.invoice_date,
	#		provider,trans_type
	#		order by 1,2,7 asc
	#		},
	sqlStmt =>qq{
			SELECT 	p.simple_name,
				tt.caption as visit_type,
				NVL(i.code,'UNK') as code,
				NVL(r.name,'N/A') as proc,
				sum(i.unit_cost) as year_cost,
				sum(i.units)	as year_units,
				sum(decode(
					   trunc(invoice_date,'MM'),
					    trunc(to_date(:3,'$SQLSTMT_DEFAULTDATEFORMAT'),'MM')
				     		,i.unit_cost,
				     	 0)
				     ) as month_cost,
				sum(decode(
					   trunc(invoice_date,'MM'),
					    trunc(to_date(:3,'$SQLSTMT_DEFAULTDATEFORMAT'),'MM')
				     		,i.units,
				     	 0)
				     ) as month_units,

				sum(decode(
					   invoice_date,
					   to_date(:3,'$SQLSTMT_DEFAULTDATEFORMAT')
				     		,i.unit_cost,
				     	 0)
				     ) as batch_cost,
				sum(decode(
					   invoice_date,
					   to_date(:3,'$SQLSTMT_DEFAULTDATEFORMAT')
				     		,i.units,
				     	 0)
				     ) as batch_units
			FROM 	invoice_charges i, person p, transaction_type tt, ref_cpt r
			WHERE (:1 IS NULL OR provider= :1 )
			AND (i.invoice_date) BETWEEN to_date(:2,'MM/DD/YYYY')
			AND to_date(:3,'MM/DD/YYYY')
			AND (:4 IS NULL OR :4 = i.facility)
			AND (:5 IS NULL OR :5 <=i.code)
			AND (:6 is NULL OR :6 >=i.code)
			AND owner_org_id = :7
			AND tt.id (+)= i.trans_type
			AND r.cpt(+)=i.code
			AND p.person_id = i.provider
			group by p.simple_name,
				tt.caption,
				NVL(i.code,'UNK'),
				NVL(r.name,'N/A')
			order by 1,2,3
		},
	sqlStmtBindParamDescr => ['Provider ID for yearToDateReceiptProcAnalysis View'],
	},
	'sel_providerreceipt'=>
	{	sqlStmt=>
		qq{
			SELECT	p.simple_name as provider,
				ic.payer_type,
				ic.payer_id,
				pm.caption as pay_type,
				sum(nvl(insurance_pay,0)+nvl(person_pay,0)) as year_rcpt,
				sum(decode(
					   trunc(ic.invoice_date,'MM'),
					    trunc(to_date(:5,'$SQLSTMT_DEFAULTDATEFORMAT'),'MM'),
				     		(nvl(insurance_pay,0)+nvl(person_pay,0)),
				     	 0)
				     ) as month_rcpt,
				sum(decode(
						ic.invoice_date,
						 to_date(:5,'$SQLSTMT_DEFAULTDATEFORMAT'),
							(nvl(insurance_pay,0)+nvl(person_pay,0)),
					 0)
				     ) as batch_rcpt
			FROM 	invoice_charges ic, person p, invoice_item_adjust iia, payment_method pm
			WHERE 	(:1 IS NULL OR provider = :1)
			AND	(:3 IS NULL OR batch_id = :3)
			AND	ic.invoice_date between to_date(:4,'$SQLSTMT_DEFAULTDATEFORMAT')
			AND 	to_date(:5,'$SQLSTMT_DEFAULTDATEFORMAT')
			AND	ic.payer_type is not null
			AND	ic.owner_org_id = :6
			AND	p.person_id (+)= ic.provider
			AND	iia.adjustment_id  (+) = ic.adjustment_id
			AND	pm.id (+)= iia.pay_method
			AND	(:2 IS NULL OR upper(pm.caption) = upper(:2))
			GROUP BY p.simple_name,pm.caption,
				ic.payer_type,	ic.payer_id,
				ic.pay_type
			UNION
			SELECT	p.simple_name as provider,
				max(-1) as payer_type,
				nvl(data_text_b,data_text_a) as payer_id,
				max('Check') as pay_type,
				sum(nvl(unit_cost,0)) as year_rcpt,
				sum(decode(
					   trunc(value_date,'MM'),
					    trunc(to_date(:5,'MM/DD/YYYY'),'MM'),
				     		(nvl(unit_cost,0)),
				     	 0)
				     ) as month_rcpt,
				sum(decode(
					   value_date,
					    to_date(:5,'MM/DD/YYYY'),
				     		(nvl(unit_cost,0)),
				     	 0)
				     ) as batch_rcpt
			FROM 	transaction t,trans_attribute  ta,person p
			WHERE	t.trans_id = ta.parent_id
			AND	ta.item_name = 'Monthly Cap/Payment/Batch ID'
			AND	trans_type = $PAYMENT
			AND	trans_status =$FILLED
			AND	(:1 IS NULL OR  provider_id = :1)
			AND	(:2 IS NULL OR 'CHECK' = upper(:2))
			AND	(:3 IS NULL OR	ta.value_text = :3)
			AND	ta.value_date between to_date(:4,'MM/DD/YYYY')
			AND 	to_date(:5,'MM/DD/YYYY')
			AND	provider_id is not null
			AND	p.person_id (+)= t.provider_id
			GROUP BY p.simple_name,
				nvl(data_text_b,data_text_a)
			ORDER BY 1,3,4,5

		},
	},


	'sel_providerreceipt2' =>
	{
		sqlStmt=>
		qq
		{
			SELECT	(SELECT simple_name FROM person where person_id = ic.provider) as provider,
				ic.invoice_id,
				decode(payer_type,0,'Personal Receipts', 'Insurance Receipts') as category,
				decode(payer_type,
					0,payer_id,
					1,(SELECT org_id FROM org WHERE payer_id = org_internal_id)) as payer_name,
				pay_type,
				invoice_date ,
				(nvl(insurance_pay,0)+nvl(person_pay,0)) as rcpt,
				trunc(invoice_date,'MM') as month_date,
				trunc(invoice_date,'YYYY') as year_date
			FROM 	invoice_charges ic
			WHERE 	(:1 IS NULL OR provider = :1)
			AND	(:2 IS NULL OR upper(pay_type) = upper(:2))
			AND	(:3 IS NULL OR batch_id = :3)
			AND	invoice_date between to_date(:4,'$SQLSTMT_DEFAULTDATEFORMAT')
			AND 	to_date(:5,'$SQLSTMT_DEFAULTDATEFORMAT')
			AND	payer_type is not null
			AND	owner_org_id = :6
			UNION
			SELECT (SELECT simple_name FROM person WHERE person_id = t.provider_id) as provider,
				to_number(NULL) as invoice_id,
				'Cap Insurance Receipts' as category,
				nvl(nvl(data_text_b,data_text_a),'UNK') as payer_name,
				'Check' as pay_type,
				value_date,
				unit_cost as rcpt,
				trunc(value_date,'MM') as month_date,
				trunc(value_date,'YYYY') as year_date
			FROM	transaction t,trans_attribute  ta
			WHERE 	t.trans_id = ta.parent_id
			AND	ta.item_name = 'Monthly Cap/Payment/Batch ID'
			AND	trans_type = $PAYMENT
			AND	trans_status =$FILLED
			AND	(:1 IS NULL OR  provider_id = :1)
			AND	(:2 IS NULL OR 'CHECK' = upper(:2))
			AND	(:3 IS NULL OR	ta.value_text = :3)
			AND	ta.value_date between to_date(:4,'$SQLSTMT_DEFAULTDATEFORMAT')
			AND 	to_date(:5,'$SQLSTMT_DEFAULTDATEFORMAT')
			AND	EXISTS
				(SELECT 1 FROM org where org_internal_id = t.receiver_id AND owner_org_id = :6)
			AND	provider_id is not null
			ORDER BY 1,3,5,6
		}
	},

	'sel_financial_monthly' =>
	{
		sqlStmt =>
		qq
		{
				SELECT  to_char(invoice_date,'MONTH') as invoice_month,
					SUM(total_charges) as total_charges,
					SUM(misc_charges) as misc_charges,
					SUM(person_write_off) as person_write_off,
					SUM(insurance_write_off)as insurance_write_off,
					SUM(total_charges+misc_charges-person_write_off-insurance_write_off) as net_charge,
					SUM(balance_transfer) as balance_transfer,
					SUM(person_pay) as person_pay,
					SUM(insurance_pay) as insurance_pay,
					SUM(refund) as refund,
					SUM(person_pay+insurance_pay+refund) as net_rcpts,
					SUM(total_charges+misc_charges-person_write_off-insurance_write_off +
					    balance_transfer -
					    (person_pay+insurance_pay+refund)
					    ) as a_r,
					to_char(invoice_date,'YYYY') as invoice_year
				FROM 	invoice_charges,org o
				WHERE   invoice_date between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
				AND to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
				AND (facility = :3 OR :3 is NULL)
				AND (provider =:4 OR :4 is NULL)
				AND o.org_internal_id = invoice_charges.facility
				AND o.owner_org_id = :5
				GROUP BY to_char(invoice_date,'YYYY'),to_char(invoice_date,'MONTH'),to_char(invoice_date,'MM')
				ORDER BY 13, to_char(invoice_date,'MM')
		},
		sqlStmtBindParamDescr => ['To From Date, Org Insurance ID, Doc Id '],
		publishDefn =>
			{
			columnDefn =>
			[
			{colIdx => 12, head =>'Year',groupBy=>'#12#', dAlign => 'left',},
			{colIdx => 0, head => 'Month', dAlign => 'left',},
			{colIdx => 1, head => 'Chrgs', dAlign => 'left',summarize => 'sum',dformat => 'currency' },
			{colIdx => 2, head => 'Misc Chrgs',dAlign =>'left' , hAlign =>'left',summarize => 'sum',dformat => 'currency' },
			{colIdx => 3, head => 'Chrg Adj', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
			{colIdx => 4, head => 'Ins W/O', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
			{colIdx => 5, head => 'Net Chrgs', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
			{colIdx => 6, head => 'Bal Trans', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
			{colIdx => 7, head => 'Per Rcpts',dAlign => 'center',summarize => 'sum',dformat => 'currency' },
			{colIdx => 8, head => 'Ins Rcpts', dAlign => 'center',summarize => 'sum',dformat => 'currency' },
			{colIdx => 9, head => 'Rcpt Adj', dAlign => 'center',summarize => 'sum',dformat => 'currency'},
			{colIdx => 10,head => 'Net Rcpts', summarize => 'sum',  dformat => 'currency' },
			{colIdx => 11,head => 'A/R', summarize => 'sum',  dformat => 'currency' },
			],
			},

	},
	'sel_aged_insurance' =>
	{
		sqlStmt =>
		qq
		{
			SELECT 	bill_to_id as insurance_ID , count (distinct(invoice_id)),
				sum(balance_0),
				sum(balance_31),
				sum(balance_61),
				sum(balance_91),
				sum(balance_121),
				sum(balance_151),
				sum(total_pending)
			FROM	agedpayments a,org
			WHERE	(a.bill_plain = :1 or :1 is NULL)
			AND	a.bill_party_type  in (2,3)
			AND	a.bill_plain = org.org_internal_id
			AND	org.owner_org_id = :2
			AND 	(:3 IS NULL OR care_provider_id = :3) 
			AND	(:4 IS NULL OR service_facility_id = :4)
			AND 	a.invoice_status <> 15
			AND	entire_invoice_balance <> 0
			GROUP BY bill_to_id
			--having sum(total_pending) <> 0
		},
		sqlStmtBindParamDescr => ['Org Insurance ID'],
		publishDefn =>
			{
			reportTitle => 'Aged Insurance Receivables',
			columnDefn =>
				[
#				{ colIdx => 0, head => 'Insurance', dataFmt => '<A HREF = "/org/#0#/account">#0#</A>' },
				{ colIdx => 0, tDataFmt => '&{count:0} Insurances',head => 'Insurance', dataFmt => '#0#',  url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=insurance&ins_org_id=#&{?}#')} },
				{ colIdx => 1, head => 'Total Invoices', tAlign=>'center', summarize=>'sum',,dataFmt => '#1#',dAlign =>'center' },
				{ colIdx => 2, head => '0 - 30', summarize=>'sum',dataFmt => '#2#', dformat => 'currency' },
				{ colIdx => 3, head => '31 - 60',summarize=>'sum', dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '61 - 90',summarize=>'sum', dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '91 - 120',summarize=>'sum', dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '121 - 150',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '151+',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => 'Total Pending',summarize=>'sum', dataFmt => '#8#', dAlign => 'center', dformat => 'currency' },
				],
			},

	},


	'sel_aged_insurance_detail' =>
	{
		sqlStmt => 		
		qq
		{
			SELECT
				a.invoice_id,
				sum(a.item_count),
				a.invoice_date,
				ist.caption,
				a.person_id,
				a.bill_to_id,
				sum(nvl(a.extended_cost,0)),
				sum(nvl(a.total_adjust,0)),
				sum(nvl(a.balance,0))
			FROM	agedpayments a, org ,	invoice_status ist
			WHERE	(a.bill_to_id = :1 or :1 is NULL)
			AND 	(invoice_item_id is NULL  or item_type in (3) )
			AND	bill_party_type in (2,3)
			AND 	a.balance <> 0		
			AND 	ist.id = a.invoice_status
			AND	a.bill_plain = org.org_internal_id
			AND	org.owner_org_id = :2
			AND 	(:3 IS NULL OR care_provider_id = :3)
			AND	(:4 IS NULL OR service_facility_id = :4)
			AND	a.invoice_status <> 15
			GROUP BY a.invoice_id,a.invoice_date,a.bill_to_id,ist.caption, a.person_id
			having sum(balance)<> 0			
		},		
		publishDefn =>
			{
				columnDefn =>
				[
				{ colIdx => 0, head => 'ID',tDataFmt => '&{count:0}', dataFmt => '<A HREF = "/invoice/#0#/summary">#0#</A>' },
				{ colIdx => 1, head => 'IC', tAlign=>'center', ,dataFmt => '#1#',dAlign =>'center' },
				{ colIdx => 2, head => 'Svc Date', dataFmt => '#2#' },
				{ colIdx => 3, head => 'Status', dataFmt => '#3#'},
				{ colIdx => 4, head => 'Client', dataFmt => '#4#' },
				{ colIdx => 5, head => 'Payer', dataFmt => '#5#' },
				{ colIdx => 6, head => 'Charges',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => 'Adjust',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => 'Balance',summarize=>'sum', dataFmt => '#8#', dformat => 'currency' },
				],
			},
	},

	'sel_aged_insurance_org' =>
	{
		sqlStmt => $STMTMGR_AGED_INSURANCE_ORG_PROV,

		whereClause => 'and t.service_facility_id = :3',

		publishDefn =>
			{
			columnDefn =>
				[
#				{ colIdx => 0, head => 'Insurance', dataFmt => '<A HREF = "/org/#0#/account">#0#</A>' },
				{ colIdx => 0, head => 'Insurance', dataFmt => '#0#',  url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=insurance&ins_org_id=#&{?}#')} },
				{ colIdx => 1, head => 'Total Invoices', tAlign=>'center', summarize=>'sum',,dataFmt => '#1#',dAlign =>'center' },
				{ colIdx => 2, head => '0 - 30', summarize=>'sum',dataFmt => '#2#', dformat => 'currency' },
				{ colIdx => 3, head => '31 - 60',summarize=>'sum', dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '61 - 90',summarize=>'sum', dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '91 - 120',summarize=>'sum', dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '121 - 150',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '151+',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => 'Total Pending',summarize=>'sum', dataFmt => '#8#', dAlign => 'center', dformat => 'currency' },
				],
			},
	},

	'sel_aged_insurance_prov_org' =>
	{
		sqlStmt => $STMTMGR_AGED_INSURANCE_ORG_PROV,

		whereClause => 'and t.care_provider_id = :3 and t.service_facility_id = :4',

		publishDefn =>
			{
			columnDefn =>
				[
#				{ colIdx => 0, head => 'Insurance', dataFmt => '<A HREF = "/org/#0#/account">#0#</A>' },
				{ colIdx => 0,tDataFmt => '&{count:0} Insurances', head => 'Insurance', dataFmt => '#0#',  url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=insurance&ins_org_id=#&{?}#')} },
				{ colIdx => 1, head => 'Total Invoices', tAlign=>'center', summarize=>'sum',,dataFmt => '#1#',dAlign =>'center' },
				{ colIdx => 2, head => '0 - 30', summarize=>'sum',dataFmt => '#2#', dformat => 'currency' },
				{ colIdx => 3, head => '31 - 60',summarize=>'sum', dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '61 - 90',summarize=>'sum', dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '91 - 120',summarize=>'sum', dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '121 - 150',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '151+',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => 'Total Pending',summarize=>'sum', dataFmt => '#8#', dAlign => 'center', dformat => 'currency' },
				],
			},
	},

	'sel_aged_all' =>
	{
		sqlStmt =>
		qq
		{
			SELECT
				p.simple_name person_name,
				a.person_id person_ID,
				count(distinct invoice_id),
				sum(balance_0),
				sum(balance_31),
				sum(balance_61),
				sum(balance_91),
				sum(balance_121),
				sum(balance_151),
				sum(decode(item_type,3,total_pending,0)),
				--a.bill_party_type  in (2,3)
				sum(decode(a.bill_party_type,2,total_pending,3,total_pending,0))
			FROM	agedpayments a, person p,person_org_category poc
			WHERE	(a.person_id = :1 or :1 is NULL)
			AND 	(invoice_item_id is NULL  or item_type in (3) )
			--AND	bill_party_type in (0,1)
			AND	entire_invoice_balance <> 0
			AND 	p.person_id = a.person_id			
			AND	a.person_id = poc.person_id
			AND	poc.org_internal_id  = :2
			AND	a.invoice_status <> 15
			AND 	(:3 IS NULL OR care_provider_id = :3)
			AND	(:4 IS NULL OR service_facility_id = :4)	
			GROUP BY a.person_id, p.simple_name
			having sum(total_pending)> 0
		},
		sqlStmtBindParamDescr => ['Org Insurance ID'],
		publishDefn =>
			{
			reportTitle => 'Aged Patient Receivables',
			columnDefn =>
				[
				{ colIdx => 0,dAlign=>'left',tAlign=>'left', tDataFmt => '&{count:0} Patients',hint=>"View Detail Data for : #1#", hAlign=>'left',head => 'Patient Name', dataFmt => '#0#',
				url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=aged_data&patient_id=#1#')}},
				{ colIdx => 1, hAlign=>'left', head => 'Patient ID', dataFmt => '#1#',   },
				{ colIdx => 2, head => 'Total Invoices',tAlign=>'center', summarize=>'sum',dataFmt => '#2#',dAlign =>'center' },
				{ colIdx => 3, head => '0 - 30',summarize=>'sum', dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '31 - 60', summarize=>'sum',dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '61 - 90', summarize=>'sum',dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '91 - 120',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '121 - 150',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => '151+', summarize=>'sum',dataFmt => '#8#', dformat => 'currency' },
				{ colIdx => 9, head => 'Co-Pay Owed', summarize=>'sum',dataFmt => '#9#', dformat => 'currency' },
				{ colIdx => 10, head => 'Pending Insurance', summarize=>'sum',dataFmt => '#10#', dAlign => 'center', dformat => 'currency' },
				],
			},	
	},

	'sel_aged_patient' =>
	{
		sqlStmt =>
		qq
		{
			SELECT
				p.simple_name person_name,
				a.person_id person_ID,
				count(distinct invoice_id),
				sum(balance_0),
				sum(balance_31),
				sum(balance_61),
				sum(balance_91),
				sum(balance_121),
				sum(balance_151),
				sum(decode(item_type,3,total_pending,0)),
				sum(total_pending)
			FROM	agedpayments a, person p,person_org_category poc
			WHERE	(a.person_id = :1 or :1 is NULL)
			AND 	(invoice_item_id is NULL  or item_type in (3) )
			AND	bill_party_type in (0,1)
			AND	entire_invoice_balance <> 0
			AND 	p.person_id = a.person_id			
			AND	a.person_id = poc.person_id
			AND	poc.org_internal_id  = :2
			AND	a.invoice_status <> 15
			AND 	(:3 IS NULL OR care_provider_id = :3)
			AND	(:4 IS NULL OR service_facility_id = :4)	
			GROUP BY a.person_id, p.simple_name
			having sum(total_pending)> 0
		},
		sqlStmtBindParamDescr => ['Org Insurance ID'],
		publishDefn =>
			{
			reportTitle => 'Aged Patient Receivables',
			columnDefn =>
				[
				{ colIdx => 0,hint=>"View Detail Data for : #1#", hAlign=>'left',head => 'Patient Name', tDataFmt => '&{count:0} Patients', dataFmt => '#0#',
				url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=aged_patient&patient_id=#1#')}},
				{ colIdx => 1, hAlign=>'left', head => 'Patient ID', dataFmt => '#1#',   },
				{ colIdx => 2, head => 'Total Invoices',tAlign=>'center', summarize=>'sum',dataFmt => '#2#',dAlign =>'center' },
				{ colIdx => 3, head => '0 - 30',summarize=>'sum', dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '31 - 60', summarize=>'sum',dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '61 - 90', summarize=>'sum',dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '91 - 120',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '121 - 150',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => '151+', summarize=>'sum',dataFmt => '#8#', dformat => 'currency' },
				{ colIdx => 9, head => 'Co-Pay Owed', summarize=>'sum',dataFmt => '#9#', dformat => 'currency' },
				{ colIdx => 10, head => 'Total Pending', summarize=>'sum',dataFmt => '#10#', dAlign => 'center', dformat => 'currency' },
				],
			},
	},

	'sel_aged_patient_detail' =>
	{
		sqlStmt =>
		qq
		{
			SELECT
				a.invoice_id,
				sum(a.item_count),
				a.invoice_date,
				ist.caption,
				a.bill_to_id,
				sum(nvl(a.extended_cost,0)),
				sum(nvl(a.total_adjust,0)),
				sum(nvl(a.balance,0))
			FROM	agedpayments a, person p,
				invoice_status ist ,person_org_category poc				
			WHERE	(a.person_id = :1 or :1 is NULL)
			AND 	(invoice_item_id is NULL  or item_type in (3) )
			AND	bill_party_type in (0,1)
			AND 	a.balance <> 0
			AND 	p.person_id = a.person_id			
			AND 	ist.id = a.invoice_status
			AND	a.person_id = poc.person_id
			AND	poc.org_internal_id  = :2
			AND 	(:3 IS NULL OR care_provider_id = :3)
			AND	(:4 IS NULL OR service_facility_id = :4)
			AND	a.invoice_status <> 15
			GROUP BY a.invoice_id,a.invoice_date,a.bill_to_id,ist.caption
			having sum(balance)<> 0
		},
		sqlStmtBindParamDescr => ['Org Insurance ID'],
		publishDefn =>
			{
			reportTitle => 'Aged Patient Receivables',
			columnDefn =>
			[
				{ head => 'ID', summarize=>'count',url => '/invoice/#&{?}#/summary', hint => "Created on: #14#",dAlign => 'RIGHT'},
				{ head => 'IC', hint => 'Number Of Items In Claim',dAlign => 'CENTER'},
				{ head => 'Invoice Date'},
				{ head => 'Status',# dataFmt => {
							#			'0' => '#3#',
							#			'1' => '#3#',
							#			'2' => '#3#',
							#			'3' => '#3#',
							#			'4' => '#3#',
							#			'5' => '#3#',
							#			'6' => '#3#',
							#			'7' => '#3#',
							#			'8' => '#3#',
							#			'9' => '#3#',
							#			'10' => '#3#',
							#			'11' => '#3#',
							#			'12' => '#3#',
							#			'13' => '#3#',
							#			'14' => '#3#',
							#			'15' => '#3#',
							#			'16' => 'Void #13#'
							#		},
				},
				{ head => 'Payer', },
				{ head => 'Charges', summarize => 'sum', dformat => 'currency'},
				{ head => 'Adjust', summarize => 'sum', dformat => 'currency'},
				{ head => 'Balance', summarize => 'sum', dformat => 'currency'},

			],
			},
	},




	'sel_aged_data_detail' =>
	{
		sqlStmt =>
		qq
		{
			SELECT
				a.invoice_id,
				sum(a.item_count),
				a.invoice_date,
				ist.caption,
				a.bill_to_id,
				sum(nvl(a.extended_cost,0)),
				sum(nvl(a.total_adjust,0)),
				sum(nvl(a.balance,0))
			FROM	agedpayments a, person p,
				invoice_status ist ,person_org_category poc				
			WHERE	(a.person_id = :1 or :1 is NULL)
			AND 	(invoice_item_id is NULL  or item_type in (3) )
			AND 	a.balance <> 0
			AND 	p.person_id = a.person_id			
			AND 	ist.id = a.invoice_status
			AND	a.person_id = poc.person_id
			AND	poc.org_internal_id  = :2
			AND 	(:3 IS NULL OR care_provider_id = :3)
			AND	(:4 IS NULL OR service_facility_id = :4)
			AND	a.invoice_status <> 15
			GROUP BY a.invoice_id,a.invoice_date,a.bill_to_id,ist.caption
			having sum(balance)<> 0						
		},
		sqlStmtBindParamDescr => ['Org Insurance ID'],
		publishDefn =>
			{
			reportTitle => 'Aged Patient Receivables',
			columnDefn =>
			[
				{ head => 'ID', summarize=>'count',url => '/invoice/#&{?}#/summary', hint => "Created on: #14#",dAlign => 'RIGHT'},
				{ head => 'IC', hint => 'Number Of Items In Claim',dAlign => 'CENTER'},
				{ head => 'Invoice Date'},
				{ head => 'Status',# dataFmt => {
							#			'0' => '#3#',
							#			'1' => '#3#',
							#			'2' => '#3#',
							#			'3' => '#3#',
							#			'4' => '#3#',
							#			'5' => '#3#',
							#			'6' => '#3#',
							#			'7' => '#3#',
							#			'8' => '#3#',
							#			'9' => '#3#',
							#			'10' => '#3#',
							#			'11' => '#3#',
							#			'12' => '#3#',
							#			'13' => '#3#',
							#			'14' => '#3#',
							#			'15' => '#3#',
							#			'16' => 'Void #13#'
							#		},
				},
				{ head => 'Payer', },
				{ head => 'Charges', summarize => 'sum', dformat => 'currency'},
				{ head => 'Adjust', summarize => 'sum', dformat => 'currency'},
				{ head => 'Balance', summarize => 'sum', dformat => 'currency'},

			],
			},
	},

	'sel_aged_patient_prov' =>
	{
		sqlStmt => $STMTMGR_AGED_PATIENT_ORG_PROV,

		whereClause => 'and t.care_provider_id = :3',

		publishDefn =>
			{
			columnDefn =>
				[
				{ colIdx => 0, head => 'Patient Name', dataFmt => '#0#' },
				{ colIdx => 1, head => 'Patient ID', dataFmt => '#1#',  url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=aged_patient&patient_id=#&{?}#')} },
				{ colIdx => 2, head => 'Total Invoices',tAlign=>'center', summarize=>'sum',dataFmt => '#2#',dAlign =>'center' },
				{ colIdx => 3, head => '0 - 30',summarize=>'sum', dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '31 - 60', summarize=>'sum',dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '61 - 90', summarize=>'sum',dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '91 - 120',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '121 - 150',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => '151+', summarize=>'sum',dataFmt => '#8#', dformat => 'currency' },
				{ colIdx => 9, head => 'Co-Pay Owed', summarize=>'sum',dataFmt => '#9#', dformat => 'currency' },
				{ colIdx => 10, head => 'Total Pending', summarize=>'sum',dataFmt => '#10#', dAlign => 'center', dformat => 'currency' },
				],
			},
	},

	'sel_aged_patient_org' =>
	{
		sqlStmt => $STMTMGR_AGED_PATIENT_ORG_PROV,

		whereClause => 'and t.service_facility_id = :3',

		publishDefn =>
			{
			columnDefn =>
				[
				{ colIdx => 0, head => 'Patient Name', dataFmt => '#0#'},
				{ colIdx => 1, head => 'Patient ID', dataFmt => '#1#',  url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=aged_patient&patient_id=#&{?}#')} },
				{ colIdx => 2, head => 'Total Invoices',tAlign=>'center', summarize=>'sum',dataFmt => '#2#',dAlign =>'center' },
				{ colIdx => 3, head => '0 - 30',summarize=>'sum', dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '31 - 60', summarize=>'sum',dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '61 - 90', summarize=>'sum',dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '91 - 120',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '121 - 150',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => '151+', summarize=>'sum',dataFmt => '#8#', dformat => 'currency' },
				{ colIdx => 9, head => 'Co-Pay Owed', summarize=>'sum',dataFmt => '#9#', dformat => 'currency' },
				{ colIdx => 10, head => 'Total Pending', summarize=>'sum',dataFmt => '#10#', dAlign => 'center', dformat => 'currency' },
				],
			},
	},

	'sel_aged_patient_prov_org' =>
	{
		sqlStmt => $STMTMGR_AGED_PATIENT_ORG_PROV,

		whereClause => 'and t.care_provider_id = :3 and t.service_facility_id = :4',

		publishDefn =>
			{
			columnDefn =>
				[
				{ colIdx => 0, head => 'Patient Name', dataFmt => '#0#'},
				{ colIdx => 1, head => 'Patient ID', dataFmt => '#1#',  url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=aged_patient&patient_id=#&{?}#')} },
				{ colIdx => 2, head => 'Total Invoices',tAlign=>'center', summarize=>'sum',dataFmt => '#2#',dAlign =>'center' },
				{ colIdx => 3, head => '0 - 30',summarize=>'sum', dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '31 - 60', summarize=>'sum',dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '61 - 90', summarize=>'sum',dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '91 - 120',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '121 - 150',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => '151+', summarize=>'sum',dataFmt => '#8#', dformat => 'currency' },
				{ colIdx => 9, head => 'Co-Pay Owed', summarize=>'sum',dataFmt => '#9#', dformat => 'currency' },
				{ colIdx => 10, head => 'Total Pending', summarize=>'sum',dataFmt => '#10#', dAlign => 'center', dformat => 'currency' },
				],
			},
	},

	'selGetVisit' =>qq
	{
		SELECT 	sum (decode(t.trans_type ,2000,1,2010,1,2040,1,2050,1,2060,1,2070,1,2080,1,2090,1,2100,1,2120,1,2130,1,2160,1,2170,1,2180,1,0))
			as office_visit,
			sum (decode(t.trans_type,2020,1,0)) as hospital_visit
		FROM	transaction t, invoice i, invoice_attribute ia,org o
		WHERE	i.main_transaction = t.trans_id
		AND	ia.parent_id = i.invoice_id
		AND	ia.item_name = 'Invoice/Creation/Batch ID'
		AND	(invoice_status !=15 or parent_invoice_id is null)
		AND 	o.org_internal_id = t.service_facility_id
		AND	ia.value_date between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
                AND 	to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
                AND 	(:3 is NULL OR t.service_facility_id = :3 )
		AND	t.provider_id = :4
                AND 	(ia.value_text >= :5 OR :5 is NULL)
                AND 	(ia.value_text <= :6 OR :6 is NULL)
		AND 	o.owner_org_id = :7
	},
	'sel_revenue_collection' => qq{
        SELECT  provider,
                sum(nvl(ffs_prof,0)+nvl(misc_charges,0)) as ffs_prof,
                sum(nvl(x_ray,0)) as x_ray,
                sum(nvl(lab,0)) as lab,
                sum(nvl(cap_ffs_prof,0)) as cap_ffs_prof,
                sum(nvl(cap_x_ray,0)) as cap_x_ray,
                sum(nvl(cap_lab,0)) as cap_lab,
                sum(nvl(ffs_pmt,0)+nvl(ancill_pmt,0)) as ffs_pmt,
                sum(nvl(cap_pmt,0)++ nvl(cap_month,0)) as cap_pmt,
                sum(nvl(ancill_pmt,0) + nvl(lab_pmt,0) + nvl(x_ray_pmt,0) ) as ancill_pmt,
                sum(nvl(refund,0)) as refund,
                sum(nvl(prof_pmt,0)+ nvl(cap_month,0)) as prof_pmt
        FROM 	revenue_collection rc,org o
        WHERE   invoice_date between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
                AND to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
                AND (facility = :3 OR :3 is NULL)
                AND ( (provider =:4 AND provider is not null )OR :4 is NULL)
                AND (batch_id >= :5 OR :5 is NULL)
                AND (batch_id <= :6 OR :6 is NULL)
		AND o.org_internal_id = rc.facility
		AND o.owner_org_id = :7
        GROUP by provider
        },

	'sel_daily_audit_detail' => qq{
	SELECT	invoice_charges.invoice_id ,
		invoice_charges.invoice_date as invoice_batch_date,
		invoice_charges.service_begin_date,
		invoice_charges.service_end_date,
		invoice_charges.provider as care_provider_id ,
		invoice_charges.client_id as patient_id,
		invoice_charges.code,
		invoice_charges.caption,
		invoice_charges.rel_diags,
		decode(item_type,7,0,units) as units,
		decode(item_type,7,0,unit_cost) as unit_cost,
		(invoice_charges.total_charges) total_charges,
		(invoice_charges.misc_charges) misc_charges ,
		(invoice_charges.person_pay) person_pay,
		(invoice_charges.insurance_pay) insurance_pay,
		(invoice_charges.insurance_write_off) insurance_write_off,
		(invoice_charges.balance_transfer) balance_transfer,
		(invoice_charges.charge_adjust) as  charge_adjust,
		(invoice_charges.person_write_off) as person_write_off,
		(invoice_charges.refund) as refund,
		pm.caption as pay_type ,
		p.simple_name simple_name
	FROM	invoice_charges,org o, person p, payment_method pm
	WHERE 	invoice_date = to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
		AND (facility = :2 or :2 IS NULL )
		AND (provider = :3 or :3 IS NULL)
		AND pm.id (+)= invoice_charges.pay_type
		AND
		(
			(batch_id >= :4 or :4 is NULL)
			AND
			(batch_id <= :5  or :5 is NULL)
		)
		AND o.org_internal_id = invoice_charges.facility
		AND o.owner_org_id = :6
		AND client_id = p.person_id
	order by invoice_id
	},
	'sel_daily_audit' => qq{
	SELECT	to_char(invoice_date,'$SQLSTMT_DEFAULTDATEFORMAT') invoice_date ,
		sum(total_charges) as total_charges ,
		sum(misc_charges) misc_charges,
		sum(charge_adjust) charge_adjust,
		sum(insurance_write_off) insurance_write_off,
		sum(balance_transfer) balance_transfer,
		sum(person_pay) person_pay,
		sum(insurance_pay) insurance_pay ,
		sum(person_write_off) person_write_off,
		sum(refund) as refund
	FROM 	invoice_charges,org o
	WHERE   invoice_date between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
		AND to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
		AND (facility = :3 OR :3 is NULL)
		AND (provider =:4 OR :4 is NULL)
		AND (batch_id >= :5 OR :5 is NULL)
		AND (batch_id <= :6 OR :6 is NULL)
		AND o.org_internal_id = invoice_charges.facility
		AND o.owner_org_id = :7
	group by invoice_date
},


	'sel_monthly_audit' => qq{
	SELECT	to_char(invoice_date,'MM/YYYY') invoice_date ,
		sum(total_charges) as total_charges ,
		sum(misc_charges) misc_charges,
		sum(charge_adjust) charge_adjust,
		sum(insurance_write_off) insurance_write_off,
		sum(balance_transfer) balance_transfer,
		sum(person_pay) person_pay,
		sum(insurance_pay) insurance_pay ,
		sum(person_write_off) person_write_off,
		sum(refund) as refund
	FROM 	invoice_charges,org o
	WHERE   invoice_date between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
		AND to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
		AND (facility = :3 OR :3 is NULL)
		AND (provider =:4 OR :4 is NULL)
		AND (batch_id >= :5 OR :5 is NULL)
		AND (batch_id <= :6 OR :6 is NULL)
		AND o.org_internal_id = invoice_charges.facility
		AND o.owner_org_id = :7

	group by to_char(invoice_date,'MM/YYYY')
	order by invoice_date asc},

	'sel_monthly_audit_newpatient_count' => qq{
	SELECT
				count(at.caption) as count, to_char(e.start_time,'MM/YYYY') start_time
	FROM 		Appt_Attendee_Type at, Event e, Event_Attribute ea, org o
	WHERE 	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
	AND      e.facility_id = o.org_internal_id
	AND      o.org_internal_id = :3
	AND  		e.event_id = ea.parent_id
	AND      e.start_time between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
	AND      to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
	AND      at.id = ea.value_int
	AND      at.caption = 'New Patient'
	GROUP BY to_char(start_time,'MM/YYYY')
	ORDER BY start_time asc
	},


	'sel_monthly_audit_estpatient_count' => qq{
		SELECT
					count(at.caption) as count, to_char(e.start_time,'MM/YYYY') start_time
		FROM 		Appt_Attendee_Type at, Event e, Event_Attribute ea, org o
		WHERE 	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
		AND      e.facility_id = o.org_internal_id
		AND      o.org_internal_id = :3
		AND  		e.event_id = ea.parent_id
		AND      e.start_time between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
		AND      to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
		AND      at.id = ea.value_int
		AND      at.caption = 'Established Patient'
		GROUP BY to_char(start_time,'MM/YYYY')
		ORDER BY start_time asc
	},

	'sel_monthly_audit_detail' => qq{
	SELECT	invoice_charges.invoice_id ,
		to_char(invoice_date,'MM/DD/YY') as invoice_batch_date,
		invoice_charges.service_begin_date,
		invoice_charges.service_end_date,
		invoice_charges.provider as care_provider_id ,
		invoice_charges.client_id as patient_id,
		invoice_charges.code,
		invoice_charges.caption,
		invoice_charges.rel_diags,
		decode(item_type,7,0,units) as units,
		decode(item_type,7,0,unit_cost) as unit_cost,
		(total_charges) total_charges,
		(misc_charges) misc_charges ,
		(person_pay) person_pay,
		(insurance_pay) insurance_pay,
		(insurance_write_off) insurance_write_off,
		(balance_transfer) balance_transfer,
		(charge_adjust) as  charge_adjust,
		(person_write_off) as person_write_off,
		(refund) as refund,
		pm.caption as pay_type ,
		p.simple_name
	FROM 	invoice_charges, org o, person p,payment_method pm
	WHERE 	to_char(invoice_date,'MM/YYYY') = :1
	AND	invoice_date between to_date(:7,'$SQLSTMT_DEFAULTDATEFORMAT')
	AND 	to_date(:8,'$SQLSTMT_DEFAULTDATEFORMAT')
	AND 	(facility = :2 or :2 IS NULL )
	AND 	pm.id (+)= invoice_charges.pay_type
	AND 	(provider = :3 or :3 IS NULL)
	AND
		(
			(batch_id >= :4 or :4 is NULL)
			AND
			(batch_id <= :5  or :5 is NULL)
		)
	AND 	o.org_internal_id = invoice_charges.facility
	AND 	o.owner_org_id = :6
	AND 	client_id = p.person_id
	ORDER BY  invoice_date asc
	},


	'selChildernOrgs' =>qq{
		SELECT	org_internal_id,org_id
		FROM	org
		WHERE	owner_org_id = :1
		AND	( (parent_org_id = :2 AND :3 = 1) OR org_internal_id = :2 OR :2 IS NULL)
		AND	upper(category) IN ('PRACTICE', 'CLINIC','FACILITY/SITE','DIAGNOSTIC SERVICES', 'DEPARTMENT', 'HOSPITAL', 'THERAPEUTIC SERVICES')
		ORDER BY org_id
	},

	'sel_patient_superbill_info' =>
	{
		sqlStmt => qq
		{
			select DISTINCT TO_CHAR(thePatientAppt.start_time -:2 , 'MM/DD/YY') AS startDate,
				TO_CHAR(thePatientAppt.start_time - :2, 'HH24:MI') AS startTime,
				thePatient.short_name AS patientname,
				thePatientAppt.subject AS reason,
				theDoctor.person_id AS doctorID,
				theDoctor.short_name AS doctorName,
				theApptOrg.name_primary as location,
				TO_CHAR(thePatient.date_of_birth, 'MM/DD/YY') AS dob,
				thePatient.person_id AS patientNo,
				thePatient.person_id AS respParty,
				thePatient.gender AS sex,
				thePatientAddr.line1 AS patientAddress,
				thePatientAddr.city,
				thePatientAddr.state,
				thePatientAddr.zip
			FROM
				Person thePatient,
				Person theDoctor,
				Person_Address thePatientAddr,
				Person_Address theDoctorAddr,
				Org theApptOrg,
				Event_Attribute theAppointmentAttr,
				Event thePatientAppt
			WHERE
				thePatientAppt.start_time >= TO_DATE(:1, 'MM/DD/YYYY') + :2
				AND thePatientAppt.start_time < TO_DATE(:1, 'MM/DD/YYYY') + 1 + :2
				AND theAppointmentAttr.parent_id = thePatientAppt.event_id
				AND theAppointmentAttr.value_type = '333'
				AND theAppointmentAttr.value_text = thePatient.person_id
				AND theAppointmentAttr.value_textB = theDoctor.person_id
				AND thePatientAppt.owner_id = theApptOrg.org_internal_id
				AND thePatient.person_id = thePatientAddr.parent_id
				AND theDoctor.person_id = theDoctorAddr.parent_id
		},

		sqlStmtBindParamDescr => ['Date'],
		publishDefn =>
			{
			columnDefn =>
				[
				{ colIdx =>  0, head => 'Start Time', dataFmt => '#0# #1#' },
				{ colIdx =>  1, head => 'Patient', dataFmt => '#2#'},
				{ colIdx =>  2, head => 'Reason', dataFmt => '#3#'},
				{ colIdx =>  3, head => 'Dr #', dataFmt => '#4#', groupBy => '#4#'},
				{ colIdx =>  4, head => 'Doctor', dataFmt => '#5#'},
				{ colIdx =>  5, head => 'Location', dataFmt => '#6#'},
				{ colIdx =>  6, head => 'DOB', dataFmt => '#7#'},
				{ colIdx =>  7, head => 'Patient #', dataFmt => '#8#'},
				{ colIdx =>  8, head => 'Resp. Party', dataFmt => '#9#'},
				{ colIdx =>  9, head => 'Sex', dataFmt => '#10#'},
				{ colIdx => 10, head => 'Address', dataFmt => '#11#' },
				{ colIdx => 11, head => 'City/State', dataFmt => '#12#, #13#' },
				{ colIdx => 12, head => 'Zip', dataFmt => '#14#' },
				{ colIdx => 13, head => 'Over 90', dataFmt => '#15#'},
				{ colIdx => 14, head => 'Over 60', dataFmt => '#16#'},
				{ colIdx => 15, head => 'Over 30', dataFmt => '#17#'},
				{ colIdx => 16, head => 'Current', dataFmt => '#18#'},
				{ colIdx => 17, head => 'Total Due', dataFmt => '#19#'},
				{ colIdx => 18, head => 'Insurance Co.', dataFmt => '#20#'},
				{ colIdx => 19, head => 'Policy #', dataFmt => '#21#'},
				{ colIdx => 20, head => 'Relationship to Insured', dataFmt => '#22#'},
				],
			maxCols => '80',
			maxRows => '63',
#			mtbDebug => 'none',
			fieldDefn =>
				[
				# Date
				{ colIdx =>  0, col =>  1, row => 48, width => 10, align => 'LEFT' },
				# Time
				{ colIdx =>  1, col =>  1, row => 49, width => 10, align => 'LEFT' },
				# Patient
				{ colIdx =>  2, col => 12, row => 48, width => 18, align => 'LEFT' },
#				{ colIdx =>  2, col => 12, row => 49, width => 18, align => 'LEFT' },
				# Reason
				{ colIdx =>  3, col => 31, row => 48, width => 11, align => 'LEFT' },
#				{ colIdx =>  3, col => 31, row => 49, width => 11, align => 'LEFT' },
				# Ticket
				# Dr. #
				{ colIdx =>  4, col =>  7, row => 51, width =>  4, align => 'LEFT' },
				# Doctor
				{ colIdx =>  5, col => 12, row => 51, width => 10, align => 'LEFT' },
				# Location
				{ colIdx =>  6, col => 23, row => 51, width => 13, align => 'LEFT' },
				# D.O.B
				{ colIdx =>  7, col => 37, row => 51, width =>  8, align => 'LEFT' },
				# Patient No
				{ colIdx =>  8, col =>  1, row => 53, width =>  6, align => 'LEFT' },
				# Responsible Party
				{ colIdx =>  9, col =>  8, row => 53, width => 19, align => 'LEFT' },
				# Phone #
				# Referring Doctor
				# Sex
				{ colIdx => 10, col =>  3, row => 55, width =>  3, align => 'LEFT',
				  type => 'conditional',
				  data => {
				  	'1' => 'X  ',
				  	'2' => '  X',
				  	'3' => ' * ',
				  },
				},
				# Address
				{ colIdx => 11, col =>  7, row => 55, width => 13, align => 'LEFT' },
				# City
				{ colIdx => 12, col => 23, row => 55, width => 10, align => 'LEFT' },
				# State
				{ colIdx => 13, col => 34, row => 55, width =>  2, align => 'LEFT' },
				# Zip
				{ colIdx => 14, col => 37, row => 55, width =>  7, align => 'LEFT' },
				# Balance over 90 days overdue
				{ colIdx => 15, col =>  3, row => 57, width =>  5, align => 'LEFT' },
				# Balance over 60 days overdue
				{ colIdx => 16, col =>  9, row => 57, width =>  5, align => 'LEFT' },
				# Balance over 30 days overdue
				{ colIdx => 17, col => 15, row => 57, width =>  6, align => 'LEFT' },
				# Current balance
				{ colIdx => 18, col => 22, row => 57, width =>  4, align => 'LEFT' },
				# Total pending
				{ colIdx => 19, col => 27, row => 57, width =>  5, align => 'LEFT' },
				# Insurance Company
				{ colIdx => 20, col =>  1, row => 59, width =>  12, align => 'LEFT' },
#				{ colIdx => 20, col =>  1, row => 60, width =>  12, align => 'LEFT' },
#				{ colIdx => 20, col =>  1, row => 61, width =>  12, align => 'LEFT' },
#				{ colIdx => 20, col =>  1, row => 62, width =>  12, align => 'LEFT' },
				# Policy ID
				{ colIdx => 21, col => 18, row => 59, width =>  16, align => 'LEFT' },
#				{ colIdx => 21, col => 18, row => 60, width =>  16, align => 'LEFT' },
#				{ colIdx => 21, col => 18, row => 61, width =>  16, align => 'LEFT' },
#				{ colIdx => 21, col => 18, row => 62, width =>  16, align => 'LEFT' },
				# Relationship to Insured
				{ colIdx => 22, col => 35, row => 61, width =>   8, align => 'LEFT',
				  type => 'conditional',
				  data => {
				  	 '1' => 'X      ',
				  	 '2' => '  X    ',
				  	 '3' => '    X  ',
				  	 '4' => '    X  ',
				  	 '5' => '    X  ',
				  	 '6' => '    X  ',
				  	 '9' => '      X',
				  	'13' => '      X',
				  	'14' => '      X',
				  	'16' => '      X',
				  	'17' => '      X',
				  	'18' => '      X',
				  	'19' => '      X',
				  },
				},
				],
			},
	},


	'sel_patient_superbill_ins_info' =>
	{
		sqlStmt => qq
		{
			SELECT	DISTINCT
				thePatient.short_name,
				theOrganization.name_primary,
				theInsurance.member_number,
				NVL(theInsurance.rel_to_guarantor, 9)
			FROM	Org theOrganization,
				Insurance theInsurance,
				Person thePatient
			WHERE	theInsurance.ins_org_id = theOrganization.org_internal_id
			AND	theInsurance.owner_person_id = thePatient.person_id
			AND	thePatient.person_id = :1
		},
		sqlStmtBindParamDescr => ['Date'],
		publishDefn =>
			{
			columnDefn =>
				[
				{ colIdx => 0, head => 'Patient', dataFmt => '#0#'},
				{ colIdx => 1, head => 'Insurance Company', dataFmt => '#1#' },
				{ colIdx => 2, head => 'Policy ID', dataFmt => '#2#'},
				{ colIdx => 3, head => 'Relationship to Insured', dataFmt => '#3#' },
				],
			},
	},
);


1;

