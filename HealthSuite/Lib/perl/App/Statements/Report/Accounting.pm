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
		units,
		unit_cost,		
		sum(total_charges) total_charges, 
		sum(misc_charges) misc_charges ,
		sum(person_pay) person_pay,
		sum(insurance_pay) insurance_pay,		
		sum(insurance_write_off) insurance_write_off,			
		sum(balance_transfer) balance_transfer,
		sum(charge_adjust) as  charge_adjust
	FROM 	invoice_charges
	WHERE 	invoice_date = to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT') 								
		AND (facility = :2 or :2 IS NULL )
		AND (provider = :3 or :3 IS NULL)
		AND
		( 
			(batch_id >= :4 or :4 is NULL) 
			AND
			(batch_id <= :5  or :5 is NULL) 		
		)		
	group by invoice_id ,
		invoice_date, 		
		service_begin_date,
		service_end_date,
		provider ,
		code, 
		caption,
		units,
		unit_cost,
		rel_diags,
		client_id
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
		sum(person_write_off) person_write_off
	FROM 	invoice_charges
	WHERE   invoice_date between to_date(:1,'$SQLSTMT_DEFAULTDATEFORMAT') 
		AND to_date(:2,'$SQLSTMT_DEFAULTDATEFORMAT')
		AND (facility = :3 OR :3 is NULL)
		AND (provider >=:4 OR :4 is NULL)
		AND (batch_id >= :5 OR :5 is NULL)
		AND (batch_id <= :6 OR :6 is NULL)
		
	group by invoice_date
},			
		
	
);


1;

