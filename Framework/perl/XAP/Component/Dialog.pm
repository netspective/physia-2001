##############################################################################
package XAP::Component::Dialog::ContentItem;
##############################################################################

use strict;
use XAP::Component::Field;
use base qw(XAP::Component::Field);
use fields qw(
	hint
	hints
	findPopup
	findPopupAppendValue
	findPopupControlField
	popup
	preHtml
	postHtml
	spacerWidth
	);

sub init
{
	my XAP::Component::Dialog::ContentItem $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);

	# variables that might be passed in
	$self->{hint} = exists $params{hint} ? $params{hint} : '';
	$self->{hints} = exists $params{hints} ? $params{hints} : '';
	$self->{findPopup} = exists $params{findPopup} ? $params{findPopup} : undef;
	$self->{findPopupAppendValue} = exists $params{findPopupAppendValue} ? $params{findPopupAppendValue} : '';
	$self->{popup} = exists $params{popup} ? $params{popup} :
		{
			url => '',
			name => 'popup',
			imgsrc => '/resources/icons/magnifying-glass-sm.gif',
			features=>'width=450,height=450,scrollbars,resizable',
			appendValue => '',
		};

	# any HTML to put in before and after a field
	$self->{preHtml} = exists $params{preHtml} ? $params{preHtml} : '';
	$self->{postHtml} = exists $params{postHtml} ? $params{postHtml} : '';

	# internal housekeeping variables
	$self->{spacerWidth} = 0;

	$self;
}

sub onBeforeAdd
{
	#my ($self, $dialog) = @_;
	return 1;
}

sub onAfterAdd
{
	#my ($self, $dialog) = @_;
	return 1;
}

sub popup_as_html
{
	my XAP::Component::Dialog::ContentItem $self = shift;
	my ($page, $dialog, $command, $dlgFlags) = @_;

	my $popupHtml = '';
	my $dialogName = $dialog->formName();
	my $fieldName = $page->fieldPName($self->{name});

	if($self->{popup}->{url})
	{
		$popupHtml =
		qq{
			<a href='javascript:top.doLookup(
						"$self->{popup}->{name}",
						"$self->{popup}->{url}",
						"$self->{popup}->{features}",
						document.$dialogName.$fieldName);'><img src='$self->{popup}->{imgsrc}' border=0></a>
		};
	}

	return $popupHtml;
}

sub findPopup_as_html
{
	my XAP::Component::Dialog::ContentItem $self = shift;
	my $page = shift;
	my XAP::Component::Dialog $dialog = shift;
	my ($command, $dlgFlags) = @_;
	my $dialogName = $dialog->formName();
	my $fieldName = $page->fieldPName($self->{name});

	if(my $arl = $self->{findPopup})
	{
		my $controlField = 'null';
		$controlField = "document.$dialogName.$self->{findPopupControlField}" if $self->{findPopupControlField};

		#my $comboBox = 'null';
		#$comboBox = "document.$dialogName.$self->{findPopupComboBox}" if $self->{findPopupComboBox};

		return qq{
			<a href="javascript:doFindLookup(document.$dialogName, document.$dialogName.$fieldName, '$arl', '$self->{findPopupAppendValue}', false, null, $controlField);"><img src='$self->{popup}->{imgsrc}' border=0></a>
		};
	}
	return '';
}

sub getHtml
{
	my XAP::Component::Dialog::ContentItem $self = shift;
	my $page = shift;
	my XAP::Component::Dialog $dialog = shift;
	my ($command, $dlgFlags, $mainData) = @_;

	my $flags = $self->{flags};
	my $readOnly = ($flags & FLDFLAG_READONLY);
	$mainData ||= '';
	my $html = '';

	my $errorMsgsHtml = '';
	my $bgColorAttr = '';
	my $spacerHtml = '&nbsp;';

	if(my @messages = $page->validationMessages($self->{name}))
	{
		$spacerHtml = '<img src="/resources/icons/arrow_right_red.gif" border=0>';
		$bgColorAttr = "bgcolor='$dialog->{errorBgColor}'";
		$errorMsgsHtml = "<br><font $dialog->{bodyFontErrorAttrs}>" . join("<br>", @messages) . "</font>";
	}

	if($self->{flags} & FLDFLAG_CUSTOMDRAW)
	{
		my $popupHtml = $self->popup_as_html($page, $dialog, $command, $dlgFlags) || $self->findPopup_as_html($page, $dialog, $command, $dlgFlags) if ! $readOnly;
		$html = "$self->{preHtml}$mainData $popupHtml$self->{postHtml}";
	}
	else
	{
		my $caption = $self->{caption};
		$caption = "<b>$caption</b>" if $flags & FLDFLAG_REQUIRED;
		$caption = "<NOBR>$caption</NOBR>" if $flags & FLDFLAG_NOBRCAPTION;
		#$self->{preHtml} = $self->flagsAsStr(1);

		# do some basic variable replacements
		my $Command = "\u$command";
		$caption =~ s/(\$\w+)/$1/eego;

		my $popupHtml = $self->popup_as_html($page, $dialog, $command, $dlgFlags) || $self->findPopup_as_html($page, $dialog, $command, $dlgFlags) if ! $readOnly;
		my $hints = ($self->{hints} && ! $readOnly) ? "<br><font $dialog->{hintsFontAttrs}>$self->{hints}</font>" : '';
		$html = qq{
		<tr valign=top $bgColorAttr>
		<td width=$self->{spacerWidth}>$spacerHtml</td>
		<td align=$dialog->{captionAlign}><font $dialog->{bodyFontAttrs}>$caption</td>
		<td>
			<font $dialog->{bodyFontAttrs}>
			$self->{preHtml}
			$mainData $popupHtml $self->{postHtml}
			$errorMsgsHtml
			$hints
			</font>
		</td>
		<td width=$self->{spacerWidth}>&nbsp;</td>
		</tr>
		};
	}

	return $html;
}

##############################################################################
package XAP::Component::Dialog::Field;
##############################################################################

use strict;
use XAP::Component::Field;
use Date::Manip;
use base qw(XAP::Component::Dialog::ContentItem);
use fields qw(
	fKeyStmt
	fKeyStmtMgr
	fKeyStmtFlags
	fKeyStmtBindPageParams
	fKeyStmtBindFields
	fKeyStmtBindSession
	fKeyTable
	fKeyWhere
	fKeyOrderBy
	fKeySelCols
	fKeyValueCol
	fKeyDisplayCol
	selOptions
	choiceDelim
	valueDelim
	style
	choiceReadOnlyDelim
	cols
	rows
	wrap
	multiDualCaptionLeft
	multiDualCaptionRight
	width
	);

XAP::Component::Field->registerXMLFieldType('_default', 'XAP::Component::Dialog::Field');
XAP::Component::Field->registerXMLFieldType('field-text', 'XAP::Component::Dialog::Field');
foreach (keys %XAP::Component::Field::VALIDATE_TYPE_DATA, 'separator', 'select', 'memo', 'password', 'bool', 'hidden')
{
	XAP::Component::Field->registerXMLFieldType("field-$_", 'XAP::Component::Dialog::Field', 0, { type => $_ });
}

sub init
{
	my XAP::Component::Dialog::Field $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	if(my $fkeyTable = $params{enum} || $params{lookup} || $params{fKeyTable})
	{
		$self->{type} = 'select';
		if(exists $params{enum})
		{
			$self->{fKeyTable} = $fkeyTable;
			$self->{fKeySelCols} = 'id,caption';
			$self->{fKeyValueCol} = 0;   # the ID column
			$self->{fKeyDisplayCol} = 1; # the Caption column
		}
		elsif(exists $params{lookup})
		{
			$self->{fKeyTable} = $fkeyTable;
			$self->{fKeySelCols} = 'id,caption,abbrev,result';
			$self->{fKeyValueCol} = -1;  # figure out value based on result
			$self->{fKeyDisplayCol} = 1; # the Caption column
		}
		$self->{size} = exists $params{size} ? $params{size} : 1;
		$self->{style} = exists $params{style} ? $params{style} : 'combo';
		$self->{choiceReadOnlyDelim} = exists $params{choiceReadOnlyDelim} ? $params{choiceReadOnlyDelim} : ', ';
	}
	elsif(exists $params{fKeyStmt})
	{
		die 'fkeyStmtMgr required if supplying fKeyStmt' unless $params{fKeyStmtMgr};

		$self->{type} = 'select';
		$self->{size} = exists $params{size} ? $params{size} : 1;
		$self->{style} = exists $params{style} ? $params{style} : 'combo';
		$self->{choiceReadOnlyDelim} = exists $params{choiceReadOnlyDelim} ? $params{choiceReadOnlyDelim} : ', ';
	}
	elsif($self->{type} eq 'select')
	{
		$self->{selOptions} = exists $params{selOptions} ? $params{selOptions} : 'No Options';
		$self->{choiceDelim} = exists $params{choiceDelim} ? $params{choiceDelim} : ';';
		$self->{valueDelim} = exists $params{valueDelim} ? $params{valueDelim} : ':';
		$self->{size} = exists $params{size} ? $params{size} : 1;
		$self->{style} = exists $params{style} ? $params{style} : 'combo';
		$self->{choiceReadOnlyDelim} = exists $params{choiceReadOnlyDelim} ? $params{choiceReadOnlyDelim} : ', ';
	}

	if($self->{type} eq 'memo')
	{
		$self->{cols} = exists $params{cols} ? $params{cols} : 30;
		$self->{rows} = exists $params{rows} ? $params{rows} : 3;
		$self->{wrap} = exists $params{wrap} ? $params{wrap} : 'soft';
		$self->{maxLength} = 1024 if $self->{maxLength} < 1024;
	}

	$self;
}

sub hidden_as_html
{
	my XAP::Component::Dialog::Field $self = shift;
	my ($page, $dialog, $command, $dlgFlags) = @_;
	my $fieldName = $page->fieldPName($self->{name});
	return "<input type='hidden' name='$fieldName' value='" . $page->field($self->{name}) . "'>";
}

sub custom_as_html
{
	my XAP::Component::Dialog::Field $self = shift;
	return "$self->{preHtml}$self->{postHtml}";
}

