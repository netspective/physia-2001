package app;

import com.xaf.form.DialogContext;
import com.xaf.skin.SkinFactory;
import com.xaf.value.ServletValueContext;
import com.xaf.value.ValueContext;

import javax.servlet.Servlet;
import javax.servlet.ServletContext;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspException;
import javax.servlet.jsp.JspWriter;
import java.io.IOException;
import java.text.DateFormat;

public class PageTag extends com.xaf.navigate.taglib.PageTag
{
	static private AppLoginDialog loginDialog;

	protected boolean doLogin(ServletContext servletContext, Servlet page, HttpServletRequest req, HttpServletResponse resp) throws IOException
	{
		if (loginDialog == null)
		{
			loginDialog = new AppLoginDialog();
			loginDialog.initialize();
		}

		String logout = req.getParameter("_logout");
		if (logout != null)
		{
			ValueContext vc = new ServletValueContext(servletContext, page, req, resp);
			loginDialog.logout(vc);

			/** If the logout parameter included a non-zero length value, then
			 *  we'll redirect to the value provided.
			 */
			if (logout.length() == 0 || logout.equals("1") || logout.equals("yes"))
				resp.sendRedirect(req.getContextPath());
			else
				resp.sendRedirect(logout);
			return true;
		}

		if (!loginDialog.accessAllowed(servletContext, req, resp))
		{
			DialogContext dc = loginDialog.createContext(servletContext, page, req, resp, SkinFactory.getDialogSkin());
			loginDialog.prepareContext(dc);
			if (dc.inExecuteMode())
			{
				loginDialog.execute(dc);
			}
			else
			{
				loginDialog.producePage(dc, resp.getWriter());
				return true;
			}
		}

		return false;
	}

