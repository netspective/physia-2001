package dialog.field;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class OutstandingItemsField extends DialogField
{
	public OutstandingItemsField()
	{
		super();
	}

	public OutstandingItemsField(String aName, String aCaption)
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
