package dialog.field;

import java.io.*;
import java.util.*;

import org.w3c.dom.*;
import com.xaf.form.*;
import com.xaf.form.field.*;
import com.xaf.value.*;

public class UnitedStatesAddressField extends DialogField
{
	protected TextField address1Field;
	protected TextField address2Field;
	protected TextField cityField;
	protected TextField stateField;
	protected ZipField  zipField;

	public UnitedStatesAddressField()
	{
		super();
	}

	public UnitedStatesAddressField(String aName, String aCaption)
	{
		super(aName, aCaption);
		createFields ("");
		setFieldFlags ();
		addFields ();
	}

	public TextField getLine1Field() { return address1Field; }
	public TextField getLine2Field() { return address2Field; }
	public TextField getCityField() { return cityField; }
	public TextField getStateField() { return stateField; }
	public ZipField getZipField() { return zipField; }

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
		boolean address1Valid = address1Field.isValid(dc);
		boolean cityValid = cityField.isValid(dc);
		boolean stateValid = stateField.isValid(dc);
		boolean zipValid = zipField.isValid(dc);

		/* Preliminary check */
		if(!(address1Valid && cityValid && stateValid && zipValid)) {
			status = false;
			invalidate (dc, "Address invalid out of hand");
		}

		if (!status) return status;

		/* Validate the state */
		String stateString = dc.getValue (stateField);
		State theState = new State (stateString);
		status = theState.isValid ();

		if (!status) {
			invalidate (dc, "State is invalid");
			return status;
		}

		/* Validate the zip */
		String zipString = dc.getValue (zipField);
		ZipCode theZip = new ZipCode (stateString, zipString);
		status = theZip.isValid ();

		if (!status) {
			invalidate (dc, "Zip Code is invalid");
			return status;
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
		address1Field = new TextField (captionPrefix + "line1", "Line 1");
		address1Field.setSize (36);
		address1Field.setMaxLength (128);
		address1Field.setFlag(DialogField.FLDFLAG_COLUMN_BREAK_AFTER);

		address2Field = new TextField (captionPrefix + "line2", "Line 2");
		address2Field.setSize (36);
		address2Field.setMaxLength (128);
		address2Field.setFlag(DialogField.FLDFLAG_COLUMN_BREAK_AFTER);

		cityField = new TextField (captionPrefix + "city", "City");
		cityField.setSize (16);
		cityField.setMaxLength (64);

		stateField = new TextField (captionPrefix + "state", "State");
		stateField.setSize (2);
		stateField.setMaxLength (2);

		zipField = new ZipField (captionPrefix + "zip", "Zip");
	}

	private void addFields ()
	{
		addChildField(address1Field);
		addChildField(address2Field);
		addChildField(cityField);
		addChildField(stateField);
		addChildField(zipField);
	}

	private void setFieldFlags ()
	{
		address1Field.setFlag (DialogField.FLDFLAG_REQUIRED);
		cityField.setFlag (DialogField.FLDFLAG_REQUIRED | DialogField.FLDFLAG_SHOWCAPTIONASCHILD);
		stateField.setFlag (DialogField.FLDFLAG_REQUIRED | DialogField.FLDFLAG_SHOWCAPTIONASCHILD);
		zipField.setFlag (DialogField.FLDFLAG_REQUIRED | DialogField.FLDFLAG_SHOWCAPTIONASCHILD);
	}
}



/* Class to validate a State */
class State {
	protected String state;
	protected int index;

	protected static String[] stateList = {
		"AL", "AK", "AS", "AZ", "AR", "AA", "AP", "AE", "CA", "CZ",
		"CO", "CT", "DE", "DC", "FL", "GA", "GU", "HI", "ID", "IL",
		"IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN",
		"MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC",
		"ND", "OH", "OK", "OR", "PA", "PR", "RI", "SC", "SD", "TN",
		"TX", "TT", "VI", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
		"MX", "XX"
	};

	public State ()
	{
		state = "XX";
		index = 61;
	}

	public State (String _state)
	{
		state = _state.toUpperCase();
		index = -1;
	}

	public void setState (String _state) { state = _state.toUpperCase(); }
	public String getState () { return state; }
	public int getIndex () { return index; }

	public String toString ()
	{
		return state;
	}

	public boolean isValid ()
	{
		boolean status = false;

		for (int i = 0; i < stateList.length; i ++) {
			if (state.equals (stateList [i])) {
				status = true;
				index = i;
				continue;
			}
		}

		return status;
	}

	public int getStateIndex ()
	{
		if (index != -1) { return index; }

		for (int i = 0; i < stateList.length; i ++) {
			if (state.equals (stateList [i])) {
				index = i;
				break;
			}
		}

		return index;
	}
}



/* Class to validate a Zip Code */
class ZipCode {
	protected int zipcode;
	protected String state;

	protected static int[] minZipByState = {
		35000, 99500, 96799, 85000, 71600,     0,     0,     0, 90000,     0,
		80000,  6000, 19700, 20000, 32000, 30000, 96900, 96700, 83200, 60000,
		46000, 50000, 60000, 40000, 70000,  3900, 20600,  1000, 48000, 55000,
		38600, 63000, 59000, 68000, 88900,  3000,  7000, 87000,  9000, 27000,
		58000, 43000, 73000, 97000, 15000,   600,  2800, 29000, 57000, 37000,
		75000,     0,   600, 84000,  5000, 22000, 98000, 24700, 53000, 82000,
		    0,     0
	};

	protected static int[] maxZipByState = {
		36999, 99999, 96799, 86599, 72999,     0,     0,     0, 96699,     0,
		81699,  6999, 19999, 20599, 34999, 31999, 96999, 96899, 83899, 62999,
		47999, 52899, 67999, 42799, 71499,  4999, 21900,  2799, 49999, 56799,
		39799, 65899, 59999, 69399, 89899,  3899,  8999, 88499, 14999, 28999,
		58899, 45899, 74999, 97999, 19699,   999,  2999, 29999, 57799, 38599,
		79999,     0,   999, 84799,  5999, 24699, 99499, 26899, 54999, 83199,
		    0,     0
	};

	protected static int nyAlternateMin = 400;
	protected static int nyAlternateMax = 499;
	protected static int vaAlternateMin = 20100;
	protected static int vaAlternateMax = 20199;

	public ZipCode ()
	{
		state = "XX";
		zipcode = 0;
	}

	public ZipCode (String _state, int _zipcode)
	{
		state = _state;
		zipcode = _zipcode;
	}

	public ZipCode (String _state, String _zipcode)
	{
		state = _state;
		zipcode = java.lang.Integer.parseInt (_zipcode);
	}

	public ZipCode (String _state)
	{
		state = _state;
		zipcode = 0;
	}

	public boolean isValid ()
	{
		boolean status = false;

		State theState = new State (state);
		int stateIdx = theState.getStateIndex ();

		if (zipcode >= minZipByState [stateIdx] && zipcode <= maxZipByState [stateIdx])
			status = true;

		/* NY - Take care of multiple ranges */
		if (!status && stateIdx == 38 && zipcode >= nyAlternateMin && zipcode <= nyAlternateMax)
			status = true;

		/* VA - Take care of multiple ranges */
		if (!status && stateIdx == 55 && zipcode >= vaAlternateMin && zipcode <= vaAlternateMax)
			status = true;

		return status;
	}
}
