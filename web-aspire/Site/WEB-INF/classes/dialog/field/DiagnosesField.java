package dialog.field;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class DiagnosesField extends DialogField {
    protected TextField placeHolderField;

	public DiagnosesField()
	{
		super();
	}

	public DiagnosesField(String aName, String aCaption)
	{
		super(aName, aCaption);
		createFields (aName, aCaption);
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);

		createFields ("diagcodes", "Diagnoses Codes");
	}

	private void createFields (String theName, String theCaption)
	{
		placeHolderField = new TextField(theName, theCaption);
		/* Add fields to the composite */
		addChildField(placeHolderField);
	}
}
