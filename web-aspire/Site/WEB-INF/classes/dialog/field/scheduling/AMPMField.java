package dialog.field.scheduling;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class AMPMField extends DialogField
{
	public AMPMField()
	{
		super();
	}

	public AMPMField(String aName, String aCaption)
	{
		super(aName, aCaption);
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);
	}

	public boolean isValid(DialogContext dc)
	{
		return super.isValid (dc);
	}

	public boolean needsValidation (DialogContext dc)
	{
		return true;
	}

	private void createFields (String captionPrefix)
	{
	}
}
