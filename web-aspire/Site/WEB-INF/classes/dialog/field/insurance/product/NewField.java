package dialog.field.insurance.product;

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
import com.xaf.value.SingleValueSource;
import org.w3c.dom.Element;

import java.util.StringTokenizer;
import java.util.List;
import java.util.ArrayList;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;

import util.TypeFlags;

public class NewField extends DialogField {
	private TextField idTextField;

	public NewField() {
		super();
	}

	public NewField(String aName, String aCaption) {
		super(aName, aCaption);

		createFields();
	}


	public void importFromXml(Element elem) {
		super.importFromXml(elem);

		createFields ();
	}

	public boolean isValid (DialogContext dc) {
		boolean status = super.isValid(dc);

		if (dc.getDataCommand() != DialogContext.DATA_CMD_ADD) return status;

		String productName = dc.getValue(idTextField);
		String ownerOrgId = (String) dc.getServletContext().getAttribute("org_internal_id");

		DatabaseContext dbContext = dc.getDatabaseContext();
		StatementManager stmtMgr = dc.getStatementManager();
		String dataSrcId = dc.getServletContext().getInitParameter("default-data-source");

        if (!productName.equalsIgnoreCase("")) {
			try {
				status = stmtMgr.stmtRecordExists(dbContext, dc, dataSrcId, "insurance.selNewProductExists", new Object[] { productName, ownerOrgId });
			} catch (Exception e) {
				status = false;
				invalidate(dc, e.toString());
			}
		}

		if (!status) {
			invalidate(dc, "Product Name " + productName + " already exists.");
		}

        return status;
	}

	private void createFields() {
		idTextField = new TextField("product_name", "Product Name");
		idTextField.setSize(16);
		idTextField.setMaxLength(32);

		addChildField(idTextField);
	}
}
