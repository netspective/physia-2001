
/* setup constants */

var elemPattern_fieldDefns    = "mdl/clinical-documentation/field-defns";
var elemPattern_templates     = "mdl/clinical-documentation/templates";
var elemPattern_visitTemplate = "mdl/clinical-documentation/templates/template[@id = 'visit']";

/* setup global variabls */

var srcLoaded = false;
var fieldDefns = null;
var templates = null;
var activeTemplate = null;
var fieldControlMap = null;      // key is field name, value is reference to field's control
var conditionalFieldsMap = null; // key is field name, value is array of ConditionalFieldInfo objects
var fieldGroupNormalsMap = null; // key is field group name, value is array of fields that are in group
var fieldOptionsCache = null;
var activeExpandedControl = null;

function ConditionalFieldInfo(fieldId, fieldDefn)
{
	this.fieldId = fieldId;
	this.fieldDefn = fieldDefn;
}

function loadSource(srcFileName)
{
	/* load data */

	var srcDoc = new ActiveXObject("Microsoft.XMLDOM");
	srcDoc.async = false;
	if(! srcDoc.load(srcFileName))
	{
		alert("Unable to load " + srcFileName + ".");
		return false;
	}

	/* setup convenience variables */

	srcLoaded = true;
	fieldDefns = srcDoc.selectSingleNode(elemPattern_fieldDefns);
	templates = srcDoc.selectSingleNode(elemPattern_templates);
	activeTemplate = srcDoc.selectSingleNode(elemPattern_visitTemplate);
	fieldControlMap = new Array(); 
	fieldGroupNormalsMap = new Array();
	fieldOptionsCache = new Array();
	conditionalFieldsMap = new Array();
	activeExpandedControl = null;
	
	return true;
}

function funcName(f)
{
	var s = f.toString().match(/function (\w*)/)[1];
	if((s == null) || (s.length == 0)) return "anonymous function";
	return "function '" + s + "'";
}

function getFieldById(id)
{
	if(id.indexOf('/') != -1)
	{
		var idList = id.split('/');
		var patterns = new Array;
		for(var i = 0; i < idList.length; i++)
		{
			patterns[i] = "field-defn[@id = '" + idList[i] + "']";
		}
		var searchPattern = patterns.join('/');
		return fieldDefns.selectSingleNode(searchPattern);
	}
	else
		return fieldDefns.selectSingleNode("field-defn[@id = '" + id + "']");
}

function getFieldSizeByType (controlType) {
	var theSize;
	
	if (controlType == 'text') {
		theSize = 30;
	} else if (controlType == 'date') {
		theSize = 12;
	} else if (controlType == 'time') {
		theSize = 12;
	} else if (controlType == 'float') {
		theSize = 12;
	} else if (controlType == 'integer') {
		theSize = 12;
	} else if (controlType == 'percentage') {
		theSize = 5;
	} else if (controlType == 'currency') {
		theSize = 7;
	}
	
	return theSize;
}

function addConditionalField(primaryField, dependentField, dependentFieldId)
{
	//alert(primaryField + ' ' + dependentFieldId);
	var info = conditionalFieldsMap[primaryField];
	if(info == null)
	{
		info = (conditionalFieldsMap[primaryField] = new Array());		
	}
	info[info.length] = new ConditionalFieldInfo(dependentFieldId, dependentField);
}

function getFieldOptionsCount(fieldNode)
{
	var optionsNode = fieldNode.selectSingleNode('options');
	return optionsNode == null ? 0 : optionsNode.childNodes.length;
}