sub separator_as_html
{
	my XAP::Component::Dialog::Field $self = shift;
	my $page = shift;
	my XAP::Component::Dialog $dialog = shift;
	
	if(my $caption = $self->{caption})
	{
		qq{
			<tr><td colspan=4><font size=1>&nbsp;</font></td></tr>
			<tr valign=top>
			<td colspan=4>
				<font $dialog->{subheadFontsAttrs}>
				<b>$caption</b><hr size=1 color=navy noshade>
				</font>
			</td>
			</tr>
		}		
	}
	else
	{
		"<tr><td colspan=4><hr size=1></td></tr>";
	}
}

sub memo_as_html
{
	my XAP::Component::Dialog::Field $self = shift;
	my ($page, $dialog, $command, $dlgFlags) = @_;
	my $fieldName = $page->fieldPName($self->{name});
	my $value = $page->field($self->{name});
	my $readOnly = ($self->{flags} & FLDFLAG_READONLY);
	my $required = ($self->{flags} & FLDFLAG_REQUIRED) ? 'class="required"' : "";
	return $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $readOnly ? $page->field($self->{name}) : "<textarea name='$fieldName' cols=$self->{cols} rows=$self->{rows} wrap='$self->{wrap}' $required>$value</textarea>");
}

sub bool_as_html
{
	my XAP::Component::Dialog::Field $self = shift;
	my ($page, $dialog, $command, $dlgFlags) = @_;
	my $html = '';
	my $fieldName = $page->fieldPName($self->{name});
	my $value = $page->field($self->{name});
	my $checked = $value == 1 ? 'checked' : '';
	my $noSelected = $value == 0 ? 'selected' : '';
	my $yesSelected = $value == 1 ? 'selected' : '';
	my $readOnly = ($self->{flags} & FLDFLAG_READONLY);

	if($readOnly)
	{
		$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $value ? 'Yes' : 'No');
	}
	else
	{
		if($self->{style} eq 'checkalone')
		{
			$html = "
			<tr valign=top>
				<td width=$self->{spacerWidth}>&nbsp;</td>
				<td align=right>
					<input type='checkbox' name='$fieldName' id='$fieldName' align=right $checked value=1>
				</td>
				<td>$self->{preHtml}<label for='$fieldName'>$self->{caption}</label>$self->{postHtml}</td>
				<td width=$self->{spacerWidth}>&nbsp;</td>
			</tr>
			";
		}
		elsif($self->{style} eq 'check')
		{
			if($self->{flags} & FLDFLAG_CUSTOMDRAW)
			{
				$html = "<input type='checkbox' name='$fieldName' id='$fieldName' align=right value=1 $checked> <label for='$fieldName'>$self->{caption}</label>";
			}
			else
			{
				$html = "
				<tr valign=top>
					<td width=$self->{spacerWidth} colspan=2>&nbsp;</td>
					<td>$self->{preHtml}<input type='checkbox' name='$fieldName' id='$fieldName' align=right value=1 $checked> <label for='$fieldName'>$self->{caption}</label>$self->{postHtml}</td>
					<td width=$self->{spacerWidth}>&nbsp;</td>
				</tr>
				";
			}
		}
		elsif($self->{style} eq 'combo')
		{
			$html .= $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, "<select name='$fieldName'><option value=0 $noSelected>No<option value=1 $yesSelected>Yes</select>");
		}
	}
	return $html;
}

sub checkChoiceValueSelected
{
	my XAP::Component::Dialog::Field $self = shift;
	my ($page, $choiceStruct) = @_;

	# $choiceStruct array is comprised of
	#   0 - whether or not the item is selected
	#   1 - the item caption
	#   2 - the item value
	#
	my $value = defined $choiceStruct->[2] ? $choiceStruct->[2] : $choiceStruct->[1];
	my $fName = $page->fieldPName($self->{name});
	if(my @fvalues = $page->param($fName))
	{
		#$page->addDebugStmt("$fName) \@" . join(';' ,@fvalues));
		foreach (@fvalues)
		{
			#$page->addDebugStmt("$fName) $_ <==> $value " . ($_ eq $value));
			$choiceStruct->[0] = 1 if $_ eq $value;
		}
	}
	else
	{
		my $fvalue = $page->param($fName);
		$choiceStruct->[0] = 1 if defined $fvalue && $fvalue eq $value;
	}
}

sub readChoicesStmt
{
	my XAP::Component::Dialog::Field $self = shift;
	my $page = shift;

	my $choices = [];
	my $fkeyValueCol = $self->{fKeyValueCol} || 0;
	my $fKeyDisplayCol = defined $self->{fKeyDisplayCol} ? $self->{fKeyDisplayCol} : 1;
	my $stmtExecFlags = $self->{fKeyStmtFlags} || 0;

	eval
	{
		my @bindParams = ();
		if(my $params = $self->{fKeyStmtBindPageParams})
		{
			if(ref $params eq 'ARRAY')
			{
				#foreach(@$params) { push(@bindParams, $page->param($_)) }
				foreach my $param(@$params) { push(@bindParams, $param) }
			}
			#else { push(@bindParams, $page->param($params)) }
			else { push(@bindParams, $params) }
		}
		if(my $params = $self->{fKeyStmtBindFields})
		{
			if(ref $params eq 'ARRAY')
			{
				foreach(@$params) { push(@bindParams, $page->field($_)) }
			}
			#else { push(@bindParams, $page->field($params)) }
			else { push(@bindParams, $params) }
		}
		if(my $params = $self->{fKeyStmtBindSession})
		{
			if(ref $params eq 'ARRAY')
			{
				foreach(@$params) { push(@bindParams, $page->session($_)) }
			}
			#else { push(@bindParams, $page->field($params)) }
			else { push(@bindParams, $params) }
		}

		my $cursor = $self->{fKeyStmtMgr}->execute($page, $stmtExecFlags, $self->{fKeyStmt}, @bindParams);
		while(my $rowRef = $cursor->fetch())
		{
			my $choiceStruct = [0, $rowRef->[$fKeyDisplayCol], $rowRef->[$fkeyValueCol]];
			$self->checkChoiceValueSelected($page, $choiceStruct);
			push(@{$choices}, $choiceStruct);
		}
	};
	$self->invalidate($page, $@) if $@;
	return $choices;
}

sub readChoices
{
	my XAP::Component::Dialog::Field $self = shift;
	my $page = shift;

	my $choices = [];
	my $fkeyValueCol = $self->{fKeyValueCol} || 0;
	my $fKeyDisplayCol = defined $self->{fKeyDisplayCol} ? $self->{fKeyDisplayCol} : $fkeyValueCol;

	my $whereCond = $self->{fKeyWhere} ? "where $self->{fKeyWhere}" : '';
	my $orderBy =  $self->{fKeyOrderBy} ? "order by $self->{fKeyOrderBy}" : '';

	eval
	{
		my $cursor = $page->prepareSql("select $self->{fKeySelCols} from $self->{fKeyTable} $whereCond $orderBy");
		$cursor->execute();
		if($fkeyValueCol == -1)  # lookups have fKeyValueCol == -1
		{
			while(my $rowRef = $cursor->fetch())
			{
				# $rowRef->[3] for lookups will be "result" which is 0, 1, 2 (for id, caption, or abbrev)
				# if no "result" type is set, assume it's the caption for lookups
				my $choiceStruct =
					[
						0, $rowRef->[$fKeyDisplayCol],
						defined $rowRef->[3] ? $rowRef->[$rowRef->[3]] : $rowRef->[1]
					];
				$self->checkChoiceValueSelected($page, $choiceStruct);
				push(@$choices, $choiceStruct);
			}
		}
		else
		{
			while(my $rowRef = $cursor->fetch())
			{
				my $choiceStruct = [0, $rowRef->[$fKeyDisplayCol], $rowRef->[$fkeyValueCol]];
				$self->checkChoiceValueSelected($page, $choiceStruct);
				push(@{$choices}, $choiceStruct);
			}
		}
	};
	$self->invalidate($page, $@) if $@;
	return $choices;
}

sub parseChoices
{
	my XAP::Component::Dialog::Field $self = shift;
	my $page = shift;

	my @choiceData = split(/$self->{choiceDelim}/, $self->{selOptions});
	my $choices = [];
	foreach (@choiceData)
	{
		my ($choice, $value) = split(/$self->{valueDelim}/);
		$value = $choice unless defined $value;

		my $choiceStruct = [0, $choice, $value];
		$self->checkChoiceValueSelected($page, $choiceStruct);
		push(@{$choices}, $choiceStruct);
	}
	return $choices;
}

