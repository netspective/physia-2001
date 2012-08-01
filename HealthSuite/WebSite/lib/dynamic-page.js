/* setup constants */

var elemPattern_fieldDefns    = "mdl/clinical-documentation/field-defns";
var elemPattern_templates     = "mdl/clinical-documentation/templates";
var elemPattern_visitTemplate = "mdl/clinical-documentation/templates/template[@id = 'visit']";

/* setup global variabls */

var srcLoaded = false;
var templateLoaded = false;
var fieldDefns = null;
var templates = null;
var activeTemplate = null;
var fieldControlMap = null;      // key is field name, value is reference to field's control
var conditionalFieldsMap = null; // key is field name, value is array of ConditionalFieldInfo objects
var fieldGroupNormalsMap = null; // key is field group name, value is array of fields that are in group
var fieldOptionsCache = null;
var activeExpandedControl = null;

var __debug = true;
var __nodebug = true;

function ConditionalFieldInfo(fieldId, fieldDefn)
{
	this.fieldId = fieldId;
	this.fieldDefn = fieldDefn;
}

function loadSource(srcFileName, templateFileName)
{
	/* load data */

	var templateDoc;
	var srcDoc = new ActiveXObject("Microsoft.XMLDOM");
	srcDoc.async = false;
	
	if(! srcDoc.load(srcFileName))
	{
		var alertMsg;
		
		if (arguments.length == 2) {
			alertMsg = "Unable to load data dictionary from " + srcFileName + "...";
		} else {
			alertMsg = "Unable to load " + srcFileName + "...";
		}

		alert(alertMsg);
		return false;
	}

	/* setup convenience variables */

	srcLoaded = true;
	fieldDefns = srcDoc.selectSingleNode(elemPattern_fieldDefns);

	if (arguments.length == 2) {
		templateDoc = new ActiveXObject("Microsoft.XMLDOM");
		templateDoc.async = false;

		if(! templateDoc.load(templateFileName))
		{
			alert("Unable to load templates from " + templateFileName + ".");
			return false;
		}
		
		templateLoaded = true;

		templates = templateDoc.selectSingleNode(elemPattern_templates);
		activeTemplate = templateDoc.selectSingleNode(elemPattern_visitTemplate);
	} else {
		templates = srcDoc.selectSingleNode(elemPattern_templates);
		activeTemplate = srcDoc.selectSingleNode(elemPattern_visitTemplate);
	}

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

function getFQNameById(id) {
	var fieldNode = getFieldById (id);

	if (__nodebug == false && __debug == true) {
		__debug = confirm ('id = ' + id + '\nparentPrefix = ' + parentPrefix);
	}

	if (__nodebug == false && __debug == true) {
		var _temp = fieldNode.getAttribute ('id');
		__debug = confirm ('fieldNode.getAttribute(\'id\') = ' + _temp);
	}

	var parentNode = fieldNode.parentNode;
	var parentPrefix = parentNode.getAttribute('id');
	fieldNode = parentNode;
	parentNode = fieldNode.parentNode;
	
	if (__nodebug == false && __debug == true) {
		__debug = confirm ('id = ' + id + '\nparentPrefix = ' + parentPrefix);
	}

	while (parentNode.getAttribute('tagName') != 'field-defns') {
		parentPrefix = parentNode.getAttribute('id') + '.' + parentPrefix;
		if (__nodebug == false && __debug == true) {
			__debug = confirm ('id = ' + id + '\nparentPrefix = ' + parentPrefix);
		}
		fieldNode = fieldNode.parentNode;
		parentNode = fieldNode.parentNode;
	}
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

	if (__nodebug == false && __debug == true) {
		__debug = confirm ('addConditionalField...\nprimaryField = ' + primaryField + '\ndependentField = ' + dependentField + '\ndependentFieldId = ' + dependentFieldId);
	}
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
	var defaultValue = fieldNode.getAttribute('default') ? fieldNode.getAttribute('default') : '';
//	if (defaultValue && defaultValue != '')
//		__debug = confirm (fieldNode.getAttribute('id') + ' (' + fieldNode.getAttribute('type') + ') [' + style + ']\nfieldNode.getAttribute(default) = ' + fieldNode.getAttribute('default'));
	
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
			var nodeSelection = (defaultValue != '' && i == defaultValue) ? ' selected' : '';
			var optionNode = optionsNode.childNodes[i];
			if(optionNode.getAttribute('normal') != null)
				html += '<option' + nodeSelection + '>'+optionNode.text+' *</option>';
			else
				html += '<option' + nodeSelection + '>'+optionNode.text+'</option>';
		}
	}
	else if(style == 'radio')
	{
		for (var i = 0; i < fieldCount; i++)
		{
			var nodeSelection = (defaultValue != '' && i == defaultValue) ? ' checked' : '';
			var optionNode = optionsNode.childNodes[i];
			html += "<input type=radio name='"+controlId+"' "+extraAttrs+" id='"+controlId+i+"' value='"+(optionNode.getAttribute('value') != null ? optionNode.getAttribute('value') : i) + "'" + nodeSelection + "> <label for='"+controlId+i+"'>"+optionNode.text+"</label>&nbsp;&nbsp; ";
		}
	}
	else if(style == 'checkbox')
	{
		for (var i = 0; i < fieldCount; i++)
		{
			var nodeSelection = (defaultValue != '' && i == defaultValue) ? ' checked' : '';
			var optionNode = optionsNode.childNodes[i];
			html += "<input type=checkbox name='"+controlId+"' "+extraAttrs+" id='"+controlId+i+"' value='"+(optionNode.getAttribute('value') != null ? optionNode.getAttribute('value') : i) + "'" + nodeSelection + "> <label for='"+controlId+i+"'>"+optionNode.text+"</label>&nbsp;&nbsp; ";
		}
	}
	
	fieldOptionsCache[controlId + '.' + style] = html;
	return html;	
}