function createFieldOptionsHtml(controlId, fieldNode, style, extraAttrs)
{
	var optionsNode = fieldNode.selectSingleNode('options');
	if(optionsNode == null) return '';
	
	if(fieldOptionsCache[controlId + '.' + style] != null)
		return fieldOptionsCache[controlId + '.' + style];
	
	var html = '';
	var fieldCount = optionsNode.childNodes.length;
	if(style == 'anchor')
	{
		for (var i = 0; i < fieldCount; i++)
		{
			var optionNode = optionsNode.childNodes[i];
			if(optionNode.getAttribute('normal') != null)
				html += '<b><span class="options_choice_normal" onclick="chooseOption(this, \''+controlId+'\')">'+optionNode.text+'</span></b><br>';
			else
				html += '<span class="options_choice" onclick="chooseOption(this, \''+controlId+'\')">'+optionNode.text+'</span><br>';
		}
	}
	else if(style == 'list')
	{
		for (var i = 0; i < fieldCount; i++)
		{
			var optionNode = optionsNode.childNodes[i];
			if(optionNode.getAttribute('normal') != null)
				html += '<option>'+optionNode.text+' *</option>';
			else
				html += '<option>'+optionNode.text+'</option>';
		}
	}
	else if(style == 'radio')
	{
		for (var i = 0; i < fieldCount; i++)
		{
			var optionNode = optionsNode.childNodes[i];
			html += "<input type=radio name='"+controlId+"' "+extraAttrs+" id='"+controlId+i+"' value='"+(optionNode.getAttribute('value') != null ? optionNode.getAttribute('value') : i)+"'> <label for='"+controlId+i+"'>"+optionNode.text+"</label>&nbsp;&nbsp; ";
		}
	}
	else if(style == 'checkbox')
	{
		for (var i = 0; i < fieldCount; i++)
		{
			var optionNode = optionsNode.childNodes[i];
			html += "<input type=checkbox name='"+controlId+"' "+extraAttrs+" id='"+controlId+i+"' value='"+(optionNode.getAttribute('value') != null ? optionNode.getAttribute('value') : i)+"'> <label for='"+controlId+i+"'>"+optionNode.text+"</label>&nbsp;&nbsp; ";
		}
	}
	
	fieldOptionsCache[controlId + '.' + style] = html;
	return html;	
}

function createTemplateHtml(template)
{
	var html = '';
	var fieldCount = template.childNodes.length;
	for (var i = 0; i < fieldCount; i++)
	{
		html += createFieldHtml(template.childNodes[i], 0, i);
	}
	return html;
}

function createFieldHtml(fieldNode, level, count, parent, parentPrefix)
{	
	if(fieldNode == null) return "fieldNode should not be null in " + funcName(arguments.callee);
	if(fieldNode.getAttribute('idref') != null)
	{
		var fieldDefnId = fieldNode.getAttribute('idref');
		fieldNode = getFieldById(fieldDefnId);
		if(fieldNode == null)
			return "field definition '" + fieldDefnId + "' was not found in " + funcName(arguments.callee);
	}
	if(level == null) level = 0;
	if(count == null) count = 0;
		
	var fieldType = fieldNode.getAttribute('type');
	if(fieldType == '' || fieldType == null) fieldType = 'container';

	var html = '';
	var sectionName = 'section' + level;
	var sectionId = sectionName + '_' + count;
	var fieldNodeId = fieldNode.getAttribute('id');
	
	if(fieldType == 'container' || fieldType == 'grid')
	{
		var contentsHtml = '';
		var normalsHtml = '';
		if(fieldType != 'grid')
		{
			var fieldCount = fieldNode.childNodes.length;
			for (var i = 0; i < fieldCount; i++)
			{
				var childFieldDefn = fieldNode.childNodes[i];
				contentsHtml += createFieldHtml(childFieldDefn, level+1, i, fieldNode, parentPrefix != null ? (parentPrefix + '.' + fieldNodeId) : fieldNodeId);
			}
			var normalsGroup = fieldGroupNormalsMap[fieldNode.getAttribute('id')];
			if(normalsGroup != null)
			{
				normalsHtml = '<span style=" text-align: right; font-weight: normal; cursor: hand;" onclick="setGroupToNormal(\''+sectionId+'\', \''+fieldNode.getAttribute('id')+'\')"><font face="Wingdings" color="red">ü</font> Normal unless specified</span>';
			}
		}
		else
		{
			contentsHtml = prepareFieldHtml_grid(fieldNode, level, count, parent, parentPrefix);
		}
		
		html =  '<div id="'+ sectionId +'" class="section" sectLevel="'+level+'">';
		html += '<div id="'+ sectionId +'_head" class="section_head" sectLevel="'+level+'"><span id="'+sectionId+'_icons" class="'+sectionName+'_icons"><img src="/resources/images/icons/plus.gif" onclick="chooseSection(\''+sectionId+'\')"> </span><span style="width:250; cursor: hand;" onclick="chooseSection(\''+sectionId+'\')">'+ fieldNode.getAttribute('caption') + '</span>' + normalsHtml + '</div>';
		html += '<div id="'+ sectionId +'_body" class="section_body" sectLevel="'+level+'" style="display:none">';
		html += contentsHtml + '</div></div>';
	}
	else if (fieldType == 'text' || fieldType == 'float' || fieldType == 'percentage' || fieldType == 'currency' || fieldType == 'integer' || fieldType == 'time' || fieldType == 'date')
	{
		return prepareFieldHtml_text(fieldNode, level, count, parent, parentPrefix);
	}
	else
	{
		return eval("prepareFieldHtml_" + fieldType + "(fieldNode, level, count, parent, parentPrefix);");
	}
	
	return html;
}

