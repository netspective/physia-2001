package com.physia;

import java.io.*;
import java.util.*;
import java.sql.*;
import javax.sql.*;
import javax.naming.*;
import javax.xml.parsers.*;
import org.w3c.dom.*;
import com.caucho.xml.*;

public class dbms
{
	static public HashMap sqlStatements = new HashMap();

	static public Connection getConnection(String dataSrcName) throws NamingException, SQLException
	{
		Context jndiEnv = (Context) new InitialContext().lookup("java:comp/env");
		DataSource source = (DataSource) jndiEnv.lookup(dataSrcName);
		return source.getConnection();
	}

	static public Connection getConnection() throws NamingException, SQLException
	{
		return getConnection("jdbc/physiadb");
	}

	static public PreparedStatement prepareStatement(String query) throws NamingException, SQLException
	{
		return getConnection().prepareStatement(query);
	}

	static public PreparedStatement prepareStatement(Connection conn, String query) throws NamingException, SQLException
	{
		return conn.prepareStatement(query);
	}

	static public Node resultSetToHtml(ResultSet rs) throws NamingException, SQLException, IOException, ParserConfigurationException
	{
		// Create a new parser using the JAXP API (javax.xml.parser)
		DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
		DocumentBuilder fbuilder = factory.newDocumentBuilder();

		// Create a new document
		Document doc = fbuilder.newDocument();

		DOMBuilder builder = new DOMBuilder();
		builder.init(doc);
		builder.startDocument();
		builder.startElement("", "table", "table");

		ResultSetMetaData rsmd = rs.getMetaData();
		builder.startElement("", "tr", "tr");
		for(int i = 1; i <= rsmd.getColumnCount(); i++)
		{
			builder.startElement("", "th", "th");
			builder.text(rsmd.getColumnName(i));
			builder.endElement("", "th", "th");
		}
		builder.endElement("", "tr", "tr");

		while(rs.next())
		{
			builder.startElement("", "tr", "tr");
			for(int i = 1; i <= rsmd.getColumnCount(); i++)
			{
				builder.startElement("", "td", "td");
				builder.text(rs.getString(i) != null ? rs.getString(i) : "");
				builder.endElement("", "td", "td");
			}
			builder.endElement("", "tr", "tr");
		}
		rs.close();

		builder.endElement("", "table", "table");
		builder.endDocument();
		return builder.getNode();
	}

	static public Node queryToHtml(Connection conn, String query) throws NamingException, SQLException, IOException, ParserConfigurationException
	{
		Statement stmt = conn.createStatement();
		ResultSet rs = stmt.executeQuery(query);
		Node node = resultSetToHtml(rs);
		stmt.close();
		return node;
	}

	static public Node queryToHtml(String query) throws NamingException, SQLException, IOException, ParserConfigurationException
	{
		return queryToHtml(getConnection(), query);
	}

	static public String formatExceptionMsg(Exception e, String query)
	{
		return "<p><b>Error in query</b></p><pre>"+ e.getMessage() + "\n" + query +"</pre>";
	}

}