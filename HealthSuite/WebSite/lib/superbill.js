var _debugFlag = 0;
var nestingDepth = 0;

function numberOrder (a, b) {
	return a - b;
}

function incrementDepth () {
	nestingDepth ++;
	if (_debugFlag) {
		alert ("Nesting Depth is now: " + nestingDepth);
	}
}

function _getIndentation (number) {
	var _spaceString = new String;
	var _number = 0;
	
	while (_number < number) {
		_spaceString = " " + _spaceString;
		_number ++;
	}
	
	return _spaceString;
}

function _stringToCharCodes (theString) {
	var charCodeArray = new Array ();
	
	for (var i = 0; i < theString.length; i ++) {
		charCodeArray.length ++;
		charCodeArray [charCodeArray.length - 1] = theString.charCodeAt (i);
	}
	
	return charCodeArray;
}

function _isAlpha (theCharCode) {
	var minAlpha = 65;
	var maxAlpha = 90;
	var returnValue = 0;
	
	if (theCharCode >= minAlpha && theCharCode <= maxAlpha) {
		returnValue = 1;
	}
	
	return returnValue;
}

function _incrementString (theString) {
	var _theStringAsArray = _stringToCharCodes (theString);
	var carry = 1;
	var carryOut = 0;
	var minNumeric = 48;
	var maxNumeric = 57;
	var minAlpha = 65;
	var maxAlpha = 90;
	
	// Start analyzing the string, character by character, starting from the 'units' side...
	for (var i = _theStringAsArray.length - 1; i >= 0; i --) {
		var minValue, maxValue;
		var currentDigit = _theStringAsArray [i];
		
		// Identify this digit and its range of values...
		if (_isAlpha (currentDigit)) {
			// Alphabetic 'digit'
			minValue = minAlpha;
			maxValue = maxAlpha;
		} else {
			// Numeric 'digit'
			minValue = minNumeric;
			maxValue = maxNumeric;
		}
		
		
		if (carry) {
			// Is this digit at its maximum value?
			if (currentDigit == maxValue) {
				// yes => carry over to next digit...
				currentDigit = minValue;
				carryOut = 1;
			} else {
				// no => just regular increment...
				currentDigit ++;
			}
		}
			
		// setup carry for next digit...
		carry = carryOut;
		carryOut = 0;
		
		// Replace existing 'digit' with the new value...
		_theStringAsArray [i] = currentDigit;
	}
	
	var _incrementedString = String.fromCharCode (_theStringAsArray [0], _theStringAsArray [1], _theStringAsArray [2], _theStringAsArray [3], _theStringAsArray [4]);
	
	return _incrementedString;
}

function _expandRange (rangeStart, rangeEnd) {
	var _temp = rangeStart;
	var _expandedRange = new Array ();
	var itemsLeft = 1;
	
	// Insert the first element into the array...
	_expandedRange.length = 1;
	// Assuming all CPT's are 5 characters long, no matter what :)
	_expandedRange [0] = rangeStart;
	
	while (itemsLeft) {
		if (_debugFlag) {
			alert ("Before incrementing: " + _temp);
		}
		_temp = _incrementString (_temp);
		if (_debugFlag) {
			alert ("After incrementing: " + _temp);
		}
		
		if (_temp == rangeEnd) {
			itemsLeft = 0;
		}
		
		_expandedRange.length ++;
		_expandedRange [_expandedRange.length - 1] = _temp;
	}
	
	return _expandedRange;
}

function _parseRange (cptRange) {
	var rangeValues = cptRange.split (/\s*-\s*/);
	if (_debugFlag) {
		alert ("numValues = " + rangeValues.length);
	}
	var theRange = _expandRange (rangeValues [0], rangeValues [1]);
					
	return theRange;
}

function _parseCPT (cptWidget) {
	var splitRegExp = /(,\s*|[\r\n]+\s*)/;
	var cptList = cptWidget.value;
	cptList.toUpperCase ();
	
	var cptTempArray = cptList.split (splitRegExp);
	var cptParsedArray;
	var cptArray = new Array ();
	
	for (var i = 0; i < cptTempArray.length; i ++) {
		var tempArrayValue = cptTempArray [i];
//		tempArrayValue = tempArrayValue.replace (/[\n\r]+$/, '');
		if (_debugFlag) {
			alert (i + " = " + tempArrayValue);
		}
		if (tempArrayValue.match (/-/) != null) {
			if (_debugFlag) {
				alert (tempArrayValue + "-> _parseRange...");
			}
			cptParsedArray = _parseRange (tempArrayValue);

			for (var j = 0; j < cptParsedArray.length; j ++) {
				cptArray.length ++;
				cptArray [cptArray.length - 1] = cptParsedArray [j];
			}
		} else {
			cptArray.length ++;
			cptArray [cptArray.length - 1] = tempArrayValue;
		}
	}
	
	var cptArrayString = cptArray.join (" | ");
	if (_debugFlag) {
		alert ("cpts entered: " + cptArrayString);
	}
	
	return cptArray;
}