function prepareFieldHtml_static(fieldNode, level, count, namePrefix, style)
{
	var sectionName = 'section' + level;
	var sectionId = sectionName + '_' + count;
	return '<span '+ style +' id="'+ namePrefix +'_label" class="section_field_static">'+fieldNode.getAttribute('caption')+':</span>';
}

function prepareFieldHtml_caption(fieldNode, level, count, namePrefix, style)
{
	var sectionName = 'section' + level;
	var sectionId = sectionName + '_' + count;
	return '<span '+ style +' id="'+ namePrefix +'_label" class="section_field_label">'+fieldNode.getAttribute('caption')+':</span>';
}

function createGridFieldHtml(fieldNode)
{
	return '<input>';
}

function addGridRow(theTable, level, count, parent, namePrefix) {
	var tableName = theTable.getAttribute ('id');
	var matches = tableName.match (/table_(.+)/i);
	var gridName = matches [1];
	var gridFieldNode = getFieldById (gridName);
	var gridId = gridFieldNode.getAttribute ('id');

	var theRow = theTable.insertRow ();
	var cellData = prepareFieldHtml_gridrowArray (gridFieldNode);
	
	for (var i = 0; i < cellData.length; i ++) {
		var theCell = theRow.insertCell ();
		theCell.innerHTML = cellData [i];
//		theRow.cells [i].class = 'section_field_grid_data';
	}
}

function prepareFieldHtml_gridrowArray(fieldNode)
{
	var fieldCount = fieldNode.childNodes.length;
	var dataRowPrototype = '';
	var dataRowArray = new Array ();
	for (var i = 0; i < fieldCount; i++)
	{
		var childFieldDefn = fieldNode.childNodes[i];
		var widgetHtml = createFieldHtml (childFieldDefn);
		dataRowArray [dataRowArray.length] = widgetHtml;
	}

	return dataRowArray;
}

function prepareFieldHtml_gridrow(fieldNode, level, count, parent, namePrefix)
{
	var fieldCount = fieldNode.childNodes.length;
	var dataRowPrototype = '';
	for (var i = 0; i < fieldCount; i++)
	{
		var childFieldDefn = fieldNode.childNodes[i];
		dataRowPrototype += '<td class="section_field_grid_data">'+createFieldHtml(childFieldDefn)+'</td>';
	}
	dataRowPrototype = '<tr>' + dataRowPrototype + '</tr>';
	return '<table class="section_field_grid">'+headRow+dataRowPrototype+'</table>';
	return dataRowPrototype;
}

function prepareFieldHtml_grid(fieldNode, level, count, parent, namePrefix)
{
	var fieldCount = fieldNode.childNodes.length;
	var headRow = '';
	var dataRowPrototype = '';
	for (var i = 0; i < fieldCount; i++)
	{
		var childFieldDefn = fieldNode.childNodes[i];
		headRow += '<td class="section_field_grid_head">'+childFieldDefn.getAttribute('caption')+'</td>';
		dataRowPrototype += '<td class="section_field_grid_data">'+createFieldHtml(childFieldDefn)+'</td>';
	}
	headRow += '<td class="section_field_grid_add" onClick="addGridRow(table_' + fieldNode.getAttribute ('id') + ')">Add...</td>';
	headRow = '<tr>' + headRow + '</tr>';
	dataRowPrototype = '<tr>' + dataRowPrototype + '</tr>';
	return '<table id="table_' + fieldNode.getAttribute ('id') + '" class="section_field_grid">'+headRow+dataRowPrototype+'</table>';
}

