package dialog.field;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class ProcedureChargeUnitsField extends DialogField {
	protected CurrencyField chargeField;
	protected IntegerField unitsField;
	protected BooleanField emgField;

	public ProcedureChargeUnitsField()
	{
		super();
	}

	public ProcedureChargeUnitsField(String aName, String aCaption)
	{
		super(aName, aCaption);
		createFields ();
	}

	public CurrencyField getChargeField() { return chargeField; }
	public IntegerField getUnitsField() { return unitsField; }
	public BooleanField getEmgField() { return emgField; }

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);
		createFields ();
	}

	private void createFields ()
	{
		chargeField = new CurrencyField();
		chargeField.setCaption("Charge");
		chargeField.setSimpleName("proccharge");

		unitsField = new IntegerField("procunits", "Units");
		unitsField.setMinValue(1);
		unitsField.setSize(6);
//		unitsField.setDefaultValue();
		unitsField.setFlag(DialogField.FLDFLAG_REQUIRED);

		emgField = new BooleanField();
		emgField.setSimpleName("emg");
		emgField.setCaption("EMG");
		emgField.setStyle(BooleanField.BOOLSTYLE_CHECK);

		/* Add fields to the composite */
		addChildField(chargeField);
		addChildField(unitsField);
		addChildField(emgField);
	}
}
