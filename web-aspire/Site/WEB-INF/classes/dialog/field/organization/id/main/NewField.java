package dialog.field.organization.id.main;

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
import dialog.field.organization.id.MainField;

public class NewField extends MainField
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
				status = !stmtMgr.stmtRecordExists(dbContext, dc, dataSrcId, "org.selOwnerOrgId", new Object[] { orgID });
			} catch (Exception e) {
			}

			if (!status) {
				String invalidateMsg = idTextField.getCaption(dc) + " " + orgID + "already exists exist.";
				invalidate(dc, invalidateMsg);
			}
		}

		return status;
	}
}