function prepareFieldHtml_composite(fieldNode, level, count, parent, namePrefix)
{
	var fieldName = fieldNode.getAttribute ('id');
	var fieldCount = fieldNode.childNodes.length;
	var insideFields = '';
	var addLabelStyle = 'style="vertical-align: top"';
	var icons = '<span style="font-family: wingdings; width: 15"></span>';
	
//	alert ('composite field: ' + fieldName + ' with ' + fieldCount + ' fields...');

	for (var i = 0; i < fieldCount; i++)
	{
		var childFieldDefn = fieldNode.childNodes[i];
		insideFields += createFieldHtml(childFieldDefn, level + 1, count, fieldName, fieldName);
	}

	var areaClassName = 'section_field_area';
	if(fieldNode.getAttribute('condition-field') != null)
	{
		areaClassName = 'section_field_area_conditional';
		var fieldId = fieldNode.getAttribute('condition-field');
		addConditionalField(fieldId, fieldNode, fieldName);
	}

	var controlHtml = '<span id="'+ fieldName +'_control" class="section_field_control" sectLevel="'+level+'">'+insideFields+'</span>';
	var html = '<div sectLevel="'+level+'" class="'+areaClassName+'" id="'+ fieldName +'_area">' + prepareFieldHtml_caption(fieldNode, level, count, namePrefix, addLabelStyle) + icons + controlHtml + '</div>';
	return html;
}

function prepareFieldHtml_text(fieldNode, level, count, parent, namePrefix)
{
	var sectionName = 'section' + level;
	var sectionId = sectionName + '_' + count;
	
	var fieldHtml = '';
	var addLabelStyle = '';
	var fieldName = namePrefix + '.' + fieldNode.getAttribute('id');
	var parentNode = fieldNode.parentNode;
	var parentNodeName = parentNode.getAttribute('id');
	var parentNodeType = parentNode.getAttribute('type');
	fieldControlMap[fieldName] = fieldNode;
	
	if (document.all[fieldNode.getAttribute ('id')]) {
		// This name already exists... add a number to its end...
		alert ('This fieldName already exists...modifying');
		var notDone = 1;
		var i = 1;
		do {
			var newName = fieldName + '.' + i;
			i ++;
			if (!eval('document.all.' + newName)) {
				notDone = 0;
			}
		} while (notDone);
		
		fieldName = newName;
		// OK this name should be fine...
	}

	if (fieldNode.getAttribute('type') == 'text') {
		if(fieldNode.getAttribute('lines') == null)
		{
			fieldHtml = '<input sectLevel="'+level+'" onfocus="handleEvent_onfocus(this)" onblur="handleEvent_onblur(this)" onchange="handleEvent_onchange(this)" class="text" name="'+fieldName+'" size="' + getFieldSizeByType (fieldNode.getAttribute('type')) + '">';
		}
		else
		{
			addLabelStyle = 'style="vertical-align: top"';
			fieldHtml = '<textarea sectLevel="'+level+'" onfocus="handleEvent_onfocus(this)" onblur="handleEvent_onblur(this)" class="text" onchange="handleEvent_onchange(this)" name="'+fieldName+'" cols="50" rows="'+fieldNode.getAttribute('lines')+'"></textarea>';
		}
	} else {
		/* Create a text field with data-dependent validation */
		fieldHtml = '<input sectLevel="'+level+'" onfocus="' + fieldNode.getAttribute('type') + '_onfocus(this)" onblur="' + fieldNode.getAttribute('type') + '_onblur(this)" onchange="' + fieldNode.getAttribute('type') + '_onchange(this)" class="text" name="'+fieldName+'" size="' + getFieldSizeByType (fieldNode.getAttribute('type')) + '">';
	}
	
	var icons = '<span style="font-family: wingdings; width: 15"></span>';
	var normalNode = fieldNode.selectSingleNode("options/option[@normal = 'yes']"); 
	if(normalNode != null)
	{
		if(parent != null)
		{
			var keyName = parent.getAttribute('id');
			var groupControls = fieldGroupNormalsMap[keyName];
			if(groupControls == null)
			{
				groupControls = new Array();
				fieldGroupNormalsMap[keyName] = groupControls;
				groupControls[0] = fieldName;
			}
			else
				groupControls[groupControls.length] = fieldName;
		}
		icons = '<span sectLevel="'+level+'" onclick="document.all.item(\''+fieldName+'\').value = \''+normalNode.text+'\'" style="font-family: wingdings; width: 15; text-align: center; cursor: hand; color: red;">ü</span>';
	}
	var areaClassName = 'section_field_area';
	if(fieldNode.getAttribute('condition-field') != null)
	{
		areaClassName = 'section_field_area_conditional';
		var fieldId = fieldNode.getAttribute('condition-field');
		addConditionalField(fieldId, fieldNode, fieldName);
	}
	
	var controlHtml = '<span id="'+ fieldName +'_control" class="section_field_control" sectLevel="'+level+'">'+fieldHtml+'</span>';
	var html = '<div sectLevel="'+level+'" class="'+areaClassName+'" id="'+ fieldName +'_area">' + prepareFieldHtml_caption(fieldNode, level, count, namePrefix, addLabelStyle);
	html += icons + controlHtml + '<div style="margin-left: 125; display:none;" id="'+ fieldName +'_options">Select</div></div>';
	
	return ((parentNodeType == 'composite' || parentNodeType == 'grid') ? (fieldNode.getAttribute ('condition-field') ? '<span id="' + fieldName + '_area" class=section_field_area_conditional" sectLevel="' + level + '" style="display: none">' + controlHtml + '</span>' : controlHtml) : html);
}