function _delGroupCPTList (theGroup) {
	var df = document.superbillItemList;
	var grpCPT = new Array ();
	var allCPTList = document.superbillData.cpts.value;
	var newCPTList = new Array;

	if (allCPTList != "") {
		var allCPTArray = allCPTList.split (' ');
		
		// Move all items that're not part of this group to another new array...
		for (var i = 0; i < allCPTArray.length; i ++) {
			var _temp = allCPTArray [i];
			var _matches = _temp.match (/(\d+)_(\d+)_(\S+)/);
			
			if (_matches.length) {
				if (_matches [1] < theGroup) {
					newCPTList.length ++;
					newCPTList [newCPTList.length - 1] = _matches [1] + "_" + (newCPTList.length - 1) + "_" + _matches [3];
				} else if (_matches [1] > theGroup) {
					newCPTList.length ++;
					newCPTList [newCPTList.length - 1] = (_matches [1] - 1) + "_" + (newCPTList.length - 1) + "_" + _matches [3];
				}
			}
		}
	}
		
	document.superbillData.cpts.value = newCPTList.join (' ');
}

function _updateGroupCPTList (theGroup, theCPTList) {
	var df = document.superbillItemList;
	var grpCPT = new Array ();
	var allCPTList = document.superbillData.cpts.value;
	var newCPTList = new Array;

	if (allCPTList != "") {
		var allCPTArray = allCPTList.split (' ');
		
		// Move all items that're not part of this group to another new array...
		for (var i = 0; i < allCPTArray.length; i ++) {
			var _temp = allCPTArray [i];
			var _matches = _temp.match (/(\d+)_(\d+)_(\S+)/);
			
			if (_matches.length) {
				if (_matches [1] != theGroup) {
					newCPTList.length ++;
					newCPTList [newCPTList.length - 1] = _matches [1] + "_" + (newCPTList.length - 1) + "_" + _matches [3];
				}
			}
		}
	}
		
	// Add i tems that're part of this group now...
	for (var i = 0; i < theCPTList.length; i ++) {
		newCPTList.length ++;
		newCPTList [newCPTList.length - 1] = theGroup + "_" + i + "_" + theCPTList [i];
	}
	
	document.superbillData.cpts.value = newCPTList.join (' ');
}

function _getStoredGroupCPTList (theGroup) {
	var df = document.superbillItemList;
	var grpCPT = new Array ();
	var allCPTList = document.superbillData.cpts.value;

	if (allCPTList != "") {
		var allCPTArray = allCPTList.split (' ');
		
		for (var i = 0; i < allCPTArray.length; i ++) {
			var _temp = allCPTArray [i];
			var _matches = _temp.match (/(\d+)_(\d+)_(\S+)/);
			
			if (_matches.length) {
				if (_matches [1] == theGroup) {
					grpCPT.length ++;
					grpCPT [grpCPT.length - 1] = _matches [3];
				}
			}
		}
	}

	return grpCPT;
}

// Now gets the most current list as reflected in the select widget
function _getGroupCPTList (theGroup) {
	var df = document.superbillItemList;
	var grpCPT = new Array ();

	for (var i = 0; i < df.superbillData.length; i ++) {
		var value = df.superbillData.options [i].value;
		var text = df.superbillData.options [i].text;
		
		value = value.replace (/ /g, "_");
		text = text.replace (/ /g, "_");
		grpCPT.length ++;
		grpCPT [grpCPT.length - 1] = value + ":" + text;
		if (_debugFlag) {
			alert ('getGroupCPTList: grpCPT [' + i + '] = ' + grpCPT [i]);
		}
	}

	return grpCPT;
}