function createTemplateHtml(template)
{
//	__nodebug = confirm ('Press Cancel to allow some debugging popups or OK to disable all debugging popups');
	var html = '';
	var fieldCount = template.childNodes.length;
	for (var i = 0; i < fieldCount; i++)
	{
		var childNode = template.childNodes [i];
		if (__nodebug == false) __debug = confirm ('node: ' + childNode.getAttribute ('idref'));

		html += createFieldHtml(template.childNodes[i], 0, i);
	}
	return html;
}

function createFieldHtml(fieldNode, level, count, parent, parentPrefix)
{	
	if(fieldNode == null) return "fieldNode should not be null in " + funcName(arguments.callee);
	
//	if (fieldNode.length) {
//		alert ('createFieldHtml...\nfieldNode.length = ' + fieldNode.length);

//		for (var x = 0; x <= fieldNode.length; x ++) {

//			var temp = fieldNode[x];

//			alert ('fieldNode[' + x + '] = ' + temp.getAttribute('id'));

//		}

//	}
	
	if(fieldNode.getAttribute('idref') != null)
	{
		var fieldDefnId = fieldNode.getAttribute('idref');
		fieldNode = getFieldById(fieldDefnId);
		if(fieldNode == null)
			return "field definition '" + fieldDefnId + "' was not found in " + funcName(arguments.callee);
			
		// Determine the parentPrefix from the idref value...
		var _parentPrefix = fieldDefnId.replace (/\/{1}/g, '.');
		_parentPrefix = _parentPrefix.replace (/\.?[\w\-]+$/, '');
		
		parentPrefix = (parentPrefix && parentPrefix != '' ? parentPrefix : _parentPrefix);

		if (__nodebug == false && __debug == true) {
			__debug = confirm ('createFieldHtml...\n_parentPrefix = ' + _parentPrefix + '\nparentPrefix = ' + parentPrefix);
		}
		
	}
	if(level == null) level = 0;
	if(count == null) count = 0;
		
	var fieldType = fieldNode.getAttribute('type');
	if(fieldType == '' || fieldType == null) fieldType = 'container';

	var html = '';
	var sectionName = 'section' + level;
//	var sectionId = sectionName + '_' + count;
	var fieldNodeId = fieldNode.getAttribute('id');
	var sectionId = (parentPrefix != null && parentPrefix != '') ? (parentPrefix + '.' + fieldNodeId) : fieldNodeId;
	var sectionClassSuffix = (fieldNode.getAttribute('expanded') == 'yes' || fieldType == 'grid') ? '_expanded' : '';
	var sectionDisplayAttribute = (fieldNode.getAttribute('expanded') == 'yes') ? '' : 'display:none';
	var sectionIcon = (fieldNode.getAttribute('expanded') == 'yes') ? 'minus.gif' : 'plus.gif';
//	var fieldName = ((parentPrefix == '') ? '' : parentPrefix + '.') + fieldNode.getAttribute ('id');
	
	if(fieldType == 'container' || fieldType == 'grid')
	{
		var contentsHtml = '';
		var normalsHtml = '';
		if(fieldType != 'grid')
		{
			if (__nodebug == false && __debug == true) {
				__debug = confirm ('id = ' + fieldNodeId + ' (' + fieldType + ')\nparentPrefix = ' + parentPrefix);
			}
			var fieldCount = fieldNode.childNodes.length;
			for (var i = 0; i < fieldCount; i++)
			{
				var childFieldDefn = fieldNode.childNodes[i];
				var controlHtml = createFieldHtml(childFieldDefn, level+1, i, fieldNode, (parentPrefix != null && parentPrefix != '') ? (parentPrefix + '.' + fieldNodeId) : fieldNodeId);
				contentsHtml += controlHtml;
				
				if (__nodebug == false && __debug == true) {
					__debug = confirm ('createFieldHtml...\nsectionId = ' + sectionId + '\nsectLevel = ' + level + '\n\ncontrolHtml = [' + controlHtml.length + '] ' + controlHtml);
				}
			}
			var normalsGroup = fieldGroupNormalsMap[fieldNode.getAttribute('id')];
			if(normalsGroup != null)
			{
				normalsHtml = '<span style=" text-align: right; font-weight: normal; cursor: hand;" onclick="setGroupToNormal(\''+sectionId+'\', \''+fieldNode.getAttribute('id')+'\')"><font face="Wingdings" color="red">ü</font> Normal unless specified</span>';
			}
		}
		else
		{
			if (__nodebug == false && __debug == true) {
				__debug = confirm ('createFieldHtml (dispatching to prepare_ functions)...\nid = ' + fieldNodeId + ' (' + fieldType + ')\nparentPrefix = ' + parentPrefix);
			}
			contentsHtml = prepareFieldHtml_grid(fieldNode, level, count, parent, parentPrefix);
		}
		
		if (__nodebug == false && __debug == true) {
			__debug = confirm ('createFieldHtml...\nsectionId = ' + sectionId + '\nsectLevel = ' + level + '\n\ncontentsHtml = [' + contentsHtml.length + '] ' + contentsHtml);
		}

		if(fieldNode.getAttribute('condition-field') != null)
		{
			sectionClassSuffix += '_conditional';
			var fieldId = '_df_.' + fieldNode.getAttribute('condition-field');
			addConditionalField(fieldId, fieldNode, sectionId);
		}

		html =  '<div id="'+ sectionId +'" class="section" sectLevel="'+level+'">\n';
		if (fieldNode.getAttribute ('bareheading') != 'yes')
			html += '\t<div id="'+ sectionId +'_head" class="section_head' + sectionClassSuffix + '" sectLevel="'+level+'">\n\t\t<span id="'+sectionId+'_icons" class="'+sectionName+'_icons"><img src="' + imagePrefix + sectionIcon + '" onclick="chooseSection(\''+sectionId+'\')"> </span><span style="width:250; cursor: hand;" onclick="chooseSection(\''+sectionId+'\')">'+ fieldNode.getAttribute('caption') + '</span>\n\t\t' + normalsHtml + '\n\t</div>\n';
		html += '\t<div id="'+ sectionId +'_body" class="section_body' + sectionClassSuffix + '" sectLevel="'+level+'" style="' + sectionDisplayAttribute + '">\n';
		html += '\t\t' + contentsHtml + '\n\t</div>\n</div>\n';
		if (fieldNode.getAttribute('condition-field') != null) {
//			__debug = confirm ('adding a div around a conditional section...\nid = ' + sectionId + '_area');
			html = '<div id="' + sectionId + '_area" class="section_field_area_conditional">' + html + '</div>';
		}
	}
	else if (fieldType == 'text' || fieldType == 'float' || fieldType == 'percentage' || fieldType == 'currency' || fieldType == 'integer' || fieldType == 'time' || fieldType == 'date')
	{
		if (__nodebug == false && __debug == true) {
			__debug = confirm ('createFieldHtml (dispatching to prepare_ functions)...\nid = ' + fieldNodeId + ' (' + fieldType + ')\nparentPrefix = ' + parentPrefix);
		}

		return prepareFieldHtml_text(fieldNode, level, count, parent, parentPrefix);
	}
	else
	{
		if (__nodebug == false && __debug == true) {
			__debug = confirm ('createFieldHtml (dispatching to prepare_ functions)...\nid = ' + fieldNodeId + ' (' + fieldType + ')\nparentPrefix = ' + parentPrefix);
		}

		return eval("prepareFieldHtml_" + fieldType + "(fieldNode, level, count, parent, parentPrefix);");
	}
	
	return html;
}

