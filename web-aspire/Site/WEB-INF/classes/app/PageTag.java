package app;

import java.io.*;

import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.jsp.*;
import javax.servlet.jsp.tagext.*;

import com.xaf.form.*;
import com.xaf.navigate.*;
import com.xaf.security.*;
import com.xaf.skin.*;
import com.xaf.value.*;

public class PageTag extends com.xaf.navigate.taglib.PageTag
{
	static private AppLoginDialog loginDialog;

	protected boolean doLogin(ServletContext servletContext, Servlet page, HttpServletRequest req, HttpServletResponse resp) throws IOException
	{
		if(loginDialog == null)
		{
			loginDialog = new AppLoginDialog();
			loginDialog.initialize();
		}

		String logout = req.getParameter("_logout");
		if(logout != null)
		{
			ValueContext vc = new ServletValueContext(servletContext, page, req, resp);
			loginDialog.logout(vc);

			/** If the logout parameter included a non-zero length value, then
			 *  we'll redirect to the value provided.
			 */
			if(logout.length() == 0 || logout.equals("1") || logout.equals("yes"))
				resp.sendRedirect(req.getContextPath());
			else
				resp.sendRedirect(logout);
			return true;
		}

		if(! loginDialog.accessAllowed(servletContext, req, resp))
		{
			DialogContext dc = loginDialog.createContext(servletContext, page, req, resp, SkinFactory.getDialogSkin());
			loginDialog.prepareContext(dc);
			if(dc.inExecuteMode())
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

		try
		{
			if(doLogin(servletContext, (Servlet) pageContext.getPage(), req, resp))
				return SKIP_BODY;

			if(! hasPermission())
			{
				out.print(req.getAttribute(PAGE_SECURITY_MESSAGE_ATTRNAME));
				return SKIP_BODY;
			}

			String resourcesUrl = req.getContextPath() + "/resources";

			out.print("<html>");
			out.print("<head>");
			out.print("	<title>"+ getTitle() +"</title>");
			out.print("</head>");
			out.print("<body background='"+ resourcesUrl +"/images/design/backgrnd.jpg' bgcolor='#FFFFFF' link='#cc0000' vlink='#336699' text='#000000' marginheight='0' marginwidth='0' topmargin=0 leftmargin=0>");
			out.print("<img src='"+ resourcesUrl +"/images/design//masthead.jpg' width='648' height='71' border='0' alt='Header Image'>");
			out.print("<table cellpadding=10><tr><td><font face='verdana' size=2>");

			String heading = getHeading();
			if(heading != null)
			{
				out.print("<h1>"+ heading +"</h1>");
			}

		}
		catch(IOException e)
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
		catch(IOException e)
		{
			throw new JspException(e.toString());
		}

		doPageEnd();
		return EVAL_PAGE;
	}
}
