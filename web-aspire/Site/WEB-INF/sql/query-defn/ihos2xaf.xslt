<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="xml" indent="yes"/>

<xsl:template match="component">
	<xaf>
		<xsl:for-each select="query-defn">
			<query-defn>
			<xsl:attribute name="id">
				<xsl:value-of select="@id"/>
			</xsl:attribute>
			<xsl:attribute name="caption">
				<xsl:value-of select="@caption"/>
			</xsl:attribute>
			<xsl:attribute name="dbms">
				<xsl:value-of select="@db"/>
			</xsl:attribute>
			<xsl:for-each select="field">
				<field>
				<xsl:attribute name="id">
					<xsl:value-of select="@id"/>
				</xsl:attribute>
				<xsl:attribute name="caption">
					<xsl:value-of select="@caption"/>
				</xsl:attribute>
				<xsl:if test="@ui-datatype">
				<xsl:attribute name="dialog-field">field.<xsl:value-of select="@ui-datatype"/></xsl:attribute>
				</xsl:if>				
				<xsl:attribute name="join">
					<xsl:value-of select="@join"/>
				</xsl:attribute>
				<xsl:if test="@column">
				<xsl:attribute name="column">
					<xsl:value-of select="@column"/>
				</xsl:attribute>
				</xsl:if>
				<xsl:if test="@columndefn">
				<xsl:attribute name="column-expr">
					<xsl:value-of select="@columndefn"/>
				</xsl:attribute>
				</xsl:if>
				</field>
			</xsl:for-each>
			<xsl:for-each select="join">
				<xsl:if test="not(@include)">
				<join>
				<xsl:attribute name="id">
					<xsl:value-of select="@id"/>
				</xsl:attribute>
				<xsl:attribute name="table">
					<xsl:value-of select="@table"/>
				</xsl:attribute>
				<xsl:if test="@requires">
				<xsl:attribute name="imply-join">
					<xsl:value-of select="@requires"/>
				</xsl:attribute>
				</xsl:if>
				<xsl:if test="autoinclude = '1'">				
					<xsl:attribute name="autoinclude">
					<xsl:value-of select="@columndefn"/>
					</xsl:attribute>
				</xsl:if>
				<xsl:if test="@condition">
				<xsl:attribute name="condition">
					<xsl:value-of select="@condition"/>
				</xsl:attribute>
				</xsl:if>
				</join>
				</xsl:if>
			</xsl:for-each>
			<xsl:for-each select="view">
				<select>
				<xsl:attribute name="id">
					<xsl:value-of select="@id"/>
				</xsl:attribute>
				<xsl:attribute name="heading">
					<xsl:value-of select="@caption"/>
				</xsl:attribute>
				<xsl:if test="distinct">				
					<xsl:attribute name="distinct">
					<xsl:value-of select="@distinct"/>
					</xsl:attribute>
				</xsl:if>
				<xsl:for-each select="column">
					<display>
					<xsl:attribute name="field">
					<xsl:value-of select="@id"/>
					</xsl:attribute>
					</display>
				</xsl:for-each>
				<xsl:for-each select="order-by">
					<order-by>
					<xsl:if test="not(contains(@id, '{'))">
						<xsl:attribute name="field">
						<xsl:value-of select="@id"/>
						</xsl:attribute>
					</xsl:if>
					<xsl:if test="contains(@id, '{')">
						<xsl:attribute name="column-expr">
						<xsl:value-of select="@id"/>
						</xsl:attribute>
					</xsl:if>
					</order-by>
				</xsl:for-each>
				<xsl:for-each select="condition">
				<condition>
					<xsl:attribute name="field">
					<xsl:value-of select="@field"/>
					</xsl:attribute>
					<xsl:attribute name="comparison">
					<xsl:value-of select="@comparison"/>
					</xsl:attribute>
					<xsl:attribute name="value">
					<xsl:value-of select="@criteria"/>
					</xsl:attribute>						
				</condition>
				</xsl:for-each>
				<xsl:for-each select="and-conditions">
					<xsl:for-each select="condition">
					<condition>
						<xsl:attribute name="field">
						<xsl:value-of select="@field"/>
						</xsl:attribute>
						<xsl:attribute name="comparison">
						<xsl:value-of select="@comparison"/>
						</xsl:attribute>
						<xsl:attribute name="value">
						<xsl:value-of select="@criteria"/>
						</xsl:attribute>						
						<xsl:if test="position() != last()">
							<xsl:attribute name="connector">and</xsl:attribute>
						</xsl:if>
					</condition>
					</xsl:for-each>
				</xsl:for-each>
				</select>
			</xsl:for-each>
			</query-defn>
		</xsl:for-each>
	</xaf>
</xsl:template>

</xsl:stylesheet>