function prepareFieldHtml_static(fieldNode, level, count, namePrefix, style)
{
	var sectionName = 'section' + level;
	var sectionId = sectionName + '_' + count;
	var fieldName = fieldNode.getAttribute ('id');
	var style = '';

	var areaClassName = 'section_field_area';
	if(fieldNode.getAttribute('condition-field') != null)
	{
		areaClassName = 'section_field_area_conditional';
		var fieldId = '_df_.' + fieldNode.getAttribute('condition-field');
		addConditionalField(fieldId, fieldNode, fieldName);
	}

	return '<span '+ style +' id="'+ fieldName +'_area" onfocus="handleEvent_onfocus(this)" onblur="handleEvent_onblur(this)" onchange="handleEvent_onchange(this)" class="' + areaClassName + '">'+fieldNode.getAttribute('caption')+'</span>';
}

function prepareFieldHtml_caption(fieldNode, level, count, namePrefix, style)
{
//	var sectionName = 'section' + level;
//	var sectionId = sectionName + '_' + count;
	return '<span '+ style +' id="'+ namePrefix +'_label" onfocus="handleEvent_onfocus(this)" onblur="handleEvent_onblur(this)" onchange="handleEvent_onchange(this)" class="section_field_label">'+fieldNode.getAttribute('caption')+':</span>';
}

