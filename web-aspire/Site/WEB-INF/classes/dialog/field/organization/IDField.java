package dialog.field.organization;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;
import com.xaf.db.DatabaseContext;
import com.xaf.db.DatabaseContextFactory;
import com.xaf.sql.StatementManager;
import com.xaf.sql.StatementManagerFactory;

public class IDField extends DialogField
{
	protected TextField idTextField;

	public IDField()
	{
		super();
	}

	public IDField(String aName, String aCaption)
	{
		super(aName, aCaption);

		createFields();
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);

		createFields();

		if (!elem.getAttribute("size").equals("16")) idTextField.setSize(Integer.parseInt(elem.getAttribute("size")));
		if (!elem.getAttribute("max-length").equals("16")) idTextField.setMaxLength(Integer.parseInt(elem.getAttribute("size")));
	}

	public boolean isValid(DialogContext dc)
	{
		boolean status = super.isValid (dc);
		String orgID = dc.getValue(idTextField).toUpperCase();

		if (status && !(orgID.equalsIgnoreCase(""))) {
			DatabaseContext dbContext = DatabaseContextFactory.getContext(dc);
			StatementManager stmtMgr = StatementManagerFactory.getManager(dc.getServletContext());
			String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");

			try {
				status = stmtMgr.stmtRecordExists(dbContext, dc, dataSrcId, "org.selOrgId", new Object[] { dc.getSession().getAttribute("org_internal_id"), orgID });
			} catch (Exception e) {
			}

			if (dc.getDataCommand() == DialogContext.DATA_CMD_ADD)
				status = !status;

			if (!status) {
				String invalidateMsg = idTextField.getCaption(dc) + " " + orgID + "does not exist.  Add " + orgID + " now as an Organization";
				invalidate(dc, invalidateMsg);
			}
		}

		return status;
	}

	private void createFields ()
	{
		idTextField = new TextField ("org_id", "Organization ID");
		idTextField.setSize(16);
		idTextField.setMaxLength(16);

		addChildField(idTextField);
	}
}
