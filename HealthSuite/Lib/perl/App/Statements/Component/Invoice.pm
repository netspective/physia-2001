##############################################################################
package App::Statements::Component::Invoice;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Data::Publish;
use App::Statements::Component;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_INVOICE
	);
@ISA    = qw(Exporter App::Statements::Component);
@EXPORT = qw($STMTMGR_COMPONENT_INVOICE);

$STMTMGR_COMPONENT_INVOICE = new App::Statements::Component::Invoice(

#----------------------------------------------------------------------------------------------------------------------

'invoice.dailyAuditRecap' => {
	sqlStmt => qq{
			select 	DAY_OF_MONTH,
				ORG_ID,
				sum(charges) as CHARGES,
				sum(misc_charges) as MISC_CHARGES,
				sum(charge_adjust) as CHARGE_ADJUST,
				sum(insurance_write_off) as INSURANCE_WRITE_OFF,
				sum(net_charges) as NET_CHARGES,
				sum(balance_transfers) as BALANCE_TRANSFERS,
				sum(personal_receipts) as PERSONAL_RECEIPTS,
				sum(insurance_receipts) as INSURANCE_RECEIPTS,
				sum(total_receipts) as TOTAL_RECEIPTS,
				sum(ending_a_r) as ENDING_A_R
			from 	daily_audit_recap
			where 	to_date(day_of_month, 'mm/dd/yyyy') between to_date(?, 'mm/dd/yyyy') and to_date(?, 'mm/dd/yyyy')
			and	org_id = ?
			group by DAY_OF_MONTH, ORG_ID
	},
	sqlStmtBindParamDescr => ['Report Start Date, Report End Date,Internal Org ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Day', dataFmt => '#0#', dAlign => 'RIGHT' },
			#{ colIdx => 1, head => 'Org', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Chrgs', summarize => 'sum', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 3, head => 'Misc Chrgs', summarize => 'sum', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 4, head => 'Chrg Adj', summarize => 'sum', dataFmt => '#4#', dformat => 'currency' },
			{ colIdx => 5, head => 'Ins Wrt-Off', summarize => 'sum', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 6, head => 'Net Chrgs', summarize => 'sum', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => 'Bal Trans', summarize => 'sum', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 8, head => 'Per Rcpts', summarize => 'sum', dataFmt => '#8#', dformat => 'currency' },
			{ colIdx => 9, head => 'Ins Rcpts', summarize => 'sum', dataFmt => '#9#', dformat => 'currency' },
			{ colIdx => 10, head => 'Ttl Rcpts', summarize => 'sum', dataFmt => '#10#', dformat => 'currency' },
			{ colIdx => 11, head => 'End A/R', summarize => 'sum', dataFmt => '#11#', dformat => 'currency' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Daily Audit Recap' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'invoice.monthlyAuditRecap' => {
	sqlStmt => qq{
			select  to_char(to_date(DAY_OF_MONTH,'mm/dd/yyyy'), 'YYYY-MON') as Month,
				ORG_ID,
				sum(charges) as CHARGES,
				sum(misc_charges) as MISC_CHARGES,
				sum(charge_adjust) as CHARGE_ADJUST,
				sum(insurance_write_off) as INSURANCE_WRITE_OFF,
				sum(net_charges) as NET_CHARGES,
				sum(balance_transfers) as BALANCE_TRANSFERS,
				sum(personal_receipts) as PERSONAL_RECEIPTS,
				sum(insurance_receipts) as INSURANCE_RECEIPTS,
				sum(total_receipts) as TOTAL_RECEIPTS,
				sum(change_a_r) as CHANGE_A_R
			   from  daily_audit_recap
			where 	to_date(day_of_month, 'mm/dd/yyyy') between to_date(?, 'mm/dd/yyyy') and to_date(?, 'mm/dd/yyyy')
			and org_id = ?
			group by to_char(to_date(DAY_OF_MONTH,'mm/dd/yyyy'), 'YYYY-MON'), ORG_ID
			order by Month
		},
	sqlStmtBindParamDescr => ['Report Start Date, Report End Date, Org ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Month', dataFmt => '#0#', dAlign => 'RIGHT' },
			#{ colIdx => 1, head => 'Org', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Chrgs', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 3, head => 'Misc Chrgs', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 4, head => 'Chrg Adj', dataFmt => '#4#', dformat => 'currency' },
			{ colIdx => 5, head => 'Ins Wrt-Off', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 6, head => 'Net Chrgs', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => 'Bal Trans', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 8, head => 'Per Rcpts', dataFmt => '#8#', dformat => 'currency' },
			{ colIdx => 9, head => 'Ins Rcpts', dataFmt => '#9#', dformat => 'currency' },
			{ colIdx => 10, head => 'Ttl Rcpts', dataFmt => '#10#', dformat => 'currency' },
			{ colIdx => 11, head => 'End A/R', dataFmt => '#11#', dformat => 'currency' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Monthly Audit Recap' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'invoice.procAnalysis' => {
	sqlStmt => qq{
			select p.short_sortable_name,
			tt.caption as visit_type,
			nvl(i.code,'UNK') as code,
			nvl(r.name,'N/A') as proc,
			sum(decode(trunc(invoice_date,'MM'),trunc(to_date(:2,'MM/DD/YYYY'),'MM'),i.units,0)) as month_to_date_units,
			sum(decode(trunc(invoice_date,'MM'),trunc(to_date(:2,'MM/DD/YYYY'),'MM'),i.unit_cost,0)) as month_to_date_unit_cost,
			sum(i.units) as year_to_date_units,
			sum(i.unit_cost) as year_to_date_unit_cost
			from invoice_charges i
			, ref_cpt r,person p, transaction t,
			Transaction_type tt,
			org o
			where  r.CPT (+) = i.code
			AND p.person_id= provider
			AND (p.person_id = :1 OR :1 IS NULL)
			AND trunc(i.invoice_date,'YYYY') =trunc(to_date(:2,'MM/DD/YYYY'),'YYYY')
			AND (:3 IS NULL OR :3 = i.facility)
			AND (:4 IS NULL OR :4 <=i.code)
			AND (:5 is NULL OR :5 >=i.code)
			AND o.org_internal_id = i.facility
			AND o.owner_org_id = :6
			AND t.trans_id (+)= i.trans_id
			AND tt.id (+)= t.trans_type
			group by r.name,p.short_sortable_name,
			i.code,tt.caption
			order by p.short_sortable_name,tt.caption
			},
	sqlStmtBindParamDescr => ['Provider ID for yearToDateReceiptProcAnalysis View'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Name', dataFmt => '#0#',groupBy=>"#0#",},
			{ colIdx => 1, head => 'Visit Type', dataFmt => '#1#',groupBy=>"#1#" },
			{ colIdx => 2, head => 'CPT Code', dataFmt => '#2#' ,},
			{ colIdx => 3, head => 'CPT Name', dataFmt => '#3#' ,},
			{ colIdx => 4, head => 'Monthly Units', summarize => 'sum',dataFmt => '#4#', },
			{ colIdx => 5, head => 'Month To Date Cost', summarize => 'sum',dataFmt => '#5#',dformat => 'currency' },
			{ colIdx => 6, head => 'Yearly Units', summarize => 'sum',dataFmt => '#6#' ,},
			{ colIdx => 7, head => 'Year To Date Cost',summarize => 'sum', dataFmt => '#7#' ,dformat => 'currency'},
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Monthly Audit Recap' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'invoice.procAnalysisAll' => {
	sqlStmt => qq{
			select 	y.NAME,
				y.DEPARTMENTNAME,
				y.CPTCODE,
				y.CPTNAME,
				m.MONTHUNITS,
				m.MONTHAMOUNT,
				y.YEARUNITS,
				y.YEARAMOUNT
			from 	monthToDateReceiptProcAnalysis m, yearToDateReceiptProcAnalysis y
			where	m.PROVIDERID(+) = y.PROVIDERID
			and	m.CPTCODE(+) = y.CPTCODE
			and	m.CPTNAME(+) = y.CPTNAME
			and	m.DEPARTMENTNAME(+) = y.DEPARTMENTNAME
			},
	sqlStmtBindParamDescr => ['Provider ID for yearToDateReceiptProcAnalysis View'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Name', dataFmt => '#0#' },
			{ colIdx => 1, head => 'Department Name', dataFmt => '#1#' },
			{ colIdx => 2, head => 'CPT Code', dataFmt => '#2#' },
			{ colIdx => 3, head => 'CPT Name', dataFmt => '#3#' },
			{ colIdx => 4, head => 'Monthly Units', dataFmt => '#4#' },
			{ colIdx => 5, head => 'Month To Date', dataFmt => '#5#' },
			{ colIdx => 6, head => 'Yearly Units', dataFmt => '#6#' },
			{ colIdx => 7, head => 'Year To Date', dataFmt => '#7#' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Monthly Audit Recap' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},



#----------------------------------------------------------------------------------------------------------------------

'invoice.claimStatus' => {
	sqlStmt => qq{
			select 	invoice_id,
				total_items, client_id,
				to_char(invoice_date, 'DD/MM/YYYY') as invoice_date,
				invoice_status as invoice_status,
				bill_to_id,
				total_cost,
				total_adjust,
				balance,
				reference,
				bill_to_type
		from 	invoice
		where	invoice_status in (?)
		and 	owner_type = 1
		and 	owner_id = ?
		and     trunc(invoice_date) between to_date(?, 'mm/dd/yyyy') and to_date(?, 'mm/dd/yyyy')
		order by invoice_date DESC
			},
	sqlStmtBindParamDescr => ['Start Date, End Date,Owner ID, Invoice Status'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Invoice ID', dataFmt => '#0#' },
			{ colIdx => 1, head => 'Number Of Items', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Client ID', dataFmt => '#2#' },
			{ colIdx => 3, head => 'Invoice Date', dataFmt => '#3#' },
			{ colIdx => 4, head => 'Invoice Status', dataFmt => '#4#' },
			{ colIdx => 5, head => 'Bill To ID', dataFmt => '#5#' },
			{ colIdx => 6, head => 'Total Cost', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => 'Total Adjustment', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 8, head => 'Balance', dataFmt => '#8#', dformat => 'currency' },
			{ colIdx => 9, head => 'Reference', dataFmt => '#9#' },
			{ colIdx => 10, head => 'Bill To Type', dataFmt => '#10#' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Claim Status' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'invoice.agedPatientData' => {
	sqlStmt => qq{
			select 	patient, sum(ageperiod1),
				sum(ageperiod2), sum(ageperiod3),
				sum(ageperiod4), sum(ageperiod5),
				sum(ageperiod6), sum(copay),
				sum(total), sum(insurance)
			from 	agedpatientdata
			where	patient = ?
			group by patient
			},
	sqlStmtBindParamDescr => ['Patient ID for agedpatientdata View'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Patient', dataFmt => '<A HREF = "/person/#0#/profile">#0#</A>' },
			{ colIdx => 1, head => '0 - 30', dataFmt => '#1#', dformat => 'currency' },
			{ colIdx => 2, head => '31 - 60', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 3, head => '61 - 90', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 4, head => '91 - 120', dataFmt => '#4#', dformat => 'currency' },
			{ colIdx => 5, head => '121 - 150', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 6, head => '>150', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => 'Co-Pay Owed', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 8, head => 'Total', dataFmt => '#8#', dformat => 'currency' },
			{ colIdx => 9, head => 'Pending Insurance', dataFmt => '#9#', dformat => 'currency' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Aged Patient Data' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'invoice.agedPatientDataAll' => {
	sqlStmt => qq{
			select 	patient, sum(ageperiod1),
				sum(ageperiod2), sum(ageperiod3),
				sum(ageperiod4), sum(ageperiod5),
				sum(ageperiod6), sum(copay),
				sum(total), sum(insurance)
			from 	agedpatientdata
			group by patient
			},
	sqlStmtBindParamDescr => ['Patient ID for agedpatientdata View'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Patient', dataFmt => '<A HREF = "/person/#0#/profile">#0#</A>' },
			{ colIdx => 1, head => '0 - 30', dataFmt => '#1#', dformat => 'currency' },
			{ colIdx => 2, head => '31 - 60', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 3, head => '61 - 90', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 4, head => '91 - 120', dataFmt => '#4#', dformat => 'currency' },
			{ colIdx => 5, head => '121 - 150', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 6, head => '>150', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => 'Co-Pay Owed', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 8, head => 'Total', dataFmt => '#8#', dformat => 'currency' },
			{ colIdx => 9, head => 'Pending Insurance', dataFmt => '#9#', dformat => 'currency' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Aged Patient Data' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'invoice.agedInsuranceData' => {
	sqlStmt => qq{
				select 	insurance, sum(patients), sum(ageperiod1), sum(ageperiod2), sum(ageperiod3),
						sum(ageperiod4), sum(ageperiod5), sum(ageperiod6), sum(total)
				from 	agedinsdata
				where	insurance = ?
				group by insurance
				},
	sqlStmtBindParamDescr => ['Patient ID for agedpatientdata View'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Insurance', dataFmt => '<A HREF = "/org/#0#/profile">#0#</A>' },
			{ colIdx => 1, head => 'Total Patients', dataFmt => '#1#' },
			{ colIdx => 2, head => '0 - 30', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 3, head => '31 - 60', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 4, head => '61 - 90', dataFmt => '#4#', dformat => 'currency' },
			{ colIdx => 5, head => '91 - 120', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 6, head => '121 - 150', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => '>150', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 8, head => 'Pending Insurance Total', dataFmt => '#8#', dAlign => 'center', dformat => 'currency' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Aged Insurance Data' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'invoice.agedInsuranceDataAll' => {
	sqlStmt => qq{
				select 	insurance, sum(patients), sum(ageperiod1), sum(ageperiod2), sum(ageperiod3),
						sum(ageperiod4), sum(ageperiod5), sum(ageperiod6), sum(total)
				from 	agedinsdata
				group by insurance
				},
	sqlStmtBindParamDescr => ['Patient ID for agedpatientdata View'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Insurance', dataFmt => '<A HREF = "/org/#0#/profile">#0#</A>' },
			{ colIdx => 1, head => 'Total Patients', dataFmt => '#1#' },
			{ colIdx => 2, head => '0 - 30', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 3, head => '31 - 60', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 4, head => '61 - 90', dataFmt => '#4#', dformat => 'currency' },
			{ colIdx => 5, head => '91 - 120', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 6, head => '121 - 150', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => '>150', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 8, head => 'Pending Insurance Total', dataFmt => '#8#', dAlign => 'center', dformat => 'currency' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Aged Insurance Data' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'invoice.financialAnalysisReport' => {
	sqlStmt => qq{
			select 	PROVIDER, ORG_ID,
				sum(charges) as CHARGES,
				sum(PERSONAL_RECEIPTS),
				sum(INSURANCE_RECEIPTS),
				sum(CHARGE_ADJUST),
				sum(INSURANCE_WRITE_OFF),
				sum(NET_CHARGES),
				sum(BALANCE_TRANSFERS),
				sum(MISC_CHARGES),
				sum(CHANGE_A_R)
			from 	provider_by_location
			where	provider = ?
			group by org_id, provider
			},
	sqlStmtBindParamDescr => ['Provider ID for provider_by_location View'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 1, head => 'Org', dataFmt => '<A HREF = "/org/#1#/profile">#1#</A>' },
			{ colIdx => 2, head => 'Chrgs', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 3, head => 'Per Rcpts', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 4, head => 'Ins Rcpts', dataFmt => '#4#', dformat => 'currency' },
			{ colIdx => 5, head => 'Chrg Adj', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 6, head => 'Ins Wrt-Off', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => 'Net Chrgs', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 8, head => 'Bal Trans', dataFmt => '#8#', dformat => 'currency' },
			{ colIdx => 9, head => 'Misc Chrgs', dataFmt => '#9#', dformat => 'currency' },
			{ colIdx => 10, head => 'Change In A/R', dataFmt => '#10#', dformat => 'currency' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Aged Insurance Data' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'invoice.financialAnalysisReportAll' => {
	sqlStmt => qq{
			select 	PROVIDER, ORG_ID,
				sum(charges) as CHARGES,
				sum(PERSONAL_RECEIPTS),
				sum(INSURANCE_RECEIPTS),
				sum(CHARGE_ADJUST),
				sum(INSURANCE_WRITE_OFF),
				sum(NET_CHARGES),
				sum(BALANCE_TRANSFERS),
				sum(MISC_CHARGES),
				sum(CHANGE_A_R)
			from 	provider_by_location
			group by org_id, provider
			},
	sqlStmtBindParamDescr => ['Provider ID for provider_by_location View'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 1, head => 'Org', dataFmt => '<A HREF = "/org/#1#/profile">#1#</A>' },
			{ colIdx => 2, head => 'Chrgs', dataFmt => '#2#', dformat => 'currency' },
			{ colIdx => 3, head => 'Per Rcpts', dataFmt => '#3#', dformat => 'currency' },
			{ colIdx => 4, head => 'Ins Rcpts', dataFmt => '#4#', dformat => 'currency' },
			{ colIdx => 5, head => 'Chrg Adj', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 6, head => 'Ins Wrt-Off', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => 'Net Chrgs', dataFmt => '#7#', dformat => 'currency' },
			{ colIdx => 8, head => 'Bal Trans', dataFmt => '#8#', dformat => 'currency' },
			{ colIdx => 9, head => 'Misc Chrgs', dataFmt => '#9#', dformat => 'currency' },
			{ colIdx => 10, head => 'Change In A/R', dataFmt => '#10#', dformat => 'currency' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Aged Insurance Data' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'invoice.appointmentCharges' => {
	sqlStmt => qq{
			select 	p1.complete_name,
				trunc(e.start_time - :4),
				to_char(e.start_time - :4, 'HH12:MIAM'),
				to_char(e.start_time - :4 +(e.duration/1440), 'HH12:MIAM'),
				o.name_primary,
				e.subject,
				t.caption,
				tt.caption,
				p.complete_name,
				p2.complete_name,
				nvl(i.total_cost, 0),
				i.client_id,
				p3.complete_name
			from 	event e, transaction t, org o, transaction_type tt,
				person p, person p1, person p2, invoice i, invoice_billing ib, person p3
			where	e.start_time >= to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :4
				and e.start_time <  to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :4
				and	e.event_id = t.parent_event_id
				and e.facility_id = o.org_internal_id
				and t.trans_type = tt.id
				and p.person_id = t.provider_id
				and p1.person_id = e.scheduled_by_id
				and t.trans_id = i.main_transaction
				and ib.invoice_id = i.invoice_id
				and ib.bill_to_id = p2.person_id
				and ib.bill_party_type in (0,1)
				and ib.bill_sequence = 1
				and ib.invoice_item_id is NULL
				and o.owner_org_id = :3
				and i.client_id = p3.person_id
			UNION ALL
			select	p1.complete_name, trunc(e.start_time - :4),
				to_char(e.start_time - :4, 'HH12:MIAM'),
				to_char(e.start_time - :4 +(e.duration/1440), 'HH12:MIAM'),
				o.name_primary, e.subject,
				t.caption, tt.caption, p.complete_name,
				o1.name_primary,
				nvl(i.total_cost, 0),
				i.client_id,
				p3.complete_name
			from 	event e, transaction t, org o, org o1, transaction_type tt,
				person p, person p1, invoice i, invoice_billing ib, person p3
			where	e.start_time >= to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :4
				and e.start_time <  to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :4
				and e.event_id = t.parent_event_id
				and e.facility_id = o.org_internal_id
				and t.trans_type = tt.id
				and p.person_id = t.provider_id
				and p1.person_id = e.scheduled_by_id
				and t.trans_id = i.main_transaction
				and ib.invoice_id = i.invoice_id
				and ib.bill_to_id = o1.org_internal_id
				and ib.bill_party_type in (2,3)
				and ib.bill_sequence = 1
				and ib.invoice_item_id is NULL
				and o.owner_org_id = :3
				and i.client_id = p3.person_id
			ORDER BY  2,12
			},
	sqlStmtBindParamDescr => ['Provider ID for provider_by_location View'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 11, head => 'Patient ID', dataFmt => '#11#',},
			{ colIdx => 0, head => 'Receptionist', dataFmt => '#0#' },
			{ colIdx => 1, head => 'Date', dataFmt => '#1#' },
			{ colIdx => 2, head => 'Start Time', dataFmt => '#2#' },
			{ colIdx => 3, head => 'End Time', dataFmt => '#3#' },
			{ colIdx => 4, head => 'Org', dataFmt => '#4#' },
			{ colIdx => 5, head => 'Reason', dataFmt => '#5#' },
			#{ colIdx => 6, head => 'Visit Type', dataFmt => '#6#' },
			{ colIdx => 7, head => 'Visit Type', dataFmt => '#7#' },
			{ colIdx => 8, head => 'Provider Name', dataFmt => '#8#' },
			{ colIdx => 9, head => 'Billed To', dataFmt => '#9#' },
			{ colIdx => 10, head => 'Charges', dataFmt => '#10#', dformat => 'currency'},
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Aged Insurance Data' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	#publishComp_st => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId]); },
	#publishComp_stp => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panel'); },
	#publishComp_stpt => sub { my ($page, $flags, $invoiceId) = @_; $invoiceId ||= $page->param('invoice_id'); $STMTMGR_COMPONENT_INVOICE->createHtml($page, $flags, 'invoice.monthlyAuditRecap', [$invoiceId], 'panelTransp'); },
},



);

1;