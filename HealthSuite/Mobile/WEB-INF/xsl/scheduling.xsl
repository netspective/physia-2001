<?xml version="1.0"?>

<xsl:stylesheet version="1.0">

<xsl:output method="html" disable-output-escaping="true"/>

<xsl:template match="appointments">
	<!--
		This tag is called as
		<appointments person-id="SJONES" date="MM/DD/YYYY" status="abc"/>
			* person-id is optional, defaults to logged in user's person id
			* date is optional, defaults to session's active_date_str
			* status optional, defaults to "any/all" -- one of 'waiting', 'in-progress', or 'completed'
	-->
	<jsp:scriptlet>
		activeSql =
			"select to_char(e.start_time + ?, 'hh24:mi') as \"Time\",\n"+
			"	patient.short_sortable_name as \"Patient\", e.subject as \"Reason\", at.caption as \"Type\", Appt_Status.caption as \"Status\", patient.person_id\n"+
			"from 	Appt_Status, Appt_Attendee_type aat, Person patient, Person provider,\n"+
			"	Event_Attribute ea, Appt_Type at, Event e\n"+
			"where e.start_time between to_date(?, 'mm/dd/yyyy hh24:mi') - ?\n"+
			"	and to_date(?, 'mm/dd/yyyy hh24:mi') - ?\n"+
			"	and e.discard_type is null\n"+
			"	and at.appt_type_id (+) = e.appt_type\n"+
			"	and ea.parent_id = e.event_id\n"+
			"	and ea.value_type = 333\n"+
			"	and ea.value_text = patient.person_id\n"+
			"	and ea.value_textB = provider.person_id\n"+
			"	and\n"+
			"	(	ea.value_textB = ? or\n"+
			"		ea.value_textB in\n"+
			"		(select value_text\n"+
			"			from person_attribute\n"+
			"			where parent_id = ?\n"+
			"				and item_name = 'WorkList'\n"+
			"				and value_type = 250\n"+
			"				and parent_org_id = ?\n"+
			"		)\n"+
			"	)\n"+
			"	and aat.id = ea.value_int\n"+
			"	and at.appt_type_id (+) = e.appt_type\n"+
			"	and Appt_Status.id = e.event_status\n"+
		<xsl:if test="@status = 'waiting'">
			"	and e.event_status = 0\n" +
		</xsl:if>
		<xsl:if test="@status = 'in-progress'">
			"	and e.event_status = 1\n" +
		</xsl:if>
		<xsl:if test="@status = 'completed'">
			"	and e.event_status = 2\n" +
		</xsl:if>
			"order by e.start_time";
		try
		{
			stmt = dbms.prepareStatement(activeSql);
			<xsl:choose>
				<xsl:when test="@person-id">
					String personId = "<xsl:value-of select="@person-id"/>";
				</xsl:when>
				<xsl:otherwise>
					String personId = (String) session.getAttribute("user_id");
				</xsl:otherwise>
			</xsl:choose>
			<xsl:choose>
				<xsl:when test="@date">
					String activeDate = "<xsl:value-of select="@date"/>";
				</xsl:when>
				<xsl:otherwise>
					String activeDate = (String) session.getAttribute("active_date_str");
				</xsl:otherwise>
			</xsl:choose>

			int paramNum = 0;
			float tzOffsetDays = ((Float) session.getAttribute("tz_gmt_offset_days")).floatValue();
			stmt.setFloat(++paramNum, tzOffsetDays);
			stmt.setString(++paramNum, activeDate + " 00:00");
			stmt.setFloat(++paramNum, tzOffsetDays);
			stmt.setString(++paramNum, activeDate + " 23:59");
			stmt.setFloat(++paramNum, tzOffsetDays);
			stmt.setString(++paramNum, personId);
			stmt.setString(++paramNum, personId);
			stmt.setInt(++paramNum, ((Integer) session.getAttribute("org_internal_id")).intValue());

			rs = stmt.executeQuery();
			while(rs.next())
			{
				<![CDATA[
				out.print(
					rs.getString(1) + // the start time
					" <b><a href=\"person.xtp?pid="+rs.getString(6)+"&name="+rs.getString(2)+"\">"
						+ rs.getString(2) + "</a></b> (" +
					rs.getString(5).substring(0, 1) +
					")<br><img src=\"spacer.gif\"><img src=\"spacer.gif\"><img src=\"spacer.gif\"><img src=\"spacer.gif\"><img src=\"spacer.gif\">" +
					rs.getString(3) + " " +
					(rs.getString(4) != null ? "(" + rs.getString(4) + ")" : "") +
					"<br>"
					);
				]]>
			}
			rs.close();
		}
		catch(Exception e)
		{
			out.print(dbms.formatExceptionMsg(e, activeSql));
		}

	</jsp:scriptlet>
</xsl:template>

<xsl:template match="in-patients">
	<!--
		This tag is called as
		<appointments person-id="SJONES" date="MM/DD/YYYY" status="abc"/>
			* person-id is optional, defaults to logged in user's person id
			* org_internal_id
			*
	-->
	<jsp:scriptlet>
		activeSql =
			"select related_data as hospital_name, \n" +
				"caption as room, \n" +
				"simple_name as patient_name, \n" +
				"provider_id, \n" +
				"trans_owner_id as patient_id, \n" +
				"trans_status_reason as complaint \n" +
			"from Person, Transaction \n" +
			"where trans_type between 11000 and 11999 \n" +
				"and trans_status = 2 \n" +
				"and trans_begin_stamp >= sysdate - data_num_a \n" +
				"and \n" +
				"(provider_id = ? OR provider_id in \n" +
					"( \n" +
						"select value_text from person_attribute \n" +
						"where parent_id = ? \n" +
							"and value_type = 250 \n" +
							"and item_name = 'WorkList' \n" +
							"and parent_org_id = ? \n" +
					") \n" +
				") \n" +
				"and person.person_id = transaction.trans_owner_id \n";

		try
		{
			stmt = dbms.prepareStatement(activeSql);
			<xsl:choose>
				<xsl:when test="@person-id">
					String personId = "<xsl:value-of select="@person-id"/>";
				</xsl:when>
				<xsl:otherwise>
					String personId = (String) session.getAttribute("user_id");
				</xsl:otherwise>
			</xsl:choose>

			int paramNum = 0;
			stmt.setString(++paramNum, personId);
			stmt.setString(++paramNum, personId);
			stmt.setInt(++paramNum, ((Integer) session.getAttribute("org_internal_id")).intValue());

			rs = stmt.executeQuery();
			while(rs.next())
			{
				<![CDATA[
				out.print(
					"<b>" + rs.getString(1) + "</b>" + // Hospital
					"<br><b><a href=\"person.xtp?pid="+rs.getString(5)+"&name="+rs.getString(3)+"\">"+rs.getString(3)+"</a></b>" +
					" (" + rs.getString(4) + ")" +
					"<br>" + rs.getString(6) +
					"<br>Room: " + (rs.getString(2) != null ? rs.getString(2) : "N/A") +
					"<br> <br>"
					);
				]]>
			}
			rs.close();
		}
		catch(Exception e)
		{
			out.print(dbms.formatExceptionMsg(e, activeSql));
		}

	</jsp:scriptlet>
</xsl:template>

</xsl:stylesheet>