package dialog.field.organization.id;

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
import dialog.field.organization.IDField;

public class NewField extends IDField
{
	public NewField()
	{
		super();
	}

	public NewField(String aName, String aCaption)
	{
		super(aName, aCaption);
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);
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
				status = !stmtMgr.stmtRecordExists(dbContext, dc, dataSrcId, "org.selOrgId", new Object[] { dc.getSession().getAttribute("org_internal_id"), orgID });
			} catch (Exception e) {
			}

			if (!status) {
				String invalidateMsg = idTextField.getCaption(dc) + " " + orgID + "already exists";
				invalidate(dc, invalidateMsg);
			}
		}

		return status;
	}
}
