##############################################################################
package App::Statements::Search::Claim;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_CLAIM_SEARCH $UPINITEMNAME_PATH
	$STMTFMT_SEL_CLAIM $STMTRPTDEFN_DEFAULT);
@ISA = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_CLAIM_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

$UPINITEMNAME_PATH = 'UPIN';

$STMTFMT_SEL_CLAIM = qq{
	SELECT *
	FROM (
		SELECT
			DISTINCT i.invoice_id,
			i.total_items,
			i.client_id,
			TO_CHAR(MIN(iit.service_begin_date), '$SQLSTMT_DEFAULTDATEFORMAT') AS service_begin_date,
			iis.caption AS invoice_status,
			ib.bill_to_id,
			i.total_cost, 
			i.total_adjust,
			i.balance,
			ib.bill_party_type,
			TO_CHAR(i.invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') AS invoice_date,
			o.org_id,
			i.invoice_status as status_id,
			i.parent_invoice_id
		FROM
			invoice_status iis,
			invoice i,
			invoice_billing ib,
			invoice_item iit,
			org o
			%tables%
		WHERE
			%whereCond%
			AND iit.parent_id (+) = i.invoice_id			
			AND ib.invoice_id = i.invoice_id
			AND ib.invoice_item_id IS NULL
			AND ib.bill_sequence = 1
			AND (owner_type = 1 AND owner_id = ?)
			AND iis.id = i.invoice_status
			AND to_char(o.org_internal_id (+)) = ib.bill_to_id
		GROUP BY
			i.invoice_id,
			i.total_items,
			i.client_id,
			iis.caption,
			ib.bill_to_id,
			i.total_cost, 
			i.total_adjust,
			i.balance,
			ib.bill_party_type,			
			i.invoice_date,
			o.org_id,
			i.invoice_status,
			i.parent_invoice_id
		ORDER BY
			i.invoice_id desc
	)
	WHERE rownum <= $LIMIT
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
		{ head => 'ID', url => q{javascript:chooseEntry('#&{?}#')}, hint => 'Created on: #10#' },
		{ head => 'IC' },
		{ head => 'Patient', url => q{javascript:chooseItem('/person/#&{?}#/account')} },
		{ head => 'Svc Date' },
		{ head => 'Status', colIdx => 12, dataFmt => {
								'0' => '#4#',
								'1' => '#4#',
								'2' => '#4#',
								'3' => '#4#',
								'4' => '#4#',
								'5' => '#4#',
								'6' => '#4#',
								'7' => '#4#',
								'8' => '#4#',
								'9' => '#4#',
								'10' => '#4#',
								'11' => '#4#',
								'12' => '#4#',
								'13' => '#4#',
								'14' => '#4#',
								'15' => '#4#',
								'16' => 'Void #13#'
							},
		},
		{ head => 'Payer', colIdx => 9,
			dataFmt =>
			{
				0 => qq{<A HREF="javascript:chooseItem('/person/#5#/account')" STYLE="text-decoration:none">#5#</A>},
				1 => qq{<A HREF="javascript:chooseItem('/person/#5#/account')" STYLE="text-decoration:none">#5#</A>},
				2 => qq{<A HREF="javascript:chooseItem('/org/#11#/account')" STYLE="text-decoration:none">#11#</A>},
				3 => qq{<A HREF="javascript:chooseItem('/org/#11#/account')" STYLE="text-decoration:none">#11#</A>},
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
	'sel_lastname' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id = person_id and name_last = ?',
			tables => ', person',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_lastname_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id = person_id and name_last like ?',
			tables => ', person',
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
			whereCond => "'%' = ?",
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
			whereCond => "'%' = ?",
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
			whereCond => 'ib.bill_party_type in (2,3) and ib.bill_to_id = o.org_internal_id and upper(o.name_primary) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insurance_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'ib.bill_party_type in (2,3) and ib.bill_to_id = o.org_internal_id and upper(o.name_primary) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_int = o2.org_internal_id and upper(o2.name_primary) = ?',
			tables => ', org o2, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_int = o2.org_internal_id and upper(o2.name_primary) like ?',
			tables => ', org o2, person_attribute attr',
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
	'sel_lastname_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id = person_id and name_last = ?',
			tables => ', person',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_lastname_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id = person_id and name_last like ?',
			tables => ', person',
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
			whereCond => 'i.invoice_status = ? and ib.bill_party_type in (2,3) and upper(o.name_primary) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insurance_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and ib.bill_party_type in (2,3) and upper(o.name_primary) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer_status' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_int = o2.org_internal_id and upper(o2.name_primary) = ?',
			tables => ', org o2, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_employer_status_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CLAIM,
			whereCond => 'i.invoice_status = ? and i.client_id = attr.parent_id and attr.value_type between 220 and 226 and attr.value_int = o2.org_internal_id and upper(o2.name_primary) like ?',
			tables => ', org o2, person_attribute attr',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},

);

1;