function prepareFieldHtml_choose(fieldNode, level, count, parent, namePrefix)
{
	var sectionName = 'section' + level;
	var sectionId = sectionName + '_' + count;
	var parentNode = fieldNode.parentNode;
	var parentNodeName = parentNode.getAttribute('id');
	var parentNodeType = parentNode.getAttribute('type');
	
	var fieldName = namePrefix + '.' + fieldNode.getAttribute('id');
	fieldControlMap[fieldName] = fieldNode;
	
	if (document.all[fieldNode.getAttribute ('id')]) {
		// This name already exists... add a number to its end...
		alert ('This fieldName already exists...modifying');
		var notDone = 1;
		var i = 1;
		do {
			var newName = fieldName + '.' + i;
			i ++;
			if (!eval('document.all.' + newName)) {
				notDone = 0;
			}
		} while (notDone);
		
		fieldName = newName;
		// OK this name should be fine...
	}

	var areaClassName = 'section_field_area';
	if(fieldNode.getAttribute('condition-field') != null)
	{
		areaClassName = 'section_field_area_conditional';
		var fieldId = fieldNode.getAttribute('condition-field');
		addConditionalField(fieldId, fieldNode, fieldName);
	}
	
	var style = fieldNode.getAttribute('style') == null ? (getFieldOptionsCount(fieldNode) > 5 ? 'list' : 'radio') : fieldNode.getAttribute('style');
	
	var fieldHtml = '';
	if(style == 'list')
		fieldHtml = '<select sectLevel="'+level+'" onfocus="handleEvent_onfocus(this)" onblur="handleEvent_onblur(this)" class="select" name="'+fieldName+'" onchange="handleEvent_onchange(this)">'+createFieldOptionsHtml(fieldName, fieldNode, 'list')+'</select>';
	else if (style == 'checkbox' || style == 'radio')
		fieldHtml = createFieldOptionsHtml(fieldName, fieldNode, style, 'onfocus="handleEvent_onfocus(this)" onblur="handleEvent_onblur(this)" onclick="handleEvent_onchange(this)"');
	var controlHtml = '<span sectLevel="'+level+'" id="'+ fieldName +'_control" class="section_field_control">'+fieldHtml+'</span>'
	var icons = '<span sectLevel="'+level+'" style="font-family: wingdings; width: 15"></span>';	
	var html = '<div sectLevel="'+level+'" id="'+ fieldName +'_area" class="'+areaClassName+'">' + prepareFieldHtml_caption(fieldNode, level, count, namePrefix);
	html += icons + controlHtml + '<div style="margin-left: 125; display:none;" id="'+ fieldName +'_options">Select</div></div>';
	
	return ((parentNodeType == 'composite' || parentNodeType == 'grid') ? (fieldNode.getAttribute ('condition-field') ? '<span id="' + fieldName + '_area" class=section_field_area_conditional" sectLevel="' + level + '">' + controlHtml + '</span>' : controlHtml) : html);
}

/* CSS expressions */

function getSectionFontFamily(element)
{
	return element.sectLevel > 0 ? 'tahoma' : 'verdana';
}

function getSectionFontSize(element)
{
	return (element.sectLevel > 0 ? (12 - (element.sectLevel * 2)) : 10) + 'pt';
}

