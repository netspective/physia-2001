/****************************************************************************
 PHYSIA PAGE.JS
 (C) Copyright 2000, Physia Corporation

 This library is loaded into every page that is displayed in a physia
 application.
 ***************************************************************************/

//****************************************************************************
// Global constants
//****************************************************************************

var WINDOWNAME_FINDPOPUP = '_physia_findPopup';
var WINDOWNAME_ACTIONPOPUP = '_physia_actionPopup';

// These constants MUST be kept identical to what is in CGI::Validator::Field
var FLDFLAG_INVISIBLE = 1;
var FLDFLAG_CONDITIONAL_INVISIBLE = 2;
var FLDFLAG_READONLY = 4;
var FLDFLAG_CONDITIONAL_READONLY = 8;
var FLDFLAG_REQUIRED = 16;
var FLDFLAG_IDENTIFIER = 32;
var FLDFLAG_UPPERCASE = 64;
var FLDFLAG_UCASEINITIAL = 128;
var FLDFLAG_LOWERCASE = 256;
var FLDFLAG_TRIM = 512;
var FLDFLAG_FORMATVALUE = 1024;
var FLDFLAG_CUSTOMVALIDATE = 2048;
var FLDFLAG_CUSTOMDRAW = 4096;
var FLDFLAG_NOBRCAPTION = 8192;
var FLDFLAG_PERSIST = 16384;
var FLDFLAG_HOME = 32768;
var FLDFLAG_SORT = 65536;

var OPTIONFLAG_TRANSKEY_DONT_MOVE_ON_ENTER = 1;

//****************************************************************************
// Create a list of all the URL parameters
//****************************************************************************

var urlParamsStr = location.search.substring(1, location.search.length);
var urlParamsList = urlParamsStr.split('&');
var urlParams = []; // this is an associative array
var urlParamsCount = 0;

for(var i = 0; i < urlParamsList.length; i++)
{
	var paramInfo = urlParamsList[i].split('=');
	var paramName = paramInfo[0];
	var paramValue = unescape(paramInfo[1]);
	// if multiple parameters are found, they are put into a list
	if(urlParams[paramName])
	{
		var curValue = urlParams[paramName];
		var newValue = curValue;
		if(typeof curValue != "object")
		{
			newValue = new Array();
			newValue[0] = curValue;
		}
		newValue[newValue.length] = paramValue;
		urlParams[paramName] = newValue;
	}
	else
	{
		urlParams[paramName] = paramValue;
	}
	urlParamsCount++;
}

//****************************************************************************
// General Utility Functions/Declarations
//****************************************************************************

function appendURLParams(url, params)
{
	if(params == null || params == '')
		return url;

	var urlStr = new String(url);
	urlStr += urlStr.indexOf('?') != -1 ? '&' : '?';
	urlStr += params;
	return urlStr;
}

function createURL(URL, paramsArray)
{
	var params = new String(paramsArray.join('&'));
	var newURL = appendURLParams(appendURLParams(URL, params), PARAMNAME_SESSIONKEY + '=' + urlParams[PARAMNAME_SESSIONKEY]);
	//alert(newURL);
	return newURL;
}

function goHRef(URL, paramsArray)
{
	location.href = createURL(URL, paramsArray);
}

var fieldsCleared = new Array;

function clearField(field)
{
	if(! fieldsCleared[field.name])
	{
		field.value = "";
		fieldsCleared[field.name] = 1;
	}
}

var dialogFields = {};

var KEYCODE_ENTER = 13;
var FIELDFLAG_NEXTFIELDONENTERKEY = 0x0001;
var LOWER_TO_UPPER_CASE=32;


var numKeysRange   = [48, 57];
var periodKeyRange = [46, 46];
var dashKeyRange   = [45, 45];
var upperAlphaRange = [65,90];
var lowAlphaRange  = [97,122];
var underScoreKeyRange = [95,95];
var validDateStrings = ["today", "now", "tomorrow", "yesterday"];
var validTimeStrings = [validDateStrings, "noon", "midnight"];
var validNumbers =  ["0","1","2","3","4","5","6","7","8","9"];

