package dialog.field;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;
import com.xaf.db.DatabaseContext;
import com.xaf.sql.StatementManager;

public class DiagnosesCheckboxField extends DialogField {
    protected SelectField diagnosesField;

	public DiagnosesCheckboxField()
	{
		super();
	}

	public DiagnosesCheckboxField(String aName, String aCaption)
	{
		super(aName, aCaption);
		createFields (aName, aCaption);
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);

		String theName = elem.getAttribute("name");
		String theCaption = elem.getAttribute("caption");

		if (theName.equals("")) theName = "procdiags";
		if (theCaption.equals("")) theCaption = "Diagnoses";

		createFields (theName, theCaption);
	}

	public void populateValue(DialogContext dc, int formatType) {
		super.populateValue(dc, formatType);

		DatabaseContext dbContext = dc.getDatabaseContext();
		StatementManager stmtMgr = dc.getStatementManager();
		String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");

		QueryResultsListValue qrlv = new QueryResultsListValue("query:/selClaimDiags?" + dc.getServletContext().getAttribute("invoice_id"), dataSrcId, "");
		diagnosesField.setDefaultListValue(qrlv);
	}

	private void createFields (String theName, String theCaption)
	{
		diagnosesField = new SelectField(theName, theCaption, SelectField.SELECTSTYLE_MULTICHECK);
		/* Add fields to the composite */
		addChildField(diagnosesField);
	}
}