function getSectionMarginLeft(element)
{
	return element.sectLevel > 0 ? 10 : 0;
}

function getSectionFontWeight(element)
{
	return element.sectLevel > 0 ? 'normal' : 'bold';
}

/* event handlers */

function chooseSection(sectId, toggle)
{
	var sectionHeadElem = document.all.item(sectId + '_head');
	var sectionBodyElem = document.all.item(sectId + '_body');
	var sectionIconsElem = document.all.item(sectId + '_icons');
	if(toggle == null || toggle == true)
	{
		if(sectionBodyElem.style.display == 'none')
		{
			sectionIconsElem.innerHTML = '<img src="/resources/images/icons/minus.gif"> ';
			sectionBodyElem.className = 'section_body_expanded';
			sectionHeadElem.className = 'section_head_expanded';
			sectionBodyElem.style.display = '';
		}
		else
		{
			sectionIconsElem.innerHTML = '<img src="/resources/images/icons/plus.gif"> ';
			sectionBodyElem.className = 'section_body';
			sectionHeadElem.className = 'section_head';
			sectionBodyElem.style.display = 'none';
		}
	}
	else
	{
		sectionIconsElem.innerHTML = '<img src="/resources/images/icons/minus.gif"> ';
		sectionBodyElem.className = 'section_body_expanded';
		sectionHeadElem.className = 'section_head_expanded';
		sectionBodyElem.style.display = '';
	}
}

function setGroupToNormal(sectId, fieldId)
{
	var fieldGroup = fieldGroupNormalsMap[fieldId];
	if(fieldGroup == null || fieldGroup == '')
	{
		alert('fieldId "'+fieldId+'" does not have any "normal" values');
		return;
	}
	for(var i = 0; i < fieldGroup.length; i++)
	{
		var controlId = fieldGroup[i];
		var fieldDefn = fieldControlMap[controlId];
		var control = document.all.item(controlId);
		var normalNode = fieldDefn.selectSingleNode("options/option[@normal = 'yes']");
		if(control.value == '' && normalNode != null)
			control.value = normalNode.text;
	}
	chooseSection(sectId, false);
}

function collapseOptions(control)
{
	var optionsArea = document.all.item(control.name + '_options');
	optionsArea.innerHTML = '';
	optionsArea.style.display = 'none';
	control.expandedOptions = false;
}

function chooseOption(srcControl, fillControlId)
{
	var fillControl = document.all.item(fillControlId);
	var fillControlXMLId = fillControlId.replace (/\./g, '/');
	var fieldNode = getFieldById(fillControlXMLId);
	var additive = fieldNode.getAttribute('additive') == 'yes' ? 1 : 0;
	
	if(fillControl.expandedOptions)
	{
		if (additive == 1 && fillControl.value) {
			fillControl.value = fillControl.value + ", " + srcControl.innerText;
		} else {
			fillControl.value = srcControl.innerText;
		}

		if (additive != 1) {
			collapseOptions(fillControl);
		}
	}
}

/* Default event handlers for all field types... */

function handleEvent_onfocus(control)
{
	if(activeExpandedControl != null)
		collapseOptions(activeExpandedControl);
	
	var fieldDefn = fieldControlMap[control.name];
	if(fieldDefn.selectSingleNode('options') != null && fieldDefn.getAttribute('type') == 'text')
	{
		var optionsArea = document.all.item(control.name + '_options');
		optionsArea.innerHTML = createFieldOptionsHtml(control.name, fieldDefn, 'anchor');
		optionsArea.style.display = '';
		control.expandedOptions = true;
		activeExpandedControl = control;
	}
}

function handleEvent_onblur(control)
{
}

function handleEvent_onchange(control)
{
//	alert('control.name = ' + control.name);
//	alert ('control.options [control.options.selectedIndex].text = ' + control.options [control.options.selectedIndex].text);
	if(conditionalFieldsMap[control.name] != null)
	{
		var conditionalFields = conditionalFieldsMap[control.name];
		for(var i = 0; i < conditionalFields.length; i++)
		{
			var fieldInfo = conditionalFields[i];
			var fieldAreaElem = document.all.item(fieldInfo.fieldId + '_area');
			if(fieldAreaElem == null) alert (fieldInfo.fieldId + '_area not found');
			if(eval(fieldInfo.fieldDefn.getAttribute('condition')) == true)
			{
				fieldAreaElem.className = 'section_field_area_conditional_expanded';
				fieldAreaElem.style.display = '';
			}
			else
			{
				fieldAreaElem.className = 'section_field_area_conditional';
				fieldAreaElem.style.display = 'none';
			}
		}
	}
}

