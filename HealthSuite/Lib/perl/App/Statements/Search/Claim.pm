##############################################################################
package App::Statements::Search::Claim;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_CLAIM_SEARCH $INVOICE_COLUMNS $UPINITEMNAME_PATH);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_CLAIM_SEARCH);

$UPINITEMNAME_PATH = 'UPIN';
#and iit.item_id = (select min(item_id) from invoice_item where parent_id (+) = i.invoice_id and iit.item_type in (1,2))

$INVOICE_COLUMNS = "invoice_id, total_items, client_id, to_char(invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date, get_Invoice_Status_cap(invoice_status) as invoice_status, bill_to_id, reference, total_cost, total_adjust, balance, bill_to_type";
#(select min(item_id) from invoice_item where parent_id = i.invoice_id and iit.item_type in (1,2))
use vars qw($STMTFMT_SEL_CLAIM $STMTRPTDEFN_DEFAULT);
$STMTFMT_SEL_CLAIM = qq{
		select distinct i.invoice_id, i.total_items, i.client_id,
			to_char(min(iit.service_begin_date), '$SQLSTMT_DEFAULTDATEFORMAT') as service_begin_date,
			iis.caption as invoice_status, ib.bill_to_id, i.total_cost, 
			i.total_adjust, i.balance, ib.bill_party_type,
			to_char(i.invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date
		from 	invoice_status iis, invoice i, invoice_billing ib, invoice_item iit %tables%
		where
			%whereCond%
			and iit.parent_id (+) = i.invoice_id			
			and ib.invoice_id = i.invoice_id
			and ib.invoice_item_id is NULL
			and ib.bill_sequence = 1
			and (owner_type = 1 and owner_id = ?)
			and iis.id = i.invoice_status
		group by i.invoice_id, i.total_items, i.client_id,
			iis.caption, ib.bill_to_id, i.total_cost, 
			i.total_adjust, i.balance, ib.bill_party_type,
			i.invoice_date
		order by i.invoice_id desc
};

$STMTRPTDEFN_DEFAULT =
{
	#style => 'pane',
	#frame =>
	#{
	#	heading => 'Fee Schedules',
	#},
	#stdIcons =>
	#{
	#	addUrlFmt => 'a', updUrlFmt => 'b', delUrlFmt => 'c',
	#},
	select =>
	{
		type => 'checkbox',
	},
	columnDefn =>
	[
		{ head => 'ID', url => 'javascript:chooseEntry("#&{?}#")', hint => 'Created on: #10#' },
		{ head => 'IC' },
		{ head => 'Patient', url => qq{javascript:chooseItem("/person/#&{?}#/account")}},
		#{ head => 'Inv Date' },
		{ head => 'Svc Date' },
		{ head => 'Status' },
		{ head => 'Payer', colIdx => 9,
			dataFmt =>
			{
				0 => qq{<A HREF="javascript:chooseItem('/person/#5#/account')" STYLE="text-decoration:none">#5#</A>},
				1 => qq{<A HREF="javascript:chooseItem('/person/#5#/account')" STYLE="text-decoration:none">#5#</A>},
				2 => qq{<A HREF="javascript:chooseItem('/org/#5#/account')" STYLE="text-decoration:none">#5#</A>},
				3 => qq{<A HREF="javascript:chooseItem('/org/#5#/account')" STYLE="text-decoration:none">#5#</A>},
				'_DEFAULT' => '#5#',
			},
		},
		#{ head => 'Reference' },
		{ head => 'Charges', summarize => 'sum', dformat => 'currency'},
		{ head => 'Adjust', summarize => 'sum', dformat => 'currency'},
		{ head => 'Balance', summarize => 'sum', dformat => 'currency'},
	],
	#rowSepStr => '',
};

$STMTMGR_CLAIM_SEARCH = new App::Statements::Search::Claim(
	'sel_id' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_id like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_patientid' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_patientid_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id = person_id and ssn = ?',
			tables => ', person',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id = person_id and ssn like ?',
			tables => ', person',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_date' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "invoice_date = to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_date_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "invoice_date like to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_servicedate' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "service_begin_date = to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_servicedate_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "service_begin_date like to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_upin' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.main_transaction = transaction.trans_id and transaction.provider_id = attr.parent_id and attr.item_name = '$UPINITEMNAME_PATH' and upper(attr.value_text) = ?",
			tables => ', transaction, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_upin_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.main_transaction = transaction.trans_id and transaction.provider_id = attr.parent_id and attr.item_name = '$UPINITEMNAME_PATH' and upper(attr.value_text) like ?",
			tables => ', transaction, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insurance' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'ib.bill_party_type in (2,3) and ib.bill_to_id = org_id and upper(name_primary) = ?',
			tables => ', org',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insurance_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'ib.bill_party_type in (2,3) and ib.bill_to_id = org_id and upper(name_primary) like ?',
			tables => ', org',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_text = o.org_id and upper(o.name_primary) = ?',
			tables => ', org o, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_text = o.org_id and upper(o.name_primary) like ?',
			tables => ', org o, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},





	'sel_id_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.invoice_id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.invoice_id like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_patientid_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_patientid_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id = person_id and ssn = ?',
			tables => ', person',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id = person_id and ssn like ?',
			tables => ', person',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_date_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status = ? and invoice_date = to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_date_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status = ? and invoice_date like to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_servicedate_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status = ? and service_begin_date = to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_servicedate_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status = ? and service_begin_date like to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_upin_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status = ? and i.main_transaction = transaction.trans_id and transaction.provider_id = attr.parent_id and attr.item_name = '$UPINITEMNAME_PATH' and upper(attr.value_text) = ?",
			tables => ', transaction, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_upin_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status = ? and i.main_transaction = transaction.trans_id and transaction.provider_id = attr.parent_id and attr.item_name = '$UPINITEMNAME_PATH' and upper(attr.value_text) like ?",
			tables => ', transaction, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insurance_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and ib.bill_party_type in (2,3) and ib.bill_to_id = org_id and upper(name_primary) = ?',
			tables => ', org',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insurance_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and ib.bill_party_type in (2,3) and ib.bill_to_id = org_id and upper(name_primary) like ?',
			tables => ', org',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_text = o.org_id and upper(o.name_primary) = ?',
			tables => ', org o, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_text = o.org_id and upper(o.name_primary) like ?',
			tables => ', org o, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},




	'sel_id_incomplete' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and i.invoice_id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_incomplete_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and i.invoice_id like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_patientid_incomplete' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and i.client_id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_patientid_incomplete_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and i.client_id like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn_incomplete' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and i.client_id = person_id and ssn = ?',
			tables => ', person',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn_incomplete_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and i.client_id = person_id and ssn like ?',
			tables => ', person',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_date_incomplete' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status in (0,1) and invoice_date = to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_date_incomplete_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status in (0,1) and invoice_date like to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_servicedate_incomplete' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status in (0,1) and service_begin_date = to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_servicedate_incomplete_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status in (0,1) and service_begin_date like to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_upin_incomplete' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status in (0,1) and i.main_transaction = transaction.trans_id and transaction.provider_id = attr.parent_id and attr.item_name = '$UPINITEMNAME_PATH' and upper(attr.value_text) = ?",
			tables => ', transaction, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_upin_incomplete_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => "i.invoice_status in (0,1) and i.main_transaction = transaction.trans_id and transaction.provider_id = attr.parent_id and attr.item_name = '$UPINITEMNAME_PATH' and upper(attr.value_text) like ?",
			tables => ', transaction, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insurance_incomplete' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and ib.bill_party_type in (2,3) and ib.bill_to_id = org_id and upper(name_primary) = ?',
			tables => ', org',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insurance_incomplete_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and ib.bill_party_type in (2,3) and ib.bill_to_id = org_id and upper(name_primary) like ?',
			tables => ', org',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer_incomplete' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_text = o.org_id and upper(o.name_primary) = ?',
			tables => ', org o, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer_incomplete_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_text = o.org_id and upper(o.name_primary) like ?',
			tables => ', org o, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);

1;
