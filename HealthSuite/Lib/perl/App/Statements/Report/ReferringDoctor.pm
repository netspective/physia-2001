##############################################################################
package App::Statements::Report::ReferringDoctor;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_REPORT_REFERRING_DOCTOR);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_REFERRING_DOCTOR);

$STMTMGR_REPORT_REFERRING_DOCTOR = new App::Statements::Report::ReferringDoctor
(
	'totalPatientCount' =>
	{
		sqlStmt => qq
		{
			select count(i.client_id) patientCount
			from person p, transaction t, invoice i,
				(
					select parent_id from invoice_item ii
					where (ii.service_begin_date >= to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') OR :3 is NULL)
					and (ii.service_end_date <= to_date(:4, '$SQLSTMT_DEFAULTDATEFORMAT') OR :4 is NULL)
					and ii.item_type in (0, 1, 2)
					and ii.data_text_b is null
				) inv_items
			where i.invoice_date between to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') and to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and t.trans_id = i.main_transaction
			and p.person_id = t.data_text_a
			and i.invoice_id = inv_items.parent_id
		}
	},

	'patientCount' =>
	{
		sqlStmt => qq
		{
			select
				p.simple_name name,
				p.person_id,
				count(i.client_id) patientCount,
				pa.item_name category,
				p.name_last,
				round((count(i.client_id) / cnt.ptCount * 100), 2) || '%' patientPercent
			from
				person p,
				transaction t,
				invoice i,
				(
					select parent_id, item_name
					from person_attribute
					where value_type = @{[ App::Universal::ATTRTYPE_SPECIALTY ]}
					and value_int = @{[ App::Universal::SPECIALTY_PRIMARY ]}
				) pa,
				(
					select count(i.client_id) ptCount
					from person p, transaction t, invoice i,
						(
							select parent_id from invoice_item ii
							where (ii.service_begin_date >= to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') OR :3 is NULL)
							and (ii.service_end_date <= to_date(:4, '$SQLSTMT_DEFAULTDATEFORMAT') OR :4 is NULL)
							and ii.item_type in (0, 1, 2)
							and ii.data_text_b is null
						) inv_items
					where i.invoice_date between to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') and to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
					and t.trans_id = i.main_transaction
					and p.person_id = t.data_text_a
					and i.invoice_id = inv_items.parent_id
				) cnt,
				(
					select parent_id from invoice_item ii
					where (ii.service_begin_date >= to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') OR :3 is NULL)
					and (ii.service_end_date <= to_date(:4, '$SQLSTMT_DEFAULTDATEFORMAT') OR :4 is NULL)
					and ii.item_type in (0, 1, 2)
					and ii.data_text_b is null
				) inv_items
			where i.invoice_date between to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') and to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and t.trans_id = i.main_transaction
			and p.person_id = t.data_text_a
			and i.invoice_id = inv_items.parent_id
			and p.person_id = pa.parent_id (+)
			group by p.simple_name, p.person_id, pa.item_name, p.name_last, cnt.ptCount
			order by pa.item_name, p.name_last
		},

		sqlStmtBindParamDescr => ['Date Range when the Doctor has referred the patient in which Plan'],

		publishDefn =>
		{
			columnDefn =>
			[
				{
					colIdx => 0,
					head => 'Category',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#3#',
					groupBy => '#3#',
				},
				{
					colIdx => 1,
					head => 'Doctor',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#0# <A HREF = "/person/#1#/profile">#1#</A>',
				},
				{
					colIdx => 2,
					head => '# of Patients',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#2#',
					summarize => 'sum',
				},
				{
					colIdx => 3,
					head => '% of Patients',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#5#',
					summarize => 'sum',
				},
			],
		},
	},

	'patientOrgCount' =>
	{
		sqlStmt => qq
		{
			select p.simple_name name, p.person_id, o.name_primary, count(i.client_id) patientCount
			from person p, transaction t, invoice i, org o, invoice_billing ib, insurance ins,
				(
					select parent_id from invoice_item ii
					where (ii.service_begin_date >= to_date(:3, 'MM/DD/YYYY') OR :3 is NULL)
					and (ii.service_end_date <= to_date(:4, 'MM/DD/YYYY') OR :4 is NULL)
					and ii.item_type in (0, 1, 2)
					and ii.data_text_b is null
				) inv_items
			where i.invoice_date between to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') and to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and t.trans_id = i.main_transaction
			and p.person_id = t.data_text_a
			and i.billing_id = ib.bill_id
			and ib.bill_ins_id = ins.ins_internal_id
			and ins.ins_org_id = o.org_internal_id
			and ib.bill_party_type = 3
			and i.invoice_id = inv_items.parent_id
			group by p.simple_name, p.person_id, o.name_primary

			union

			select p.simple_name name, p.person_id, null, count(i.client_id) patientCount
			from person p, transaction t, invoice i, invoice_billing ib,
				(
					select parent_id from invoice_item ii
					where (ii.service_begin_date >= to_date(:3, 'MM/DD/YYYY') OR :3 is NULL)
					and (ii.service_end_date <= to_date(:4, 'MM/DD/YYYY') OR :4 is NULL)
					and ii.item_type in (0, 1, 2)
					and ii.data_text_b is null
				) inv_items
			where i.invoice_date between to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') and to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and t.trans_id = i.main_transaction
			and p.person_id = t.data_text_a
			and i.billing_id = ib.bill_id
			and ib.bill_party_type <> 3
			and i.invoice_id = inv_items.parent_id
			group by p.simple_name, p.person_id
		},

		sqlStmtBindParamDescr => ['Date Range when the Doctor has referred the patient in which Plan'],

		publishDefn =>
		{
			columnDefn =>
			[
				{
					colIdx => 0,
					head => 'Doctor',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#0#',
				},
				{
					colIdx => 1,
					head => 'Insurance Org',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#2#',
				},
				{
					colIdx => 2,
					head => '# of Patients',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#3#',
				},
			],
		},
	},
);


1;