sub select_as_html
{
	my XAP::Component::Dialog::Field $self = shift;
	my ($page, $dialog, $command, $dlgFlags) = @_;
	my $fieldName = $page->fieldPName($self->{name});
	my $value = $page->field($self->{name});
	my $readOnly = ($self->{flags} & FLDFLAG_READONLY);
	my $autoBreak = ($self->{flags} & FLDFLAG_AUTOBREAK);
	my $html = '';
	my $i = 1;

	my $choices = $self->{fKeyStmt} ? $self->readChoicesStmt($page) : ($self->{fKeyTable} ? $self->readChoices($page) : $self->parseChoices($page));
	$self->{size} = scalar(@$choices) if $self->{size} == 0;

	if($readOnly)
	{
		my @captions = ();
		foreach (@{$choices})
		{
			next if ! $_->[0];
			$html .= "<input type='hidden' name='$fieldName' value='$value'>";
			push(@captions, $_->[1]);
		}
		$html .= $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, join($self->{choiceReadOnlyDelim}, @captions));
	}
	else
	{
		if($self->{style} eq 'multicheck')
		{
			my $inputs = '';
			foreach (@{$choices})
			{
				my $selected = $_->[0] ? 'checked' : '';
				$inputs .= " " . ($autoBreak ? '<br>' : '') if $i > 1;
				$inputs .= "<nobr><input type='checkbox' name='$fieldName' id='$fieldName$i' value='$_->[2]' $selected> <label for='$fieldName$i'>$_->[1]</label>&nbsp;&nbsp;</nobr>";
				$i++;
			}
			$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $inputs);
		}
		elsif($self->{style} eq 'radio')
		{
			my $inputs = '';
			foreach (@{$choices})
			{
				my $selected = $_->[0] ? 'checked' : '';
				$inputs .= "<nobr><input type=radio name='$fieldName' id='$fieldName$i' value='$_->[2]' $selected> <label for='$fieldName$i'>$_->[1]</label>&nbsp;&nbsp;</nobr> ";
				$i++;
			}
			$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $inputs);
		}
		elsif($self->{style} eq 'multidual')
		{
			my ($selectOptions, $selectOptionsSelected) = ('', '');
			foreach (@{$choices})
			{
				my $lb = $_->[0] ? \$selectOptionsSelected : \$selectOptions;
				$$lb .= "<option value=\"$_->[2]\">$_->[1]</option>";
			}
			my $sorted = $self->flagIsSet(FLDFLAG_SORT) ? 'true' : 'false';
			$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, qq{
					<TABLE CELLSPACING=0 CELLPADDING=1 ALIGN=left BORDER=0>
					<TR>
					<TD ALIGN=left><FONT SIZE=2>$self->{multiDualCaptionLeft}</FONT></TD><TD></TD>
					<TD ALIGN=left><FONT SIZE=2>$self->{multiDualCaptionRight}</FONT></TD>
					</TR>
					<TR>
					<TD ALIGN=left VALIGN=top>
						<SELECT ondblclick="MoveSelectItems('Dialog', '$self->{name}_From', '_f_$self->{name}', $sorted)" NAME=$self->{name}_From SIZE=$self->{size} MULTIPLE STYLE="width: $self->{width}pt">
						$selectOptions
						</SELECT>
					</TD>
					<TD ALIGN=center VALIGN=middle>
						&nbsp;<INPUT TYPE=button NAME="$self->{name}_addBtn" onClick="MoveSelectItems('Dialog', '$self->{name}_From', '_f_$self->{name}', $sorted)" VALUE=" > ">&nbsp;<BR CLEAR=both>
						&nbsp;<INPUT TYPE=button NAME="$self->{name}_removeBtn" onClick="MoveSelectItems('Dialog', '_f_$self->{name}', '$self->{name}_From', $sorted)" VALUE=" < ">&nbsp;
					</TD>
					<TD ALIGN=left VALIGN=top>
						<SELECT ondblclick="MoveSelectItems('Dialog', '_f_$self->{name}', '$self->{name}_From', $sorted)" NAME=_f_$self->{name} SIZE=$self->{size} MULTIPLE STYLE="width: $self->{width}pt">
						$selectOptionsSelected
						</SELECT>
					</TD>
					</TR>
					</TABLE>
				});
		}
		else
		{
			my $options = '';
			my $multiple = $self->{style} eq 'multi' ? 'multiple' : '';
			$options .= "<option value=''></option>" if ($self->{flags} & FLDFLAG_PREPENDBLANK);
			foreach (@{$choices})
			{
				my $selected = $_->[0] ? 'selected' : '';
				$options .= "<option value='$_->[2]' $selected>$_->[1]</option>";
			}
			$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, "<select name='$fieldName' size=$self->{size} $multiple>$options</select>");
		}
	}

	return $html;
}

sub getHtml
{
	my XAP::Component::Dialog::Field $self = shift;
	my ($page, $dialog, $command, $dlgFlags) = @_;
	my $html = '';

	my $specialHdl = "$self->{type}_as_html";

	if ($self->can($specialHdl))
	{
		$html = $self->$specialHdl($page, $dialog, $command, $dlgFlags);
	}
	else
	{
		# if there was an error running a special handler, then there was no
		# special handler so just perform default html formatting

		my $fieldName = $page->fieldPName($self->{name});
		#my $value = $page->field($self->{name}) || $self->{hint};
		my $value = (defined $page->field($self->{name})) ? $page->field($self->{name}) : $self->{hint};
		my $readOnly = ($self->{flags} & FLDFLAG_READONLY);
		my $required = ($self->{flags} & FLDFLAG_REQUIRED) ? 'class="required"' : "";

		if(! $readOnly)
		{
			my $javaScript = $self->generateJavaScript($page);
			my $onFocus = $self->{hint} ? " onFocus='clearField(this)'" : '';
			$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, "<input name='$fieldName' type=$self->{type} value='$value' size=$self->{size} maxlength=$self->{maxLength} $javaScript$onFocus $required>");
		}
		else
		{
			$html = "<input type='hidden' name='$fieldName' value='$value'>";
			$html .= $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $value);
		}
	}

	return $html;
}

##############################################################################
package XAP::Component::Dialog::Field::TableColumn;
##############################################################################

#
# The TableColumn field is a "smart-field" that tries to setup a field with
# all known Schema, Table, and Column properties. It can:
#   -- automatically figure out the column type, name and caption
#   -- automatically populates a default value (if any)
#   -- automatically mark a field as a primaryKey
#   -- automatically set the FLDFLAG_REQUIRED flag
#   -- automatically check for unique column value when command is 'add'
#

use strict;
use Carp;
use XAP::Component::Field;
use base qw(XAP::Component::Dialog::Field);
use Date::Manip;
use vars qw(@ISA);
use Schema::Utilities;

use fields qw(
	schema
	tableColumn
	);

XAP::Component::Field->registerXMLFieldType('field-column', 'XAP::Component::Dialog::Field::TableColumn');

sub init
{
	my XAP::Component::Dialog::Field::TableColumn $self = shift;
	my %params = @_;

	my $schema = $params{schema};
	my $columnName = $params{column};

	croak "schema parameter required" unless $schema;
	croak "column parameter required" unless $columnName;

	my $fieldType = $params{type};
	$params{options} = 0 unless $params{options};
	if(my $column = $schema->getColumn($columnName))
	{
		$params{tableColumn} = $column;
		$params{name} = $column->getName() unless $params{name};
		$params{caption} = $column->getCaption() unless $params{caption};
		$params{options} |= FLDFLAG_PRIMARYKEY if $column->isPrimaryKey();
		$params{options} |= FLDFLAG_REQUIRED if $column->isRequiredUI();
		$params{defaultValue} = $column->getDefaultVal();

		my $colType = $column->getType();
		$params{maxLength} = $column->getSize();
		my $fkeySetupAlready = 0;
		if(my $valType = $CGI::Validator::Field::VALIDATE_TYPE_DATA{$colType})
		{
			# found a validation type with the same name as colType, so use it
			$params{type} = $colType unless $fieldType;
		}
		else
		{
			# didn't find a validator so try go figure something out
			if(my $method = __PACKAGE__->can("setup_coltype_$colType"))
			{
				&{$method}($schema, $column, \%params);
				$fkeySetupAlready = 1;
			}
			else
			{
				my $colSize = $column->getSize();
				if(! $fieldType)
				{
					$params{type} = $colSize > 64 ? 'memo' : 'text';
				}
				$params{maxLength} = $colSize;
			}
		}
		if($column->isForeignKey() && $fkeySetupAlready == 0)
		{
			my $foreignCol = $column->getForeignCol();
			my $foreignTable = $foreignCol->getTable();

			if($foreignTable->isTableType('Type_Definition'))
			{
				$params{type} = 'foreignKey';
				$params{fKeyTable} = $foreignTable->getName();
				$params{fKeySelCols} = "id,caption";
				$params{fKeyValueCol} = 0;
				$params{fKeyDisplayCol} = 1;

				if(! exists $params{fKeyWhere})
				{
					if(my $typeRange = $params{typeRange})
					{
						# range is provided as lower..upper so split the range
						my ($lower, $upper) = split(/\.\./, $typeRange);
						$params{fKeyWhere} = "(id between $lower and $upper)";
					}
					if(my $typeGroup = $params{typeGroup})
					{
						my $cond = Schema::Utilities::addSingleQuotes($typeGroup);
						if(ref $cond eq 'ARRAY')
						{
							$cond = 'in (' . join(', ', @$cond) . ')';
						}
						else
						{
							$cond = ' = ' . $cond;
						}
						$params{fKeyWhere} .= " and " if $params{fKeyWhere};
						$params{fKeyWhere} = "$params{fKeyWhere} (group_name $cond)";
					}
				}
				$params{fKeyOrderBy} = 'id';
			}
			elsif($foreignTable->isTableType('Lookup'))
			{
				$params{lookup} = $foreignTable->getName();
			}
			elsif($foreignTable->isTableType('Enumeration'))
			{
				$params{type} = 'enum';
				$params{enum} = $foreignTable->getName();
			}
		}
	}
	else
	{
		croak "column $columnName does not exist in $schema->{name}";
	}

	$self->SUPER::init(%params);
	$self;
}

sub needsValidation
{
	my XAP::Component::Dialog::Field::TableColumn $self = shift;
	my ($page, $validator) = @_;

	# if we've been deemed as needsValidation already, leave
	return 1 if $self->SUPER::needsValidation();

	# if the column is unique, then it requires validation
	return 1 if $self->{tableColumn}->isUnique();
	return 0;
}

