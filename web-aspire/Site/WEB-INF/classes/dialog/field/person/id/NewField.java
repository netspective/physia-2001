package dialog.field.person.id;

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
import org.w3c.dom.Element;

import java.util.StringTokenizer;
import java.util.List;
import java.util.ArrayList;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;

import util.TypeFlags;

public class NewField extends DialogField {
	private static String[] personTypes = { "Superuser", "Administrator", "Physician", "Referring-Doctor", "Nurse", "Staff", "Guarantor", "Patient", "Insured-Person" };

	private TextField idTextField;
	private TypeFlags personType = new TypeFlags (personTypes);
	private int allowedPersonTypes;

	public NewField() {
		super();
	}

	public NewField(String aName, String aCaption) {
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

		createFields ();

		// Override the fields' defaults
		String theHint = elem.getAttribute("hint");
		if (theHint.length() > 0)
			idTextField.setHint(theHint);
	}

	public boolean isValid (DialogContext dc) {
		boolean status = super.isValid(dc);

		if (dc.getDataCommand() != DialogContext.DATA_CMD_ADD) return status;

		String personID = dc.getValue(idTextField).toUpperCase();
		DatabaseContext dbContext = DatabaseContextFactory.getContext(dc);
		StatementManager stmtMgr = StatementManagerFactory.getManager(dc.getServletContext());
		String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");

        if (personID.equalsIgnoreCase("")) {
			String[] suggestion = autoSuggest(dc);
			String invalidateMsg = "Please select an ID from the following suggestions: ";

			for (int i = 0; i < suggestion.length; i ++) {
				if (i == 0)
					invalidateMsg += suggestion[i];
				else
					invalidateMsg += ", " + suggestion[i];
			}

			invalidate(dc, invalidateMsg);
			status = false;
			return status;
		}

		try {
			boolean recordFound = stmtMgr.stmtRecordExists(dbContext, dc, dataSrcId, "person.selRegistry", new Object[] { personID });
			if (recordFound) status = false;
		} catch (Exception e) {
			status = false;
		}

		if (status == false) {
			String[] suggestion = autoSuggest(dc);
			String invalidateMsg = this.getCaption(dc) + " '" + personID + "' already exists in the database.";
			invalidateMsg += "  Please select an ID from the following suggestions: ";

			for (int i = 0; i < suggestion.length; i ++) {
				if (i == 0)
					invalidateMsg += suggestion[i];
				else
					invalidateMsg += ", " + suggestion[i];
			}

			invalidate(dc, invalidateMsg);
			return status;
		}

        return status;
	}

	private void createFields() {
		idTextField = new TextField("person_id", "Person ID");
		idTextField.setSize(16);
		idTextField.setMaxLength(16);
		idTextField.setHint("To use the ID autosuggestion feature, leave this field blank");
		addChildField(idTextField);
	}

//	private String[] autoSuggest (DialogContext dc, String firstName, String middleInitial, String lastName, String ssn, String dob) {
	private String[] autoSuggest (DialogContext dc) {
/*
		String firstNameInitial = firstName.substring(0, 1);
		String lastFourSSN = ssn.substring(ssn.length() - 4);
		String yearOfBirth = dob.substring(dob.length() - 2);

		List suggestion = new ArrayList();

		suggestion.add((firstNameInitial + lastName.substring(0, 15)).toUpperCase());
		suggestion.add((firstNameInitial + middleInitial + lastName.substring(0, 14)).toUpperCase());
		suggestion.add((lastName + firstName).substring(0, 16).toUpperCase());
        suggestion.add((firstNameInitial + lastName.substring(0, 14) + yearOfBirth).toUpperCase());
		suggestion.add((firstNameInitial + lastName.substring(0, 12) + lastFourSSN).toUpperCase());
		suggestion.add((firstNameInitial + middleInitial + lastName.substring(0, 12) + yearOfBirth).toUpperCase());
		suggestion.add((firstNameInitial + middleInitial + lastName.substring(0, 10) + lastFourSSN).toUpperCase());
		suggestion.add((firstNameInitial + lastName.substring(0, 9) + yearOfBirth + lastFourSSN).toUpperCase());
		suggestion.add((firstNameInitial + lastName.substring(0, 12) + Integer.toString((int) Math.rint(Math.random() * 8999.0 + 1000.0))).toUpperCase());
		suggestion.add((firstNameInitial + lastName.substring(0, 12) + Integer.toString((int) Math.rint(Math.random() * 8999.0 + 1000.0))).toUpperCase());
		suggestion.add((firstNameInitial + lastName.substring(0, 12) + Integer.toString((int) Math.rint(Math.random() * 8999.0 + 1000.0))).toUpperCase());
*/
		int maxSuggestions = 3;
		int maxStringLength = 16;
		String[] suggestion = new String [maxSuggestions];
		String alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
		int maxIndex = alphabet.length() - 1;

		DatabaseContext dbContext = DatabaseContextFactory.getContext(dc);
		StatementManager stmtMgr = StatementManagerFactory.getManager(dc.getServletContext());
		String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");

//		try {
			for (int i = 0; i < maxSuggestions; i ++) {
				String tempString;

//				do {
					tempString = "";

					for (int j = 0; j < maxStringLength; j ++) {
						int randomIndex = (int) Math.rint(Math.random() * maxIndex);
						tempString += alphabet.substring(randomIndex, randomIndex + 1);
					}
//				} while (stmtMgr.stmtRecordExists(dbContext, dc, dataSrcId, "person.selRegistry", new Object[] { tempString }));

				suggestion [i] = tempString;
			}
//		} catch (Exception e) {
//		}

		return suggestion;
	}
}
