<jsp:directive.taglib prefix="app" uri="/WEB-INF/tld/page.tld"/>

<app:page title="Cura" heading="Welcome to Cura">

	<b>Accounts</b><br/>
	&nbsp;&nbsp;<app:link url="/account/index.jsp?cmd=dialog,org.registration,add">Create new Account</app:link><br/>
	&nbsp;&nbsp;<app:link url="/account/browse.jsp">Review Accounts</app:link><br/>
	<b>Contacts</b><br/>
	&nbsp;&nbsp;<app:link url="/resources/pages">Create new Contact</app:link><br/>
	&nbsp;&nbsp;<app:link url="/resources/pages">Review Contacts</app:link><br/>

	<p>
	<app:link url="/resources/pages">Leads</app:link><br/>
	<app:link url="/resources/pages">Opportunities</app:link><br>
	<app:link url="/resources/pages">Projects</app:link><p>

</app:page>