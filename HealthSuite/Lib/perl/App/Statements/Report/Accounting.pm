##############################################################################
package App::Statements::Report::Accounting;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_REPORT_ACCOUNTING $STMTFMT_SEL_RECEIPT_ANALYSIS $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_ACCOUNTING );

$STMTFMT_SEL_RECEIPT_ANALYSIS = qq{ 
			select 	y.NAME,
				y.CATEGORY_NAME,
				y.TRANSACTION_TYPE,
				y.POLICYNAME,
				sum(DECODE(trunc(m.PAYDATE,'MM'), trunc(to_date(?,'MM/DD/YYYY'),'MM'), NVL(m.PERSONALMONTHAMOUNT, 0) + NVL(m.INSURANCEMONTHAMOUNT, 0),0))  as MONTHAMOUNT,
				sum(NVL(y.PERSONALYEARAMOUNT, 0) + NVL(y.INSURANCEYEARAMOUNT, 0)) as YEARAMOUNT
			from 	monthToDateReceiptAnalysis m, yearToDateReceiptAnalysis y
			where	m.PROVIDERID(+) = y.PROVIDERID
			and	m.CATEGORY_NAME(+) = y.CATEGORY_NAME
			and	m.TRANSACTION_TYPE(+) = y.TRANSACTION_TYPE
			and 	m.PAYDATE (+) = y.PAYDATE
			and 	m.POLICYNAME (+) = y.POLICYNAME
			and	m.NAME (+) = y.NAME
			and     trunc(y.PAYDATE,'YYYY') =trunc(to_date(?,'MM/DD/YYYY'),'YYYY')
			and 	m.owner_org_id (+) = y.owner_org_id
			and	y.owner_org_id = ?
			and	%whereCond%
			group by y.NAME, y.CATEGORY_NAME, y.TRANSACTION_TYPE, y.POLICYNAME
			order by y.NAME, y.CATEGORY_NAME desc
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
		[
			{ colIdx => 0, head => 'Name', groupBy => '#0#', dataFmt => '#0#' },
			{ colIdx => 1, head => 'Category Name', groupBy => '#1#', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Transaction Type', groupBy => 'Total', dataFmt => '#2#' },
			{ colIdx => 3, head => 'Policy Name', dataFmt => '#3#'},
			{ colIdx => 4, head => 'Month To Date Cost', summarize => 'sum', dataFmt => '#4#',dformat => 'currency' },
			{ colIdx => 5, head => 'Year To Date Cost', summarize => 'sum', dataFmt => '#5#',dformat => 'currency' },
		],
};

$STMTMGR_REPORT_ACCOUNTING = new App::Statements::Report::Accounting(
	'sel_providerreceipt' =>
	{
		_stmtFmt => $STMTFMT_SEL_RECEIPT_ANALYSIS,
		whereCond => " UPPER(y.PROVIDERID) = ? AND UPPER(y.TRANSACTION_TYPE) = ?",
		publishDefn => $STMTRPTDEFN_DEFAULT,
	},
	'sel_providerreceipt_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_RECEIPT_ANALYSIS,
		whereCond => " UPPER(y.PROVIDERID) LIKE ? AND UPPER(y.TRANSACTION_TYPE) LIKE ?",
		publishDefn => $STMTRPTDEFN_DEFAULT,
	},
	'sel_provider_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_RECEIPT_ANALYSIS,
		whereCond => " UPPER(y.PROVIDERID) LIKE ? AND UPPER(y.TRANSACTION_TYPE) = ?",
		publishDefn => $STMTRPTDEFN_DEFAULT,
	},
	'sel_receipt_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_RECEIPT_ANALYSIS,
		whereCond => " UPPER(y.PROVIDERID) = ? AND UPPER(y.TRANSACTION_TYPE) LIKE ?",
		publishDefn => $STMTRPTDEFN_DEFAULT,
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
			SELECT 	person_id person_ID ,
			count(distinct invoice_id),
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
			AND 	(invoice_item_id is NULL  or item_type in (3) )
			AND	bill_party_type in (0,1)
			AND 	a.balance > 0
			AND	person_id IN
			(
			 SELECT person_id
			 FROM 	person_org_category
			 WHERE  org_internal_id = :2
			 ) 
			GROUP BY person_id
			having sum(total_pending)> 0
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
	
	'selGetVisit' =>qq
	{
		SELECT 	count (decode(t.trans_type ,2000,1,2010,1,2040,1,2050,1,2060,1,2070,1,2080,1,2090,1,2100,1,2120,1,2130,1,2160,1,2170,1,2180,1,0)) 
			as office_visit,                               
			count (decode(t.trans_type,2020,1,0)) as hospital_visit
		FROM	transaction t, invoice i, invoice_attribute ia,org o
		WHERE	i.main_transaction = t.trans_id
		AND	ia.parent_id = i.invoice_id
		AND	ia.item_name = 'Invoice/Creation/Batch ID'
		AND	(invoice_status !=15 or parent_invoice_id is null)
		AND 	o.org_internal_id = t.service_facility_id		
		AND	ia.value_date between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT')
                AND 	to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
                AND 	(:3 is NULL OR t.service_facility_id = :3 )
		AND	t.care_provider_id = :4
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
		(total_charges) total_charges,
		(misc_charges) misc_charges ,
		(person_pay) person_pay,
		(insurance_pay) insurance_pay,
		(insurance_write_off) insurance_write_off,
		(balance_transfer) balance_transfer,
		(charge_adjust) as  charge_adjust,
		(person_write_off) as person_write_off,
		(refund) as refund,		
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
		(total_charges) total_charges,
		(misc_charges) misc_charges ,
		(person_pay) person_pay,
		(insurance_pay) insurance_pay,
		(insurance_write_off) insurance_write_off,
		(balance_transfer) balance_transfer,
		(charge_adjust) as  charge_adjust,
		(person_write_off) as person_write_off,
		(refund) as refund,		
		pay_type
	FROM 	invoice_charges, org o
	WHERE 	to_char(invoice_date,'MM/YYYY') = :1
	AND	invoice_date between to_date(:7,'$SQLSTMT_DEFAULTDATEFORMAT')
	AND 	to_date(:8,'$SQLSTMT_DEFAULTDATEFORMAT')	
	AND 	(facility = :2 or :2 IS NULL )
	AND 	(provider = :3 or :3 IS NULL)
	AND
		(
			(batch_id >= :4 or :4 is NULL)
			AND
			(batch_id <= :5  or :5 is NULL)
		)
	AND 	o.org_internal_id = invoice_charges.facility
	AND 	o.owner_org_id = :6
	ORDER BY  invoice_id
	},


	'selChildernOrgs' =>qq{
		SELECT	org_internal_id,org_id
		FROM	org
		WHERE	owner_org_id = :1 
		AND	( (parent_org_id = :2 AND :3 = 1) OR org_internal_id = :2 OR :2 IS NULL)
		AND	upper(category) IN ('CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE')
		ORDER BY org_id
	},

	'sel_patient_superbill_info' => 
	{
		sqlStmt => qq
		{
			sELECT DISTINCT
			TO_CHAR(thePatientAppt.start_time, 'MM/DD/YY') AS startDate,
			TO_CHAR(thePatientAppt.start_time, 'HH24:MI') AS startTime,
			thePatient.short_name AS patientname,
			thePatientAppt.subject AS reason,
			theDoctor.person_id AS doctorID,
			theDoctor.short_name AS doctorName,
			theDoctorAddr.line1 AS location,
			TO_CHAR(thePatient.date_of_birth, 'MM/DD/YY') AS dob,
			thePatient.person_id AS patientNo,
			thePatient.person_id AS respParty,
			thePatient.gender AS sex,
			thePatientAddr.line1 AS patientAddress,
			thePatientAddr.city,
			thePatientAddr.state,
			thePatientAddr.zip
			FROM
			Event thePatientAppt,
			Event_Attribute theAppointmentAttr,
			Person thePatient,
			Person theDoctor,
			Person_Address thePatientAddr,
			Person_Address theDoctorAddr
			WHERE
			TRUNC(thePatientAppt.start_time) = TO_DATE(:1, 'MM/DD/YYYY')
			AND theAppointmentAttr.parent_id = thePatientAppt.event_id
			AND theAppointmentAttr.value_type = '333'
			AND theAppointmentAttr.value_text = thePatient.person_id
			AND theAppointmentAttr.value_textB = theDoctor.person_id
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
				{ colIdx =>  3, head => 'Dr #', dataFmt => '#4#'},
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

