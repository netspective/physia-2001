package app;

import java.io.*;
import java.util.*;
import java.sql.*;
import javax.servlet.http.*;
import javax.naming.NamingException;

import com.xaf.db.*;
import com.xaf.form.*;
import com.xaf.form.field.TextField;
import com.xaf.form.field.SelectField;
import com.xaf.form.field.BooleanField;
import com.xaf.form.field.SeparatorField;
import com.xaf.security.*;
import com.xaf.skin.*;
import com.xaf.sql.*;
import com.xaf.value.*;
import com.xaf.config.ConfigurationManager;
import com.xaf.config.ConfigurationManagerFactory;
import com.xaf.config.Configuration;

public class AppLoginDialog extends LoginDialog
{
	protected TextField aspireUserIdField;
	protected TextField aspirePasswordField;
	protected SelectField timeZone;
	protected BooleanField sessionLogout;
	protected SelectField nextAction;
	protected StandardDialogSkin skin;

	public TextField createUserIdField()
	{
		TextField result = new TextField("person_id", "User ID");
		result.setFlag(DialogField.FLDFLAG_REQUIRED);
		result.setFlag(DialogField.FLDFLAG_INITIAL_FOCUS);
		return result;
	}

	public TextField createPasswordField()
	{
		TextField result = new TextField("password", "Password");
		result.setFlag(DialogField.FLDFLAG_REQUIRED | TextField.FLDFLAG_MASKENTRY);
		return result;
	}

	public void initialize()
	{
		this.setHeading("Please Login");
		this.setName("login");

		aspireUserIdField = createUserIdField();
		aspirePasswordField = createPasswordField();
		timeZone = new SelectField("timezone", "Time Zone", SelectField.SELECTSTYLE_COMBO, "GMT=GMT;US-Atlantic=AST4ADT;US-Eastern=EST5EDT;US-Central=CST6CDT;US-Mountain=MST7MDT;US-Pacific=PST8PDT");
		sessionLogout = new BooleanField("clear_sessions", "Logout of all active sessions", BooleanField.BOOLSTYLE_CHECK, BooleanField.CHOICES_YESNO);
		nextAction = new SelectField("nextaction_redirecturl", "Start Page", SelectField.SELECTSTYLE_COMBO, "Worklist=/worklist;Home=/home;Main Menu=/menu;Schedule=/schedule");

		addField(aspireUserIdField);
		addField(aspirePasswordField);
		addField(timeZone);
		addField(sessionLogout);
		addField(nextAction);
		addField(new DialogDirector());

		skin = new StandardDialogSkin();
		skin.setOuterTableAttrs("cellspacing='1' cellpadding='0'");
		skin.setInnerTableAttrs("cellspacing='0' cellpadding='4'");
		skin.setCaptionFontAttrs("size='2' face='tahoma,arial,helvetica' style='font-size:8pt' color='navy'");
	}

	public DialogSkin getSkin()
	{
		return skin;
	}

	public void producePage(DialogContext dc, Writer writer) throws IOException
	{
		String resourcesUrl = ((HttpServletRequest) dc.getRequest()).getContextPath() + "/resources";

		writer.write("<head>");
		writer.write("<title>[Physia]</title>");
		writer.write("</head>");
		writer.write("<body background='white'>");
		writer.write("	<center><br>");
		writer.write("		<img src='"+ resourcesUrl +"/images/welcome.gif' border='0'>");
		writer.write("		<p>");
		writer.write(       getHtml(dc, true));
		writer.write("	</center>");
		writer.write("</body>");
	}

	public boolean isValid(DialogContext dc)
    {
		if(! super.isValid(dc))
			return false;

		if (! isValidUser(dc))
			return false;

		if (! isValidPassword(dc))
			return false;

		String personId = dc.getValue(aspireUserIdField);
		dc.getRequest().setAttribute("person_id", personId);

		return true;
    }

	public boolean isValidUser(DialogContext dc) {
		boolean status = false;
		DatabaseContext dbc = dc.getDatabaseContext();
		StatementManager stmtMgr = dc.getStatementManager();
		String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");
		String userId = dc.getValue(aspireUserIdField);

		try
		{
			status = stmtMgr.stmtRecordExists(dbc, dc, dataSrcId, "person.selPersonCategoryExists", new Object[] { userId });
		}
		catch (Exception e)
		{
			aspireUserIdField.invalidate(dc, e.toString() + " thrown while validating userIdField");
		}

		return status;
	}

	public boolean isValidPassword(DialogContext dc) {
		boolean status = false;

		DatabaseContext dbc = dc.getDatabaseContext();
		StatementManager stmtMgr = dc.getStatementManager();
		String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");
		String userId = dc.getValue(aspireUserIdField);
		String password = dc.getValue(aspirePasswordField);

		Map loginInfo = null;
		try
		{
			loginInfo = stmtMgr.executeStmtGetValuesMap(dbc, dc, dataSrcId, "person.selLoginAnyOrg", new Object[] { userId });
		}
		catch (Exception e)
		{
			aspirePasswordField.invalidate(dc, e.toString() + " thrown while executing person.selLoginAnyOrg");
		}

		// Invalidate login if no record of this user/pass exists in database
        if (loginInfo.isEmpty()) {
			aspirePasswordField.invalidate(dc, userId + " is not allowed to login (no password specified in system for given Organization ID");
			return status;
		}

		// Invalidate if password mismatch
		if (!password.equals(loginInfo.get("password"))) {
			aspirePasswordField.invalidate(dc, "Invalid password specified for " + userId + "@" + (String) loginInfo.get("org_internal_id"));
			return status;
		}

		// Invalidate if too many sessions
		int activeSessions = Integer.parseInt((String) loginInfo.get("quantity"));
        if (dc.getValue(sessionLogout).equalsIgnoreCase("no")) {
			if (dc.getValue("org_id").equals("")) {
				try {
					stmtMgr.execute(dbc, dc, dataSrcId, "person.updSessionsTimeout");
				} catch (Exception e) {
					aspirePasswordField.invalidate(dc, e.toString() + " thrown while executing person.updSessionsTimeout");
				}
			} else {
				try {
					stmtMgr.execute(dbc, dc, dataSrcId, "person.updSessionsTimeoutOrg", new Object[] { dc.getValueAsObject("org_internal_id") });
				} catch (Exception e) {
					aspirePasswordField.invalidate(dc, e.toString() + " thrown while executing person.updSessionsTimeoutOrg");
				}
			}
		}

		return status;
	}
/*
	public AuthenticatedUser createUserData(DialogContext dc)
	{
		// This is where we set the session variables etc...
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
				/* col 1 is the org_id, col 2 is org_name * /
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
*/
}
