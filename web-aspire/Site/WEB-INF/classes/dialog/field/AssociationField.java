package dialog.field;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;
import com.xaf.db.DatabaseContext;
import com.xaf.sql.StatementManager;

public class AssociationField extends DialogField
{
	protected SelectField relationshipField;
	protected TextField otherRelationshipField;

	public AssociationField()
	{
		super();
	}

	public AssociationField(String aName, String aCaption)
	{
		super(aName, aCaption);

		createFields();
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);

		createFields();
	}

	public boolean isValid(DialogContext dc) {
		boolean status = super.isValid(dc);

		// Check the value of the selectbox.  If it was "Other", then check the value of the TextBox to ensure it's
		// non-empty.

		return status;
	}

	public void populateValue(DialogContext dc, int formatType) {
		super.populateValue(dc, formatType);

		DatabaseContext dbContext = dc.getDatabaseContext();
		StatementManager stmtMgr = dc.getStatementManager();
		String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");
		QueryResultsListValue qrlv = new QueryResultsListValue("query:/person.selRelationship", dataSrcId, "person.selRelationship");

		relationshipField.setDefaultListValue(qrlv);
	}

	private void createFields ()
	{
		relationshipField = new SelectField("rel_type", "Relationship", SelectField.SELECTSTYLE_COMBO);
		relationshipField.setHint("Select an existing relationship type or select 'Other' and fill in the 'Other' field");
		otherRelationshipField = new TextField("other_rel_type", "Other");

		addChildField(relationshipField);
		addChildField(otherRelationshipField);
		addChildField(otherRelationshipField);
	}
}
