package util;

import java.util.Vector;
import java.util.ArrayList;
import java.util.List;
import java.util.StringTokenizer;


public class TypeFlags {
	private List choices = new ArrayList ();

	public TypeFlags () {
	}

	public TypeFlags (String[] theChoices) {
		for (int i = 0; i < theChoices.length; i ++)
			choices.add(theChoices[i]);
	}

	public void addChoice (String newChoice) {
		choices.add(newChoice);
	}

	public boolean removeChoice (String oldChoice) {
		return choices.remove(oldChoice);
	}

    public void setChoice (int index, String newChoice) {
		choices.set(index, newChoice);
    }

	public String getChoice (int index) {
		String returnValue = null;

		if (index < choices.size()) {
			returnValue = (String)choices.get(index);
		}

		return returnValue;
	}

	public int getIndex (String theChoice) {
		return choices.indexOf(theChoice);
	}

	public int getFlagValue (String theChoice) {
		int index = choices.indexOf(theChoice);
		return (1 << index);
	}

	public int getMaxFlagValue () {
		int returnValue = 0;

		for (int i = 0; i < choices.size(); i ++)
			returnValue += (1 << i);

		return returnValue;
	}

	public int getNumChoices () { return choices.size(); }

	public int translateStringToFlagValue (String flaggedChoices) {
		return translateStringToFlagValue (flaggedChoices, ",");
	}

    public int translateStringToFlagValue (String flaggedChoices, String delimiter) {
		StringTokenizer st = new StringTokenizer (flaggedChoices, delimiter);

		int flags = 0;

		while (st.hasMoreTokens())
			flags += getFlagValue(st.nextToken().trim());

		return flags;
	}

	public int translateStringsToFlagValue (String[] flaggedChoices) {
		int flagValue = 0;

		for (int i = 0; i < flaggedChoices.length; i ++) {
			int flagIdx = choices.indexOf(flaggedChoices[i]);

			flagValue += (1 << flagIdx);
		}

		return flagValue;
	}

	public String[] translateFlagValueToStrings (int flagValue) {
		int currentFlagValue = flagValue;
		List flagList = new ArrayList();

		for (int i = choices.size(); i >= 0; i --) {
			int thisFlagValue = (1 << i);

			if (currentFlagValue >= thisFlagValue) {
				currentFlagValue -= thisFlagValue;
				flagList.add((String) choices.get(i));
			}
		}

		String[] returnValue = new String [flagList.size()];

		for (int i = 0; i < flagList.size(); i ++) {
			returnValue[i] = (String) flagList.get(i);
		}

		return returnValue;
	}

	public String translateFlagValueToSqlSet (int flagValue) {
		int currentFlagValue = flagValue;
		List flagList = new ArrayList();

		for (int i = choices.size(); i >= 0; i --) {
			int thisFlagValue = (1 << i);

			if (currentFlagValue >= thisFlagValue) {
				currentFlagValue -= thisFlagValue;
				flagList.add((String) choices.get(i));
			}
		}

		String returnValue = "( ";

		for (int i = 0; i < flagList.size(); i ++) {
			if (returnValue.equals("( ")) {
				returnValue += "'" + (String) flagList.get(i) + "'";
			} else {
				returnValue += ", '" + (String) flagList.get(i) + "'";
			}
		}

		returnValue += " )";

		return returnValue;
	}
}