function searchDialogFlagNoValue(flag)
{
	var dialog = dialogFields['dialog'];
	for (i in dialog)
	{
		var field = dialog[i];
		var element = "document.forms.dialog."+i;
		if (eval(element))
		{
			var value = eval(element+".value");
			if ( (field.options & flag) && (typeof(value) == "string") && (value.length == 0) )
			{
				return i;
			}
		}
	}
	return null;
}

function getDialogData(fieldName, dataName)
{
	var dialog = dialogFields['dialog'];
	var field = dialog[fieldName];
	return eval("field."+dataName);
}

function processOnInit()
{
	//setDialogHome()
	return true;
}

// Puts the cursor in the correct field element
function setDialogHome()
{
	var dialog = dialogFields['dialog'];
	if (dialog)
	{
		var field = searchDialogFlagNoValue(FLDFLAG_HOME);
		if (field != null)
		{
			setFocus(field);
		}
		else
		{
			for (field in dialog)
			{
				setFocus(field);
				return true;
			}
		}
	}
	return true;
}

function validateOnSubmit(objForm)
{
	var objSelect;
	var field;
	
	field = searchDialogFlagNoValue(FLDFLAG_REQUIRED);
	if (field != null)
	{
		var fieldName = getDialogData(field, "name");
		var fieldCaption = getDialogData(field, "caption");
		validationError(field, fieldCaption+" required!");
		return false;
	}

	// Select all items in multidual elements. If items aren't selected, they won't be posted.
	var dialog = dialogFields['dialog'];
	for (var i in dialog)
	{
		field = dialog[i];
		if (field.style == "multidual")
		{
			objSelect = eval("document.forms.dialog."+i);
			for (var j = 0; j < objSelect.options.length; j++) 
			{
				objSelect.options[j].selected = true;
			}
		}
	}

	return true;
}

function translateEnterKey(event, flags)
{
	if(event.keyCode == KEYCODE_ENTER || event.which == KEYCODE_ENTER)
	{
		var dialog = dialogFields['dialog'];
		var field = dialog[event.srcElement.name];
		var blnMoveNextField = true;
		
		if (flags != null) {
			if (flags & OPTIONFLAG_TRANSKEY_DONT_MOVE_ON_ENTER)
				blnMoveNextField = false;
		}

		if(field.nextFld != null && blnMoveNextField)
		{
			var property = "document.forms.dialog."+field.nextFld;
			if(eval(property))
			{
				var moved = false;
				var focusMethod = eval(property+".focus");
				if(focusMethod)
				{
					focusMethod();
					moved = true;
				}
				event.returnValue = false;
				if(! moved)
					alert('Please press Tab to get to the next field ('+property+').');
				return true;
			}
		}
	}
	return false;
}

function keypressAcceptAny(event, flags, acceptKeyRanges)
{
	var keyCodeValue;

	if(translateEnterKey(event, flags))
		return;

	for (i in acceptKeyRanges)
	{
		if (event.keyCode) {
			keyCodeValue = event.keyCode;
		}
		else {
			keyCodeValue = event.which;
		}

		var keyInfo = acceptKeyRanges[i];
		if(keyCodeValue >= keyInfo[0] && keyCodeValue <= keyInfo[1]) {
			return true;
		}
	}

	// if we get to here, it means we didn't accept any of the ranges
	return false;

}

function processKeypress_identifier(event, flags)
{
	if (event.keyCode) {	// IE 
		if (event.keyCode >= lowAlphaRange[0] && event.keyCode <= lowAlphaRange[1])
			event.keyCode = event.keyCode - LOWER_TO_UPPER_CASE;
	}
	else {	// NS
		if (event.which >= lowAlphaRange[0] && event.which <= lowAlphaRange[1])
			event.which = event.which - LOWER_TO_UPPER_CASE;
	}
	return keypressAcceptAny(event, flags, [numKeysRange, dashKeyRange,lowAlphaRange,upperAlphaRange,underScoreKeyRange]);
}


function processKeypress_default(event, flags)
{
	translateEnterKey(event, flags);
	return true;
}