	public int doStartTag() throws JspException
	{
		doPageBegin();

		JspWriter out = pageContext.getOut();

		HttpServletRequest req = (HttpServletRequest) pageContext.getRequest();
		HttpServletResponse resp = (HttpServletResponse) pageContext.getResponse();
		ServletContext servletContext = pageContext.getServletContext();

		HttpSession session = pageContext.getSession();
		String userId = (String) session.getValue("user_id");
		String orgId = (String) session.getValue("org_id");

		String currentDate = DateFormat.getDateInstance().format(new java.util.Date());
		currentDate = new java.util.Date().toString();

		try
		{
			if (doLogin(servletContext, (Servlet) pageContext.getPage(), req, resp))
				return SKIP_BODY;

			if (!hasPermission())
			{
				out.print(req.getAttribute(PAGE_SECURITY_MESSAGE_ATTRNAME));
				return SKIP_BODY;
			}

			String resourcesUrl = req.getContextPath() + "/resources";

			out.println("<html>");
			out.println("<head>");
			out.println("\t<title>" + getTitle() + "</title>");
			out.println("</head>");
			out.println("<body background='" + resourcesUrl + "/images/design/backgrnd.jpg' bgcolor='#FFFFFF' link='#cc0000' vlink='#336699' text='#000000' marginheight='0' marginwidth='0' topmargin=0 leftmargin=0>");
			out.println("<table cellspacing='0' cellpadding='0' border='0' bgcolor='#389cce' width='100%'>");
			out.println("<tr>");
			out.println("<td width='100'>");
			out.println("<img src='/aspire/resources/images/design/app-corporate-logo.gif' width='110' height='30' border='0'><br>");
			out.println("</td>");
			out.println("<td>");
			out.println("<font face='tahoma,arial' size='2' style='font-size:8pt' color='white'>");
			out.println("<img src='/aspire/resources/icons/home-sm.gif' width='13' height='12' border='0'>");
			out.println("<a href='/aspire/home' style='text-decoration:none; color:yellow' onmouseover='anchorMouseOver(this, \"white\")' onmouseout='anchorMouseOut(this, \"yellow\")'>");
			out.println("<b>" + userId + "</b></a>@<a href='/aspire/homeorg' style='text-decoration:none; color:yellow' onmouseover='anchorMouseOver(this,\"white\")' onmouseout='anchorMouseOut(this, \"yellow\")'>");
			out.println(orgId + "</a>");
			out.println("<img src='/aspire/resources/icons/arrow-right-lblue.gif' width='10' height='10' border='0'>");
			out.println("</font>");
			out.println("</td>");
			out.println("<td>&nbsp;</td>");
			out.println("<td align='right' valign='middle' width='10'>");
			out.println("<table cellpadding='1' cellspacing='0' style='border:2; border-style:outset; background-color:#EEEEEE'>");
			out.println("<tr>");
			out.println("<td align='right' valign='bottom'>");
			out.println("<font face='tahoma,arial' size='2' style='font-size:8pt' color='yellow'>");
			out.println("<nobr>");
			out.println("<a href='/aspire/logout'><img src='/aspire/resources/icons/small-arrow.gif' width='10' height='9' border='0'></a>");
			out.println("<b><a href='/aspire/logout' style='text-decoration:none; color:black' onmouseover='anchorMouseOver(this, \"red\")' onmouseout='anchorMouseOut(this, \"black\")'>Logout</a></b>");
			out.println("</nobr>");
			out.println("</font>");
			out.println("</td></tr></table>");
			out.println("</td><td>");
			out.println("&nbsp;");
			out.println("</td></tr></table>");
			out.println("<table cellspacing='0' cellpadding='0' border='0' bgcolor='#353365' width='100%'>");
			out.println("<tr height='1' bgcolor='#ff9935'><td colspan='3'>");
			out.println("<img src='/aspire/resources/design/transparent-line.gif' width='100%' height='1' border='0'>");
			out.println("</td></tr><tr height='4'><td colspan='3'>");
			out.println("<img src='/aspire/resources/design/transparent-line.gif' width='100%' height='1' border='0'>");
			out.println("</td></tr><tr><td width='4'>");
			out.println("<img src='/aspire/resources/design/transparent-line.gif' width='100%' height='1' border='0'>");
			out.println("</td><td valign='top'>");
			out.println("<font face='tahoma,arial' size='2' style='font-size:8pt' color='#ff9935'></font>");
			out.println("</td><td align='right' valign='bottom' rowspan='2'>");
			out.println("</td></tr><tr height='2' bgcolor='#353365'><td colspan='2'>");
			out.println("<img src='/aspire/resources/design/transparent-line.gif' width='100%' height='1' border='0'>");
			out.println("</td></tr><tr height='2' bgcolor='#dddddd'><td colspan='3'>");
			out.println("<img src='/aspire/resources/design/transparent-line.gif' width='100%' height='1' border='0'>");
			out.println("</td></tr></table>");
			out.println("<table cellspacing='0' cellpadding='0' border='0' bgcolor='#353365' width='100%'>");
			out.println("<tr bgcolor='#dddddd'><td width='4'>");
			out.println("<img src='/aspire/resources/design/transparent-line.gif' width='100%' height='1' border='0'>");
			out.println("</td><td width='15'>");
			out.println("<img src='/aspire/resources/images/page-icons/search.gif' width='34' height='25' border='0'>");
			out.println("</td><td valign='center'>");
			out.println("&nbsp;");
			out.println("<b><font face='helvetica' size='4'>" + getHeading() + "</font></b>");
			out.println("</td><td align='right'>");
			out.println("<font face='tahoma,arial,helvetica' style='font-size:8pt' color='navy'>");
			out.println("Updated " + currentDate + "</font>");
			out.println("&nbsp;");
			out.println("</td></tr><tr height='2' bgcolor='#dddddd'><td colspan='4'>");
			out.println("<img src='/aspire/resources/design/transparent-line.gif' width='100%' height='1' border='0'>");
			out.println("</td></tr></table>");
			//out.println("<img src='"+ resourcesUrl +"/images/design//masthead.jpg' width='648' height='71' border='0' alt='Header Image'>");
			out.println("<table cellpadding=10><tr><td><font face='verdana' size=2>");
		}
		catch (IOException e)
		{
			throw new JspException(e.toString());
		}

		return EVAL_BODY_INCLUDE;
	}

	public int doEndTag() throws JspException
	{
		JspWriter out = pageContext.getOut();
		try
		{
			out.print("<font></td></tr></table>");
			out.print("</body>");
			out.print("</html>");
		}
		catch (IOException e)
		{
			throw new JspException(e.toString());
		}

		doPageEnd();
		return EVAL_PAGE;
	}
}
