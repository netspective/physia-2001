package dialog.field.person;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class PersonNameField extends DialogField
{
	protected TextField lastNameField;
	protected TextField firstNameField;
	protected TextField middleNameField;
	protected TextField suffixField;

	public PersonNameField()
	{
		super();
	}

	public PersonNameField(String aName, String aCaption)
	{
		super(aName, aCaption);
		createFields ("");
		setFieldFlags ();
		addFields ();
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
		setFieldFlags ();
		addFields ();
	}

	public boolean isValid(DialogContext dc)
	{
		boolean status = true;
		boolean lastNameValid = lastNameField.isValid(dc);
		boolean firstNameValid = lastNameField.isValid(dc);
		boolean middleNameValid = middleNameField.isValid(dc);
		boolean suffixValid = suffixField.isValid(dc);

		/* Preliminary check */
		if(!(lastNameValid && firstNameValid && middleNameValid && suffixValid)) {
			status = false;
			invalidate (dc, "Name is invalid out of hand");
		}

		return status;
	}

	public boolean needsValidation (DialogContext dc)
	{
		setFieldFlags ();
		return true;
	}

	private void createFields (String captionPrefix)
	{
		lastNameField = new TextField (captionPrefix + "name_last", "Last Name");
		lastNameField.setSize (16);

		firstNameField = new TextField (captionPrefix + "name_first", "First Name");
		firstNameField.setSize (12);

		middleNameField = new TextField (captionPrefix + "name_middle", "Middle Name");
		middleNameField.setSize (8);

		suffixField = new TextField (captionPrefix + "name_suffix", "Suffix");
		suffixField.setSize (16);
	}

	private void addFields ()
	{
		addChildField(lastNameField);
		addChildField(firstNameField);
		addChildField(middleNameField);
		addChildField(suffixField);
	}

	private void setFieldFlags ()
	{
		lastNameField.setFlag (DialogField.FLDFLAG_REQUIRED);
		firstNameField.setFlag (DialogField.FLDFLAG_REQUIRED);
	}
}
