<?xml version="1.0"?>

<xsl:stylesheet version="1.0">
<xtp:declaration>
	String options = null;
</xtp:declaration>

<xsl:output method="html" disable-output-escaping="true"/>

<xsl:template match="dialog">
	<form>
		<xsl:apply-templates/>
	</form>
</xsl:template>

<xsl:template match="field-active-patient">
	Patient: <jsp:expression>session.getAttribute("active-person-name")</jsp:expression>
	<xsl:if test="not(@break) or @break = 'yes'"><![CDATA[<br>]]></xsl:if>
</xsl:template>

<xsl:template match="field-text">
	<xsl:if test="caption | @caption">
		<xsl:value-of select="caption | @caption"/>: 
	</xsl:if>
	<xsl:if test="@rows or @cols">
	<input name="{@name}" type="text" rows="{@rows}" cols="{@cols}"/>
	</xsl:if>
	<xsl:if test="not(@rows or @cols)">
	<input name="{@name}" type="text" size="{@size}"/>
	</xsl:if>
	<xsl:if test="not(@break) or @break = 'yes'"><![CDATA[<br>]]></xsl:if>
</xsl:template>

<xsl:template match="field-date">
	<xsl:if test="caption | @caption">
		<xsl:value-of select="caption | @caption"/>: 
	</xsl:if>
	<![CDATA[
	<input name="{@name}" type="text" size="{@size}" value="<jsp:expression>session.getAttribute("active_date_str")</jsp:expression>"/>
	]]>
	<xsl:if test="not(@break) or @break = 'yes'"><![CDATA[<br>]]></xsl:if>
</xsl:template>

<xsl:template match="field-bool">
	<input name="{@name}" type="checkbox"/>
	<xsl:if test="caption | @caption">
		<xsl:value-of select="caption | @caption"/>
	</xsl:if>
	<xsl:if test="not(@break) or @break = 'yes'"><![CDATA[<br>]]></xsl:if>
</xsl:template>

<xsl:template match="field-buttons">
	<input type="submit" value="Submit"/>
</xsl:template>

<xsl:template match="field-choose">
	<xsl:if test="caption | @caption">
		<xsl:value-of select="caption | @caption"/>: 
	</xsl:if>
	<xsl:if test="not(@style) or @style = 'list' or @style = 'combo'">
		<xsl:if test="@options">
		<xtp:scriptlet>
			StringTokenizer optionsTok = new StringTokenizer(((CauchoElement) node).getAttribute("options"), ";");
			options = "";
			<![CDATA[
			while(optionsTok.hasMoreTokens())		
				options += "<option>" + optionsTok.nextToken() + "</option>";
			]]>
		</xtp:scriptlet>
		</xsl:if>
		<xsl:if test="(not(@style) or @style = 'combo') and (not(@size) or (number(@size) < 2))">
			<select name="{@name}" size="1">
				<xtp:expression>options</xtp:expression>
			</select>
		</xsl:if>
		<xsl:if test="@style = 'list' or (@size and number(@size) > 1)">
			<select name="{@name}" size="{@size}">
				<xtp:expression>options</xtp:expression>
			</select>
		</xsl:if>
	</xsl:if>
	<xsl:if test="@style = 'radio' or @style = 'check'">
	</xsl:if>
	<xsl:if test="not(@break) or @break = 'yes'"><![CDATA[<br>]]></xsl:if>
</xsl:template>

</xsl:stylesheet>