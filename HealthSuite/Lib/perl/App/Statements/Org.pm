##############################################################################
package App::Statements::Org;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_ORG $PUBLISH_DEFN);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ORG);

my $ATTRTYPE_PHONE = App::Universal::ATTRTYPE_PHONE;

$STMTMGR_ORG = new App::Statements::Org(
	'selOrgSimpleNameById' => qq{
			select name_primary from org where org_id = ?
		},
	'selRegistry' => qq{
		select *
		from org
		where org_id = ?
		},
	'selCategory' => qq{
		select category
		from org
		where org_id = ?
		},
	'selAttribute' => qq{
		select * from org_attribute
		where parent_id = ? and item_name = ?
		},
	'selAttributeById' => qq{
		select * from org_attribute
		where item_id = ?
		},
	'selAttributeByValueType' => qq{
		select * from org_attribute
		where parent_id = ? and value_type = ?
		},
	'selAttributeByItemNameAndValueTypeAndParent' => qq{
		select * from org_attribute
		where parent_id = ? and item_name = ? and value_type = ?
		},
	'selAlerts' => qq{
		select trans_type, trans_id, caption, detail, to_char(trans_begin_stamp, '$SQLSTMT_DEFAULTDATEFORMAT') as trans_begin_stamp,
				trans_end_stamp, trans_subtype
		from transaction
		where
			(
			(trans_owner_type = 1 and trans_owner_id = ?)
			)
			and
			(
			trans_type between 8000 and 8999
			)
			and
			(
			trans_status = 2
			)
		order by trans_begin_stamp desc
		},
	'selContactMethods' => qq{
		select * from org_attribute
		where parent_id = ?
		and value_type  in (10, 15, 20, 40, 50)
		order by name_sort, item_name
		},
	'selOrgAddressByAddrName' => qq{
		select *
		from org_address
		where parent_id = ?
		and address_name = ?
		},
	'selOrgAddressById' => qq{
		select *
		from org_address
		where item_id = ?
		},
	'selAddresses' => qq{
		select parent_id, address_name, complete_addr_html
		from org_address where parent_id = ?
		order by address_name
		},
	'selDepartments' => qq{
		select *
					from org org, org_category ocat
					where org.parent_org_id = ?
				and ocat.member_name = 'Department' and ocat.parent_id = org.org_id
	  	 },
	 'selInsOrgName' => qq{
	   	select name_primary, ins_org_id
	   		from org, insurance
	   		where product_name = ?
			and org_id = 'ins_org_id'
		},

	'selMemberNames' => qq{
		select member_name
			from org_category
			where parent_id = ?
		},
	'selHealthRule' => qq{
		select *
			from hlth_maint_rule
			where rule_id = ?
		},
	'selTimeMetric' => qq{
		select id, caption
			from Time_Metric
		},
	'selOrgCategory' => qq{
		select member_name
			from Org_Category
			where parent_id = ?
		},

	'sel_payToOrgInfo' => {
		_stmtFmt => qq{
			select name_primary, complete_addr_html, value_text as phone
			from Org_Attribute, Invoice_Address, Org
			where Org.org_id =
				(select value_textB
					from Invoice_Attribute
					where parent_id = ?
						and item_name = 'Pay To Org/Name')
				and Invoice_Address.parent_id = ?
				and Invoice_Address.address_name = 'Pay To Org'
				and Org_Attribute.parent_id = Org.org_id
				and Org_Attribute.value_type = $ATTRTYPE_PHONE
				and Org_Attribute.item_name = 'Primary'
		},
	},

	'sel_personDataFromInvoice' => qq{
		select person_id, complete_name, complete_addr_html
		from Invoice_Address, Person, Invoice
		where invoice_id = ?
			and person_id = client_id
			and parent_id = invoice_id
			and address_name = 'Patient'
	},

	'sel_invoiceCostItems' => {
		_stmtFmt => qq{
			select to_char(service_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_begin_date,
				initcap(name) as cpt_description,
				extended_cost,
				Invoice_Item.total_adjust as item_adjust,
				Invoice.total_cost,
				Invoice.total_adjust
			from Ref_CPT, Invoice_Item, Invoice
			where invoice_id = ?
				and Invoice_Item.parent_id = Invoice.invoice_id
				and item_type in (0, 1, 2)
				and Ref_CPT.cpt (+) = code
		},

		publishDefn =>
		{
			columnDefn =>
			[
				{head => 'Date', colIdx => 0},
				{head => 'Description', colIdx => 1},
				{head => 'Amount', colIdx => 2, summarize => 'sum'},
				{head => 'Paid', colIdx => 3, summarize => 'sum'},
			],
		},
	},

	'sel_invoicePaymentItems' => {
		_stmtFmt => qq{
			select to_char(cr_stamp, '$SQLSTMT_DEFAULTDATEFORMAT') as pay_date,
				'Payment - Thank You' as description,
				null,
				total_adjust
			from Invoice_Item
			where parent_id = ?
				and item_type in (3, 5)
				and total_adjust is NOT NULL
		},

		publishDefn =>
		{
			columnDefn =>
			[
				{head => 'Date', colIdx => 0},
				{head => 'Description', colIdx => 1},
				{head => 'Amount', colIdx => 2, summarize => 'sum'},
				{head => 'Paid', colIdx => 3, summarize => 'sum'},
			],
		},
	},

	'sel_previousBalance' => qq{
		select upper(client_id) as client_id, sum(balance) as balance
		from Invoice
		where upper(client_id) = (select client_id from Invoice where invoice_id = ?)
			and invoice_id != ?
			and balance > 0
		group by upper(client_id)
	},
	
	'sel_futureAppointments' => {
		_stmtFmt => qq{
			select 	to_char(e.start_time, 'mm/dd/yyyy HH12:MI AM') appt_time,
				eadoc.value_text as physician, e.subject
			from 	event_attribute eaper, event_attribute eadoc, event e
			where e.start_time > sysdate	
				and eaper.parent_id = e.event_id
				and	eaper.value_text = ?
				and	eaper.item_name like '%Patient'
				and	eadoc.parent_id = e.event_id
				and	eadoc.item_name like '%Physician'
		},
	},

);

$PUBLISH_DEFN =
{
	columnDefn =>
	[
		{head => 'Date', colIdx => 0},
		{head => 'Description', colIdx => 1},
		{head => 'Amount', colIdx => 2, summarize => 'sum', dAlign => 'right', dformat => 'currency',},
		{head => 'Paid', colIdx => 3, summarize => 'sum', dAlign => 'right', dformat => 'currency',},
	],
};


1;
