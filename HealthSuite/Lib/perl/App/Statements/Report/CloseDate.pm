##############################################################################
package App::Statements::Report::CloseDate;
##############################################################################

use strict;
use DBI::StatementManager;
use Data::Publish;

use base qw(Exporter DBI::StatementManager);

use vars qw(@EXPORT $STMTMGR_REPORT_CLOSEDATE);
@EXPORT = qw($STMTMGR_REPORT_CLOSEDATE);

my $invoice_charges = 'Invoice_Charges';

my $monthFormat = 'mm/yyyy';

my $sel_TotalsForDate = qq{
	SELECT sum(total_charges) as total_charges,
		sum(person_pay) as person_pay,
		sum(insurance_pay) as insurance_pay,
		sum(person_write_off) as courtesy_adj,
		sum(insurance_write_off) as contractual_adj,
		sum(misc_charges) as misc_charges,
		sum(refund) as refund
	FROM $invoice_charges
	WHERE owner_org_id = :1
		and real_invoice_date >= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
		and real_invoice_date <  to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') +1
		%andDocCriterial%
};

my $sel_TotalsForMonth = qq{
	SELECT sum(total_charges) as total_charges,
		sum(person_pay) as person_pay,
		sum(insurance_pay) as insurance_pay,
		sum(person_write_off) as courtesy_adj,
		sum(insurance_write_off) as contractual_adj,
		sum(misc_charges) as misc_charges,
		sum(refund) as refund
	FROM $invoice_charges
	WHERE owner_org_id = :1
		and real_invoice_date >= to_date(:2, '$monthFormat')
		and real_invoice_date <  to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1
		%andDocCriterial%		
};

my $sel_TotalsForYear = qq{
	SELECT sum(total_charges) as total_charges,
		sum(person_pay) as person_pay,
		sum(insurance_pay) as insurance_pay,
		sum(person_write_off) as courtesy_adj,
		sum(insurance_write_off) as contractual_adj,
		sum(misc_charges) as misc_charges,
		sum(refund) as refund
	FROM $invoice_charges
	WHERE owner_org_id = :1
		and real_invoice_date >= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
		and real_invoice_date <  to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1
		%andDocCriterial%
};

$STMTMGR_REPORT_CLOSEDATE = new App::Statements::Report::CloseDate(

	# -----------------------------------------------
	'sel_orgTotalsForDate' => {
		sqlStmt => $sel_TotalsForDate,
		andDocCriterial => undef,
	},

	'sel_orgTotalsForMonth' => {
		sqlStmt => $sel_TotalsForMonth,
		andDocCriterial => undef,
	},

	'sel_orgTotalsForYear' => {
		sqlStmt => $sel_TotalsForYear,
		andDocCriterial => undef,
	},

	'sel_orgDayStartingAR' => {
		sqlStmt => qq{
			select sum(balance) from Invoice
			where owner_id = :1
				and invoice_date < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
				and NOT (invoice_status = 15 and parent_invoice_id is NOT NULL)
		},
	},

	'sel_orgMonthStartingAR' => {
		sqlStmt => qq{
			select sum(balance) from Invoice 
			where owner_id = :1
				and invoice_date < to_date(:2, '$monthFormat')
				and NOT (invoice_status = 15 and parent_invoice_id is NOT NULL)
		},
	},
		
	'sel_orgYearStartingAR' => {
		sqlStmt => qq{
			select sum(balance) from Invoice 
			where owner_id = :1
				and invoice_date < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
				and NOT (invoice_status = 15 and parent_invoice_id is NOT NULL)
		},
	},

	# -----------------------------------------------
	'sel_docTotalsForDate' => {
		sqlStmt => $sel_TotalsForDate,
		andDocCriterial => 'and provider = :3',
	},

	'sel_docTotalsForMonth' => {
		sqlStmt => $sel_TotalsForMonth,
		andDocCriterial => 'and provider = :4',
	},

	'sel_docTotalsForYear' => {
		sqlStmt => $sel_TotalsForYear,
		andDocCriterial => 'and provider = :4',
	},

	'sel_docDayStartingAR' => {
		sqlStmt => qq{
			select sum(balance) from Transaction, Invoice
			where Invoice.owner_id = :1
				and invoice_date < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
				and NOT (invoice_status = 15 and parent_invoice_id is NOT NULL)
				and Transaction.trans_id = Invoice.main_transaction
				and Transaction.provider_id = :3
		},
	},

	'sel_docMonthStartingAR' => {
		sqlStmt => qq{
			select sum(balance) from Transaction, Invoice 
			where Invoice.owner_id = :1
				and invoice_date < to_date(:2, '$monthFormat')
				and NOT (invoice_status = 15 and parent_invoice_id is NOT NULL)
				and Transaction.trans_id = Invoice.main_transaction
				and Transaction.provider_id = :3
		},
	},
		
	'sel_docYearStartingAR' => {
		sqlStmt => qq{
			select sum(balance) from Transaction, Invoice 
			where Invoice.owner_id = :1
				and invoice_date < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
				and NOT (invoice_status = 15 and parent_invoice_id is NOT NULL)
				and Transaction.trans_id = Invoice.main_transaction
				and Transaction.provider_id = :3
		},
	},

	# -----------------------------------------------
	'sel_lastCloseDate' => qq{
		select to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as last_close_date 
		from Org_Attribute
		where parent_id = :1
			and value_type = @{[ App::Universal::ATTRTYPE_DATE ]}
			and item_name = 'Retire Batch Date'
	},

	'sel_providerList' => qq{
		select distinct provider from $invoice_charges
		where owner_org_id = :1
			and invoice_date >= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and invoice_date <  add_months(to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT'), 12)
	},
	
);

1;