sub isValid
{
	my XAP::Component::Dialog::Field::TableColumn $self = shift;
	my ($page, $validator) = @_;

	if($self->SUPER::isValid($page, $validator))
	{
		if (my $value = $page->field($self->{name}))
		{
			my $column = $self->{tableColumn};
			if($column->isUnique() && $validator->getActiveCommand() eq 'add')
			{
				$self->invalidate($page, "$self->{caption} '$value' already exists.")
					if $page->schemaRecExists($column->getTableName(), $column->getName() => $value);
			}
		}
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

sub handle_coltype_xxx
{
	my ($schema, $column, $params) = @_;

	# this type of handler can be written for specific column types
}

##############################################################################
package XAP::Component::Dialog::MultiField;
##############################################################################

use strict;
use XAP::Component::Field;
use base qw(XAP::Component::Dialog::ContentItem);
use fields qw(fields);

XAP::Component::Field->registerXMLFieldType('field-group', 'XAP::Component::Dialog::MultiField', FLDXMLTYPEFLAG_NESTED);

sub init
{
	my XAP::Component::Dialog::MultiField $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{fields} = exists $params{fields} ? $params{fields} : [];
	$self;
}

sub addContent
{
	my XAP::Component::Dialog::MultiField $self = shift;
	my $field = shift;
	push(@{$self->{fields}}, $field);
}

sub updateFlag
{
	my XAP::Component::Dialog::MultiField $self = shift;
	my ($flag, $value) = @_;
	foreach (@{$self->{fields}})
	{
		# make sure validation is really need for sub-fields
		$_->updateFlag($flag, $value);
	}
	$self->SUPER::updateFlag($flag, $value);
}

sub setFlag
{
	my XAP::Component::Dialog::MultiField $self = shift;
	my ($flag) = @_;
	foreach (@{$self->{fields}})
	{
		# make sure validation is really need for sub-fields
		$_->setFlag($flag);
	}
	$self->SUPER::setFlag($flag);
}

sub clearFlag
{
	my XAP::Component::Dialog::MultiField $self = shift;
	my ($flag) = @_;
	foreach (@{$self->{fields}})
	{
		# make sure validation is really need for sub-fields
		$_->clearFlag($flag);
	}
	$self->SUPER::clearFlag($flag);
}

sub needsValidation
{
	my XAP::Component::Dialog::MultiField $self = shift;
	my ($page, $validator) = @_;

	my $needsVal = 0;
	$needsVal++ if $self->SUPER::needsValidation();

	foreach (@{$self->{fields}})
	{
		# make sure validation is really need for sub-fields
		$_->updateFlag(FLDFLAG_READONLY, $self->flagIsSet(FLDFLAG_READONLY));
		$_->updateFlag(FLDFLAG_INVISIBLE, $self->flagIsSet(FLDFLAG_INVISIBLE));
		$needsVal++ if $_->needsValidation();
	}

	$needsVal;
}

sub populateValue
{
	my XAP::Component::Dialog::MultiField $self = shift;
	my ($page, $validator) = @_;

	foreach (@{$self->{fields}})
	{
		$_->populateValue($page, $validator);
	}

	return 1;
}

sub isValid
{
	my XAP::Component::Dialog::MultiField $self = shift;
	my ($page, $validator) = @_;

	# just cycle through all the rules and let them validate themselves
	foreach (@{$self->{fields}})
	{
		$_->updateFlag(FLDFLAG_READONLY, $self->flagIsSet(FLDFLAG_READONLY));
		$_->isValid($page, $validator) if $_->needsValidation($page, $validator);
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

sub getHtml
{
	my XAP::Component::Dialog::MultiField $self = shift;
	my $page = shift;
	my XAP::Component::Dialog $dialog = shift;
	my ($command, $dlgFlags) = @_;

	my $readOnly = ($self->{flags} & FLDFLAG_READONLY);

	my $completeHtml = '';
	my $fieldsHtml = '';
	my $errorMsgsHtml = '';
	my $bgColorAttr = '';
	my $spacerHtml = '&nbsp;';
	my $fields = $self->{fields};
	my $requiredCols = 0;

	my @messages = ();
	foreach(@$fields)
	{
		my @fldValMsgs = $page->validationMessages($_->{name});
		push(@messages, @fldValMsgs) if @fldValMsgs;
		$_->setFlag(FLDFLAG_CUSTOMDRAW);
		$requiredCols += $_->flagIsSet(FLDFLAG_REQUIRED);
		$fieldsHtml .= $_->getHtml($page, $dialog, $command, $dlgFlags) . ' ';
	}
	if(@messages)
	{
		$spacerHtml = '<img src="/resources/icons/arrow_right_red.gif" border=0>';
		$bgColorAttr = "bgcolor='$dialog->{errorBgColor}'";

		my $msgsHtml = '';
		foreach (@messages)
		{
			next if m/^\s*$/;  # skip blanks
			$msgsHtml .= '<br>' . $_;
		}
		$errorMsgsHtml = "<font $dialog->{bodyFontErrorAttrs}>$msgsHtml</font>";
	}

	# Multifield caption overrides sub field captions
	my $caption = "";
	if ($self->{flags} & FLDFLAG_DEFAULTCAPTION)
	{
		foreach(@$fields)
		{
			if (defined $_->{caption})
			{
				$caption .= " / " if ($caption);
				$caption .= $_->{flags} & FLDFLAG_REQUIRED ? "<b>$_->{caption}</b>" : $_->{caption};
			}
		}
	}
	else
	{
		$caption = $self->{caption};
		$caption = "<b>$caption</b>" if $requiredCols > 0;
	}


	# do some basic variable replacements
	my $Command = "\u$command";
	$caption =~ s/(\$\w+)/$1/eego;

	my $popupHtml = $self->popup_as_html($page, $dialog, $command, $dlgFlags) || $self->findPopup_as_html($page, $dialog, $command, $dlgFlags) if ! $readOnly;
	my $hints = ($self->{hints} && ! $readOnly) ? "<br><font $dialog->{hintsFontAttrs}>$self->{hints}</font>" : '';
	return qq{
		<tr valign=top $bgColorAttr>
		<td width=$self->{spacerWidth}>$spacerHtml</td>
		<td align=$dialog->{captionAlign}><font $dialog->{bodyFontAttrs}>$caption</td>
		<td>
			<font $dialog->{bodyFontAttrs}>
			$self->{preHtml}
			$fieldsHtml $popupHtml $self->{postHtml}
			$errorMsgsHtml
			$hints
			</font>
		</td>
		<td width=$self->{spacerWidth}>&nbsp;</td>
		</tr>
	};
}

##############################################################################
package XAP::Component::Dialog::Field::Duration;
##############################################################################

use strict;
use Date::Manip;
use XAP::Component::Field;
use base qw(XAP::Component::Dialog::MultiField);

XAP::Component::Field->registerXMLFieldType('field-duration', 'XAP::Component::Dialog::Field::Duration');

sub init
{
	my XAP::Component::Dialog::Field::Duration $self = shift;
	my %params = @_;

	my $name = $params{name} || 'duration';
	my $type = $params{type} || 'date';

	my $beginParams = { type => $type, name => "$name\_begin_$type", options => $params{options}, defaultValue => '' };
	my $endParams = { type => $type, name => "$name\_end_$type", options => $params{options}, defaultValue => '' };

	# now see if any begin_ or end_ params were given (passed into apprpriate field)
	foreach (keys %params)
	{
		next unless m/^(begin_|end_)(.*)$/;
		my $fldParams = $1 eq 'begin_' ? $beginParams : $endParams;
		$fldParams->{$2} = $params{$_};
	}

	$params{fields} = [
		new XAP::Component::Dialog::Field(%{$beginParams}),
		new XAP::Component::Dialog::Field(%{$endParams}),
	];

	$self->SUPER::init(%params);
	$self;
}

sub needsValidation
{
	XAP::Component::Dialog::MultiField::needsValidation(@_);
	return 1;
}

sub isValid
{
	my ($self, $page, $validator) = @_;

	# fields->[0] is always the start date/stamp
	# fields->[1] is always the end date/stamp
	#
	my $fields = $self->{fields};
	my $start  = $fields->[0];
	my $end    = $fields->[1];

	# make sure that the starting is less then end and end is greater than start
	$start->{preDate} = $page->field($end->{name});
	$end->{postDate} = $page->field($start->{name});

	return $self->SUPER::isValid($page, $validator);
}

##############################################################################
package XAP::Component::Dialog::HeadFootItem;
##############################################################################

use strict;
use XAP::Component::Field;
use base qw(XAP::Component::Field);
use fields qw(preHtml postHtml);

sub getHtml
{
}

##############################################################################
package XAP::Component::Dialog::Buttons;
##############################################################################

use strict;
use XAP::Component::Field;
use base qw(XAP::Component::Dialog::HeadFootItem);
use fields qw(nextActions cancelUrl);

use constant NEXTACTION_PARAMNAME => '_f_nextaction_redirecturl';
use constant NEXTACTION_FIELDNAME => 'nextaction_redirecturl';

XAP::Component::Field->registerXMLFieldType('field-buttons', 'XAP::Component::Dialog::Buttons', FLDXMLTYPEFLAG_FOOTERITEM);

sub init
{
	my XAP::Component::Dialog::Buttons $self = shift;
	my %params = @_;

	$params{type} = -1 if ! exists $params{type};

	#
	# nextActions is a reference to another array of the following type:
	#   option, url, isDefault
	#   where "option" is the text of the action
	#   where "url" is the URL to go to when selected
	#      URL can have the following variables
	#          #session.xxxx# which will be replaced at runtime by $page->session('xxxx')
	#          #URL.xxxx#   which will be replaced at runtime by $page->param('xxxx')
	#          #field.xxxx#   which will be replaced at runtime by $page->field('xxxx')
	#      remember, the actual replacements for #xxxx.yyyy# will happen in CGI::Page::send_http_header
	#   where "isDefault" should be set to "1" to make the option the selected option
	#
	# nextActions can come in the following forms:
	#   just "nextActions" -- meaning show it in all cases
	#   just "nextActions->{add}" -- meaning show it just for "add" command
	#   just "nextActions->{update}" -- meaning show it just for "update" command
	#   just "nextActions->{remove}" -- meaning show it just for "remove" command
	#
	$params{cancelUrl} = 'javascript:history.back()' unless $params{cancelUrl};

	$self->SUPER::init(%params);
	$self;
}

sub getHtml
{
	my XAP::Component::Dialog::Buttons $self = shift;
	my $page = shift;
	my XAP::Component::Dialog $dialog = shift;
	my ($command, $dlgFlags) = @_;

	my $tableCols = $dialog->{tableCols};
	my $rowColor = '';
	my $cancelURL = $page->isPopup() ? 'javascript:window.close()' : $self->{cancelUrl};
	my @nextActions = ();
	if(my $actionsList = (ref $self->{nextActions} eq 'HASH' ? $self->{nextActions}->{$command} : $self->{nextActions}))
	{
		my $activeAction = $page->param(NEXTACTION_PARAMNAME);
		foreach(@$actionsList)
		{
			push(@nextActions, qq{ <OPTION VALUE='$_->[1]' @{[ $activeAction ? ($activeAction eq $_->[1] ? 'SELECTED' : '') : ($_->[2] ? 'SELECTED' : '') ]}>$_->[0]</OPTION> });
		}
	}
	my $nextActions = @nextActions ? qq{ <FONT FACE=Arial,Helvetica SIZE=2 STYLE="font-size:8pt; font-family: tahoma,arial"><B>Next Action:</B> </FONT><SELECT NAME='_f_nextaction_redirecturl' style='font-size:8pt; font-family: tahoma,arial,helvetica'>@{[ join('', @nextActions) ]}</SELECT> } : '';

	my $submitCaption = "Submit";
	$submitCaption = "Create" if $self->{type} == 0;
	$submitCaption = "Modify" if $self->{type} == 1;
	$submitCaption = "Delete Record" if $self->{type} == 2;

	my $resetButton = '<input type="reset" value="Reset">';
	$resetButton = '' if $self->{type} eq 'delete';

	my $fieldName = $page->fieldPName('OK');
	return qq{
		<tr><td colspan=$tableCols><font size=1>&nbsp;</font></td></tr>
		<tr valign=center bgcolor=$rowColor>
		<td align=center colspan=$tableCols valign=bottom>
			@{[ defined $self->{preHtml} ? $self->{preHtml} : '']}
			$nextActions
			<input name="$fieldName" type="image" src="/resources/widgets/ok_btn.gif" border=0 title="">
			<a href="$cancelURL"><img src="/resources/widgets/cancel_btn.gif" border=0></a>
			@{[ defined $self->{postHtml} ? $self->{postHtml} : '']}
		</td>
		</tr>
	};
}

##############################################################################
package XAP::Component::Dialog::Text;
##############################################################################

use strict;

use XAP::Component::Field;
use base qw(XAP::Component::Dialog::HeadFootItem);
use fields qw(text);

XAP::Component::Field->registerXMLFieldType('field-static', 'XAP::Component::Dialog::Text', FLDXMLTYPEFLAG_HEADERITEM);

sub init
{
	my XAP::Component::Dialog::Text $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{text} = exists $params{text} ? $params{text} : 'No text provided';
	$self;
}

sub getHtml
{
	my XAP::Component::Dialog::Text $self = shift;
	my $page = shift;
	my XAP::Component::Dialog $dialog = shift;
	my ($command, $dlgFlags) = @_;

	return qq{
	<tr valign=top>
	<td colspan=$dialog->{tableCols}>
		$self->{text}
		<br>&nbsp;
	</td>
	</tr>
	};
}

##############################################################################
package XAP::Component::Dialog;
##############################################################################

use strict;
use Carp;
use XAP::Component;
use XAP::Component::Field;
use XAP::Component::Validator;
use XAP::Component::CommandProcessor;
use XAP::Component::Command::Query;

use base qw(XAP::Component::Validator);
use fields qw(
	formName
	formAttrs
	dlgHeader
	dlgFooter
	preHtml
	postHtml
	fieldMap
	priKeys
	headColor
	headErrorColor
	bgColor
	errorBgColor
	ruleBelowHeading
	cellPadding
	columns
	headFontAttrs
	bodyFontAttrs
	bodyFontErrorAttrs
	hintsFontAttrs
	subheadFontsAttrs
	captionAlign
	activityLog
	tableCols
	execCmds
	populateCmds
	_activeDlgContainer
	adjacentContent
	adjacentFlags
	);

use enum qw(BITMASK:DLGFLAG_
	DATAENTRY_INITIAL
	DATAENTRY
	EXECUTE
	PRIKEYREADONLY
	READONLY
	ADD
	UPDATE
	REMOVE
	ADD_DATAENTRY_INITIAL
	UPDORREMOVE_DATAENTRY_INITIAL
	UPDORREMOVE
	IGNOREREDIRECT
	);
	
use enum qw(BITMASK:ADJFLAG_ 	
	HAVEHORIZ
	HAVEVERT
	HAVELEFT
	HAVERIGHT
	HAVETOP
	HAVEBOTTOM);

use constant FIELDNAME_EXECMODE => 'dlg_execmode';
use constant FIELDNAME_REFERER  => 'dlg_referer';

use constant PAGEPROPNAME_EXECMODE => '_dlg_execmode';
use constant PAGEPROPNAME_INEXEC   => '_dlg_inexec';
use constant PAGEPROPNAME_FLAGS    => '_dlg_flags';
use constant PAGEPROPNAME_VALID    => '_dlg_valid';
use constant PAGEPROPNAME_COMMAND  => '_dlg_command';

use constant CALLBACKITEM_POPULATEDATAFUNC => 0;
use constant CALLBACKITEM_EXECUTEFUNC => 1;
use constant CALLBACKITEM_EXTRADATA => 2;

use enum qw(:ADJACENTLOCATION_ LEFT RIGHT TOP BOTTOM);

use vars qw(%DIALOG_COMMAND_ACTIVITY_MAP %DLG_FLAGS_ATTRMAP %FIELD_FLAGS_ATTRMAP %ADJACENT_ATTRMAP);
%DIALOG_COMMAND_ACTIVITY_MAP = (
	'view' => 0, 'add' => 1, 'update' => 2, 'remove' => 3,
	'cancel' => 4, 'noshow' => 5, 'reschedule' => 6,
);

use constant ACTIVITY_TYPE_RECORD => 0;
use constant ACTIVITY_TYPE_PAGE => 1;
use constant ACTIVITY_LEVEL_HIGH => 0;
use constant ACTIVITY_LEVEL_MEDIUM => 1;
use constant ACTIVITY_LEVEL_LOW => 2;

%ADJACENT_ATTRMAP = (
	'left' => [ADJACENTLOCATION_LEFT, ADJFLAG_HAVEHORIZ | ADJFLAG_HAVELEFT],
	'right' => [ADJACENTLOCATION_RIGHT, ADJFLAG_HAVEHORIZ | ADJFLAG_HAVERIGHT],
	'top' => [ADJACENTLOCATION_TOP, ADJFLAG_HAVEVERT | ADJFLAG_HAVETOP],
	'bottom' => [ADJACENTLOCATION_BOTTOM, ADJFLAG_HAVEVERT | ADJFLAG_HAVEBOTTOM],
	);

%DLG_FLAGS_ATTRMAP = (
	'initialDataEntry' => DLGFLAG_DATAENTRY_INITIAL,
	'anyDataEntry' => DLGFLAG_DATAENTRY,
	'execute' => DLGFLAG_EXECUTE,
	'priKeyReadOnly' => DLGFLAG_PRIKEYREADONLY,
	'readOnly' => DLGFLAG_READONLY,
	'add' => DLGFLAG_ADD,
	'update' => DLGFLAG_UPDATE,
	'remove' => DLGFLAG_REMOVE,
	'addInitialDataEntry' => DLGFLAG_ADD_DATAENTRY_INITIAL,
	'updOrRemoveInitialDataEntry' => DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL,
	'updOrRemove' => DLGFLAG_UPDORREMOVE,
	'ignoreRedirect' => DLGFLAG_IGNOREREDIRECT,
	);

%FIELD_FLAGS_ATTRMAP = (
	'invisible' => FLDFLAG_INVISIBLE,
	'readOnly' => FLDFLAG_READONLY,
	'required' => FLDFLAG_REQUIRED,
	'identifier' => FLDFLAG_IDENTIFIER,
	'trim' => FLDFLAG_TRIM,
	'uppercase' => FLDFLAG_UPPERCASE,
	'ucaseinitial' => FLDFLAG_UCASEINITIAL,
	'lowercase' => FLDFLAG_LOWERCASE,
	'nobrcaption' => FLDFLAG_NOBRCAPTION,
	'persist' => FLDFLAG_PERSIST,
	'home' => FLDFLAG_HOME,
	'sort' => FLDFLAG_SORT,
	'prependBlank' => FLDFLAG_PREPENDBLANK,
	'primaryKey' => FLDFLAG_PRIMARYKEY,
	'autobreak' => FLDFLAG_AUTOBREAK,
	);

#
# execmode can be (I)nput, (V)alidate, or (E)xecute [case matters!]
#

XAP::Component->registerXMLTagClass('dialog', __PACKAGE__);

sub init
{
	my XAP::Component::Dialog $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);

	$self->{dlgHeader} = exists $params{dlgHeader} ? $params{dlgHeader} : [];
	$self->{dlgFooter} = exists $params{dlgFooter} ? $params{dlgFooter} : [];
	$self->{preHtml} = exists $params{preHtml} ? $params{preHtml} : [];
	$self->{postHtml} = exists $params{postHtml} ? $params{postHtml} : [];
	$self->{fieldMap} = exists $params{fieldMap} ? $params{fieldMap} : {};
	$self->{priKeys} = exists $params{priKeys} ? $params{priKeys} : [];
	$self->{headColor} = exists $params{headColor} ? $params{headColor} : "LIGHTSTEELBLUE";
	$self->{headErrorColor} = exists $params{headErrorColor} ? $params{headErrorColor} : "DARKRED";
	$self->{bgColor} = exists $params{bgColor} ? $params{bgColor} : "#EEEEEE";
	$self->{errorBgColor} = exists $params{errorBgColor} ? $params{errorBgColor} : "#d7dfd7";
	$self->{ruleBelowHeading} = exists $params{ruleBelowHeading} ? $params{ruleBelowHeading} : 0;
	$self->{cellPadding} = exists $params{cellPadding} ? $params{cellPadding} : 2;
	$self->{columns} = exists $params{columns} ? $params{columns} : 1;
	$self->{headFontAttrs} = exists $params{headFontAttrs} ? $params{headFontAttrs} : "face='arial,helvetica' size='2' color=yellow";
	$self->{bodyFontAttrs} = exists $params{bodyFontAttrs} ? $params{bodyFontAttrs} : "face='arial,helvetica' size='2' color=black";
	$self->{bodyFontErrorAttrs} = exists $params{bodyFontErrorAttrs} ? $params{bodyFontErrorAttrs} : "face='arial,helvetica' size='2' color=red";
	$self->{hintsFontAttrs} = exists $params{hintsFontAttrs} ? $params{hintsFontAttrs} : "face='arial,helvetica' size=2 color=navy";
	$self->{subheadFontsAttrs} = exists $params{subheadFontsAttrs} ? $params{subheadFontsAttrs} : "face='arial,helvetica' size=2 color=navy";
	$self->{formAttrs} = exists $params{formAttrs} ? $params{formAttrs} : '';
	$self->{formName} = exists $params{formName} ? $params{formName} : 'dialog';
	$self->{captionAlign} = exists $params{captionAlign} ? $params{captionAlign} : 'left';
	$self->{execCmds} = exists $params{execCmds} ? $params{execCmds} : undef;
	$self->{populateCmds} = exists $params{populateCmds} ? $params{populateCmds} : undef;
	$self->{translateURLParams} = 'action';
	$self->{_activeDlgContainer} = undef; # used for XML parsing information
	$self->{adjacentContent} = exists $params{adjacentContent} ? $params{adjacentContent} : undef;
	$self->{adjacentFlags} = exists $params{adjacentFlags} ? $params{adjacentFlags} : 0;

	$self;
}

#
# createDialogFlagsFromText is called from XAP::Component::Command without $self (it's undef) so check it 
# before calling
#
sub createDialogFlagsFromText
{
	my XAP::Component::Dialog $self = shift;
	my $flagNames = shift;

	my $flags = 0;
	foreach (split(/,/, $flagNames))
	{
		if(exists $XAP::Component::Dialog::DLG_FLAGS_ATTRMAP{$_})
		{
			$flags |= $XAP::Component::Dialog::DLG_FLAGS_ATTRMAP{$_};
		}
		elsif($self)
		{
			$self->addError("unknown dialog flag '$_' in dialog '$self->{id}' ($flagNames)");
		}
		else
		{
			die "unknown dialog flag '$_' in ($flagNames)";
		}
	}
	return $flags;
}

sub initFieldsFromXML
{
	my XAP::Component::Dialog $self = shift;
	my ($tag, $content) = @_;

	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
	my XAP::Component $container = $self->{_activeDlgContainer};
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		next unless $chTag; # if $tag is 0, it's just characters

		my $chAttrs = $chContent->[0];
		if($chTag eq 'on-execute')
		{
			$self->{execCmds} = new XAP::Component::CommandProcessor(parent => $self);
			$self->{execCmds}->applyXML($chTag, $chContent);
			next;
		}
		elsif($chTag eq 'on-populate')
		{
			$self->{populateCmds} = new XAP::Component::CommandProcessor(parent => $self);
			$self->{populateCmds}->applyXML($chTag, $chContent);
			next;
		}
		elsif($chTag eq 'field-custom')
		{
			$container->addContent(new XAP::Component::Dialog::Field(type => 'custom', flags => FLDFLAG_CUSTOMDRAW, preHtml => getTagTextOnly($chContent)));
			next;
		}
		elsif($chTag eq 'adjacent-content')
		{
			$self->{adjacentContent} = [undef, undef, undef, undef] unless $self->{adjacentContent};
			my $adjTemplate = new XAP::Component::Template(parent => $self);
			$adjTemplate->applyXML($chTag, $chContent);
			my $location = $chAttrs->{location} || 'right';
			my $locInfo = exists $ADJACENT_ATTRMAP{$location} ? $ADJACENT_ATTRMAP{$location} : $ADJACENT_ATTRMAP{'right'};
			$self->{adjacentContent}->[$locInfo->[0]] = $adjTemplate;
			$self->{adjacentFlags} |= $locInfo->[1];
			next;
		}

		# make a copy of the attrs because we'll be changing them
		my $fieldAttrs = convertAttrsToHashRef($chAttrs);
		if(my $flagNames = $chAttrs->{options})
		{
			my $flags = XAP::Component::Field::FLDFLAGS_DEFAULT;
			foreach (split(/,/, $flagNames))
			{
				if(exists $FIELD_FLAGS_ATTRMAP{$_})
				{
					$flags |= $FIELD_FLAGS_ATTRMAP{$_};
				}
				else
				{
					$self->addError("unknown field flag '$_' in dialog '$self->{id}' field '$chAttrs->{name}'");
				}
			}
			$fieldAttrs->{options} = $flags;
		}

		foreach my $dlgCondAttr ('readOnlyWhen', 'invisibleWhen')
		{
			$fieldAttrs->{$dlgCondAttr} = $self->createDialogFlagsFromText($chAttrs->{$dlgCondAttr}) if $chAttrs->{$dlgCondAttr};
		}

		my XAP::Component::Dialog::Field $field;
		my $typeFlags;
		($field, $typeFlags) = XAP::Component::Field->createXMLFieldType($chTag, id => $fieldAttrs->{name}, %$fieldAttrs);
		if($field)
		{
			if($typeFlags & FLDXMLTYPEFLAG_HEADERITEM)
			{
				$container->addHeader($field);
			}
			elsif($typeFlags & FLDXMLTYPEFLAG_FOOTERITEM)
			{
				$container->addFooter($field);
			}
			else
			{
				$container->addContent($field);
			}

			my $gChildCount = scalar(@$chContent);
			my $firstOption = 1;
			for(my $gChild = 1; $gChild < $gChildCount; $gChild += 2)
			{
				my ($gChTag, $gChContent) = ($chContent->[$gChild], $chContent->[$gChild+1]);
				next unless $gChTag; # if $tag is 0, it's just characters
				
				my $gChAttrs = $gChContent->[0];
				if($gChTag eq 'validate-query')
				{
					my XAP::Component::Command::Query $query = new XAP::Component::Command::Query;
					$query->applyXML($gChTag, $gChContent);
					
					$field->{onValidateQuery} = $query;
					if(my $message = $gChAttrs->{message})
					{
						$field->{message} = $message;
					}
					else
					{
						$field->{message} = "$field->{caption} was not found in the system. Please be sure $field->{caption} already exists." if $query->{action} == QUERYACTIONTYPE_RECORDEXISTS;
						$field->{message} = "$field->{caption} is already in the system. Please be sure $field->{caption} does not already exist." if $query->{action} == QUERYACTIONTYPE_RECORDNOTEXISTS;
					}
				}
				elsif($gChTag eq 'field-option')
				{
					$field->{selOptions} = $firstOption ? '' : ($field->{selOptions} . ';');
					$field->{selOptions} .= $gChAttrs->{caption} . (exists $gChAttrs->{value} ? (':' . $gChAttrs->{value}) : '');
					$firstOption = 0;
				}
			}
			
			if($typeFlags & FLDXMLTYPEFLAG_NESTED)
			{
				$self->{_activeDlgContainer} = $field;
				$self->initFieldsFromXML($chTag, $chContent);
				$self->{_activeDlgContainer} = $self;
			}
		}
		else
		{
			$self->addError("unable to create field type '$chTag' in dialog '$self->{id}'") if $chTag =~ m/^field/;
		}
	}
}

sub applyXML
{
	my XAP::Component::Dialog $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);
	$self->{_activeDlgContainer} = $self;
	$self->initFieldsFromXML($tag, $content);
	$self->{_activeDlgContainer} = undef;
	$self;
}

sub id
{
	my XAP::Component::Dialog $self = shift;
	return $self->{id};
}

sub formName
{
	my XAP::Component::Dialog $self = shift;
	return $self->{formName};
}

sub getField
{
	my XAP::Component::Dialog $self = shift;
	my ($name) = @_;
	my $fmap = $self->{fieldMap};
	if(exists $fmap->{$name})
	{
		return $self->{childCompList}->[$fmap->{$name}];
	}
	else
	{
		return undef;
	}
}

sub updateFieldFlags
{
	my XAP::Component::Dialog $self = shift;
	my ($name, $flags, $condition) = @_;
	my $fmap = $self->{fieldMap};
	if(exists $fmap->{$name})
	{
		my XAP::Component::Field $field = $self->{childCompList}->[$fmap->{$name}];
		$field->updateFlag($flags, $condition);
		return $field;
	}
	return undef;
}

sub setFieldFlags
{
	my XAP::Component::Dialog $self = shift;
	my ($name, $flags) = @_;
	my $fmap = $self->{fieldMap};
	if(exists $fmap->{$name})
	{
		my XAP::Component::Field $field = $self->{childCompList}->[$fmap->{$name}];
		$field->setFlag($flags);
		return $field;
	}
	return undef;
}

sub clearFieldFlags
{
	my XAP::Component::Dialog $self = shift;
	my ($name, $flags) = @_;
	my $fmap = $self->{fieldMap};
	if(exists $fmap->{$name})
	{
		my XAP::Component::Field $field = $self->{childCompList}->[$fmap->{$name}];
		$field->clearFlag($flags);
		return $field;
	}
	return undef;
}

sub makeStateChanges
{
	my XAP::Component::Dialog $self = shift;
	my ($page, $command, $dlgFlags) = @_;

	foreach(@{$self->{childCompList}})
	{
		# clear the read-only flag by default
		$_->{flags} = 0 unless defined $_->{flags};
		my $flagsRef = \$_->{flags};

		# now see if the field needs readOnly flags set
		$$flagsRef &= ~FLDFLAG_READONLY;
		$$flagsRef |= FLDFLAG_READONLY
			if	($dlgFlags & DLGFLAG_READONLY) ||
			 	($_->{options} && $_->{options} & FLDFLAG_PRIMARYKEY && ($dlgFlags & DLGFLAG_PRIKEYREADONLY)) ||
			 	($_->{options} && $_->{options} & FLDFLAG_READONLY);

		$_->updateFlag(FLDFLAG_READONLY, $dlgFlags & $_->{readOnlyWhen})
			if $$flagsRef & FLDFLAG_CONDITIONAL_READONLY;

		$_->updateFlag(FLDFLAG_INVISIBLE, $dlgFlags & $_->{invisibleWhen})
			if $$flagsRef & FLDFLAG_CONDITIONAL_INVISIBLE;
	}

	if(my $method = $self->can("makeStateChanges_$command"))
	{
		&{$method}($self, $page, $command, $dlgFlags);
	}
}

sub addPreHtml
{
	my XAP::Component::Dialog $self = shift;
	push(@{$self->{preHtml}}, @_);
}

sub addHeader
{
	my XAP::Component::Dialog $self = shift;

	foreach (@_)
	{
		# only add things to the dialog that are objects inherited from XAP::Component::Dialog::HeadFootItem
		next if ! ref $_ || ! $_->isa('XAP::Component::Dialog::HeadFootItem');
		push(@{$self->{dlgHeader}}, $_);
	}
}

sub addFooter
{
	my XAP::Component::Dialog $self = shift;

	foreach (@_)
	{
		# only add things to the dialog that are objects inherited from XAP::Component::Dialog::HeadFootItem
		next if ! ref $_ || ! $_->isa('XAP::Component::Dialog::HeadFootItem');
		push(@{$self->{dlgFooter}}, $_);
	}
}

sub addContent
{
	my XAP::Component::Dialog $self = shift;
	my $contentList = $self->{childCompList};

	my $cookieNamePrefix = ref $self;
	my XAP::Component::Dialog::ContentItem $field = undef;
	foreach $field (@_)
	{
		# only add things to the dialog that are objects inherited from DialogItem
		next unless ref $field && $field->isa('XAP::Component::Dialog::ContentItem');
		next unless $field->onBeforeAdd($self);

		$field->{cookieName} = "$cookieNamePrefix.$field->{name}" if $field->flagIsSet(FLDFLAG_PERSIST);
		push(@$contentList, $field);
		$self->{fieldMap}->{$field->{name}} = scalar(@{$self->{childCompList}}) - 1;

		my $last = scalar(@$contentList);
		push(@{$self->{priKeys}}, ($last-1)) if $field->flagIsSet(FLDFLAG_PRIMARYKEY);

		$field->onAfterAdd($self);
	}
}

sub customValidate
{
	#my ($self, $page) = @_;
	# custom validation not necessary normally, so just return TRUE for valid
	return 1;
}

sub isValid
{
	my XAP::Component::Dialog $self = shift;
	my ($page, $activeExecMode) = @_;

	return $self->populateValues($page) if defined($activeExecMode) && $activeExecMode eq 'I';
	return 1 if scalar(@{$self->{childCompList}}) == 0;

	my $isValid = undef;
	my $cachePropName = PAGEPROPNAME_VALID . $self->id();
	if(my $cacheValue = $page->property($cachePropName))
	{
		$isValid = $cacheValue eq 'yes' ? 1 : 0;
	}
	else
	{
		$self->customValidate($page);
		$isValid = $self->SUPER::isValid($page);
		$page->property($cachePropName, $isValid ? 'yes' : 'no');
	}

	return $isValid;
}

sub activeExecMode
{
	my XAP::Component::Dialog $self = shift;
	my ($page) = @_;

	my $execMode = 'I';
	if(my $givenMode = $page->field(FIELDNAME_EXECMODE))
	{
		$execMode =
			$givenMode eq 'V' ?
				($self->isValid($page) ? 'E' : 'V') :
				$givenMode;
	}
	return $execMode;
}

sub nextExecMode
{
	my XAP::Component::Dialog $self = shift;
	my ($page, $activeExecMode) = @_;

	my $isValid = 1;
	my $execMode = $activeExecMode;
	if($execMode eq 'I')
	{
		$execMode = $self->needsValidation($page) ? 'V' : 'E';
	}
	elsif($execMode eq 'V')
	{
		$isValid = $self->isValid($page);
		$execMode = $isValid ? 'E' : 'V';
	}
	elsif($execMode eq 'E')
	{
		$execMode = 'I';
	}
	$execMode;
}

sub getFlags
{
	my XAP::Component::Dialog $self = shift;
	my ($command, $activeExecMode) = @_;

	my $flags = 0;

	$flags |= DLGFLAG_DATAENTRY_INITIAL if $activeExecMode eq 'I';
	$flags |= DLGFLAG_DATAENTRY if $activeExecMode eq 'I' || $activeExecMode eq 'V';
	$flags |= DLGFLAG_EXECUTE if $activeExecMode eq 'E';

	$flags |= DLGFLAG_ADD if $command eq 'add';
	$flags |= DLGFLAG_UPDATE if $command eq 'update';
	$flags |= DLGFLAG_REMOVE if $command eq 'remove';
	$flags |= DLGFLAG_UPDORREMOVE if $command eq 'update' || $command eq 'remove';
	$flags |= DLGFLAG_PRIKEYREADONLY if $flags & DLGFLAG_UPDORREMOVE;
	$flags |= DLGFLAG_READONLY if $command eq 'remove';

	$flags |= DLGFLAG_ADD_DATAENTRY_INITIAL
		if ($flags & DLGFLAG_DATAENTRY_INITIAL) && ($flags & DLGFLAG_ADD);
	$flags |= DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL
		if ($flags & DLGFLAG_DATAENTRY_INITIAL) && ($flags & DLGFLAG_UPDORREMOVE);

	return $flags;
}

sub populateData
{
	my XAP::Component::Dialog $self = shift;
	my ($page, $command, $activeExecMode, $flags) = @_;

	if(my $method = $self->can("populateData_$command"))
	{
		return &{$method}($self, $page, $command, $activeExecMode, $flags);
	}

	if(my $populateCmds = $self->{populateCmds})
	{
		$populateCmds->execute($page, 0, dialog => $self, dialogCmd => $command, dialogFlags => $flags);
	}
}

sub execute
{
	my XAP::Component::Dialog $self = shift;
	my ($page, $command, $flags) = @_;

	$page->property(PAGEPROPNAME_INEXEC . '_' . $self->id(), 1);

	if(my $method = $self->can("execute_$command"))
	{
		return &{$method}($self, $page, $command, $flags);
	}

	if(my $execCmds = $self->{execCmds})
	{
		my $html = $execCmds->execute($page, 0, dialog => $self, dialogCmd => $command, dialogFlags => $flags);
		return $html if $html;
	}

	return $self->getBodyHtmlStatic($page);
}

sub handlePostExecute
{
	my XAP::Component::Dialog $self = shift;
	my ($page, $command, $flags, $specificRedirect) = @_;
	if(my $activityLog = $self->{activityLog})
	{
		$page->recordActivity(
					exists $activityLog->{type} ? $activityLog->{type} : ACTIVITY_TYPE_RECORD,
					exists $activityLog->{action} ? $activityLog->{action} : $DIALOG_COMMAND_ACTIVITY_MAP{$command},
					$activityLog->{scope}, $activityLog->{key},
					exists $activityLog->{level} ? $activityLog->{level} : ACTIVITY_LEVEL_HIGH,
					$activityLog->{data},
					$page->session('user_id'),
				);
	}
	if($page->isPopup())
	{
		#unshift(@{$page->{page_head}}, qq{<script>opener.location.reload(); window.close()</script>});
		unshift(@{$page->{page_head}},
			qq{
					<script>
						if(eval("opener.inErrorMode"))
						{
							opener.focus(); window.close()
						}
						else
						{
							opener.location.reload(); window.close()
						}
					</script>
			}
		);
		return 1;
	}
	if($specificRedirect)
	{
		$page->redirect($specificRedirect);
		return 1;
	}
	else
	{
		unless($flags & DLGFLAG_IGNOREREDIRECT)
		{
			if(my $url = ($page->param(XAP::Component::Dialog::Buttons::NEXTACTION_PARAMNAME) || $self->getReferer($page)))
			{
				#$page->addError("Redirecting to $url");
				$page->redirect($url);
				return 1;
			}
		}
	}
	return 0;
}

sub getReferer
{
	my XAP::Component::Dialog $self = shift;
	my ($page) = @_;
	return $page->param('_dialogreturnurl') || $page->field(FIELDNAME_REFERER);
}

sub getStateData
{
	my XAP::Component::Dialog $self = shift;
	my ($page, $command) = @_;

	my $id = $self->id();
	my $inExec = $page->property(PAGEPROPNAME_INEXEC . '_' . $id);
	
	$page->property(PAGEPROPNAME_COMMAND . '_' . $id, $command);

	my $flags = $self->getFlags($command, 'UNKNOWN');
	$self->makeStateChanges($page, $command, $flags);

	my $activeExecMode = $inExec ? 'I' : $self->activeExecMode($page);
	$flags = $self->getFlags($command, $activeExecMode);

	$page->property(PAGEPROPNAME_FLAGS . '_' . $id, $flags);
	$page->property(PAGEPROPNAME_EXECMODE . '_' . $id, $activeExecMode);

	return ($flags, $activeExecMode);
}

sub getActiveCommand
{
	#
	# VALID ONLY INSIDE a call to getHtml
	#
	my XAP::Component::Dialog $self = shift;
	my ($page) = @_;
	return $page->property(PAGEPROPNAME_COMMAND . '_' . $self->id());
}

sub getActiveFlags
{
	#
	# VALID ONLY INSIDE a call to getHtml
	#
	my XAP::Component::Dialog $self = shift;
	my ($page) = @_;
	return $page->property(PAGEPROPNAME_FLAGS . '_' . $self->id());
}

#
# THIS METHOD NEEDS ALOT OF WORK --
#   1. first, it should create a "flattend" list of all fields
#   2. it should account for readonly and invisible fields
#   3. it should mark whether a field can be focused (i.e not radio button/checkbox, etc)
#
sub populateFieldInfoJS
{
	my XAP::Component::Dialog $self = shift;
	my ($fieldsList, $jsList, $recurseInfo) = @_;

	my $dialogName = $self->formName();
	my $fieldNum = 0;
	my $lastFieldNum = scalar(@$fieldsList)-1;
	my $prevField = defined $recurseInfo ? $recurseInfo->{prevf} : 'null';
	my $nextField = undef;
	foreach (@$fieldsList)
	{
		my $nf = $fieldsList->[$fieldNum+1];
		$nextField = $fieldNum == $lastFieldNum ? (defined $recurseInfo ? $recurseInfo->{nextf} : 'null') : "'_f_$nf->{name}'";

		if($_->isa('XAP::Component::Dialog::MultiField'))
		{
			my $newRecurseInfo = { prevf => $prevField, nextf => $nextField };
			$self->populateFieldInfoJS($_->{fields}, $jsList, $newRecurseInfo);
			$prevField = $newRecurseInfo->{lastf};
		}
		else
		{
			my $editable = $self->isEditable($_);
			my $caption = $_->{caption};
			$caption =~ s/\'//g;
			push(@$jsList, "dlg_$dialogName\_fields['_f_$_->{name}'] = { 'name' : '$_->{name}', 'type' : '$_->{type}', 'prevFld' : $prevField, 'nextFld' : $nextField, 'caption' : '$caption', 'options' : '$_->{options}', 'style' : '$_->{style}', 'editable' : '$editable' };");
			$prevField = "'_f_$_->{name}'";
		}
		$fieldNum++;
	}
	$recurseInfo->{lastf} = $prevField if defined $recurseInfo;
}

sub isEditable
{
	my XAP::Component::Dialog $self = shift;
	my ($field) = @_;
	my @skipFlags = [FLDFLAG_INVISIBLE, FLDFLAG_READONLY];
	my @skipTypes = ['separator'];
	my $item;

	foreach $item (@skipFlags)
	{
		return 0 if defined $field->{options} && $field->{options} & $item;
	}
	foreach $item (@skipTypes)
	{
		return 0 if defined $field->{type} && $field->{type} eq $item;
	}
	return 1;
}

sub getBodyHtml
{
	my XAP::Component::Dialog $self = shift;
	my ($page, $command, $callbacks, $hiddenParams) = @_;

	die "CGI \$page parameter required" unless $page;
	$command = $page->param('action') || 'add' unless $command;

	# the $callbacks array ref is comprised of
	#   0 : the function to call when populating data
	#   1 : the function to call when executing
	#   2 : array ref of "extraData" to be passed to callback

	my ($flags, $activeExecMode) = $self->getStateData($page, $command);
	if(defined $callbacks)
	{
		if($flags & DLGFLAG_EXECUTE)
		{
			if(my $onExecute = $callbacks->[CALLBACKITEM_EXECUTEFUNC])
			{
				return &{$onExecute}($page, $self, $command, $flags, $callbacks->[CALLBACKITEM_EXTRADATA]);
			}
			return $self->execute($page, $command, $flags);
		}
		if(my $onPopulateData = $callbacks->[CALLBACKITEM_POPULATEDATAFUNC])
		{
			&{$onPopulateData}($page, $self, $command, $activeExecMode, $flags, $callbacks->[CALLBACKITEM_EXTRADATA]);
		}
	}
	else
	{
		return $self->execute($page, $command, $flags) if $flags & DLGFLAG_EXECUTE;
		$self->populateData($page, $command, $activeExecMode, $flags);
	}

	my $html = $flags & DLGFLAG_DATAENTRY ? ($page->selfHiddenFormFields() . ($hiddenParams || '')) : '';
	my $isValid = $self->isValid($page, $activeExecMode);
	my $newExecMode = $self->nextExecMode($page, $activeExecMode);
	my $heading = $self->{heading};

	# do some simple variable replacements (just what's available here)
	my $Command = "\u$command";
	$heading =~ s/(\$\w+)/$1/eego;

	my $errorsHtml = '';
	#unless($isValid)
	#{
	#	$heading = "$heading (<font color=white>ERROR</font>)";
	#	my $errorMsgs = join("<li>", $page->validationMessages());
	#	$errorsHtml = qq{
	#	<font $self->{bodyFontAttrs}>
	#	<!---<font color=red size=+1><b>There was some incorrect data entered.</b></font><br>--->
	#	<font color=red size=+1><b>Please correct the following problems</b></font>:
	#	<ul>
	#		<li>$errorMsgs
	#		<SCRIPT>var inErrorMode = 1;</SCRIPT>
	#	</ul>
	#	</font>
	#	};
	#}

	my $dialogName = $self->formName();
	my $cols = $self->{columns};
	my @fieldsInfoJS = ("dialogFields['$dialogName'] = {};", "var dlg_$dialogName\_fields = dialogFields['$dialogName'];");
	$self->populateFieldInfoJS($self->{childCompList}, \@fieldsInfoJS);
	my $contentList = $self->{childCompList};
	foreach (@$contentList)
	{
		$cols++ if exists $_->{colBreak} && $_->{colBreak};
	}
	$self->{columns} = $cols;
	$self->{tableCols} = $self->{columns} == 1 ? 4 : $self->{columns};
	my $fieldsInfoJS = join("\n", @fieldsInfoJS);

	foreach (@{$self->{dlgHeader}})
	{
		$html .= $_->getHtml($page, $self, $command, $flags);
	}

	if($self->{columns} > 1)
	{
		my $rowsPerCol = int(scalar(@{$self->{childCompList}})/$self->{columns})+1;
		my @colData = ();

		my $col = 0;
		my $row = 0;
		foreach (@{$self->{childCompList}})
		{
			$colData[$col] .= $_->getHtml($page, $self, $command, $flags);
			$row++;

			if($row >= $rowsPerCol || (exists $_->{colBreak} && $_->{colBreak}))
			{
				$col++;
				$row = 0;
			}
		}
		my $columns = '';
		foreach (@colData)
		{
			$columns .= "<td><table cellspacing=0 cellpadding=2 border=0>$_</table></td>";
		}
		$html .= "<tr valign=top>$columns</tr>\n";
	}
	else
	{
		foreach (@{$self->{childCompList}})
		{
			next if ($_->{flags} & FLDFLAG_INVISIBLE);
			$html .= $_->getHtml($page, $self, $command, $flags);
		}
	}

	foreach (@{$self->{dlgFooter}})
	{
		$html .= $_->getHtml($page, $self, $command, $flags);
	}

	my $titleRule = '';
	if($self->{ruleBelowHeading})
	{
		$titleRule = "<hr size=1 color=navy width=100%>";
	}

	if($errorsHtml)
	{
		$errorsHtml = "
		<tr>
		<td>
		$errorsHtml
		<hr size=1 width=100% noshade>
		</td>
		</tr>
		";
	}

	# UserId @{[ $page->session('user_id') ]}

	my @dlgHouskeepingHiddens = ();
	if($flags & DLGFLAG_DATAENTRY_INITIAL)
	{
		my $refererFieldName = $page->fieldPName(FIELDNAME_REFERER) || '';
		my $actualReferer = $page->referer() || '';
		push(@dlgHouskeepingHiddens, "<input type='hidden' name='$refererFieldName' value='$actualReferer'>");
	}
	my $execModeFieldName = $page->fieldPName(FIELDNAME_EXECMODE);
	push(@dlgHouskeepingHiddens, "<input type='hidden' name='$execModeFieldName' value='$newExecMode'>");

	my $formAction = $page->getActiveURL();
	my $adjFlags = $self->{adjacentFlags};
	my $adjContent = $self->{adjacentContent}; 
	return qq{
	@{[ $adjFlags & ADJFLAG_HAVETOP ? ($adjContent->[ADJACENTLOCATION_TOP]->getBodyHtml($page, 0)) : '' ]}
	@{[ $adjFlags & ADJFLAG_HAVEHORIZ ? '<TABLE><TR VALIGN=TOP><TD>' : '' ]}
	@{[ $adjFlags & ADJFLAG_HAVELEFT ? ($adjContent->[ADJACENTLOCATION_LEFT]->getBodyHtml($page, 0) . '</TD><TD>') : '' ]}
	<table border=0 bgcolor=@{[ $isValid ? $self->{headColor} : $self->{headErrorColor} ]} cellspacing=2 cellpadding=0>
	<tr><td>
	<table border=0 bgcolor=$self->{bgColor} cellspacing=0 cellpadding=4>
		<tr align=center bgcolor=@{[ $isValid ? $self->{headColor} : $self->{headErrorColor} ]}>
			<td @{[ $isValid ? "background='/resources/design/verttab.gif'" : '' ]}>
				<font $self->{headFontAttrs}>&nbsp;<b>$heading</b><!--$activeExecMode : $newExecMode : $isValid)-->&nbsp;</font>
				$titleRule
			</td>
		</tr>

		$errorsHtml
		<tr>
		<td>
		@{$self->{preHtml}}
		<table border=0 bgcolor=$self->{bgColor} cellspacing=0 cellpadding=$self->{cellPadding} width=100%>
		<SCRIPT>
		$fieldsInfoJS
		</SCRIPT>
		<form name="$self->{formName}" action="$formAction" $self->{formAttrs} method="post" onSubmit="return validateOnSubmit(this)">
			@dlgHouskeepingHiddens
			$html
		</form>
		</table>
		</td>
		</tr>
	</table>
	</tr></td>
	</table>
	@{[ $adjFlags & ADJFLAG_HAVERIGHT ? ('</TD><TD>' . $adjContent->[ADJACENTLOCATION_RIGHT]->getBodyHtml($page, 0)) : '' ]}
	@{[ $adjFlags & ADJFLAG_HAVEHORIZ ? '</TD></TR></TABLE>' : '' ]}
	@{[ $adjFlags & ADJFLAG_HAVEBOTTOM ? ($adjContent->[ADJACENTLOCATION_BOTTOM]->getBodyHtml($page, 0)) : '' ]}
	<br>
	};
}

