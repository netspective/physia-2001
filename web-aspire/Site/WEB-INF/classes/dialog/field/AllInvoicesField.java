package dialog.field;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class AllInvoicesField extends DialogField
{
	public AllInvoicesField()
	{
		super();
	}

	public AllInvoicesField(String aName, String aCaption)
	{
		super(aName, aCaption);
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);
	}

	public boolean isValid(DialogContext dc)
	{
		return super.isValid ();
	}

	public boolean needsValidation (DialogContext dc)
	{
		setFieldFlags ();
		return true;
	}

	private void createFields (String captionPrefix)
	{
	}

	private void addFields ()
	{
	}

	private void setFieldFlags ()
	{
	}
}