function _refreshGroupList () {
	var df = document.superbillItemList;
	var groupListing = document.superbillData.groups.value;
	var groupListingArray = groupListing.split (' ');
	
	for (var i = 1; i < groupListingArray.length; i ++) {
		var _temp = groupListingArray [i];
		var _matches = _temp.match (/(\d+)_(.+)/);
		var _temp2 = _matches [2];
		_temp2 = _temp2.replace (/_/g, " ");
		
		df.superbillGroups.options [df.superbillGroups.length] = new Option (_temp2, i);
	}
}

function _populateGroupCPT (grpWidget) {
	var currGroup = grpWidget.selectedIndex;
	var currGrpCPTList = _getStoredGroupCPTList (currGroup);
	var df = document.superbillItemList;
	
	df.superbillData.options.length = 0;

	for (var i = 0; i < currGrpCPTList.length; i ++) {
		var _temp = currGrpCPTList [i];
		_temp = _temp.replace (/_/g, " ");
		if (_debugFlag) {
			alert ('_populateGroupCPT: _temp = ' + _temp);
		}
		_matches = _temp.split (/:/);
		df.superbillData.options [i] = new Option (_matches [1], _matches [0]);
		if (_debugFlag) {
			alert ('_populateGroupCPT: Text = ' + _matches [1] + ', Value = ' + _matches [0]);
		}
	}
}

function _updateGroups () {
	var df = document.superbillItemList;
	var currGrpList = new Array ();
	var currGrpListAsString;
	
	for (var i = 0; i < df.superbillGroups.length; i ++) {
		var grpName = df.superbillGroups.options [i].text;
		grpName = grpName.replace (/ /, '_');
		
		if (currGrpListAsString) {
			currGrpListAsString = currGrpListAsString + ' ' + i + '_' + grpName;
		} else {
			currGrpListAsString = i + '_' + grpName;
		}
	}
	
	document.superbillData.groups.value = currGrpListAsString;
}

function _addGroupHeading () {
	var df = document.superbillItemList;
	
	if (df.groupHeading.value == "") {
		alert ("Please enter a group heading before clicking this button.  Thank you");
	} else {
		df.superbillGroups.options [df.superbillGroups.length] = new Option (df.groupHeading.value, df.groupHeading.value);
		df.superbillGroups.selectedIndex = df.superbillGroups.length - 1;
		
		// Add this group to the end of the list of groups...
		var groupName = df.groupHeading.value;
		groupName = groupName.replace (/ /g, '_');
		var groupList = document.superbillData.groups.value;
		var groupListArray = groupList.split (' ');
		groupName = groupListArray.length + "_" + groupName;
		groupListArray.length ++;
		groupListArray [groupListArray.length - 1] = groupName;

		if (_debugFlag) {
			alert ("Added group named " + groupName + " as group #" + groupListArray.length);
		}
		
		groupList = groupListArray.join (' ');
		document.superbillData.groups.value = groupList;
	}
}

function _delGroupHeading () {
	var df = document.superbillItemList;
	
	if (df.superbillGroups.selectedIndex < 1) {
		alert ("Please select a group heading to delete.");
	} else {
		var groupNum = df.superbillGroups.selectedIndex;
		df.superbillGroups.options [df.superbillGroups.selectedIndex] = null;
		df.superbillGroups.selectedIndex --;
		
		// Delete this group from the list of groups...
		var groupName = df.groupHeading.value;
		groupName = groupName.replace (/ /g, '_');
		var groupList = document.superbillData.groups.value;
		var groupListArray = groupList.split (' ');
		
		var newGroupListArray = new Array ();
		var matchNotFound = 1;

		for (var i = 0; i < groupListArray.length && matchNotFound; i ++) {
			var _tempGrp = groupListArray [i];

			if (i < groupNum) {
				newGroupListArray.length ++;
				newGroupListArray [newGroupListArray.length - 1] = _tempGrp;
			} else if (i > groupNum) {
				_matches = _tempGrp.match (/(\d+)_(\S+)/);
			
				if (_matches.length) {
					newGroupListArray.length ++;
					newGroupListArray [newGroupListArray.length - 1] = (_matches [1] - 1) + "_" + _matches [2];
				}
			}
		}
		
		groupListArray = newGroupListArray;
		groupList = groupListArray.join (' ');
		document.superbillData.groups.value = groupList;
		_delGroupCPTList (groupNum);
	}
	_populateGroupCPT(document.superbillItemList.superbillGroups);
}