function addGridRow(theTable, level, count, parent, namePrefix) {
	if (__nodebug == false) __debug = confirm ('tableName = ' + tableName + '\ngridName = ' + gridName);
	var tableObject = document.all[theTable];
	var tableName = theTable;
	var matches = tableName.match (/table_(.+)/i);
	var gridName = matches [1];
	if (__nodebug == false) __debug = confirm ('tableName = ' + tableName + '\ngridName = ' + gridName);
	var gridXMLName = gridName.replace (/\./g, '/');
	var gridFieldNode = getFieldById (gridXMLName);
	var gridId = gridFieldNode.getAttribute ('id');
//	alert ('addGridRow...\ngridFieldNode.length = ' + gridFieldNode.length + '\ngridId = ' + gridId)

	var theRow = tableObject.insertRow ();
	var cellData = prepareFieldHtml_gridrowArray (gridFieldNode, level, count, parent, gridName);
	
	for (var i = 0; i < cellData.length; i ++) {
		var theCell = theRow.insertCell ();
		theCell.innerHTML = cellData [i];
	}
}

function prepareFieldHtml_gridrowArray(fieldNode, level, count, parent, namePrefix)
{
	var fieldCount = fieldNode.childNodes.length;
	var dataRowPrototype = '';
	var dataRowArray = new Array ();
	var parentPrefix = (namePrefix ? namePrefix + '.' : '') + fieldNode.getAttribute('id');
	var gridId = fieldNode.getAttribute ('id');
	if (__nodebug == false) __debug = confirm ('prepareFieldHtml_gridRowArray...\nnamePrefix = ' + namePrefix + '\nparentPrefix = ' + parentPrefix);
//	alert ('prepareFieldHtml_gridRowArray...\nfieldNode.length = ' + fieldNode.length + '\ngridId = ' + gridId)

	for (var i = 0; i < fieldCount; i++)
	{
		var childFieldDefn = fieldNode.childNodes[i];
//		alert ('prepareFieldHtml_gridrowArray...\nchildFieldDefn = ' + childFieldDefn.getAttribute('id') + '\nchildFieldDefn.length = ' + childFieldDefn.length);

		var widgetHtml = createFieldHtml (childFieldDefn, level, count, parent, parentPrefix);
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
	var fieldNodeId = fieldNode.getAttribute ('id');
	var fieldType = fieldNode.getAttribute ('type');

	if (__nodebug == false && __debug == true) {
		__debug = confirm ('id = ' + fieldNodeId + ' (' + fieldType + ')\nnamePrefix = ' + namePrefix);
	}

	var rowCount = fieldNode.getAttribute('rows');
	var fieldCount = fieldNode.childNodes.length;
	var headRow = '';
	var dataRowPrototype = '';
	var parentPrefix = (namePrefix ? namePrefix + '.' : '') + fieldNode.getAttribute('id');
	var tableName = 'table_' + parentPrefix;
	
	if (!rowCount || rowCount == '')
		rowCount = 1;

	if (__nodebug == false) __debug = confirm ('prepareFieldHtml_grid...\nid = ' + fieldNodeId + ' (' + fieldType + ')\nnamePrefix = ' + namePrefix + '\nparentPrefix = ' + parentPrefix + '\ntableName = ' + tableName);
	
	for (var i = 0; i < fieldCount; i++)
	{
		var childFieldDefn = fieldNode.childNodes[i];
		headRow += '<td class="section_field_grid_head">'+childFieldDefn.getAttribute('caption')+'</td>';
		dataRowPrototype += '<td class="section_field_grid_data">'+createFieldHtml(childFieldDefn, level + 1, count, parent, parentPrefix)+'</td>';
	}
	if (fieldNode.getAttribute ('append') != 'no')
		headRow += '<td class="section_field_grid_add" onClick="addGridRow(\'' + tableName + '\')">Add...</td>';
	headRow = '<tr>' + headRow + '</tr>';
	dataRowPrototype = '<tr>' + dataRowPrototype + '</tr>';
	var html = '<table id="' + tableName + '" class="section_field_grid">'+headRow+dataRowPrototype;

	for (var row = 1; row < rowCount; row ++) {
		if (__nodebug == false) __debug = confirm ('adding row #' + rowCount);
		var theDataRow = "";
		for (var i = 0; i < fieldCount; i++)
		{
			var childFieldDefn = fieldNode.childNodes[i];
			theDataRow = '<td class="section_field_grid_data">'+createFieldHtml(childFieldDefn, level + 1, count, parent, parentPrefix)+'</td>';
		}
		
		theDataRow = '<tr>' + theDataRow + '</tr>';
		html += theDataRow;
	}

	html += '</table>';
	return html;
}

function prepareFieldHtml_composite(fieldNode, level, count, parent, namePrefix)
{
	var fieldName = fieldNode.getAttribute ('id');
	var fieldCount = fieldNode.childNodes.length;
	var insideFields = '';
	var addLabelStyle = 'style="vertical-align: top"';
	var icons = '<span style="font-family: wingdings; width: 15"></span>';
	var parentPrefix = (namePrefix ? namePrefix + '.' : '') + fieldNode.getAttribute('id');
	
	if (__nodebug == false && __debug == true) {
		__debug = confirm ('Composite field: id = ' + fieldName + '\nnamePrefix = ' + namePrefix);
	}

	for (var i = 0; i < fieldCount; i++)
	{
		var childFieldDefn = fieldNode.childNodes[i];
		insideFields += createFieldHtml(childFieldDefn, level + 1, count, parent, parentPrefix);
	}

	var areaClassName = 'section_field_area';
	if(fieldNode.getAttribute('condition-field') != null)
	{
		areaClassName = 'section_field_area_conditional';
		var fieldId = '_df_.' + fieldNode.getAttribute('condition-field');
		addConditionalField(fieldId, fieldNode, fieldName);
	}

	var controlHtml = '<span id="'+ fieldName +'_control" class="section_field_control" sectLevel="'+level+'">'+insideFields+'</span>';
	var html = '<div sectLevel="'+level+'" class="'+areaClassName+'" id="'+ fieldName +'_area">' + prepareFieldHtml_caption(fieldNode, level, count, namePrefix, addLabelStyle) + icons + controlHtml + '</div>';
	return html;
}

function prepareFieldHtml_text(fieldNode, level, count, parent, namePrefix)
{
//	var sectionName = 'section' + level;
//	var sectionId = sectionName + '_' + count;
	
	var fieldHtml = '';
	var addLabelStyle = '';
	var fieldName = '_df_.' + namePrefix + '.' + fieldNode.getAttribute('id');
	var parentNode = fieldNode.parentNode;
	var parentNodeName = parentNode.getAttribute('id');
	var parentNodeType = parentNode.getAttribute('type');
	var defaultValue = fieldNode.getAttribute('default') ? fieldNode.getAttribute('default') : ''; 
	fieldControlMap[fieldName] = fieldNode;
	
	if (document.all[fieldName]) {
		// This name already exists... add a number to its end...
		if (__nodebug == false) __debug = confirm ('This fieldName already exists...modifying');
		var notDone = 1;
		var i = 1;
		do {
			var newName = fieldName + '.' + i;
			if (__nodebug == false) notDone = confirm ('Trying ' + newName + '...\nOK - Continue\nCancel - Stop');
			i ++;
			if (!document.all[newName]) {
				if (__nodebug == false) __debug = confirm (newName + ' works!');
				notDone = 0;
			}
		} while (notDone);
		
		fieldName = newName;
		// OK this name should be fine...
	}

	if (fieldNode.getAttribute('type') == 'text') {
		if(fieldNode.getAttribute('lines') == null)
		{
			fieldHtml = '<input sectLevel="'+level+'" onfocus="handleEvent_onfocus(this)" onblur="handleEvent_onblur(this)" onchange="handleEvent_onchange(this)" class="text" name="'+fieldName+'" size="' + getFieldSizeByType (fieldNode.getAttribute('type')) + ((defaultValue && defaultValue != '') ? '" value="' + defaultValue : '') + '">';
		}
		else
		{
			addLabelStyle = 'style="vertical-align: top"';
			fieldHtml = '<textarea sectLevel="'+level+'" onfocus="handleEvent_onfocus(this)" onblur="handleEvent_onblur(this)" class="text" onchange="handleEvent_onchange(this)" name="'+fieldName+'" cols="50" rows="'+fieldNode.getAttribute('lines')+'">' + ((defaultValue && defaultValue != '') ? defaultValue : '') + '</textarea>';
		}
	} else {
		/* Create a text field with data-dependent validation */
		fieldHtml = '<input sectLevel="'+level+'" onfocus="' + fieldNode.getAttribute('type') + '_onfocus(this)" onblur="' + fieldNode.getAttribute('type') + '_onblur(this)" onchange="' + fieldNode.getAttribute('type') + '_onchange(this)" class="text" name="'+fieldName+'" size="' + getFieldSizeByType (fieldNode.getAttribute('type')) + ((defaultValue && defaultValue != '') ? '" value="' + defaultValue : '') + '">';
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
		var fieldId = '_df_.' + fieldNode.getAttribute('condition-field');
		addConditionalField(fieldId, fieldNode, fieldName);
	}
	
	var controlHtml = '<span id="'+ fieldName +'_control" class="section_field_control" sectLevel="'+level+'">'+fieldHtml+'</span>';
	var html = '<div sectLevel="'+level+'" class="'+areaClassName+'" id="'+ fieldName +'_area">' + prepareFieldHtml_caption(fieldNode, level, count, namePrefix, addLabelStyle);
	html += icons + controlHtml + '<div style="margin-left: 125; display:none;" id="'+ fieldName +'_options">Select</div></div>';
	
	return ((parentNodeType == 'composite' || parentNodeType == 'grid') ? (fieldNode.getAttribute ('condition-field') ? '<span id="' + fieldName + '_area" class=section_field_area_conditional" sectLevel="' + level + '" style="display: none">' + controlHtml + '</span>' : controlHtml) : html);
}

function prepareFieldHtml_choose(fieldNode, level, count, parent, namePrefix)
{
//	var sectionName = 'section' + level;
//	var sectionId = sectionName + '_' + count;
	var parentNode = fieldNode.parentNode;
	var parentNodeName = parentNode.getAttribute('id');
	var parentNodeType = parentNode.getAttribute('type');
	
	var fieldName = '_df_.' + namePrefix + '.' + fieldNode.getAttribute('id');
	fieldControlMap[fieldName] = fieldNode;
	
	if (document.all[fieldName]) {
		// This name already exists... add a number to its end...
		if (__nodebug == false) __debug = confirm ('This fieldName already exists...modifying');
		var notDone = 1;
		var i = 1;
		do {
			var newName = fieldName + '.' + i;
			if (__nodebug == false) notDone = confirm ('Trying ' + newName + '...\nOK - Continue\nCancel - Stop');
			i ++;
			if (!document.all[newName]) {
				if (__nodebug == false) __debug = confirm (newName + ' works!');
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
		var fieldId = '_df_.' + fieldNode.getAttribute('condition-field');
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
//		__debug = confirm ('sectionBodyElem = ' + sectionBodyElem + ' [' + sectionBodyElem.length + ']\nsectionBodyElem.style = ' + sectionBodyElem.style + '\nsectionBodyElem.display = ' + sectionBodyElem.display + '\nsectId = ' + sectId + '\ntoggle = ' + toggle);

		if(sectionBodyElem.style.display == 'none')
		{
			sectionIconsElem.innerHTML = '<img src="' + imagePrefix + 'minus.gif"> ';
			sectionBodyElem.className = 'section_body_expanded';
			sectionHeadElem.className = 'section_head_expanded';
			sectionBodyElem.style.display = '';
		}
		else
		{
			sectionIconsElem.innerHTML = '<img src="' + imagePrefix + 'plus.gif"> ';
			sectionBodyElem.className = 'section_body';
			sectionHeadElem.className = 'section_head';
			sectionBodyElem.style.display = 'none';
		}
	}
	else
	{
		sectionIconsElem.innerHTML = '<img src="' + imagePrefix + 'minus.gif"> ';
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
	if (__nodebug == false) __debug = confirm ('handleEvent_onchange\ncontrol.name = ' + control.name);
	if(conditionalFieldsMap[control.name] != null)
	{
		if (__nodebug == false) __debug = confirm ('handleEvent_onchange\nconditionalFieldsMap [control.name].length = ' + conditionalFieldsMap [control.name].length);
		var conditionalFields = conditionalFieldsMap[control.name];
		for(var i = 0; i < conditionalFields.length; i++)
		{
			var fieldInfo = conditionalFields[i];
			var fieldAreaElem = document.all.item(fieldInfo.fieldId + '_area');
			if (__nodebug == false) __debug = confirm ('handleEvent_onchange\nfieldInfo = ' + fieldInfo + '\nfieldAreaElem = ' + fieldAreaElem);
			if (__nodebug == false) __debug = confirm ('handleEvent_onchange\ncondition = ' + fieldInfo.fieldDefn.getAttribute('condition'));
			if(fieldAreaElem == null) alert (fieldInfo.fieldId + '_area not found');
			if(eval(unescape(fieldInfo.fieldDefn.getAttribute('condition'))) == true)
			{
				if (__nodebug == false) __debug = confirm ('handleEvent_onchange\neval(condition) = true');
				fieldAreaElem.className = 'section_field_area_conditional_expanded';
				fieldAreaElem.style.display = '';
			}
			else
			{
				if (__nodebug == false) __debug = confirm ('handleEvent_onchange\neval(condition) = false');
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

/* type=static */

function static_onfocus(control)
{
	handleEvent_onfocus(control);
}

function static_onblur(control)
{
	handleEvent_onblur(control);
}

function static_onchange(control)
{
	handleEvent_onchange(control);
}

