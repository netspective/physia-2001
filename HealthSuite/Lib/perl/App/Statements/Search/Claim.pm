##############################################################################
package App::Statements::Search::Claim;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Devel::ChangeLog;

use vars qw(@ISA @EXPORT @CHANGELOG $STMTMGR_CLAIM_SEARCH $INVOICE_COLUMNS $UPINITEMNAME_PATH);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_CLAIM_SEARCH);

$UPINITEMNAME_PATH = 'UPIN';


$INVOICE_COLUMNS = "invoice_id, total_items, client_id, to_char(invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date, get_Invoice_Status_cap(invoice_status) as invoice_status, bill_to_id, reference, total_cost, total_adjust, balance, bill_to_type";


use vars qw($STMTFMT_SEL_CLAIM $STMTRPTDEFN_DEFAULT);
$STMTFMT_SEL_CLAIM = qq{
		select distinct i.invoice_id, i.total_items, i.client_id,
			to_char(i.invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date,
			iis.caption as invoice_status, ib.bill_to_id, i.total_cost, i.total_adjust,
			i.balance, i.reference, ib.bill_party_type
		from 	invoice_status iis, invoice i, invoice_billing ib %tables%
		where
			%whereCond%
			and ib.invoice_id = i.invoice_id
			and ib.invoice_item_id is NULL
			and ib.bill_sequence = 1
			and (owner_type = 1 and owner_id = ?)
			and iis.id = i.invoice_status
		order by invoice_date DESC
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
		{ head => 'ID', url => 'javascript:chooseEntry("#&{?}#")', hint => 'Reference: #9#' },
		{ head => 'IC' },
		{ head => 'Patient', url => '/person/#&{?}#/account' },
		{ head => 'Date' },
		{ head => 'Status' },
		{ head => 'Payer', colIdx => 10,
			dataFmt =>
			{
				0 => '<A HREF=\'/person/#5#/account\' STYLE="text-decoration:none">#5#</A>',
				1 => '<A HREF=\'/person/#5#/account\' STYLE="text-decoration:none">#5#</A>',
				2 => '<A HREF=\'/org/#5#/account\' STYLE="text-decoration:none">#5#</A>',
				3 => '<A HREF=\'/org/#5#/account\' STYLE="text-decoration:none">#5#</A>',
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
			whereCond => 'invoice_date like ?',
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
			whereCond => 'i.invoice_status = ? and invoice_date = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_date_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and invoice_date like ?',
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
			whereCond => 'i.invoice_status in (0,1) and i.client_id = person_id and invoice_date = ?',
			tables => ', person',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_date_incomplete_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status in (0,1) and i.client_id = person_id and invoice_date like ?',
			tables => ', person',
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

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/06/2000', 'MAF',
		'Search/Claim',
		'Updated the Claim select statements by replacing them with _stmtFmt.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/19/2000', 'MAF',
		'Search/Claim',
		'Created simple reports instead of using createOutput function.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '03/21/2000', 'MAF',
		'Search/Claim',
		'Fixed visit date and employer statements and other minor fixes.'],
);
1;