function _addCPT () {
	var df = document.superbillItemList;
	var currentGroup = (df.superbillGroups.selectedIndex < 0) ? 0 : df.superbillGroups.selectedIndex;
	var groupCPTList = _getGroupCPTList (currentGroup);
	
	if (_debugFlag) {
		alert ("Current Group: " + currentGroup);
	}
	
	var cptArray = _parseCPT (df.cpts);
	var cptArrayString = cptArray.join (" | ");

	if (_debugFlag) {
		alert ("cpts received (" + cptArray.length + "): " + cptArrayString);
	}
	
	for (var i = 0; i < cptArray.length; i ++) {
		var tempCPTValue = cptArray [i];
		var duplicate = 0;
		
		// Make it look like the rest of the cpt and group names... :)
		tempCPTValue = tempCPTValue.replace (/ /g, "_");
		
		// Search for dupes in there...
		for (var j = 0; j < groupCPTList.length && duplicate == 0; j ++) {
			var currCPT = groupCPTList [j];

			// Current format for CPT Storage: 90782:Shots_Across_Texas
			var cptComponents = currCPT.split (':');
			var cptCode = cptComponents [0];
			var cptCaption = cptComponents [1];
			
			if (_debugFlag) {
				alert ('Dupe Search: Comparing ' + cptCode + ' and ' + cptArray [i]);
			}
			if (cptCode == cptArray [i]) {
				duplicate = 1;
			}
		}
		
		if (duplicate == 0) {
			if (_debugFlag) {
				alert ("Adding " + tempCPTValue + " to Group " + currentGroup);
			}
			groupCPTList.length ++;
			groupCPTList [groupCPTList.length - 1] = tempCPTValue + ":" + tempCPTValue;
		}
	}
	
	var groupCPTListString = groupCPTList.join (" | ");
	if (_debugFlag) {
		alert ("cpts in group (" + groupCPTList.length + "): " + groupCPTListString);
	}
	
	if (_debugFlag) {
		alert ("Group list: " + document.superbillData.groups.value);
		alert ("CPT list: " + document.superbillData.cpts.value);
	}
	_updateGroupCPTList (currentGroup, groupCPTList);
	if (_debugFlag) {
		alert ("Group list: " + document.superbillData.groups.value);
		alert ("CPT list: " + document.superbillData.cpts.value);
	}
	_populateGroupCPT(document.superbillItemList.superbillGroups);
}

function _delCPT () {
	var df = document.superbillItemList;

	if (df.superbillData.selectedIndex < 0) {
		alert ("Please select a CPT to delete.  Thank you");
	} else {
		var df = document.superbillItemList;
	
		if (_debugFlag) {
			alert('Text: ' + oldText + ', Value: ' + value + ', new Text: ' + text);
		}
		
		for (var i = 0; i < df.superbillData.length; i ++) {
			if (df.superbillData.options [i].selected) {
				df.superbillData.options [i] = null;
			}
		}
		
		var currentGroup = (df.superbillGroups.selectedIndex < 0) ? 0 : df.superbillGroups.selectedIndex;
		var groupCPTList = _getGroupCPTList (currentGroup);

		if (_debugFlag) {
			alert ("Group list: " + document.superbillData.groups.value);
			alert ("CPT list: " + document.superbillData.cpts.value);
		}
		_updateGroupCPTList (currentGroup, groupCPTList);
		if (_debugFlag) {
			alert ("Group list: " + document.superbillData.groups.value);
			alert ("CPT list: " + document.superbillData.cpts.value);
		}
		_populateGroupCPT(document.superbillItemList.superbillGroups);
	}
}

function _moveCPTUp () {
	var df = document.superbillItemList;
	
	if (df.superbillData.selectedIndex > 0) {
		var currIdx = df.superbillData.selectedIndex;
		var newIdx = currIdx - 1;
		
		var tempText = df.superbillData.options [newIdx].text;
		var tempValue = df.superbillData.options [newIdx].value;
		
		df.superbillData.options [newIdx].text = df.superbillData.options [currIdx].text;
		df.superbillData.options [newIdx].value = df.superbillData.options [currIdx].value;
		df.superbillData.options [currIdx].text = tempText;
		df.superbillData.options [currIdx].value = tempValue;

		var currentGroup = (df.superbillGroups.selectedIndex < 0) ? 0 : df.superbillGroups.selectedIndex;
		var groupCPTList = _getGroupCPTList (currentGroup);
		_updateGroupCPTList (currentGroup, groupCPTList);
		df.superbillData.selectedIndex = newIdx;
	}
}

