package com.aspire.util;

import java.util.Vector;


public class TypeFlags {
	protected Vector choices = new Vector ();

	public TypeFlags () {
	}

	public TypeFlags (String[] theChoices) {
		for (int i = 0; i < theChoices.length; i ++)
			choices.add(theChoices[i]);
	}

	public void addChoice (String newChoice) {
		choices.add (newChoice);
	}

	public boolean removeChoice (String oldChoice) {
		return choices.remove(oldChoice);
	}

    public void setChoice (int index, String newChoice) {
		choices.setElementAt(newChoice, index);
    }

	public String getChoice (int index) {
		String returnValue = null;

		if (index < choices.size()) {
			try {
				returnValue = (String)choices.elementAt (index);
			} catch (Exception e) {
			}
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

	public int getNumChoices () { return choices.size(); }

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
		Vector flagList = new Vector ();

		for (int i = choices.size(); i >= 0; i --) {
			int thisFlagValue = (1 << i);

			if (currentFlagValue >= thisFlagValue) {
				currentFlagValue -= thisFlagValue;
				flagList.add((String) choices.elementAt(i));
			}
		}

		return (String[]) flagList.toArray();
	}
}
