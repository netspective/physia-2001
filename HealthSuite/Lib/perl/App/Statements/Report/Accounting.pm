##############################################################################
package App::Statements::Report::Accounting;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_REPORT_ACCOUNTING );
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_ACCOUNTING);

$STMTMGR_REPORT_ACCOUNTING = new App::Statements::Report::Accounting(
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
					SUM(person_pay+insurance_pay-refund) as net_rcpts,
					SUM(total_charges+misc_charges-person_write_off-insurance_write_off +
					    balance_transfer -
					    (person_pay+insurance_pay-refund)
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
			GROUP BY bill_to_id	
		},
		sqlStmtBindParamDescr => ['Org Insurance ID'],
		publishDefn => 
			{
			columnDefn => 
				[
				{ colIdx => 0, head => 'Insurance', dataFmt => '<A HREF = "/org/#0#/account">#0#</A>' },
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
	
	'sel_aged_patient' => 
	{
		sqlStmt => 
		qq
		{
			SELECT 	person_id person_ID , count (distinct (invoice_id)),
				sum(balance_0),
				sum(balance_31),
				sum(balance_61),
				sum(balance_91),
				sum(balance_121),			
				sum(balance_151),
				sum(decode(item_type,3,total_pending,0)),
				sum(total_pending)
			FROM	agedpayments a
			WHERE	(a.person_id = :1 or :1 is NULL)	
			AND 	(invoice_item_id is NULL  or item_type = 3)
			AND	bill_party_type in (0,1)
			AND	person_id IN
			(
			 SELECT person_id
			 FROM 	person_org_category
			 WHERE  org_internal_id = :2
			 )
			GROUP BY person_id
		},
		sqlStmtBindParamDescr => ['Org Insurance ID'],
		publishDefn => 
			{
			columnDefn => 
				[
				{ colIdx => 0, head => 'Patient ID', dataFmt => '<A HREF = "/person/#0#/account">#0#</A>' },
				{ colIdx => 1, head => 'Total Invoices',tAlign=>'center', summarize=>'sum',dataFmt => '#1#',dAlign =>'center' },
				{ colIdx => 2, head => '0 - 30',summarize=>'sum', dataFmt => '#2#', dformat => 'currency' },
				{ colIdx => 3, head => '31 - 60', summarize=>'sum',dataFmt => '#3#', dformat => 'currency' },
				{ colIdx => 4, head => '61 - 90', summarize=>'sum',dataFmt => '#4#', dformat => 'currency' },
				{ colIdx => 5, head => '91 - 120',summarize=>'sum', dataFmt => '#5#', dformat => 'currency' },
				{ colIdx => 6, head => '121 - 150',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
				{ colIdx => 7, head => '151+', summarize=>'sum',dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 8, head => 'Co-Pay Owed', summarize=>'sum',dataFmt => '#7#', dformat => 'currency' },
				{ colIdx => 9, head => 'Total Pending', summarize=>'sum',dataFmt => '#8#', dAlign => 'center', dformat => 'currency' },
				],
			},
	},
	
	
	'sel_revenue_collection' => qq{
        SELECT  provider,
                sum(nvl(ffs_prof,0)) as ffs_prof,
                sum(nvl(x_ray,0)) as x_ray,
                sum(nvl(lab,0)) as lab,
                sum(nvl(cap_ffs_prof,0)) as cap_ffs_prof,
                sum(nvl(cap_x_ray,0)) as cap_x_ray,
                sum(nvl(cap_lab,0)) as cap_lab,
                sum(nvl(ffs_pmt,0)) as ffs_pmt,
                sum(nvl(cap_pmt,0)) as cap_pmt,
                sum(nvl(ancill_pmt,0)) as ancill_pmt,
                MIN ( (SELECT COUNT (e.event_id)
                 FROM 	Event e, Event_Attribute ea 
                 WHERE 	ea.item_name = 'Appointment/Attendee/Physician'
                 AND	e.event_status=2 
                 AND	e.event_type = 100
                 AND	trunc(e.checkin_stamp) between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT') 
                 AND	to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')  
                 AND	ea.value_text = provider
                 AND    ea.parent_id = e.event_id 
                 ))as appt                
        FROM revenue_collection,org o
        WHERE   invoice_date between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
                AND to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
                AND (facility = :3 OR :3 is NULL)
                AND (provider =:4 OR :4 is NULL)
                AND (batch_id >= :5 OR :5 is NULL)
                AND (batch_id <= :6 OR :6 is NULL)
		AND o.org_internal_id = revenue_collection.facility
		AND o.owner_org_id = :7	                
        GROUP by provider
        },
	
	'sel_daily_audit_detail' => qq{
	SELECT	invoice_id ,
		invoice_date as invoice_batch_date, 		
		service_begin_date,
		service_end_date,
		provider as care_provider_id ,
		client_id as patient_id,
		code, 
		caption,
		rel_diags,
		decode(item_type,7,0,units) as units,
		decode(item_type,7,0,unit_cost) as unit_cost,		
		sum(total_charges) total_charges, 
		sum(misc_charges) misc_charges ,
		sum(person_pay) person_pay,
		sum(insurance_pay) insurance_pay,		
		sum(insurance_write_off) insurance_write_off,			
		sum(balance_transfer) balance_transfer,
		sum(charge_adjust) as  charge_adjust,
		sum(person_write_off) as person_write_off,
		pay_type
	FROM	invoice_charges,org o
	WHERE 	invoice_date = to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT') 								
		AND (facility = :2 or :2 IS NULL )
		AND (provider = :3 or :3 IS NULL)
		AND
		( 
			(batch_id >= :4 or :4 is NULL) 
			AND
			(batch_id <= :5  or :5 is NULL) 		
		)	
		AND o.org_internal_id = invoice_charges.facility
		AND o.owner_org_id = :6		
	group by invoice_id ,
		invoice_date, 		
		service_begin_date,
		service_end_date,
		provider ,
		code, 
		caption,
		decode(item_type,7,0,units) ,
		decode(item_type,7,0,unit_cost) ,		
		rel_diags,
		client_id,
		pay_type
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
		
	group by to_char(invoice_date,'MM/YYYY') },

	'sel_monthly_audit_detail' => qq{
	SELECT	invoice_id ,
		to_char(invoice_date,'MM/YYYY') as invoice_batch_date, 		
		service_begin_date,
		service_end_date,
		provider as care_provider_id ,
		client_id as patient_id,
		code, 
		caption,
		rel_diags,
		decode(item_type,7,0,units) as units,
		decode(item_type,7,0,unit_cost) as unit_cost,		
		sum(total_charges) total_charges, 
		sum(misc_charges) misc_charges ,
		sum(person_pay) person_pay,
		sum(insurance_pay) insurance_pay,		
		sum(insurance_write_off) insurance_write_off,			
		sum(balance_transfer) balance_transfer,
		sum(charge_adjust) as  charge_adjust
	FROM 	invoice_charges, org o
	WHERE 	to_char(invoice_date,'MM/YYYY') = :1								
		AND (facility = :2 or :2 IS NULL )
		AND (provider = :3 or :3 IS NULL)
		AND
		( 
			(batch_id >= :4 or :4 is NULL) 
			AND
			(batch_id <= :5  or :5 is NULL) 		
		)	
		AND o.org_internal_id = invoice_charges.facility
		AND o.owner_org_id = :6
	group by invoice_id ,
		to_char(invoice_date,'MM/YYYY') ,		
		service_begin_date,
		service_end_date,
		provider ,
		code, 
		caption,
		decode(item_type,7,0,units) ,
		decode(item_type,7,0,unit_cost) ,		
		rel_diags,
		client_id
	},
		
	
);


1;