/* Field-type specific event handlers... */

/* type=float */

function float_onfocus(control)
{
	handleEvent_onfocus(control);
}

function float_onblur(control)
{
	if (float_validate (control)) {
		handleEvent_onblur(control);
	} else {
		alert ('The value you entered is invalid.  Please change it to a value in the format [-]999.999');
		control.focus ();
	}
}

function float_onchange(control)
{
	if (float_validate (control)) {
		handleEvent_onchange(control);
	} else {
		alert ('The value you entered is invalid.  Please change it to a value in the format [-]999.999');
	}
}

function float_validate(control)
{
	var theValue = control.value;
	var returnValue = false;
	
	if (theValue.match (/^\-?\d+(\.\d+)?$/)) {
		returnValue = true;
	}
	
	if (theValue == '') {
		returnValue = true;
	}
	
	return returnValue;
}

/* type=percentage */

function percentage_onfocus(control)
{
	handleEvent_onfocus(control);
}

function percentage_onblur(control)
{
	var validation = percentage_validate(control);
	
	if (-1 == validation) {
		alert ('The value you entered is out of range.  Please change it to a value between 0.00% and 100.00%');
		control.focus ();
	} else if (0 == validation) {
		alert ('The value you entered is invalid.  Please change it to a value in the format 99.99%');
		control.focus ();
	} else {
		handleEvent_onblur(control);
	}
}

function percentage_onchange(control)
{
	var validation = percentage_validate(control);
	
	if (-1 == validation) {
		alert ('The value you entered is out of range.  Please change it to a value between 0.00% and 100.00%');
		control.focus ();
	} else if (0 == validation) {
		alert ('The value you entered is invalid.  Please change it to a value in the format 99.99%');
		control.focus ();
	} else {
		handleEvent_onchange(control);
	}
}

function percentage_validate(control)
{
	var theValue = control.value;
	var matchValues;
	var returnValue = 0;
	
	if (null != (matchValues = theValue.match (/^(\d{1,3})(\.\d{1,2})?\%$/))) {
		/* Preliminary test passed... Test for value between 0 and 100 */
		returnValue = 1;
		
		var testValue = parseFloat (matchValues [1] + matchValues [2]);
		if (testValue < 0.00 || testValue > 100.00) {
			returnValue = -1;
		}
	}
	
	if (theValue == '') {
		returnValue = 1;
	}

	return returnValue;
}

/* type=currency */

function currency_onfocus(control)
{
	handleEvent_onfocus(control);
}

function currency_onblur(control)
{
	handleEvent_onblur(control);
}

function currency_onchange(control)
{
	var theValue = control.value;
	
	if (theValue.match (/^\d+(\.\d+)?$/)) {
		handleEvent_onchange(control);
	} else {
		alert ('The value you entered is invalid.  Please change it to a value in the format [-]999.999');
		control.focus ();
	}
}

/* type=integer */

function integer_onfocus(control)
{
	handleEvent_onfocus(control);
}

function integer_onblur(control)
{
	handleEvent_onblur(control);
}

function integer_onchange(control)
{
	var theValue = control.value;
	
	if (theValue.match (/^\d+$/)) {
		handleEvent_onchange(control);
	} else {
		alert ('The value you entered is invalid.  Please change it to a value in the format [-]999');
		control.focus ();
	}
}

/* type=time */

function time_onfocus(control)
{
	handleEvent_onfocus(control);
}

function time_onblur(control)
{
	var validation = time_validate(control);
	
	if (-3 == validation) {
		alert ('The values you entered for hours and minutes are out of range.\nPlease change hours to a value between 0 and 12.\nPlease change minutes to a value between 0 and 59.');
		control.focus ();
	} else if (-2 == validation) {
		alert ('The value you entered for minutes is out of range.\nPlease change it to a value between 0 and 59');
		control.focus ();
	} else if (-1 == validation) {
		alert ('The value you entered for hours is out of range.\nPlease change it to a value between 0 and 12');
		control.focus ();
	} else if (0 == validation) {
		alert ('The value you entered is invalid.  Please change it to a value in the format HH:MMpm');
		control.focus ();
	} else {
		handleEvent_onblur(control);
	}
}