sub getBodyHtmlStatic
{
	my XAP::Component::Dialog $self = shift;
	my ($page) = @_;

	my $contentList = $self->{childCompList};
	my $cols = $self->{columns};
	my $html = '';
	my $flags = 0;
	my $command = '';

	foreach (@$contentList)
	{
		$cols++ if exists $_->{colBreak} && $_->{colBreak};
	}
	$self->{columns} = $cols;
	$self->{tableCols} = $self->{columns} == 1 ? 4 : $self->{columns};

	foreach (@{$self->{dlgHeader}})
	{
		$_->{flags} |= FLDFLAG_READONLY;
		$html .= $_->getHtml($page, $self, $command, $flags);
	}

	if($self->{columns} > 1)
	{
		my $rowsPerCol = int(scalar(@{$self->{childCompList}})/$self->{columns})+1;
		my @colData = ();

		my $col = 0;
		my $row = 0;
		foreach (@{$self->{childCompList}})
		{
			$_->setFlag(FLDFLAG_READONLY);
			$colData[$col] .= $_->getHtml($page, $self, $command, $flags);
			$row++;

			if($row >= $rowsPerCol || (exists $_->{colBreak} && $_->{colBreak}))
			{
				$col++;
				$row = 0;
			}
		}
		my $columns = '';
		foreach (@colData)
		{
			$columns .= "<td><table cellspacing=0 cellpadding=2 border=0>$_</table></td>";
		}
		$html .= "<tr valign=top>$columns</tr>\n";
	}
	else
	{
		foreach (@{$self->{childCompList}})
		{
			next if ($_->{flags} & FLDFLAG_INVISIBLE);
			$_->setFlag(FLDFLAG_READONLY);
			$html .= $_->getHtml($page, $self, $command, $flags);
		}
	}

	#foreach (@{$self->{dlgFooter}})
	#{
	#	$_->{flags} |= FLDFLAG_READONLY;
	#	$html .= $_->getHtml($page, $self, $command, $flags);
	#}

	return qq{
	<table border=0 cellspacing=1 cellpadding=2>
		$html
	</table>
	};
}

1;