function _moveCPTDown () {
	var df = document.superbillItemList;
	
	if (df.superbillData.selectedIndex >= 0 && df.superbillData.selectedIndex < (df.superbillData.length - 1)) {
		var currIdx = df.superbillData.selectedIndex;
		var newIdx = currIdx + 1;
		
		var tempText = df.superbillData.options [newIdx].text;
		var tempValue = df.superbillData.options [newIdx].value;
		
		df.superbillData.options [newIdx].text = df.superbillData.options [currIdx].text;
		df.superbillData.options [newIdx].value = df.superbillData.options [currIdx].value;
		df.superbillData.options [currIdx].text = tempText;
		df.superbillData.options [currIdx].value = tempValue;

		var currentGroup = (df.superbillGroups.selectedIndex < 0) ? 0 : df.superbillGroups.selectedIndex;
		var groupCPTList = _getGroupCPTList (currentGroup);
		_updateGroupCPTList (currentGroup, groupCPTList);
		df.superbillData.selectedIndex = newIdx;
	}
}

function _moveGroupUp () {
	var df = document.superbillItemList;
	
	if (df.superbillGroups.selectedIndex > 0) {
		var currIdx = df.superbillGroups.selectedIndex;
		var newIdx = currIdx - 1;
		
		var tempGrpCPTList = _getStoredGroupCPTList (newIdx);
		var currGrpCPTList = _getGroupCPTList (currIdx);
		
		var tempGrpName = df.superbillGroups.options [newIdx].text;
		df.superbillGroups.options [newIdx].text = df.superbillGroups.options [currIdx].text;
		df.superbillGroups.options [currIdx].text = tempGrpName;
		
		alert ('groups = ' + document.superbillData.groups.value);
		_updateGroups ();
		alert ('groups = ' + document.superbillData.groups.value);
		_updateGroupCPTList (currIdx, tempGrpCPTList);
		_updateGroupCPTList (newIdx, currGrpCPTList);
		df.superbillGroups.selectedIndex = newIdx;
	}
}

function _moveGroupDown () {
	var df = document.superbillItemList;
	
	if (df.superbillGroups.selectedIndex >= 0 && df.superbillGroups.selectedIndex < (df.superbillGroups.length - 1)) {
		var currIdx = df.superbillGroups.selectedIndex;
		var newIdx = currIdx + 1;
		
		var tempGrpCPTList = _getStoredGroupCPTList (newIdx);
		var currGrpCPTList = _getGroupCPTList (currIdx);
		
		var tempGrpName = df.superbillGroups.options [newIdx].text;
		df.superbillGroups.options [newIdx].text = df.superbillGroups.options [currIdx].text;
		df.superbillGroups.options [currIdx].text = tempGrpName;
		
		alert ('groups = ' + document.superbillData.groups.value);
		_updateGroups ();
		alert ('groups = ' + document.superbillData.groups.value);
		_updateGroupCPTList (currIdx, tempGrpCPTList);
		_updateGroupCPTList (newIdx, currGrpCPTList);
		df.superbillGroups.selectedIndex = newIdx;
	}
}

function _updateCaption () {
	var df = document.superbillItemList;
	
	if (df.superbillData.selectedIndex >= 0) {
		var text = df.superbillDataCaption.value;
		var oldText = df.superbillData.options [df.superbillData.selectedIndex].text;
		var value = df.superbillData.options [df.superbillData.selectedIndex].value;
		
		if (_debugFlag) {
			alert('Text: ' + oldText + ', Value: ' + value + ', new Text: ' + text);
		}
		
		df.superbillData.options [df.superbillData.selectedIndex] = new Option (text, value);
		
		var currentGroup = (df.superbillGroups.selectedIndex < 0) ? 0 : df.superbillGroups.selectedIndex;
		var groupCPTList = _getGroupCPTList (currentGroup);
		_updateGroupCPTList (currentGroup, groupCPTList);
	}
}

function _createSuperbill () {
	var dd = document.superbillData;
	var df = document.superbillItemList;
	
	dd.caption.value = df.superbillName.value;
	dd.description.value = df.superbillDescription.value;
	dd.catalog_id.value = df.superbillID.value;
	dd.submit ();
}

function _refreshSuperbill () {
	var dd = document.superbillData;
	var df = document.superbillItemList;
	
	df.superbillName.value = dd.caption.value;
	df.superbillDescription.value = dd.description.value;
	df.superbillID.value = dd.catalog_id.value;
}