<?xml version="1.0"?>

<xsl:stylesheet version="1.0">

<xsl:output method="html" disable-output-escaping="true"/>

<xtp:directive.page import="com.physia.*"/>

<jsp:directive.page import="java.text.*"/>
<jsp:directive.page import="java.sql.*"/>
<jsp:directive.page import="com.caucho.xml.*"/>
<jsp:directive.page import="org.w3c.dom.*"/>
<jsp:directive.page import="com.physia.*"/>

<jsp:declaration>
	Node tableNode = null;
	PreparedStatement stmt = null;
	String activeSql = null;
	SimpleDateFormat dateFormatShort = new SimpleDateFormat("MM/dd/yyyy");
	SimpleDateFormat dateFormatText = new SimpleDateFormat("EE, MMM dd, yy");
	ResultSet rs = null;
</jsp:declaration>

<!-- copy everything not matching to the output -->
<xsl:template match="*|@*">
  <xsl:copy>
    <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
</xsl:template>

<xsl:template match="page">
	<html>
	<head><title><xsl:value-of select="@heading | heading"/></title></head>

	<xsl:apply-templates/>

	</html>
</xsl:template>

<xsl:template match="menu">

	<ul>
	<xsl:for-each select="menu-item">
		<li><a href="{@href}.xtp"><xsl:value-of select="@caption"/></a></li>
	</xsl:for-each>
	</ul>

</xsl:template>

<xsl:template match="active-user">
<jsp:expression>(String) session.getAttribute("user_id")</jsp:expression>
</xsl:template>

<xsl:template match="active-org">
<jsp:expression>(String) session.getAttribute("org_id")</jsp:expression>
</xsl:template>

<xsl:template match="active-user-org">
<jsp:expression>(String) session.getAttribute("user_id") + "@" + (String) session.getAttribute("org_id")</jsp:expression>
</xsl:template>

<xsl:template match="active-date">
<jsp:expression>dateFormatText.format(session.getAttribute("active_date"))</jsp:expression>
</xsl:template>

<xsl:template match="active-person-id">
<jsp:expression>(String) session.getAttribute("active-person-id")</jsp:expression>
</xsl:template>

<xsl:include href="scheduling.xsl"/>
<xsl:include href="dialog.xsl"/>
<xsl:include href="person.xsl"/>

</xsl:stylesheet>