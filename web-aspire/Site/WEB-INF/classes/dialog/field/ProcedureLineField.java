package dialog.field;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class ProcedureLineField extends DialogField {
	protected TextField procedureLineField;
	protected TextField procedureModifierField;

	public ProcedureLineField()
	{
		super();
	}

	public ProcedureLineField(String aName, String aCaption)
	{
		super(aName, aCaption);
		createFields ();
	}

	public TextField getProcedureField() { return procedureLineField; }
	public TextField getProcedureModifierField() { return procedureModifierField; }

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);
		createFields ();
	}

	private void createFields ()
	{
		procedureLineField = new TextField("procedure", "Procedure");
		procedureLineField.setSize (8);
		procedureLineField.setFlag (DialogField.FLDFLAG_REQUIRED);

		procedureModifierField = new TextField("procmodifier", "Modifier");
		procedureModifierField.setSize(4);

		/* Add fields to the composite */
		addChildField(procedureLineField);
		addChildField(procedureModifierField);
	}
}
