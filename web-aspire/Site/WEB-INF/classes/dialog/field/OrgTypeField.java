package dialog.field;

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
import org.apache.oro.text.perl.Perl5Util;

import java.util.StringTokenizer;
import java.util.Map;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;

import util.TypeFlags;

public class OrgTypeField extends DialogField {
	private static String[] organizationTypes = { "CLINIC", "FACILITY/SITE" };

	private SelectField idSelectField;
	private TypeFlags orgType = new TypeFlags (organizationTypes);
	private int allowedOrgTypes;

	public OrgTypeField() {
		super();
	}

	public OrgTypeField(String aName, String aCaption) {
		super(aName, aCaption);

		allowedOrgTypes = orgType.getMaxFlagValue();
		createFields();
	}


	public void importFromXml(Element elem) {
		super.importFromXml(elem);
		String name = getSimpleName();


		String allowedTypes = elem.getAttribute("types");

		if (allowedTypes.length() <= 0)
			allowedOrgTypes = orgType.getMaxFlagValue();
		else
			allowedOrgTypes = orgType.translateStringToFlagValue(allowedTypes);

		createFields ();
	}

	public void populateValue (DialogContext dc, int formatType) {
		super.populateValue(dc, formatType);

		DatabaseContext dbContext = DatabaseContextFactory.getContext(dc);
		StatementManager stmtMgr = StatementManagerFactory.getManager(dc.getServletContext());
		String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");
		SelectChoicesList scl = new SelectChoicesList();
		int numChoices = 0;

		try {
			String sqlStatement = "select distinct org_internal_id, name_primary from Org_Category, Org where Org.owner_org_id = ? and Org_Category.parent_id = Org.org_internal_id and ltrim(rtrim(upper(Org_Category.member_name))) in ? order by name_primary";
			StatementManager.ResultInfo ri = StatementManager.executeSql(dbContext, dc, dataSrcId, sqlStatement, new Object[] { dc.getSession().getAttribute("org_internal_id"), orgType.translateFlagValueToSqlSet (allowedOrgTypes) });
			ResultSet rs = ri.getResultSet();

			while (rs.next()) {
				numChoices ++;
				scl.add(new SelectChoice(rs.getString(1), rs.getString(0)));
			}
		} catch (Exception e) {
		}

		ListSource ls = new ListSource();
		ls.setChoices(scl);

		idSelectField.setListSource(ls);
	}

	private void createFields() {
		idSelectField = new SelectField("person_id", "Person ID", SelectField.SELECTSTYLE_COMBO);
		addChildField(idSelectField);
	}
}
