package dialog.field.catalog;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;
import com.xaf.db.DatabaseContext;
import com.xaf.sql.StatementManager;

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
	}

	public boolean isValid(DialogContext dc)
	{
		boolean status = super.isValid (dc);
		String idValue = dc.getValue(idTextField);

		if (status && !(idValue.equals("")))
		{
			DatabaseContext dbContext = dc.getDatabaseContext();
			StatementManager stmtMgr = dc.getStatementManager();
			String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");
			Object orgIntId = dc.getSession().getAttribute("org_internal_id");

			try {
				status = stmtMgr.stmtRecordExists(dbContext, dc, dataSrcId, "catalog.selInternalCatalogIdById", new Object[] { orgIntId });
			} catch (Exception e) {
				invalidate(dc, e.toString());
			}
		}

		return status;
	}

	private void createFields ()
	{
		idTextField = new TextField("catalog_id", "Catalog ID");
		idTextField.setSize(16);
		idTextField.setMaxLength(32);

		addChildField(idTextField);
	}
}
