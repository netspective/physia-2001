package app;

import java.io.*;
import java.util.*;
import java.sql.*;
import javax.servlet.http.*;

import com.xaf.db.*;
import com.xaf.form.*;
import com.xaf.security.*;
import com.xaf.skin.*;
import com.xaf.sql.*;
import com.xaf.value.*;
import com.xaf.config.ConfigurationManager;
import com.xaf.config.ConfigurationManagerFactory;
import com.xaf.config.Configuration;

public class AppLoginDialog extends LoginDialog
{
	protected StandardDialogSkin skin;

	public void initialize()
	{
		super.initialize();

		skin = new StandardDialogSkin();
		skin.setOuterTableAttrs("cellspacing='1' cellpadding='0'");
		skin.setInnerTableAttrs("cellspacing='0' cellpadding='4'");
		skin.setCaptionFontAttrs("size='2' face='tahoma,arial,helvetica' style='font-size:8pt' color='navy'");

		setHeading((SingleValueSource) null);
	}

	public DialogSkin getSkin()
	{
		return skin;
	}

	public void producePage(DialogContext dc, Writer writer) throws IOException
	{
		String resourcesUrl = ((HttpServletRequest) dc.getRequest()).getContextPath() + "/resources";

		writer.write("<head>");
		writer.write("<title>Welcome to CURA</title>");
		writer.write("</head>");
		writer.write("<body background='white'>");
		writer.write("	<center><br>");
		writer.write("		<img src='"+ resourcesUrl +"/images/design/logo-main.gif' border='0'>");
		writer.write("		<p>");
		writer.write(       getHtml(dc, true));
		writer.write("	</center>");
		writer.write("</body>");
	}

    public boolean isValid(DialogContext dc)
    {
		if(! super.isValid(dc))
			return false;

		try
		{

			String userIdProvided = dc.getValue("user_id");

			DatabaseContext dbc = DatabaseContextFactory.getContext(dc);
			StatementManager stmtMgr = StatementManagerFactory.getManager(dc.getServletContext());

			StatementManager.ResultInfo ri = stmtMgr.execute(dbc, dc, null, "security.login-info", new Object[] { userIdProvided });
			Object[] loginInfo = stmtMgr.getResultSetSingleRowAsArray(ri.getResultSet());
			ri.close();

			if(loginInfo == null)
			{
				DialogField userIdField = dc.getDialog().findField("user_id");
				userIdField.invalidate(dc, "User id '"+ userIdProvided +"' is not valid.");
				return false;
			}

			String personId = loginInfo[0].toString();
			String password = loginInfo[1].toString();
			String passwordProvided = dc.getValue("password");

			if(! passwordProvided.equals(password))
			{
				DialogField passwordField = dc.getDialog().findField("password");
				passwordField.invalidate(dc, "Password is not valid.");
				return false;
			}

			dc.getRequest().setAttribute("user-person-id", personId);
		}
		catch(Exception e)
		{
			DialogField userIdField = dc.getDialog().findField("user_id");
			userIdField.invalidate(dc, e.toString());
			return false;
		}

		return true;
    }

	public AuthenticatedUser createUserData(DialogContext dc)
	{
		String personId = (String) dc.getRequest().getAttribute("user-person-id");
		Map personRegistration = null;
		Map memberOrgs = new HashMap();

		try
		{
			DatabaseContext dbc = DatabaseContextFactory.getContext(dc);
			StatementManager stmtMgr = StatementManagerFactory.getManager(dc.getServletContext());

			StatementManager.ResultInfo ri = stmtMgr.execute(dbc, dc, null, "person.active-org-memberships", new Object[] { personId });
			ResultSet rs = ri.getResultSet();
			while(rs.next())
			{
				/* col 1 is the org_id, col 2 is org_name */
				memberOrgs.put(rs.getString(1), rs.getString(2));
			}
			ri.close();

			ri = stmtMgr.execute(dbc, dc, null, "person.registration", new Object[] { personId });
			personRegistration = stmtMgr.getResultSetSingleRowAsMap(ri.getResultSet());
			ri.close();
		}
		catch(Exception e)
		{
			throw new RuntimeException(e.toString());
		}

		if(personRegistration == null)
			return null;

		AuthenticatedUser user = new BasicAuthenticatedUser(dc.getValue("user_id"), (String) personRegistration.get("complete_name"));
		user.setAttribute("person-id", personId);
		user.setAttribute("registration", personRegistration);
		user.setAttribute("member-orgs", memberOrgs);

		return user;
	}
}