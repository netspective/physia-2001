package dialog.field.catalog.id;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class NewField extends DialogField
{
	protected TextField idTextField;

	public NewField()
	{
		super();
	}

	public NewField(String aName, String aCaption)
	{
		super(aName, aCaption);
		createFields();
	}

	public void importFromXml(Element elem)
	{
		super.importFromXml(elem);
		createFields();
	}

	private void createFields ()
	{
		idTextField = new TextField("catalog_id", "Catalog ID");
		idTextField.setSize(16);
		idTextField.setMaxLength(32);

		addChildField(idTextField);
	}
}