function time_onchange(control)
{
	var validation = time_validate(control);
	
	if (-3 == validation) {
		alert ('The values you entered for hours and minutes are out of range.\nPlease change hours to a value between 0 and 12.\nPlease change minutes to a value between 0 and 59.');
		control.focus ();
	} else if (-2 == validation) {
		alert ('The value you entered for minutes is out of range.\nPlease change it to a value between 0 and 59');
		control.focus ();
	} else if (-1 == validation) {
		alert ('The value you entered for hours is out of range.\nPlease change it to a value between 0 and 12');
		control.focus ();
	} else if (0 == validation) {
		alert ('The value you entered is invalid.  Please change it to a value in the format HH:MMpm');
		control.focus ();
	} else {
		handleEvent_onchange(control);
	}
}

function time_validate(control)
{
	var theValue = control.value;
	var matchValues;
	var returnValue = 0;
	
	if (null != (matchValues = theValue.match (/^(\d\d):(\d\d)\s*([AaPp][Mm])$/))) {
		/* Preliminary test passed... Test for values of hours and minutes... */
		returnValue = 1;
		
		var hours = parseInt (matchValues [1]);
		var minutes = parseInt (matchValues [2]);

		if (hours < 0 || hours > 12) {
			returnValue = -1;
		}
		
		if (minutes < 0 || minutes > 59) {
			returnValue -= 2;
		}
	}
	
	if (theValue == '') {
		returnValue = 1;
	}

	return returnValue;
}

/* type=date */

function date_onfocus(control)
{
	handleEvent_onfocus(control);
}

function time_onblur(control)
{
	var validation = date_validate(control);
	
	if (-3 == validation) {
		alert ('The values you entered for hours and minutes are out of range.\nPlease change hours to a value between 0 and 12.\nPlease change minutes to a value between 0 and 59.');
		control.focus ();
	} else if (-2 == validation) {
		alert ('The value you entered for minutes is out of range.\nPlease change it to a value between 0 and 59');
		control.focus ();
	} else if (-1 == validation) {
		alert ('The value you entered for hours is out of range.\nPlease change it to a value between 0 and 12');
		control.focus ();
	} else if (0 == validation) {
		alert ('The value you entered is invalid.  Please change it to a value in the format HH:MMpm');
		control.focus ();
	} else {
		handleEvent_onblur(control);
	}
}

function date_onchange(control)
{
	var validation = date_validate(control);
	
	if (-3 == validation) {
		alert ('The values you entered for hours and minutes are out of range.\nPlease change hours to a value between 0 and 12.\nPlease change minutes to a value between 0 and 59.');
		control.focus ();
	} else if (-2 == validation) {
		alert ('The value you entered for minutes is out of range.\nPlease change it to a value between 0 and 59');
		control.focus ();
	} else if (-1 == validation) {
		alert ('The value you entered for hours is out of range.\nPlease change it to a value between 0 and 12');
		control.focus ();
	} else if (0 == validation) {
		alert ('The value you entered is invalid.  Please change it to a value in the format HH:MMpm');
		control.focus ();
	} else {
		handleEvent_onchange(control);
	}
}

function date_validate(control)
{
	var theValue = control.value;
	var matchValues;
	var returnValue = 0;
	
	if (null != (matchValues = theValue.match (/^(\d{1,2})[:\/\.\s](\d{1,2})[:\/\.\s](\d{2}|\d{4})$/))) {
		/* Preliminary test passed... Test for values of month, day and year... */
		returnValue = 1;
		
		var month = parseInt (matchValues [1]);
		var day = parseInt (matchValues [2]);
		var year = parseInt (matchValues [3]);

		if (month < 1 || month > 12) {
			returnValue = -1;
		}
		
		if (day < 1 || day > 31) {
			returnValue -= 2;
		}
	
		if (year < 100 && year >= 70) {
			year += 1900;
		}
		
		if (year < 100 && year < 70) {
			year += 2000;
		}
		
		if (year < 1800 && year > 2999) {
			returnValue -= 4;
		}
	}
	
	if (theValue == '') {
		returnValue = 1;
	}

	return returnValue;
}

