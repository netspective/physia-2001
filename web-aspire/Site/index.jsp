<jsp:directive.taglib prefix="app" uri="/WEB-INF/tld/page.tld"/>

<app:page title="[Physia] Main Menu" heading="Main Menu">
		<table width=100% bgcolor="#EEEEEE" cellspacing="0" cellpadding="0" border="0"><tr><form><td align="right">
		<!--
			$functions
			$addFunctions
		-->
		</td></form></tr><tr><td>
			<img src="/aspire/resources/design/bar.gif" width="1" height="1" border="0"><br>
			<!-- @{[ getImageTag('design/bar', { width => "100%", height => "1", }) ]}<br> -->
		</td></tr></table>
		<center>
		<table border="0" cellspacing="0" cellpadding="5" align="center"><tr valign="top"><td>
			<table bgcolor="white" border="0" cellspacing="1" cellpadding="2"><tr valign="top" bgcolor="white"><td valign="middle">
				<img src="/aspire/resources/images/page-icons/person.gif" width="32" height="32" border="0">
				<!-- $IMAGETAGS{'images/page-icons/person'} -->
			</td><td valign="middle">
				<font face="arial,helvetica" size=5 color=navy><b>People</b></font>
			</td></tr><tr><td colspan="2">
				<img src="/aspire/resources/design/bar.gif" width="100%" height="1" border="0"><br>
				<!-- @{[ getImageTag('design/bar', { height => "1", width => "100%", }) ]}<br> -->
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<app:link url="/search/person">All Persons</app:link>,
					<app:link url="/search/patient">Patients</app:link>,
					<app:link url="/search/insured-Person">Insured Persons</app:link>,
					<app:link url="/search/physician">Physician / Providers</app:link>,
					<app:link url="/search/referring-Doctor">Referring Doctors</app:link>,
					<app:link url="/search/nurse">Nurses</app:link>,
					<app:link url="/search/staff">Staff Members</app:link>, or
					<app:link url="/search/associate">Personnel</app:link>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new <app:link url="/org/${session:org_id}/dlg-add-patient">Patient</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-physician">Physician / Provider</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-referring-doctor">Referring Doctor</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-nurse">Nurse</app:link>, or
					<app:link url="/org/${session:org_id}/dlg-add-staff">Staff Member</app:link>
				</font>
			</td></tr></table>
			<p>
			<table bgcolor="white" border="0" cellspacing="1" cellpadding="2"><tr valign="top" bgcolor="white"><td valign="middle">
				<img src="/aspire/resources/images/page-icons/org.gif" width="32" height="32" border="0">
				<!-- $IMAGETAGS{'images/page-icons/org'} -->
			</td><td valign="middle">
				<font face="arial,helvetica" size="5" color="navy"><b>Organizations</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/aspire/resources/design/bar.gif" height=1 width=100%><br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<app:link url="/search/org">Departments</app:link>,
					<app:link url="/search/org">Associated Providers</app:link>,
					<app:link url="/search/org">Pharmacies</app:link>,
					<app:link url="/search/org">Employers</app:link>,
					<app:link url="/search/org">Insurers</app:link>,
					<app:link url="/search/org">IPAs</app:link>, or
					<app:link url="/search/org">Ancillary Service</app:link>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<app:link url="/org/${session:org_id}/dlg-add-org-dept">Department</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-org-provider">Associated Provider</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-org-pharmacy">Pharmacy</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-org-employer">Employer</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-org-insurance">Insurance</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-org-ipa">IPA</app:link>, or
					<app:link url="/org/${session:org_id}/dlg-add-org-ancillary">Ancillary Service</app:link>
				</font>
			</td></tr></table>
			<p>
			<table bgcolor="white" border="0" cellspacing="1" cellpadding="2"><tr valign="top" bgcolor="white"><td valign="middle">
				<img src="/aspire/resources/images/page-icons/reference.gif" width="32" height="28" border="0">
				<!-- $IMAGETAGS{'images/page-icons/reference'} -->
			</td><td valign="middle">
				<font face="arial,helvetica" size="5" color="navy"><b>References / Codes</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/aspire/resources/design/bar.gif" height=1 width=100%><br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<app:link url="/search/icd">ICD-9</app:link>,
					<app:link url="/search/cpt">CPT</app:link>,
					<app:link url="/search/hcpcs">HCPCS</app:link>,
					<app:link url="/search/epsdt">EPSDT</app:link>,
					<app:link url="/search/miscprocedure">Misc Procedure Code</app:link>,
					<app:link url="/search/modifier">Modifier</app:link>,
					<app:link url="/search/serviceplace">Service Place</app:link>,
					<app:link url="/search/servicetype">Service Type</app:link>,
					<app:link url="/search/gpci">GPCI</app:link>, or
					<app:link url="/search/epayer">E-Remit Payer</app:link>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<app:link url="/org/${session:org_id}/dlg-add-misc-procedure">Misc Procedure Code</app:link>
				</font>
		</td></tr></table></td><td>
			<table bgcolor=white border=0 cellspacing=1 cellpadding=2><tr valign=top bgcolor=white><td valign="middle">
				<img src="/aspire/resources/images/page-icons/reference.gif" width="32" height="28" border="0">
				<!-- $IMAGETAGS{'images/page-icons/accounting'} -->
			</td><td valign="middle">
				<font face="arial,helvetica" size=5 color=navy><b>Accounting / Billing</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/aspire/resources/design/bar.gif" height=1 width=100%></td></tr>
			<tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<app:link url="/search/claim">Claims</app:link>,
					<app:link url="/search/catalog">Fee Schedules</app:link>,
					<app:link url="/search/insproduct">Insurance Product</app:link>, or
					<app:link url="/search/insplan">Insurance Plan</app:link>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<app:link url="/org/${session:org_id}/dlg-add-claim">Claim</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-claim?isHosp=1">Hospital Claim</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-batch">Batch Payment</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-postcappayment">Monthly Cap Payment</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-close-date">Close Date</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-catalog">Fee Schedule</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-catalog-item">Fee Schedule Item</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-ins-product">Insurance Product</app:link>,
					<app:link url="/org/${session:org_id}/dlg-add-ins-plan">Insurance Plan</app:link>, or
					<app:link url="/org/${session:org_id}/dlg-add-ins-coverage">Personal Insurance Coverage</app:link>
				</font>
			</td></tr></table>
			<p>
			<table bgcolor=white border=0 cellspacing=1 cellpadding=2><tr valign=top bgcolor=white><td valign="middle">
				<img src="/aspire/resources/images/page-icons/schedule.gif" width="32" height="32" border="0">
				<!-- $IMAGETAGS{'images/page-icons/schedule'} -->
			</td><td valign="middle">
				<font face="arial,helvetica" size="5" color="navy"><b>Appointments / Scheduling</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/aspire/resources/design/bar.gif" height=1 width=100%><br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<app:link url="/search/appointment">Existing Appointment</app:link>,
					<app:link url="/search/apptslot">Next Available Appointment Slot</app:link>
					<app:link url="/search/template">Scheduling Template</app:link>, or
					<app:link url="/search/appttype">Appointment Type</app:link>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<app:link url="/schedule/dlg-add-appointment?_dialogreturnurl=/menu">Appointment</app:link>
					<app:link url="/schedule/dlg-add-template?_dialogreturnurl=/menu">Schedule Template</app:link>, or
					<app:link url="/schedule/dlg-add-appttype?">Appointment Type</app:link>
				</font>
			</td></tr></table>
			<p>
			<table bgcolor=white border=0 cellspacing=1 cellpadding=2><tr valign=top bgcolor=white><td valign="middle">
				<img src="/aspire/resources/images/page-icons/tools.gif" width="32" height="32" border="0">
				<!-- $IMAGETAGS{'images/page-icons/tools'} -->
			</td><td valign="middle">
				<font face="arial,helvetica" size="5" color="navy"><b>Utilities / Functions</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/aspire/resources/design/bar.gif" height=1 width=100%><br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Print Destination</b>
					<app:link url="/utilities/printerSpec" hint="Select paper-claim printer">Paper Claims Printer</app:link>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Paper Claims</b>
					<app:link url="/utilities" hint="Create a new batch of paper claims for printing">Create new Batch</app:link>,&nbsp;
					<app:link url="/paperclaims" hint="Print a batch of paper claims">Print</app:link>
				</font>

			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>EDI Reports</b>
					<app:link url="/edi" hint="View reports from Clearing House">View</app:link>
				</font>

			</td></tr><tr valign=top bgcolor=white><td align="right">
				<img src="/aspire/resources/icons/arrow-right-red.gif" width="14" height="12" border="0">
				<!-- $IMAGETAGS{'icons/arrow_right_red'} -->
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Reports</b>
					<app:link url="/report/Accounting" hint="View reports ">Accounting</app:link>,&nbsp;
					<app:link url="/report/Billing" hint="View reports">Billing</app:link>,&nbsp;
					<app:link url="/report/Scheduling" hint="View reports">Scheduling</app:link>
				</font>

			</td></tr></table>
		</td></tr></table>

		</td></tr></table>
		</center>
</app:page>