function processKeypress_float(event, flags)
{
	return keypressAcceptAny(event, flags, [numKeysRange, periodKeyRange]);
}

function processKeypress_integer(event, flags)
{
	return keypressAcceptAny(event, flags, [numKeysRange]);
}

function processKeypress_alphaonly(event, flags)
{
	return keypressAcceptAny(event, flags, [upperAlphaRange, lowAlphaRange]);
}

function processKeypress_integerdash(event, flags)
{
	return keypressAcceptAny(event, flags, [numKeysRange, dashKeyRange]);
}

function parseNumbers(string)
{
	var nums = "";
	for (var i = 0; i < string.length; i++)
	{
		if (string.charAt(i) >= "0" && string.charAt(i) <= "9")
			nums += string.charAt(i);
	}
	if (nums == "")
		return null;
	else
		return nums;
}

function validateChange_SSN(event, flags)
{
	var inSSN = event.srcElement.value + "";
	var nums = parseNumbers(inSSN);
	var fmtMessage = "SSN must be in the correct format NNN-NN-NNNN";

	if (nums == null)
	{
		if (inSSN.length > 0)
			validationError(event.srcElement.name, fmtMessage);
		return;
	}
	if (nums.length == 9)
	{
		var ssn = nums.substring(0,3) + "-" + nums.substring(3,5) + "-" + nums.substring(5);
		event.srcElement.value = ssn;
	}
	else
	{
		validationError(event.srcElement.name, fmtMessage);

	}
}

// returns a string of exactly count characters left padding with zeros
function padZeros(number, count)
{
	var padding = "0";
	for (var i=1; i < count; i++)
		padding += "0";
	if (typeof(number) == 'number')
		number = number.toString();
	if (number.length < count)
		number = (padding.substring(0, (count - number.length))) + number;
	if (number.length > count)
		number = number.substring((number.length - count));
	return number;
}

function validateChange_Date(event, flags)
{
	event.srcElement.value = validateDate(event.srcElement.name, event.srcElement.value);
}

function validateDate(fieldName, inDate)
{
	var field = 0;
	var today = new Date();
	var currentDate = today.getDate();
	var currentMonth = today.getMonth() + 1;
	var currentYear = today.getYear();
	var fmtMessage = "Date must be in correct format: 'D', 'M/D', 'M/D/Y', or 'M/D/YYYY'";

	inDate = inDate.toLowerCase();
	for (i in validDateStrings)
		if (inDate == validDateStrings[i]) return inDate;
	var a = splitNotInArray(inDate, validNumbers);
	for (i in a)
	{
		a[i] = '' + a[i];
	}
	if (a.length == 0)
	{
		if (inDate.length > 0)
			validationError(fieldName, fmtMessage);
		return inDate;
	}
	if (a.length == 1)
	{
		if ((a[0].length == 6) || (a[0].length == 8))
		{
			a[2] = a[0].substring(4);
			a[1] = a[0].substring(2,4);
			a[0] = a[0].substring(0,2);
		}
		else
		{
			if (a[0] == 0)
			{
				a[0] = currentMonth;
				a[1] = currentDate;
			}
			else
			{
				a[1] = a[0];
				a[0] = currentMonth;
			}
		}
	}
	if (a.length == 2)
	{
		if (a[0] <= (currentMonth - 3))
			a[2] = currentYear + 1;
		else
			a[2] = currentYear;
	}
	if (a[2] < 100 && a[2] > 10)
		a[2] = "19" + a[2];
	if (a[2] < 1000)
		a[2] = "20" + a[2];
	if ( (a[0] < 1) || (a[0] > 12) )
	{
		validationError(fieldName, "Month value must be between 1 and 12");
		return inDate;
	}
	if ( (a[1] < 1) || (a[1] > 31) )
	{
		validationError(fieldName, "Day value must be between 1 and 31");
		return inDate;
	}
	if ( (a[2] < 1800) || (a[2] > 2999) )
	{
		validationError(fieldName, "Year must be between 1800 and 2999");
		return inDate;
	}
	return padZeros(a[0],2) + "/" + padZeros(a[1],2) + "/" + a[2];
}

