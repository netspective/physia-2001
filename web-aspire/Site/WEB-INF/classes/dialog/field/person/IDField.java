package dialog.field.person;

import com.xaf.form.DialogField;
import com.xaf.form.DialogContext;
import com.xaf.form.field.TextField;
import com.xaf.form.field.SelectField;
import com.xaf.form.field.SelectChoicesList;
import com.xaf.form.field.SelectChoice;
import com.xaf.db.DatabaseContextFactory;
import com.xaf.db.DatabaseContext;
import com.xaf.sql.StatementManagerFactory;
import com.xaf.sql.StatementManager;
import com.xaf.value.ListSource;
import com.xaf.value.QueryResultsListValue;
import org.w3c.dom.Element;
import org.apache.oro.text.perl.Perl5Util;

import java.util.StringTokenizer;
import java.util.Map;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;

import util.TypeFlags;

public class IDField extends DialogField {
	public static final int FIELDSTYLE_TEXT = 0;
	public static final int FIELDSTYLE_SELECT = 1;
	private static String[] personTypes = { "Superuser", "Administrator", "Physician", "Referring-Doctor", "Nurse", "Staff", "Guarantor", "Patient", "Insured-Person" };

	private SelectField idSelectField;
	private TextField idTextField;
	private int fieldType = FIELDSTYLE_TEXT;
	private TypeFlags personType = new TypeFlags (personTypes);
	private int allowedPersonTypes;

	public IDField() {
		super();
	}

	public IDField(String aName, String aCaption) {
		super(aName, aCaption);

		allowedPersonTypes = personType.getMaxFlagValue();
		createFields();
	}


	public void importFromXml(Element elem) {
		super.importFromXml(elem);
		String name = getSimpleName();


		String allowedTypes = elem.getAttribute("types");

		if (allowedTypes.length() <= 0)
			allowedPersonTypes = personType.getMaxFlagValue();
		else
			allowedPersonTypes = personType.translateStringToFlagValue(allowedTypes);

		String style = elem.getAttribute("style");

		if (style.length() > 0) {
			if (style.equalsIgnoreCase("select"))
				fieldType = FIELDSTYLE_SELECT;
		}

		createFields ();
	}

	public boolean isValid (DialogContext dc) {
        boolean status = true;

		// In case this is a select field, all the choices are already chosen according to categories, so this must be valid
		if (fieldType == FIELDSTYLE_SELECT) return status;

		// For the case of a TextField, perform more validation
        String personID = dc.getValue(idTextField).toUpperCase();
        DatabaseContext dbContext = DatabaseContextFactory.getContext(dc);
		StatementManager stmtMgr = StatementManagerFactory.getManager(dc.getServletContext());
		String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");

		if (isPseudoResource(dc, personID)) return status;

		try {
			status = stmtMgr.stmtRecordExists(dbContext, dc, dataSrcId, "person.selRegistry", new Object[] { personID });
		} catch (Exception e) {
			invalidate(dc, e.toString());
			status = false;
		}
		if (!status) {
			invalidate(dc, this.getCaption(dc) + " '" + personID + "' does not exist.  Add " + personID + " as a Patient");
			return status;
		}

		// Add session:org_internal_id here.  Find out how.
		try {
			status = stmtMgr.stmtRecordExists(dbContext, dc, dataSrcId, "person.selCategory", new Object[] { personID, dc.getSession().getAttribute("org_internal_id") });
		} catch (Exception e) {
			invalidate(dc, e.toString());
			status = false;
		}
		if (!status) {
            invalidate(dc, "You do not have permission to select people outside of your organization");
			return status;
		}

        return status;
	}

	public void populateValue (DialogContext dc, int formatType) {
		super.populateValue(dc, formatType);

		if (fieldType == FIELDSTYLE_SELECT) {
			DatabaseContext dbContext = DatabaseContextFactory.getContext(dc);
			StatementManager stmtMgr = StatementManagerFactory.getManager(dc.getServletContext());
			String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");
			SelectChoicesList scl = new SelectChoicesList();
			int numChoices = 0;

			QueryResultsListValue qrlv = new QueryResultsListValue();

			try {
				String sqlStatement = "select distinct(person_id), category from person_org_category where category in " + personType.translateFlagValueToSqlSet (allowedPersonTypes);
				StatementManager.ResultInfo ri = StatementManager.executeSql(dbContext, dc, dataSrcId, sqlStatement, null);
				ResultSet rs = ri.getResultSet();

				while (rs.next()) {
					numChoices ++;
					scl.add(new SelectChoice(rs.getString(1)));
				}
			} catch (Exception e) {
			}

			qrlv.setChoices(scl);

			idSelectField.setListSource(qrlv);
		}
	}

	private void createFields() {
		if (fieldType == FIELDSTYLE_SELECT) {
			idSelectField = new SelectField("person_id", "Person ID", SelectField.SELECTSTYLE_COMBO);
			addChildField(idSelectField);
		} else {
			idTextField = new TextField("person_id", "Person ID");
			addChildField(idTextField);
		}
	}

	private boolean isPseudoResource (DialogContext dc, String personID) {
		boolean status = false;
		Perl5Util perlUtil = new Perl5Util();
        String types = personType.translateFlagValueToSqlSet(allowedPersonTypes);

		if (perlUtil.match("/_\\d$/", personID) && perlUtil.match("/Physician/", types)) {
			DatabaseContext dbContext = DatabaseContextFactory.getContext(dc);
			StatementManager stmtMgr = StatementManagerFactory.getManager(dc.getServletContext());
			String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");

			Map[] results = new Map[0];

			try {
				results = stmtMgr.executeStmtGetValuesMapArray(dbContext, dc, dataSrcId, "scheduling.selRovingPhysicianTypes", null);
			} catch (Exception e) {
			}

			String personIDRoot = personID;
			personIDRoot = perlUtil.substitute("s/_\\d$//", personIDRoot);

			for (int i = 0; i < results.length; i ++) {
				if (results[i].containsKey(personIDRoot)) {
					status = true;
					break;
				}
			}
		}

		return status;
	}
}
