package dialog.field;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;
import com.xaf.db.DatabaseContext;
import com.xaf.sql.StatementManager;

public class BatchDateIDField extends DialogField
{
    protected TextField batchIDField;
	protected TextField dateField;
	protected String parameter;
	protected int paramType;

	public static final int PARAM_ORG_INTERNAL_ID = 0;
	public static final int PARAM_INVOICE_ID = 1;
	public static final int PARAM_LIST_INVOICE = 2;

	public BatchDateIDField()
	{
		super();
	}

	public BatchDateIDField(String aName, String aCaption, int paramType)
	{
		super(aName, aCaption);
		this.paramType = paramType;
		createFields();
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);

		paramType = PARAM_LIST_INVOICE;
		if (elem.getAttribute("listInvoiceFieldName").equals("")) {
			paramType = PARAM_LIST_INVOICE;
			parameter = elem.getAttribute("listInvoiceFieldName");
		} else if (elem.getAttribute("invoiceIdFieldName").equals("")) {
			paramType = PARAM_INVOICE_ID;
			parameter = elem.getAttribute("invoiceIdFieldName");
		} else if (elem.getAttribute("orgInternalIdFieldName").equals("")) {
			paramType = PARAM_ORG_INTERNAL_ID;
			parameter = elem.getAttribute("orgInternalIdFieldName");
		} else {
			paramType = -1;
		}

		createFields();
	}

	public boolean isValid(DialogContext dc)
	{
		boolean status = super.isValid (dc);

		String orgInternalId;

		if (status) {
			switch (paramType) {
				case PARAM_ORG_INTERNAL_ID:
					orgInternalId = parameter;
					break;

				case PARAM_INVOICE_ID:
					String invoiceId = parameter;
					DatabaseContext dbContext = dc.getDatabaseContext();
					StatementManager stmtMgr = dc.getStatementManager();
					String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");

					try {
						orgInternalId = (String) stmtMgr.executeStmtGetValue(dbContext, dc, dataSrcId, "invoice.selServiceOrgByInvoiceId", new Object[] { invoiceId });
					} catch (Exception e) {
						invalidate(dc, e.toString());
						status = false;
					}
					break;
			}
		}

		return status;
	}

	private void createFields ()
	{
		batchIDField = new TextField("batch_id", "Batch ID");
		batchIDField.setSize(12);
		batchIDField.setFlag(DialogField.FLDFLAG_REQUIRED);

		dateField = new DateTimeField("batch_date", "Batch Date", DateTimeField.DTTYPE_DATEONLY);
		dateField.setFlag(DialogField.FLDFLAG_REQUIRED);

		addChildField(batchIDField);
		addChildField(dateField);
	}
}