// Split "string" into multiple tokens at "char"
function splitOnChar(strString, strDelimiter)
{
	var a = new Array();
	var field = 0;
	for (var i = 0; i < strString.length; i++)
	{
		if ( strString.charAt(i) != strDelimiter )
		{
			if (a[field] == null)
				a[field] = strString.charAt(i);
			else
				a[field] += strString.charAt(i);
		}
		else
		{
			if (a[field] != null)
				field++;
		}
	}
	return a;
}

// Split "strString" into multiple tokens at inverse of "array"
function splitNotInArray(strString, arrArray)
{
	var a = new Array();
	var field = 0;
	var matched;
	for (var i = 0; i < strString.length; i++)
	{
		matched = 0;
		for (k in arrArray)
		{
			if (strString.charAt(i) == arrArray[k])
			{
				if (a[field] == null)
					a[field] = strString.charAt(i);
				else
					a[field] += strString.charAt(i);
				matched = 1;
				break;
			}
		}
		if ( matched == 0 && a[field] != null )
			field++;
	}
	return a;
}

function validateTime(fieldName, inTime)
{
	var today = new Date();
	var currentHour = today.getHours();
	var currentTime = currentHour < 12 ? "am" : "pm";
	var hour;
	var min;
	var time;
	var fmtMessage = "Time must be in 'HH:MM AM', 'HH:MM PM', or military time 'HHMM'";

	inTime = inTime.toLowerCase();
	for (i in validTimeStrings)
		if (inTime == validTimeStrings[i]) return inTime;
	var a = splitNotInArray(inTime, ["a", "p"]);
	if (a.length > 1)
	{
		if (inTime.length > 0)
			validationError(fieldName, fmtMessage);
		return "";
	}
	if (a.length == 1)
		time = a[0] == "a" ? "AM" : "PM";
	var a = splitNotInArray(inTime, validNumbers);
	for (i in a)
		a[i] = parseInt(a[i]);
	if (a.length == 0 || a.length > 2)
	{
		if (inTime.length > 0)
		{
			validationError(fieldName, fmtMessage);
			return inTime;
		}
		else
			return "";
	}
	if (a.length == 1)
	{
		if (a[0] < 24)
		{
			hour = a[0]
			min = 0;
		}
		else
		{
			if (a[0] < 100)
			{
				hour = 0;
				min = a[0];
			}
			else
			{
				hour = parseInt(a[0] / 100);
				min = a[0] % 100;
			}
		}
	}
	if (a.length == 2)
	{
		hour = a[0];
		min = a[1];
	}
	if (hour > 12)
	{
		hour -= 12;
		time = "PM";
	}
	if (time == null)
	{
		if (hour < 7)
			time = "PM";
		else
			time = "AM";
	}
	if (hour == 0)
		hour = 12;
	if (hour < 1 || hour > 12)
	{
		validationError(fieldName, "Hour value must be between 1 and 12");
		return inTime;
	}
	if (min < 0 || min > 59)
	{
		validationError(fieldName, "Minutes value must be between 0 and 59");
		return inTime;
	}
	return padZeros(hour,2) + ":" + padZeros(min,2) + " " + time;
}

function validateChange_Time(event, flags)
{
	event.srcElement.value = validateTime(event.srcElement.name, event.srcElement.value);
}

