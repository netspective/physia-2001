package dialog.field.insurance;

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
import util.TypeFlags;

public class PlanField extends DialogField
{
	public static final int FIELDSTYLE_TEXT = 0;
	public static final int FIELDSTYLE_SELECT = 1;
	private static String[] productTypes = {  };

	private SelectField idSelectField;
	private TextField idTextField;
	private int fieldType = FIELDSTYLE_TEXT;
	private TypeFlags productType = new TypeFlags (productTypes);
	private int allowedProductTypes;

	public PlanField()
	{
		super();
	}

	public PlanField(String aName, String aCaption)
	{
		super(aName, aCaption);

		allowedProductTypes = productType.getMaxFlagValue();
		createFields();
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);
		String allowedTypes = elem.getAttribute("types");

		if (allowedTypes.length() <= 0)
			allowedProductTypes = productType.getMaxFlagValue();
		else
			allowedProductTypes = productType.translateStringToFlagValue(allowedTypes);

		String style = elem.getAttribute("style");

		if (style.length() > 0) {
			if (style.equalsIgnoreCase("select"))
				fieldType = FIELDSTYLE_SELECT;
		}

		createFields ();
	}

	private void createFields ()
	{
		if (fieldType == FIELDSTYLE_SELECT) {
			idSelectField = new SelectField("plan_name", "Plan Name", SelectField.SELECTSTYLE_COMBO);
			addChildField(idSelectField);
		} else {
			idTextField = new TextField("plan_name", "Plan Name");
			idTextField.setSize(16);
			idTextField.setMaxLength(32);
			addChildField(idTextField);
		}
	}
}
