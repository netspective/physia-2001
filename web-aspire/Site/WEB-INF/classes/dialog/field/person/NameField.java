package dialog.field.person;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class NameField extends DialogField
{
	protected TextField lastNameField;
	protected TextField firstNameField;
	protected TextField middleNameField;
	protected TextField suffixField;

	public NameField()
	{
		super();
	}

	public NameField(String aName, String aCaption)
	{
		super(aName, aCaption);
		createFields (aName + "_");
	}

	public TextField getLastNameField() { return lastNameField; }
	public TextField getFirstNameField() { return firstNameField; }
	public TextField getMiddleNameField() { return middleNameField; }
	public TextField getSuffixField() { return suffixField; }

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);
		String name = getSimpleName();
		createFields (name + "_");
	}

	private void createFields (String captionPrefix)
	{
		lastNameField = new TextField (captionPrefix + "name_last", "Last Name");
		lastNameField.setSize (16);
		lastNameField.setFlag (DialogField.FLDFLAG_REQUIRED);

		firstNameField = new TextField (captionPrefix + "name_first", "First Name");
		firstNameField.setSize (12);
		firstNameField.setFlag (DialogField.FLDFLAG_REQUIRED);

		middleNameField = new TextField (captionPrefix + "name_middle", "Middle Name");
		middleNameField.setSize (8);

		suffixField = new TextField (captionPrefix + "name_suffix", "Suffix");
		suffixField.setSize (16);

		/* Add fields to the composite */
		addChildField(lastNameField);
		addChildField(firstNameField);
		addChildField(middleNameField);
		addChildField(suffixField);
	}
}