function validateChange_Stamp(event, flags)
{
	var inStamp = event.srcElement.value;
	var a = splitOnChar(inStamp, " ");
	var date;
	var time;
	var fieldName = "DateTime Stamp";
	var fmtMessage = fieldName;
	fmtMessage += " must be entered in the correct format:\n\n";
	fmtMessage += "\tDD HH\n";
	fmtMessage += "\tMM/DD HH:MM\n";
	fmtMessage += "\tMM/DD/YYYY HH:MM [AP]M\n\n";
	fmtMessage += "Note: The date and time must be separated by at least one space, however\n";
	fmtMessage += "a space is not required between the time and the 'AM' or 'PM'.  Also, using\n";
	fmtMessage += "'a' for 'AM' and 'p' for 'PM' will suffice.\n\n";
	fmtMessage += "Examples:\n\n";
	fmtMessage += "\t'0 3' becomes 'current-date 03:00 PM'\n";
	fmtMessage += "\t'15 8:30' becomes 'current-month/15/current-year 08:30 AM'\n\n";
	fmtMessage += "If you don't enter a year and the month entered is more than 3 months behind\n";
	fmtMessage += "the current month, it will automatically set the year to the next year.  For example\n";
	fmtMessage += "if it was currently December 6, 2000:\n\n";
	fmtMessage += "\t'1/1 9' becomes '01/01/2001 09:00 AM'\n";
	fmtMessage += "\t'11/15 9' becomes '11/15/2000 09:00 AM'\n";
	if (a.length < 2)
	{
		if (inStamp.length > 0)
			validationError(event.srcElement.name, fmtMessage);
		return;
	}
	date = validateDate(event.srcElement.name, a[0]);
	for (var i = 2; i < a.length; i++)
	{
		a[1] += a[i];
	}
	time = validateTime(event.srcElement.name, a[1]);
	event.srcElement.value = date + " " + time;
}

function validationError(fieldName, fmtMessage)
{
	setFocus(fieldName);
	alert(fmtMessage);
}

function setFocus(fieldName)
{
	var field = "document.forms.dialog."+fieldName;
	if(eval(field))
	{
		var focusMethod = eval(field+".focus");
		if (focusMethod)
		{
			focusMethod();
		}
	}
}

function validateChange_Float(event, flags)
{
	var a = splitNotInArray(event.srcElement.value, ["."]);
	var fmtMessage = "A number cannot contain more than one decimal point!";
	if (a.length == 0) return true;
	if (a.length > 1 || a[0].length > 1)
		validationError(event.srcElement.name, fmtMessage);
}

function validateChange_Percentage(event, flags)
{
	validateChange_Float(event, flags);
}

function validateChange_Currency(event, flags)
{
	validateChange_Float(event, flags);
}

function validateChange_EMail(event, flags)
{
}

function validateChange_Zip(event, flags)
{
	var inZip = event.srcElement.value;
	var fmtMessage = "Zip code must be entered in the correct format: '12345', '123456789' or '12345-6789'";
	var nums = parseNumbers(inZip);
	if (nums == null)
	{
		if (inZip.length > 0)
			validationError(event.srcElement.name, fmtMessage);
		return;
	}
	if (nums.length == 9)
		event.srcElement.value = nums.substring(0,5) + "-" + nums.substring(5,9);
	else
	{
		if (nums.length == 5)
			event.srcElement.value = nums;
		else
			validationError(event.srcElement.name, fmtMessage);
	}
}

function validatePhone(inPhone, sep, fmtMessage)
{
	var outPhone = "";
	var nums = parseNumbers(inPhone);
	if (nums == null)
		return null;
	if (nums.length >= 10)
	{
		outPhone = nums.substring(0,3) + "-" + nums.substring(3,6) + "-" + nums.substring(6,10);
		if (nums.length > 10)
			outPhone += sep + nums.substring(10);
		return outPhone;
	}
	return null;
}

function validateChange_Pager(event, flags)
{
	var fmtMessage = "Pager number must be in the correct format: 'XXX-XXX-XXXX pXXXXXX'";
	var inPager = event.srcElement.value;
	var outPager = validatePhone(inPager, " p", fmtMessage);
	if (outPager != null)
		event.srcElement.value = outPager;
	else
	{
		if (inPager.length > 0)
			validationError(event.srcElement.name, fmtMessage);
	}
}

function validateChange_Phone(event, flags)
{
	var fmtMessage = "Phone number must be in the correct format: 'XXX-XXX-XXXX xXXXXXX'";
	var inPhone = event.srcElement.value;
	var outPhone = validatePhone(inPhone, " x", fmtMessage);
	if (outPhone != null)
		event.srcElement.value = outPhone;
	else
	{
		if (inPhone.length > 0)
			validationError(event.srcElement.name, fmtMessage);
	}
}

function validateChange_URL(event, flags)
{
}

function validateChange_LowerCase(event, flags)
{
	var inText = event.srcElement.value;
	var outText = inText.toLowerCase();
	event.srcElement.value = outText;
}

function validateChange_UpperCase(event, flags)
{
	var inText = event.srcElement.value;
	var outText = inText.toUpperCase();
	event.srcElement.value = outText;
}

function validateChange_UCaseInitial(event, flags)
{
	var inText = event.srcElement.value;
	var outText = new String;
	ouText = "";

	for(var i = 0; i < inText.length; i++) {
		var ch = inText.charAt(i);
		if((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
			if(i == 0) outText = ouText + ch.toUpperCase();
			else {
				var ch1 = inText.charAt(i-1);
				if((ch1 >= 'a' && ch1 <= 'z') || (ch1 >= 'A' && ch1 <= 'Z'))
					outText = outText +  ch.toLowerCase();
				else outText = outText +  ch.toUpperCase();
			}
		}
		else outText = outText +  ch;
	}
	event.srcElement.value = outText;
}


function setSelectedValue(selectObj, value)
{
	for(i = 0; i < selectObj.options.length; i++)
	{
		if(selectObj.options[i].value == value)
			selectObj.selectedIndex = i;
	}
}

//****************************************************************************
// Find/Lookup popup window support
//****************************************************************************

//
// these are global variable used for sending information
// to the findPopup window (they are set in doFindLookup and
// used in isLookupWindow and populateControl)
//
var activeFindForm = null;
var activeFindWinControl = null;
var activeFindARL = null;
var activeFindAppendValue = '';

function doFindLookup(formInstance, populateControl, arl, appendValue, prefill, features, controlField)
{
	if(prefill == null)
		prefill = true;

	if(prefill)
		arl += populateControl.value != '' ? '/' + populateControl.value : '';

	activeFindForm = formInstance;
	activeFindWinControl = populateControl;
	activeFindARL = arl;

	if(appendValue == null) appendValue = '';
	activeFindAppendValue = appendValue;

	var newArl = arl;
	
	if(controlField)
	{
		newArl = replaceString(arl, 'itemValue', controlField.value);
	}

	//
	// do the actual opening of the find popup window; it will be the job
	// of the popup window to check the value of activeFindWinControl and
	// either automatically populate the control or do something else
	//
	var popUpWindow = open(newArl, WINDOWNAME_FINDPOPUP, features == null ? "width=600,height=600,scrollbars,resizable" : features);
	popUpWindow.focus();
}

function isLookupWindow()
{
	// we check parent.window.name because the populateControl will be called
	// from the "content" frame of the findPopup window
	//
	var flag = window.name == WINDOWNAME_FINDPOPUP && opener.activeFindWinControl != null ? true : false;
	//alert(parent.window.name + ' == ' + WINDOWNAME_FINDPOPUP + ': ' + parent.opener.activeFindWinControl);
	//alert(flag);
	return flag;
}

function populateControl(what, closeWindow)
{
	if(closeWindow == null)
		closeWindow = true;

	populated = false;
	if(isLookupWindow())
	{
		if(parent.opener.activeFindAppendValue != '')
		{
			if(parent.opener.activeFindWinControl.value != '')
				parent.opener.activeFindWinControl.value += parent.opener.activeFindAppendValue;
				parent.opener.activeFindWinControl.value += what;
		}
		else
			parent.opener.activeFindWinControl.value = what;

		parent.opener.activeFindWinControl.title = 'lookup result: ' + what;
		populated = true;
	}
	else
	{
		alert('no opener or opener.activeFindWinControl found');
	}
	if(closeWindow) parent.close();
	return populated;
}

function replaceString(lookInStr, lookForStr, replaceWithStr)
{
	var start = lookInStr.indexOf(lookForStr);
	while(start >= 0)
	{
		var left = lookInStr.substring(0, start);
		var right = lookInStr.substring(start + lookForStr.length, lookInStr.length);
		lookInStr = left + replaceWithStr + right;
		start = lookInStr.indexOf(lookForStr);
	}
	return lookInStr;
}

function chooseEntry(itemValue,  actionObj, destObj, itemCategory)
{
	if(isLookupWindow())
	{
		populateControl(itemValue, true);
		return;
	}

	if(actionObj == null)
		actionObj = search_form.item_action_arl_select;
	
	if(destObj == null)
		destObj = search_form.item_action_arl_dest_select;

	if(actionObj != null) {
		var arlFmt = actionObj.options[actionObj.selectedIndex].value;
		var newArl = replaceString(arlFmt, '%itemValue%', itemValue);

		if(itemCategory != null) {
			itemCategory = itemCategory.toLowerCase()
			newArl = replaceString(newArl, '%itemCategory%', itemCategory);
		}
		if(destObj == null)
		{
			window.location.href = newArl;
		}
		else
		{
			if(destObj.selectedIndex == 0)
				window.location.href = newArl;
			else
				doActionPopup(newArl);
		}
	}
}

function chooseItem(arlFmt, itemValue, inNewWin)
{
	if(isLookupWindow())
	{
		populateControl(itemValue, true);
		return;
	}
	
	if(isActionPopupWindow())
	{
		parent.close();
		return;
	}

	var newArl = replaceString(arlFmt, '%itemValue%', itemValue);

	if (inNewWin == null) {
		inNewWin = false;
		if (search_form.item_action_arl_dest_select.selectedIndex == 1)
			inNewWin = true;
	}
	if(inNewWin) {
		doActionPopup(newArl);
		//window.open(newArl, '');
	}
	else {
		window.location.href = newArl;
	}
}

function chooseItem2(arlFmt, itemValue, inNewWin, features)
{
	if(isLookupWindow())
	{
		populateControl(itemValue, true);
		return;
	}

	var newArl = replaceString(arlFmt, '%itemValue%', itemValue);
	
	if (inNewWin == null) {
		inNewWin = false;
		if (search_form.item_action_arl_dest_select.selectedIndex == 1)
			inNewWin = true;
	}
	
	if(inNewWin) {
		var popUpWindow = open(newArl, WINDOWNAME_ACTIONPOPUP, features == null ? "width=620,height=440,scrollbars,resizable" : features);
		popUpWindow.focus();
	}
	else
		window.location.href = newArl;
}

function chooseItemForParent(arlFmt)
{
	if(isActionPopupWindow())
	{
		parent.opener.location.href = arlFmt;
	}
	else
	{
		alert('No opener Window found');
	}
	
	parent.close();
}

//****************************************************************************
// Multiselect field type support function
//****************************************************************************

/* 
Description:
	Moves items from one select box to another. 
Input:
	strFormName = Name of the form containing the <SELECT> elements
	strFromSelect = Name of the left or "from" select list box.
	strToSelect = Name of the right or "to" select list box
	blnSort = Indicates whether list box should be sorted when an item(s) is added

Return:	
	none
*/
function MoveSelectItems(strFormName, strFromSelect, strToSelect, blnSort) {
	var objSelectFrom, objSelectTo;
	
	objSelectFrom = document.forms[0].elements[strFromSelect];
	objSelectTo = document.forms[0].elements[strToSelect];

	var intLength = objSelectFrom.options.length;

	for (var i=0; i < intLength; i++) {
		if(objSelectFrom.options[i].selected && objSelectFrom.options[i].value != "") {
			var objNewOpt = new Option();
			objNewOpt.value = objSelectFrom.options[i].value;
			objNewOpt.text = objSelectFrom.options[i].text;
			objSelectTo.options[objSelectTo.options.length] = objNewOpt;
			objSelectFrom.options[i].value = "";
			objSelectFrom.options[i].text = "";
		}
	}

	if (blnSort) SimpleSort(objSelectTo);
	RemoveEmpties(objSelectFrom, 0);
}

/* 
Description:
	Removes empty select items. This is a helper function for MoveSelectItems.
Input:
	objSelect = A <SELECT> object.
	intStart = The start position (zero-based) search. Optimizes the recursion.
Return:	
	none
*/
function RemoveEmpties(objSelect, intStart)  {
	for(var i=intStart; i<objSelect.options.length; i++) {
		if (objSelect.options[i].value == "")  {
			objSelect.options[i] = null;	// This removes item and reduces count
			RemoveEmpties(objSelect, i);
			break;
		}
	}
}

/* 
Description:
	Sorts a select box. Uses a simple sort. 
Input:
	objSelect = A <SELECT> object.
Return:	
	none
*/
function SimpleSort(objSelect)  {
	var arrTemp = new Array();
	var objTemp = new Object();
	for(var i=0; i<objSelect.options.length; i++)  {
		arrTemp[i] = objSelect.options[i];
	}
	for(var x=0; x<arrTemp.length-1; x++)  {
		for(var y=(x+1); y<arrTemp.length; y++)  {
			if(arrTemp[x].text > arrTemp[y].text)  {
				objTemp = arrTemp[x].text;
				arrTemp[x].text = arrTemp[y].text;
				arrTemp[y].text = objTemp;
			}
		}
	}
}

//****************************************************************************
// Action popup window support
//****************************************************************************

//
// these are global variable used for sending information
// to the findPopup window (they are set in doFindLookup and
// used in isLookupWindow and populateControl)
//
var activeActionWindow = null;
var activeActionARL = null;
var activeActionAutoRefresh = null;

function doActionPopup(arl, autoRefresh, features)
{
	if(autoRefresh == null)
		autoRefresh = true;

	activeActionWindow = window;
	activeActionAutoRefresh = autoRefresh;

	//
	// all of the popup ARL resources end in "-p", which handleARL
	// (in Perl) treats automatically as a popup and sets up some
	// house-keeping variables.
	//
	var pathItems = arl.split('/');
	var resource = pathItems[1];

	if(resource.substring(resource.length-2, resource.length) != '-p')
	{
		pathItems[1] += '-p';
		arl = pathItems.join('/');
	}
	activeActionARL = arl;

	//
	// do the actual opening of the find popup window; it will be the job
	// of the popup window to check the value of activeFindWinControl and
	// either automatically populate the control or do something else
	//
	//open(arl, WINDOWNAME_ACTIONPOPUP, features == null ? "width=620,height=350,scrollbars,resizable" : features);
	var popUpWindow = open(arl, WINDOWNAME_ACTIONPOPUP, features == null ? "width=620,height=600,scrollbars,resizable" : features);
	popUpWindow.focus();
}

function isActionPopupWindow()
{
	// we check parent.window.name because the populateControl will be called
	// from the "content" frame of the findPopup window
	//
	var windowName = new String(this.window.name);
	var re = new RegExp(WINDOWNAME_ACTIONPOPUP);
	var flag = ( (windowName.search(re) != -1) && (opener.activeActionWindow != null) ) ? true : false;

	return flag;
}

function completePopupAction(closeWindow)
{
	if(closeWindow == null)
		closeWindow = true;

	if(isActionPopupWindow() && opener.activeActionAutoRefresh)
	{
		opener.activeActionWindow.document.search_form.execute.click();
	}
	if(closeWindow) parent.close();
}

function confirmPassword(Form)
{
	if ((Form._f_password.value != Form._f_confirm_password.value) && (Form._f_confirm_password.value != '') )
	{
		alert("Passwords are NOT confirmed.  Please re-enter.");
		Form._f_confirm_password.value = '';
		Form._f_password.focus();
	}
}

function validateHours(Form)
{
	startHour = new Number(Form._f_start_hour.value);
	endHour   = new Number(Form._f_end_hour.value);

	if (endHour < startHour && startHour != '' && endHour != '')
	{
		alert("End Hour must be greater than or equal to Start Hour");
		Form._f_end_hour.focus();
	}
}

//
// The following variable is set so that pages that call this library can check
// to see if the library was successfully loaded. The code to verify the package
// is "if(typeof pageLibraryLoaded == 'undefined') alert('library not loaded')"
//
var pageLibraryLoaded = true;

