##############################################################################
package CGI::Dialog::ContentItem;
##############################################################################

use strict;
use CGI::Validator::Field;

# See Bug 532
use App::Page;

use vars qw(@ISA);

@ISA = qw(CGI::Validator::Field);

sub new
{
	my $self = CGI::Validator::Field::new(@_);

	# variables that might be passed in
	$self->{priKey} = 0 unless $self->{priKey};
	$self->{defaultValue} = $self->{value} if exists $self->{value};
	$self->{hint} = '' unless $self->{hint};
	$self->{hints} = '' unless $self->{hints};
	$self->{findPopup} = undef unless $self->{findPopup};
	$self->{findPopupAppendValue} = '' unless $self->{findPopupAppendValue};
	$self->{addPopup} = undef unless $self->{addPopup};
	$self->{popup} =
		{
			url => '',
			name => 'popup',
			imgsrc => '/resources/icons/magnifying-glass-sm.gif',
			features => 'width=450,height=450,scrollbars,resizable',
			appendValue => '',
		} unless $self->{popup};

	# any HTML to put in before and after a field
	$self->{preHtml} = '' unless $self->{preHtml};
	$self->{postHtml} = '' unless $self->{postHtml};

	# internal housekeeping variables
	$self->{_spacerWidth} = 0;

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
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

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
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $dialogName = $dialog->formName();
	my $fieldName = $page->fieldPName($self->{name});

	if(my $arl = $self->{findPopup})
	{
		my $controlField = 'null';
		$controlField = "document.$dialogName.$self->{findPopupControlField}" if $self->{findPopupControlField};

		my $secondaryFindField = 'null';
		$secondaryFindField = "document.$dialogName.$self->{secondaryFindField}" if $self->{secondaryFindField};

		my $imgId = "_find_img_" . $self->{name};
		my $linkId = "_find_link_" . $self->{name};

		return qq{
			<a id="$linkId" href="javascript:doFindLookup(document.$dialogName, document.$dialogName.$fieldName, '$arl', '$self->{findPopupAppendValue}', false, null, $controlField, $secondaryFindField);"><img id="$imgId" src='$self->{popup}->{imgsrc}' border=0></a>
		};
	}
	return '';
}

sub addPopup_as_html
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $dialogName = $dialog->formName();
	my $fieldName = $page->fieldPName($self->{name});

	if(my $arl = $self->{addPopup})
	{
		my $controlField = 'null';
		$controlField = $self->{addPopupControlField} if $self->{addPopupControlField};

		my $imgId = "_add_img_" . $self->{name};
		my $linkId = "_add_link_" . $self->{name};

		#the <SCRIPT> tag was put in to make sure parent dialog does not refresh
		return qq{
			<SCRIPT>var bypassRefresh = 1;</SCRIPT>
			<a id="$linkId" href="javascript:doActionPopup('$arl', false, null, ['$controlField'], ['$fieldName']);"><img id="$imgId" src='/resources/icons/action-edit-add.gif' border=0></a>
		};
	}
	return '';
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags, $mainData) = @_;

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
		$bgColorAttr = qq{bgcolor="$dialog->{errorBgColor}"};
		$errorMsgsHtml = "<br><font $dialog->{bodyFontErrorAttrs}>" . join("<br>", @messages) . "</font>";
	}

	delete $self->{postHtml} if ($self->{flags} & FLDFLAG_READONLY);
	
	if($self->{flags} & FLDFLAG_CUSTOMDRAW)
	{
		my $popupHtml = $self->popup_as_html($page, $dialog, $command, $dlgFlags) || $self->findPopup_as_html($page, $dialog, $command, $dlgFlags) if ! $readOnly;
		$html = "$self->{preHtml}$mainData $popupHtml &nbsp; &nbsp; $self->{postHtml}";
	}
	else
	{
		my $caption = $self->{caption};
		$caption = "<b>$caption</b>" if $flags & FLDFLAG_REQUIRED;
		$caption = "<NOBR>$caption</NOBR>" if $flags & FLDFLAG_NOBRCAPTION;
		#$self->{preHtml} = $self->flagsAsStr(1);

		# do some basic variable replacements
		my $Command = "\u$command";
		$Command =~ s/_(.)/" \u$1"/ge;
		$caption =~ s/(\$\w+)/$1/eego;

		my $popupHtml = $self->popup_as_html($page, $dialog, $command, $dlgFlags) || $self->findPopup_as_html($page, $dialog, $command, $dlgFlags) . $self->addPopup_as_html($page, $dialog, $command, $dlgFlags) if ! $readOnly;
		#$popupHtml .= $self->addPopup_as_html($page, $dialog, $command, $dlgFlags) if ! $readOnly;
		my $hints = ($self->{hints} && ! $readOnly) ? "<br><font $dialog->{hintsFontAttrs}>$self->{hints}</font>" : '';
		my $id = "_id_" . $self->{name};
		$html = qq{<tr valign="top" id="$id" $bgColorAttr><td width=$self->{_spacerWidth}>
			$spacerHtml
		</td><td align=$dialog->{captionAlign}>
			<font $dialog->{bodyFontAttrs}>
				$caption
			</font>
		</td><td>
			<font $dialog->{bodyFontAttrs}>
				$self->{preHtml}$mainData$popupHtml &nbsp; &nbsp; $self->{postHtml}
				$errorMsgsHtml
				$hints
			</font>
		</td><td width=$self->{_spacerWidth}>
		&nbsp;
		</td></tr>};
	}

	return $html;
}

##############################################################################
package CGI::Dialog::Field;
##############################################################################

use strict;
use CGI::Validator::Field;
use Date::Manip;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::ContentItem);

use vars qw(%FIELD_FLAGS_ATTRMAP);

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
	'inlineCaption' => FLDFLAG_INLINECAPTION,
	);

# static method
sub XAP_initialize
{
	my ($xap, $tagAttrs, $typeDefns) = @_;

	$xap->addTagHandler('field', \&XAP_tag_handler, 'dialog');
}

sub XAP_createField
{
	my ($xap, $fieldClass, $tag, $tagContent) = @_;
	my $attrs = $tagContent->[0];

	return unless $xap->allStructMembersAvail($attrs, "attribute '%s' required in '$tag' tag", 'name');

	# make a copy of the attrs because we'll be changing them
	my %fieldAttrs = %$attrs;
	if(my $flagNames = $attrs->{flags})
	{
		my $flags = CGI::Validator::Field::FLDFLAGS_DEFAULT;
		foreach (split(/,/, $flagNames))
		{
			if(exists $FIELD_FLAGS_ATTRMAP{$_})
			{
				$flags |= $FIELD_FLAGS_ATTRMAP{$_};
			}
			else
			{
				$xap->logError("unknown field flag '$_' in $xap->{_parser_activeDialogId} field $attrs->{name}");
			}
		}
		$fieldAttrs{flags} = $flags;
	}

	foreach my $dlgCondAttr ('readOnlyWhen', 'invisibleWhen')
	{
		if(my $flagNames = $attrs->{$dlgCondAttr})
		{
			my $flags = 0;
			foreach (split(/,/, $flagNames))
			{
				if(exists $CGI::Dialog::DLG_FLAGS_ATTRMAP{$_})
				{
					$flags |= $CGI::Dialog::DLG_FLAGS_ATTRMAP{$_};
				}
				else
				{
					$xap->logError("unknown dialog flag '$_' in $xap->{_parser_activeDialogId} field $attrs->{name} '$dlgCondAttr'");
				}
			}
			$fieldAttrs{$dlgCondAttr} = $flags;
		}
	}

	return $fieldClass->new(%fieldAttrs);
}

sub XAP_tag_handler
{
	my ($xap, $tag, $tagContent) = @_;
	CGI::Dialog::XAP_addDialogField($xap, $tag, $tagContent, XAP_createField($xap, __PACKAGE__, $tag, $tagContent));
}

sub new
{
	my $type = shift;
	my %params = @_;

	$params{type} = 'text' if ! exists $params{type};
	die q{lookupListId not allowed anymore --> use 'lookup' or 'foreignKey'} if exists $params{lookupListId};

	if(my $fkeyTable = $params{enum} || $params{lookup} || $params{fKeyTable})
	{
		$params{type} = 'select';
		if(exists $params{enum})
		{
			$params{fKeyTable} = $fkeyTable;
			$params{fKeySelCols} = 'id,caption';
			$params{fKeyValueCol} = 0;   # the ID column
			$params{fKeyDisplayCol} = 1; # the Caption column
		}
		elsif(exists $params{lookup})
		{
			$params{fKeyTable} = $fkeyTable;
			$params{fKeySelCols} = 'id,caption,abbrev,result';
			$params{fKeyValueCol} = -1;  # figure out value based on result
			$params{fKeyDisplayCol} = 1; # the Caption column
		}
		$params{size} = 1 unless exists $params{size};
		$params{style} = 'combo' unless exists $params{style};
		$params{choiceReadOnlyDelim} = ', ' unless exists $params{choiceReadOnlyDelim};
	}
	elsif($params{fKeyStmt})
	{
		die 'fkeyStmtMgr required if supplying fKeyStmt' unless $params{fKeyStmtMgr};

		$params{type} = 'select';
		$params{size} = 1 unless exists $params{size};
		$params{style} = 'combo' unless exists $params{style};
		$params{choiceReadOnlyDelim} = ', ' unless exists $params{choiceReadOnlyDelim};
	}
	elsif($params{type} eq 'select')
	{
		$params{selOptions} = 'No Options' unless exists $params{selOptions};
		$params{choiceDelim} = ';' unless exists $params{choiceDelim};
		$params{valueDelim} = ':' unless exists $params{valueDelim};
		$params{choiceReadOnlyDelim} = ', ' unless exists $params{choiceReadOnlyDelim};
		$params{size} = 1 unless exists $params{size};
		$params{style} = 'combo' unless exists $params{style};
	}

	if($params{type} eq 'memo')
	{
		$params{cols} = 30 if ! exists $params{cols};
		$params{rows} = 3 if ! exists $params{rows};
		$params{wrap} = 'soft' if ! exists $params{wrap};
	}

	$params{maxLength} = 1024 if ! exists $params{maxLength};
	$params{readOnly} = 0 if ! exists $params{readOnly};

	return CGI::Dialog::ContentItem::new($type, %params);
}

sub hidden_as_html
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $fieldName = $page->fieldPName($self->{name});
	return qq{<input type="hidden" name="$fieldName" value="@{[ $page->field($self->{name}) ]}">};
}

sub separator_as_html
{
	return "<tr><td colspan=4><hr size=1></td></tr>";
}

sub memo_as_html
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $fieldName = $page->fieldPName($self->{name});
	my $value = $page->field($self->{name});
	my $readOnly = ($self->{flags} & FLDFLAG_READONLY);
	my $required = ($self->{flags} & FLDFLAG_REQUIRED) ? 'class="required"' : "";
	
	if ($readOnly)
	{
		$value =~ s/\n/<br>/g;
		my $width = $self->{cols} * 6;
		$value = '<div style="width: ' . $width . 'px; border: 2px; border-style: outset; padding: 5px;">' . $value . '</div>';
	}
	else
	{
		$value = "<textarea name='$fieldName' cols=$self->{cols} rows=$self->{rows} wrap='$self->{wrap}' $required>$value</textarea>";
	}
	
	return $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $value);
}

sub bool_as_html
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
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
				<td width=$self->{_spacerWidth}>&nbsp;</td>
				<td align=right>
					<input type='checkbox' name='$fieldName' id='$fieldName' align=right $checked value=1>
				</td>
				<td>$self->{preHtml}<label for='$fieldName'>$self->{caption}</label>$self->{postHtml}</td>
				<td width=$self->{_spacerWidth}>&nbsp;</td>
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
					<td width=$self->{_spacerWidth} colspan=2>&nbsp;</td>
					<td>$self->{preHtml}<input type='checkbox' name='$fieldName' id='$fieldName' align=right value=1 $checked> <label for='$fieldName'>$self->{caption}</label>$self->{postHtml}</td>
					<td width=$self->{_spacerWidth}>&nbsp;</td>
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
	my ($self, $page, $choiceStruct) = @_;

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
	my ($self, $page) = @_;

	#$page->addDebugStmt($self->{fKeyStmtMgr});
	#$page->addDebugStmt($self->{fKeyStmt});
	#$page->addDebugStmt($self->{fKeyStmtBindPageParams});

	my $choices = [];
	my $fkeyValueCol = $self->{fKeyValueCol} || 0;
	my $fKeyDisplayCol = exists $self->{fKeyDisplayCol} ? $self->{fKeyDisplayCol} : 1;
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
	my ($self, $page) = @_;

	my $choices = [];
	my $fkeyValueCol = $self->{fKeyValueCol} || 0;
	my $fKeyDisplayCol = exists $self->{fKeyDisplayCol} ? $self->{fKeyDisplayCol} : $fkeyValueCol;

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
	my ($self, $page) = @_;

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
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $fieldName = $page->fieldPName($self->{name});
	my $value = $page->field($self->{name});
	my $readOnly = ($self->{flags} & FLDFLAG_READONLY);
	my $html = '';
	my $i = 1;

	my $choices = exists $self->{fKeyStmt} ? $self->readChoicesStmt($page) : ($self->{fKeyTable} ? $self->readChoices($page) : $self->parseChoices($page));
	$self->{size} = scalar(@$choices) if $self->{size} == 0;

	my $JS = '';
	foreach (keys %$self)
	{
		/^(.*?)JS$/ and do {$JS .= lc($1) . '="' . $self->{$_} . '" '};
	}

	if($readOnly)
	{
		my @captions = ();
		foreach (@{$choices})
		{
			next if ! $_->[0];
			$html .= qq{<input type='hidden' name='$fieldName' value="$value">};
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
				$inputs .= "<nobr><input type='checkbox' name='$fieldName' id='$fieldName$i' value='$_->[2]' $selected> <label for='$fieldName$i'>$_->[1]</label>&nbsp;&nbsp;</nobr> ";
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
			my $width = $self->{width} || '175 pt';
			$width .= ' pt' if $width =~ /^\d+$/;
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
						<SELECT ondblclick="MoveSelectItems('Dialog', '$self->{name}_From', '_f_$self->{name}', $sorted)" NAME=$self->{name}_From SIZE=$self->{size} MULTIPLE STYLE="width: $width">
						$selectOptions
						</SELECT>
					</TD>
					<TD ALIGN=center VALIGN=middle>
						&nbsp;<INPUT TYPE=button NAME="$self->{name}_addBtn" onClick="MoveSelectItems('Dialog', '$self->{name}_From', '_f_$self->{name}', $sorted)" VALUE=" > ">&nbsp;<BR CLEAR=both>
						&nbsp;<INPUT TYPE=button NAME="$self->{name}_removeBtn" onClick="MoveSelectItems('Dialog', '_f_$self->{name}', '$self->{name}_From', $sorted)" VALUE=" < ">&nbsp;
					</TD>
					<TD ALIGN=left VALIGN=top>
						<SELECT ondblclick="MoveSelectItems('Dialog', '_f_$self->{name}', '$self->{name}_From', $sorted)" NAME=_f_$self->{name} SIZE=$self->{size} MULTIPLE STYLE="width: $width">
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
			$options .= "<option value=''></option>\n" if ($self->{flags} & FLDFLAG_PREPENDBLANK);
			foreach (@{$choices})
			{
				my $selected = $_->[0] ? 'selected' : '';
				$options .= qq{<option value="$_->[2]" $selected>$_->[1]</option>\n};
			}
			my $caption = '';
			if ($self->{flags} & FLDFLAG_INLINECAPTION)
			{
				$caption = $self->{caption};
				$caption = "<b>$caption</b> " if $self->{flags} & FLDFLAG_REQUIRED;
				$caption = "<NOBR>$caption</NOBR> " if $self->{flags} & FLDFLAG_NOBRCAPTION;
				#$caption = '<span style="">' . $caption . '&nbsp;</span>';
			}
			
			$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, qq{$caption<select name="$fieldName" size="$self->{size}" $JS $multiple>\n$options</select>\n});
		}
	}

	return $html;
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
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

		my $caption = '';
		if ($self->{flags} & FLDFLAG_INLINECAPTION)
		{
			$caption = $self->{caption};
			$caption = "<b>$caption</b> " if $self->{flags} & FLDFLAG_REQUIRED;
			$caption = "<NOBR>$caption</NOBR> " if $self->{flags} & FLDFLAG_NOBRCAPTION;
		}


		if(! $readOnly)
		{
			my $javaScript = $self->generateJavaScript($page);
			my $onFocus = $self->{hint} ? " onFocus='clearField(this)'" : '';
			$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, qq{$caption<input name="$fieldName" type=$self->{type} value="$value" size=$self->{size} maxlength=$self->{maxLength} $javaScript$onFocus $required>});
		}
		else
		{
			$html = qq{<input type='hidden' name='$fieldName' value="$value">};
			$html .= $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $value);
		}
	}

	return $html;
}

##############################################################################
package CGI::Dialog::Field::TableColumn;
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
use CGI::Validator::Field;
use Date::Manip;
use vars qw(@ISA);
use Schema::Utilities;

@ISA = qw(CGI::Dialog::Field);

sub XAP_initialize
{
	my ($xap, $tagAttrs, $typeDefns) = @_;

	$xap->addTagHandler('field-tablecolumn', \&XAP_tag_handler, 'dialog');
}

sub XAP_tag_handler
{
	my ($xap, $tag, $tagContent) = @_;
	CGI::Dialog::XAP_addDialogField($xap, $tag, $tagContent, CGI::Dialog::Field::XAP_createField($xap, __PACKAGE__, $tag, $tagContent));
}

sub new
{
	my ($type, %params) = @_;

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
		$params{priKey} = 1 if $column->isPrimaryKey();
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

	delete $params{schema}; # don't hang on to this value
	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	my ($self, $page, $validator) = @_;

	# if we've been deemed as needsValidation already, leave
	return 1 if $self->SUPER::needsValidation();

	# if the column is unique, then it requires validation
	return 1 if $self->{tableColumn}->isUnique();
	return 0;
}

sub isValid
{
	my ($self, $page, $validator) = @_;

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
package CGI::Dialog::MultiField;
##############################################################################

use strict;
use CGI::Validator::Field;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::ContentItem);

# static method
sub XAP_initialize
{
	my ($xap, $tagAttrs, $typeDefns) = @_;

	$xap->addTagHandler('field-group', \&XAP_tag_handler, 'dialog');
}

sub XAP_tag_handler
{
	my ($xap, $tag, $content) = @_;
	my $attrs = $content->[0];

	$xap->{_parser_activeFieldGrp} = new CGI::Dialog::MultiField(%$attrs);
	$xap->{_parser_activeDialog}->addContent($xap->{_parser_activeFieldGrp});
	CGI::Dialog::XAP_handleElementDialogContent($xap, $content);
	$xap->{_parser_activeFieldGrp} = undef;
}

sub new
{
	# just override for future growth
	#
	# expect ONE NEW PARAMTER: fields => [x, y, z]
	#
	return CGI::Dialog::ContentItem::new(@_);
}

sub updateFlag
{
	my ($self, $flag, $value) = @_;
	foreach (@{$self->{fields}})
	{
		# make sure validation is really need for sub-fields
		$_->updateFlag($flag, $value);
	}
	$self->SUPER::updateFlag($flag, $value);
}

sub setFlag
{
	my ($self, $flag) = @_;
	foreach (@{$self->{fields}})
	{
		# make sure validation is really need for sub-fields
		$_->setFlag($flag);
	}
	$self->SUPER::setFlag($flag);
}

sub clearFlag
{
	my ($self, $flag) = @_;
	foreach (@{$self->{fields}})
	{
		# make sure validation is really need for sub-fields
		$_->clearFlag($flag);
	}
	$self->SUPER::clearFlag($flag);
}

sub needsValidation
{
	my ($self, $page, $validator) = @_;

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
	my ($self, $page, $validator) = @_;

	foreach (@{$self->{fields}})
	{
		$_->populateValue($page, $validator);
	}

	return 1;
}

sub isValid
{
	my ($self, $page, $validator) = @_;

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
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

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
	$Command =~ s/_(.)/" \u$1"/ge;
	$caption =~ s/(\$\w+)/$1/eego;

	my $popupHtml = $self->popup_as_html($page, $dialog, $command, $dlgFlags) || $self->findPopup_as_html($page, $dialog, $command, $dlgFlags) if ! $readOnly;
	my $hints = ($self->{hints} && ! $readOnly) ? "<br><font $dialog->{hintsFontAttrs}>$self->{hints}</font>" : '';
	my $id = "_id_" . $self->{name};
	return qq{<tr valign="top" id="$id" $bgColorAttr><td width="$self->{_spacerWidth}">
		$spacerHtml
	</td><td align="$dialog->{captionAlign}">
		<font $dialog->{bodyFontAttrs}>
			$caption
		</font>
	</td><td>
		<font $dialog->{bodyFontAttrs}>
			$self->{preHtml}
			$fieldsHtml $popupHtml $self->{postHtml}
			$errorMsgsHtml
			$hints
		</font>
	</td><td width="$self->{_spacerWidth}">
		&nbsp;
	</td></tr>};
}



##############################################################################
package CGI::Dialog::DataGrid;
##############################################################################

use strict;
use CGI::Validator::Field;
use base qw(CGI::Dialog::MultiField);

sub new
{
	my $class = shift;
	my %params = @_;
	my $rowFields = $params{rowFields};
	$params{fields} = [];

	foreach my $row (1..$params{rows})
	{
		foreach my $col (1..@{$rowFields})
		{
			unless (ref($rowFields->[$col-1]) eq 'HASH')
			{
				die "'rowFields' parameter of a DataGrid must be an array of hashes";
			}
			# Get the template for the field
			my %field = %{$rowFields->[$col-1]};

			# Skip the field on this row if asked
			if (defined $field{_skipOnRows})
			{
				next if grep {$_ eq $row} @{$field{_skipOnRows}};
			}

			# Include the row number in the field name
			$field{name} .= '_' . $row;
			$field{_row} = $row unless defined $field{_row};
			$field{_col} = $col unless defined $field{_col};

			# Create a new field object
			no strict 'refs';
			my $fieldObj = &{"$field{_class}::new"}($field{_class}, %field);

			# Add it to the list
			push @{$params{fields}}, $fieldObj;
		}
	}
	return CGI::Dialog::MultiField::new($class, %params);
}


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	my $readOnly = ($self->{flags} & FLDFLAG_READONLY);

	my $name = $self->{name};
	my $completeHtml = '';
	my $fieldsHtml = '';
	my $errorMsgsHtml = '';
	my $bgColorAttr = '';
	my $spacerHtml = '&nbsp;';
	my $fields = $self->{fields};
	my $requiredCols = 0;
	my @messages = ();

	my $row = 0;
	my $col = 0;
	$fieldsHtml = qq{<table border="0" cellpadding="0" cellspacing="0"><tr id="_id_${name}_${row}">};

	# Make a first pass to get column headings
	my @headings = ();
	foreach(@$fields)
	{
		next unless $_->{caption};
		my $caption = "<font $dialog->{bodyFontAttrs}>$_->{caption}</font>";
		if ($caption && $_->{flags} & FLDFLAG_REQUIRED)
		{
			$caption = "<b>$caption</b>";
		}
		$headings[$_->{_col}] = $caption;
	}

	# Print the heading row
	foreach(0..$#headings)
	{
		my $caption = $headings[$_];
		$fieldsHtml .= qq{<td align="center" id="_id_${name}_${row}_${_}">$caption$spacerHtml$spacerHtml</td>};
	}

	# Print the data rows
	foreach(@$fields)
	{
		my @fldValMsgs = $page->validationMessages($_->{name});
		push(@messages, @fldValMsgs) if @fldValMsgs;
		$_->setFlag(FLDFLAG_CUSTOMDRAW);
		$requiredCols += $_->flagIsSet(FLDFLAG_REQUIRED);
		if ($_->{_row} != $row)
		{
			$row = $_->{_row};
			$fieldsHtml .= qq{</tr><tr id="_id_${name}_${row}">};
			$col = 0;
		}

		while($col < $_->{_col})
		{
			$fieldsHtml .= qq{<td id="_id_${name}_${row}_${col}">} . '</td>';
			$col++;
		}

		$fieldsHtml .= qq{<td id="_id_${name}_${row}_${col}" nowrap>} . $_->getHtml($page, $dialog, $command, $dlgFlags) . $spacerHtml . '</td>';
		$col++;
	}
	$fieldsHtml .= '</tr></table>';

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
	$Command =~ s/_(.)/" \u$1"/ge;
	$caption =~ s/(\$\w+)/$1/eego;

	my $popupHtml = $self->popup_as_html($page, $dialog, $command, $dlgFlags) || $self->findPopup_as_html($page, $dialog, $command, $dlgFlags) if ! $readOnly;
	my $hints = ($self->{hints} && ! $readOnly) ? "<br><font $dialog->{hintsFontAttrs}>$self->{hints}</font>" : '';
	my $id = "_id_" . $self->{name};
	return qq{<tr valign="top" id="$id" $bgColorAttr><td width="$self->{_spacerWidth}">
		$spacerHtml
	</td><td align="$dialog->{captionAlign}">
		<font $dialog->{bodyFontAttrs}>
			$caption
		</font>
	</td><td>
		<font $dialog->{bodyFontAttrs}>
			$self->{preHtml}
			$fieldsHtml $popupHtml $self->{postHtml}
			$errorMsgsHtml
			$hints
		</font>
	</td><td width="$self->{_spacerWidth}">
		&nbsp;
	</td></tr>};
}


##############################################################################
package CGI::Dialog::Field::Duration;
##############################################################################

use strict;
use Date::Manip;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::MultiField);

sub XAP_initialize
{
	my ($xap, $tagAttrs, $typeDefns) = @_;

	$xap->addTagHandler('field-duration', \&XAP_tag_handler, 'dialog');
}

sub XAP_tag_handler
{
	my ($xap, $tag, $tagContent) = @_;
	CGI::Dialog::XAP_addDialogField($xap, $tag, $tagContent, CGI::Dialog::Field::XAP_createField($xap, __PACKAGE__, $tag, $tagContent));
}

sub new
{
	my ($class, %params) = @_;

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
		new CGI::Dialog::Field(%{$beginParams}),
		new CGI::Dialog::Field(%{$endParams}),
	];
	return CGI::Dialog::MultiField::new($class, %params);
}

sub needsValidation
{
	CGI::Dialog::MultiField::needsValidation(@_);
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
package CGI::Dialog::Subhead;
##############################################################################

use strict;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::ContentItem);

sub XAP_initialize
{
	my ($xap, $tagAttrs, $typeDefns) = @_;

	$xap->addTagHandler('field-subhead', \&XAP_tag_handler, 'dialog');
}

sub XAP_tag_handler
{
	my ($xap, $tag, $tagContent) = @_;
	my $attrs = $tagContent->[0];

	return unless $xap->allStructMembersAvail($attrs, "attribute '%s' required in '$tag' tag", 'heading');
	CGI::Dialog::XAP_addDialogField($xap, $tag, $tagContent, __PACKAGE__->new(%$attrs));
}

sub new
{
	my $type = shift;
	my %params = @_;

	$params{level} = 1 if ! exists $params{level};

	return CGI::Dialog::ContentItem::new($type, %params);
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	my $shFntAttrs = $dialog->{subheadFontsAttrs};
	my $html = qq{<tr><td colspan=4>
		<font size=1>
			&nbsp;
		</font>
	</td></tr><tr valign=top><td colspan=4>
		<font $shFntAttrs>
			<b>$self->{heading}</b>
			<hr size=1 color=navy noshade>
		</font>
	</td></tr>};

	return $html;
}

##############################################################################
package CGI::Dialog::HeadFootItem;
##############################################################################

sub new
{
	my $type = shift;
	my %params = @_;

	return bless \%params, $type;
}

sub getHtml
{
}

##############################################################################
package CGI::Dialog::Buttons;
##############################################################################

use strict;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::HeadFootItem);

use constant NEXTACTION_PARAMNAME => '_f_nextaction_redirecturl';
use constant NEXTACTION_FIELDNAME => 'nextaction_redirecturl';

sub XAP_initialize
{
	my ($xap, $tagAttrs, $typeDefns) = @_;

	$xap->addTagHandler('dialog-buttons', \&XAP_tag_handler, 'dialog');
}

sub XAP_tag_handler
{
	my ($xap, $tag, $tagContent) = @_;
	my $attrs = $tagContent->[0];
	CGI::Dialog::XAP_addDialogField($xap, $tag, $tagContent, __PACKAGE__->new(%$attrs));
}

sub new
{
	my $type = shift;
	my %params = @_;

	$params{type} = -1 if ! exists $params{type};

	#
	# nextActions is a reference to another array of the following type:
	#   option, url, isDefault
	#   where "option" is the text of the action
	#   where "url" is the URL to go to when selected
	#      URL can have the following variables
	#          #session.xxxx# which will be replaced at runtime by $page->session('xxxx')
	#          #param.xxxx#   which will be replaced at runtime by $page->param('xxxx')
	#          #field.xxxx#   which will be replaced at runtime by $page->field('xxxx')
	#      remember, the actual replacements for #xxxx.yyyy# will happen in CGI::Page::send_http_header
	#   where "isDefault" should be set to "1" to make the option the selected option
	#
	# nextActions can come in the following forms:
	#   just "nextActions" -- meaning show it in all cases
	#   just "nextActions_add" -- meaning show it just for "add" command
	#   just "nextActions_update" -- meaning show it just for "update" command
	#   just "nextActions_remove" -- meaning show it just for "remove" command
	#
	$params{cancelUrl} = 'javascript:history.back()' unless $params{cancelUrl};
	return CGI::Dialog::HeadFootItem::new($type, %params);
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	my $tableCols = $dialog->{_tableCols};
	my $rowColor = '';
	my $cancelURL = $page->flagIsSet(App::Page::PAGEFLAG_ISPOPUP) ? 'javascript:window.close()' : $self->{cancelUrl};
	my @nextActions = ();
	if(my $actionsList = ($self->{"nextActions_$command"} || $self->{nextActions}))
	{
		my $activeAction = $page->param(NEXTACTION_PARAMNAME);
		foreach(@$actionsList)
		{
			my $replaceData = $page->replaceVars($_->[1]);			
			push(@nextActions, qq{ <OPTION VALUE="$_->[1]" @{[ $activeAction ? ($activeAction eq $replaceData ? ' SELECTED' : '') : ($_->[2] ? ' SELECTED' : '') ]}>$_->[0]</OPTION> });
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
	my $okButton =qq{<input name="$fieldName" type="image" src="/resources/widgets/ok_btn.gif" border=0 title="">};
	$okButton = qq{<a href="$cancelURL"><img src="/resources/widgets/ok_btn.gif" border=0></a>}if $dialog->{viewOnly};
	
	return qq{
		<tr><td colspan=$tableCols><font size=1>&nbsp;</font></td></tr>
		<tr valign=center bgcolor=$rowColor>
		<td align=center colspan=$tableCols valign=bottom>
			$self->{preHtml}
			$nextActions
			$okButton
			<a href="$cancelURL"><img src="/resources/widgets/cancel_btn.gif" border=0></a>
			$self->{postHtml}
		</td>
		</tr>
	};
}

##############################################################################
package CGI::Dialog::Text;
##############################################################################

use strict;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::HeadFootItem);

sub XAP_initialize
{
	my ($xap, $tagAttrs, $typeDefns) = @_;

	$xap->addTagHandler('field-static', \&XAP_tag_handler, 'dialog');
}

sub XAP_tag_handler
{
	my ($xap, $tag, $tagContent) = @_;
	my $attrs = $tagContent->[0];

	return unless $xap->allStructMembersAvail($attrs, "attribute '%s' required in '$tag' tag", 'text');
	CGI::Dialog::XAP_addDialogField($xap, $tag, $tagContent, __PACKAGE__->new(%$attrs));
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	return qq{
	<tr valign=top>
	<td colspan=$dialog->{_tableCols}>
		$self->{text}
		<br>&nbsp;
	</td>
	</tr>
	};
}

##############################################################################
package CGI::Dialog;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Validator;

use vars qw(@ISA $POSTMATCH);
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
	VIEWONLY);

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

use enum qw(:PAGE_SUPPLEMENTARYHTML_ NONE LEFT RIGHT TOP BOTTOM);

@ISA = qw(CGI::Validator);
use vars qw(%DLG_FLAGS_ATTRMAP);

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

# static method
sub XAP_initialize
{
	my ($xap, $tagAttrs, $typeDefns) = @_;

	$xap->addTagHandler('dialog', \&XAP_tag_handler);
}

use constant TAG_SECTION		=> 'section';
use constant TAG_FIELDGROUP		=> 'field-group';

sub XAP_tag_handler
{
	my ($xap, $tag, $tagContent) = @_;
	my $attrs = $tagContent->[0];

	return unless $xap->allStructMembersAvail($attrs, "attribute '%s' required in '$tag' tag", 'id');

	my ($pkgId, $scopeId) = $xap->getQualifiedId('dlg', $attrs->{id});

	my %constructAttrs = %{$attrs};
	$constructAttrs{id} = $pkgId;
	my $dialog = new CGI::Dialog(qualifiedId => $scopeId, %constructAttrs);

	# the following code is not re-entrant or thread-safe
	$xap->{_parser_activeDialog} = $dialog;
	$xap->{_parser_activeDialogId} = $scopeId;
	$xap->{_parser_activeFieldGrp} = undef;
	XAP_handleElementDialogContent($xap, $tagContent);
	delete $xap->{_parser_activeFieldGrp};
	delete $xap->{_parser_activeDialogId};
	delete $xap->{_parser_activeDialog};

	$xap->addComponent(1, $attrs->{id}, $pkgId, $scopeId, $dialog);
}

sub XAP_handleElementDialogSection
{
	my ($xap, $tag, $content) = @_;
	my $attrs = $content->[0];

	return unless $xap->allStructMembersAvail($attrs, "attribute '%1' required in '$tag' tag", 'heading');

	$xap->{_parser_activeDialog}->addContent(CGI::Dialog::Subhead->new(heading => $attrs->{heading}));
}

sub XAP_addDialogField
{
	my ($xap, $tag, $tagContent, $newField) = @_;

	if(my $group = $xap->{_parser_activeFieldGrp})
	{
		push(@{$group->{fields}}, $newField);
	}
	else
	{
		$xap->{_parser_activeDialog}->addContent($newField);
	}
}

sub XAP_handleElementDialogContent
{
	my ($xap, $content) = @_;
	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);

	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		next unless $chTag; # if $tag is 0, it's just characters

		if($chTag eq TAG_SECTION)
		{
			XAP_handleElementDialogSection($xap, $chTag, $chContent);
		}
		else
		{
			$xap->handleRegisteredTag($chTag, $chContent);
		}
	}
}

#
# execmode can be (I)nput, (V)alidate, or (E)xecute [case matters!]
#

sub new
{
	my $validator = CGI::Validator::new(@_);
	my ($class, %params) = @_;

	# this message should be temporary, remove before production
	#confess 'do not provide applet parameter to new CGI::Dialog' if $params{applet};
	#confess 'id parameter in new CGI::Dialog is required' unless $params{id};

	my $properties =
		{
			_header => [],
			_footer => [],
			topHtml => [],
			preHtml => [],
			postHtml => [],
			fieldMap => {},   # key is fieldName, value is fieldIndex in content
			priKeys => [],
			heading => '',
			#headColor => "#a7afa7",
			#bgColor => "#d7dfe7",
			headColor => "LIGHTSTEELBLUE",
			bgColor => "#EEEEEE",
			errorBgColor => "#d7dfd7",
			ruleBelowHeading => 0,
			cellPadding => 2,
			columns => 1,
			headFontAttrs => "face='arial,helvetica' size='2' color=yellow",
			bodyFontAttrs => "face='arial,helvetica' size='2' color=black",
			bodyFontErrorAttrs => "face='arial,helvetica' size='2' color=red",
			hintsFontAttrs => "face='arial,helvetica' size=2 color=navy",
			subheadFontsAttrs => "face='arial,helvetica' size=2 color=navy",
			formAttrs => '',
			captionAlign => 'left',
			errorsHeading => 'Please review',
			id => $class,
			viewOnly=>0,			
		};

	$properties->{formName} = 'dialog' unless $params{formName};
	foreach (keys %{$properties})
	{
		$validator->{$_} = $properties->{$_};
	}
	foreach (keys %params)
	{
		$validator->{$_} = $params{$_};
	}

	if(exists $params{runtimeAttrs})
	{
		my $attrs = $params{runtimeAttrs};
		while($attrs)
		{
			$attrs =~ m/(\w+)\s*=\s*'?(.*)'?/;
			$validator->{$1} = $2;
			$attrs = $POSTMATCH;
		}
	}

	my $self = bless $validator, $class;
	$self->initialize();

	$self;
}

sub initialize
{
}

sub id
{
	return $_[0]->{id};
}

sub formName
{
	return $_[0]->{formName};
}

sub heading
{
	$_[0]->{heading} = $_[1] if defined $_[1];
	return $_[0]->{heading};
}

sub flagsAsStr
{
	my $str = unpack("B32", pack("N", shift));
	$str =~ s/^0+(?=\d)// if $_[1]; # otherwise you'll get leading zeros
	return $str;
}

sub getField
{
	my ($self, $name) = @_;
	my $fmap = $self->{fieldMap};
	if(exists $fmap->{$name})
	{
		return $self->{content}->[$fmap->{$name}];
	}
	else
	{
		return undef;
	}
}

sub updateFieldFlags
{
	my ($self, $name, $flags, $condition) = @_;
	my $fmap = $self->{fieldMap};
	if(exists $fmap->{$name})
	{
		my $field = $self->{content}->[$fmap->{$name}];
		$field->updateFlag($flags, $condition);
		return $field;
	}
	return undef;
}

sub setDialogViewOnly
{
	my ($self,$flags)  = @_;
	my $contentList = $self->{content};
	
	#Change all fields on dialog to readonly
	foreach(@$contentList)
	{
		my $field = $_;
		$field->setFlag(FLDFLAG_READONLY);		
	}	
	
	#Set dialog to viewonly mode
	$self->{viewOnly}=1;	
	
	#Remove Add/Update part of caption from Heading
	$self->{heading}=~s/[Update|add|Add|update]//;
}


sub setFieldFlags
{
	my ($self, $name, $flags) = @_;
	my $fmap = $self->{fieldMap};
	if(exists $fmap->{$name})
	{
		my $field = $self->{content}->[$fmap->{$name}];
		$field->setFlag($flags);
		return $field;
	}
	return undef;
}

sub clearFieldFlags
{
	my ($self, $name, $flags) = @_;
	my $fmap = $self->{fieldMap};
	if(exists $fmap->{$name})
	{
		my $field = $self->{content}->[$fmap->{$name}];
		$field->clearFlag($flags);
		return $field;
	}
	return undef;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	

	foreach(@{$self->{content}})
	{
		# clear the read-only flag by default
		my $flagsRef = \$_->{flags};

		# now see if the field needs readOnly flags set
		$$flagsRef &= ~FLDFLAG_READONLY;
		$$flagsRef |= FLDFLAG_READONLY
			if	($dlgFlags & DLGFLAG_READONLY) ||
			 	($_->{priKey} && ($dlgFlags & DLGFLAG_PRIKEYREADONLY)) ||
			 	($_->{options} & FLDFLAG_READONLY);

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
	my $self = shift;
	push(@{$self->{preHtml}}, @_);
}

sub addPostHtml
{
	my $self = shift;
	push(@{$self->{postHtml}}, @_);
}

sub addHeader
{
	my $self = shift;

	foreach (@_)
	{
		# only add things to the dialog that are objects inherited from CGI::Dialog::HeadFootItem
		next if ! ref $_ || ! $_->isa('CGI::Dialog::HeadFootItem');
		push(@{$self->{_header}}, $_);
	}
}

sub addFooter
{
	my $self = shift;

	foreach (@_)
	{
		# only add things to the dialog that are objects inherited from CGI::Dialog::HeadFootItem
		next if ! ref $_ || ! $_->isa('CGI::Dialog::HeadFootItem');
		push(@{$self->{_footer}}, $_);
	}
}

sub addContent
{
	my $self = shift;
	my $contentList = $self->{content};

	my $cookieNamePrefix = $self;
	$cookieNamePrefix =~ s/=.*//;

	foreach (@_)
	{
		# only add things to the dialog that are objects inherited from DialogItem
		next unless ref $_ && $_->isa('CGI::Dialog::ContentItem');
		next unless $_->onBeforeAdd($self);

		$_->{cookieName} = "$cookieNamePrefix.$_->{name}" if $_->flagIsSet(FLDFLAG_PERSIST);
		push(@$contentList, $_);
		$self->{fieldMap}->{$_->{name}} = scalar(@{$self->{content}}) - 1;

		my $last = scalar(@$contentList);
		push(@{$self->{priKeys}}, ($last-1)) if $_->{priKey};

		$_->onAfterAdd($self);
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
	my ($self, $page, $activeExecMode) = @_;

	return $self->populateValues($page) if defined($activeExecMode) && $activeExecMode eq 'I';
	return 1 if scalar(@{$self->{content}}) == 0;

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
	my ($self, $page) = @_;

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
	my ($self, $page, $activeExecMode) = @_;

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
	my ($self, $command, $activeExecMode) = @_;

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
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	if(my $method = $self->can("populateData_$command"))
	{
		return &{$method}($self, $page, $command, $activeExecMode, $flags);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	if(my $method = $self->can("execute_$command"))
	{
		return &{$method}($self, $page, $command, $flags);
	}
	return $self->abstractMsg();
}

sub handlePostExecute
{
	my ($self, $page, $command, $flags, $specificRedirect, $message) = @_;
	if(my $activityLog = $self->{activityLog})
	{
		$page->recordActivity(
					exists $activityLog->{type} ? $activityLog->{type} : App::Universal::ACTIVITY_TYPE_RECORD,
					exists $activityLog->{action} ? $activityLog->{action} : $App::Universal::DIALOG_COMMAND_ACTIVITY_MAP{$command},
					$activityLog->{scope}, $activityLog->{key},
					exists $activityLog->{level} ? $activityLog->{level} : App::Universal::ACTIVITY_LEVEL_HIGH,
					$activityLog->{data},
					$page->session('user_id'),
				);
	}
	if($page->flagIsSet(App::Page::PAGEFLAG_ISPOPUP))
	{
		#unshift(@{$page->{page_head}}, qq{<script>opener.location.reload(); window.close()</script>});
		unshift(@{$page->{page_head}},
			qq{
					<script>
						if(eval("opener.bypassRefresh"))
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
	
	my $url = defined $specificRedirect ? $specificRedirect : ($page->param(CGI::Dialog::Buttons::NEXTACTION_PARAMNAME) || $self->getReferer($page) || $page->param('home'));
	$url = $page->replaceRedirectVars($url);
	if (defined $message)
	{
		$page->addContent(qq{$message<BR>Click <a href="$url">Here</a> to Continue});
	}
	else
	{
		
		if($specificRedirect)
		{
			$page->redirect($specificRedirect);
			return 1;
		}
		else
		{
			unless($flags & DLGFLAG_IGNOREREDIRECT)
			{
				if($url)
				{
					#$page->addError("Redirecting to $url");
					$page->redirect($url);
					return 1;
				}
			}
		}
	}
	return 0;
}

sub getReferer
{
	my ($self, $page) = @_;
	return $page->param('_dialogreturnurl') || $page->field(FIELDNAME_REFERER);
}

sub getStateData
{
	my ($self, $page, $command) = @_;

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
	my ($self, $page) = @_;
	return $page->property(PAGEPROPNAME_COMMAND . '_' . $self->id());
}

sub getActiveFlags
{
	#
	# VALID ONLY INSIDE a call to getHtml
	#
	my ($self, $page) = @_;
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
	my ($self, $fieldsList, $jsList, $recurseInfo) = @_;

	my $dialogName = $self->formName();
	my $fieldNum = 0;
	my $lastFieldNum = scalar(@$fieldsList)-1;
	my $prevField = defined $recurseInfo ? $recurseInfo->{prevf} : 'null';
	my $nextField = undef;
	foreach (@$fieldsList)
	{
		my $nf = $fieldsList->[$fieldNum+1];
		$nextField = $fieldNum == $lastFieldNum ? (defined $recurseInfo ? $recurseInfo->{nextf} : 'null') : "'_f_$nf->{name}'";

		if($_->isa('CGI::Dialog::MultiField'))
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
	my ($self, $field) = @_;
	my @skipFlags = [FLDFLAG_INVISIBLE, FLDFLAG_READONLY];
	my @skipTypes = ['separator'];
	my $item;

	foreach $item (@skipFlags)
	{
		return 0 if $field->{options} & $item;
	}
	foreach $item (@skipTypes)
	{
		return 0 if $field->{type} == $item;
	}
	return 1;
}

sub getHtml
{
	my ($self, $page, $command, $callbacks, $hiddenParams) = @_;

	die "CGI \$page parameter required" unless $page;

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
	$Command =~ s/_(.)/" \u$1"/ge;
	$heading =~ s/(\$\w+)/$1/eego;

	my $errorsHtml = '';
	unless($isValid)
	{
		$heading = "$heading (<font color=white>ERROR</font>)";
		my $errorMsgs = join("<li>", $page->validationMessages());
		$errorsHtml = qq{
		<font $self->{bodyFontAttrs}>
		<!---<font color=red size=+1><b>There was some incorrect data entered.</b></font><br>--->
		<font color=red size=+1><b>$self->{errorsHeading}</b></font>:
		<ul>
			<li>$errorMsgs
			<SCRIPT>var bypassRefresh = 1;</SCRIPT>
		</ul>
		</font>
		};
	}

	my $dialogName = $self->formName();
	my $cols = $self->{columns};
	my @fieldsInfoJS = ("dialogFields['$dialogName'] = {};", "var dlg_$dialogName\_fields = dialogFields['$dialogName'];");
	$self->populateFieldInfoJS($self->{content}, \@fieldsInfoJS);
	my $contentList = $self->{content};
	foreach (@$contentList)
	{
		$cols++ if exists $_->{colBreak} && $_->{colBreak};
	}
	$self->{columns} = $cols;
	$self->{_tableCols} = $self->{columns} == 1 ? 4 : $self->{columns};
	my $fieldsInfoJS = join("\n", @fieldsInfoJS);

	foreach (@{$self->{_header}})
	{
		$html .= $_->getHtml($page, $self, $command, $flags);
	}

	if($self->{columns} > 1)
	{
		my $rowsPerCol = int(scalar(@{$self->{content}})/$self->{columns})+1;
		my @colData = ();

		my $col = 0;
		my $row = 0;
		foreach (@{$self->{content}})
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
		foreach (@{$self->{content}})
		{
			next if ($_->{flags} & FLDFLAG_INVISIBLE);
			$html .= $_->getHtml($page, $self, $command, $flags);
		}
	}

	foreach (@{$self->{_footer}})
	{
		$html .= $_->getHtml($page, $self, $command, $flags);
	}

	my $titleRule = '';
	if($self->{ruleBelowHeading})
	{
		$titleRule = qq{<hr size="1" color="navy" width="100%">};
	}

	if($errorsHtml)
	{
		$errorsHtml = qq{<tr><td>
			$errorsHtml
			<hr size="1" width="100%" noshade>
		</td></tr>};
	}

	# UserId @{[ $page->session('user_id') ]}

	my @dlgHouskeepingHiddens = ();
	if($flags & DLGFLAG_DATAENTRY_INITIAL)
	{
		my $refererFieldName = $page->fieldPName(FIELDNAME_REFERER);
		my $actualReferer = $page->referer();
		push(@dlgHouskeepingHiddens, qq{<input type="hidden" name="$refererFieldName" value="$actualReferer">});
	}
	my $execModeFieldName = $page->fieldPName(FIELDNAME_EXECMODE);
	push(@dlgHouskeepingHiddens, qq{<input type="hidden" name="$execModeFieldName" value="$newExecMode">});

	my $formAction = "/";
	$formAction .= $page->param('_isPopup') ? $page->param('arl_asPopup') : $page->param('arl');
	$formAction =~ s/\?.*$//;

	# Don't display a window title unless a header is defined
	my $titleBarHtml = '';
	if ($heading)
	{
		$titleBarHtml = qq{<tr align="center" bgcolor="$self->{headColor}"><td background="/resources/design/verttab.gif">
			<font $self->{headFontAttrs}>
				&nbsp;<b>$heading</b><!--$activeExecMode : $newExecMode : $isValid)-->&nbsp;
			</font>
			$titleRule
			</td></tr>};
	}

	return qq{
	<center>
	<table border="0" bgcolor="$self->{headColor}" cellspacing="2" cellpadding="0" width="$self->{width}"><tr><td>@{$self->{topHtml}}
	<table border="0" bgcolor="$self->{bgColor}" cellspacing="0" cellpadding="4" width="$self->{width}">$titleBarHtml$errorsHtml<tr><td>
		@{$self->{preHtml}}
	<table align="center" border="0" bgcolor="$self->{bgColor}" cellspacing="0" cellpadding="$self->{cellPadding}"><SCRIPT>
		$fieldsInfoJS
	</SCRIPT><form name="$self->{formName}" action="$formAction" $self->{formAttrs} method="post" onSubmit="return validateOnSubmit(this)">@dlgHouskeepingHiddens $html </form></table>
	</td></tr></table>
		@{$self->{postHtml}}
	</td></tr></table>
	</center>
	};
}

sub getStaticHtml
{
	my ($self, $page) = @_;

	my $contentList = $self->{content};
	my $cols = $self->{columns};
	my $html = '';
	my $flags = 0;
	my $command = '';

	foreach (@$contentList)
	{
		$cols++ if exists $_->{colBreak} && $_->{colBreak};
	}
	$self->{columns} = $cols;
	$self->{_tableCols} = $self->{columns} == 1 ? 4 : $self->{columns};

	foreach (@{$self->{_header}})
	{
		$_->{flags} |= FLDFLAG_READONLY;
		$html .= $_->getHtml($page, $self, $command, $flags);
	}

	if($self->{columns} > 1)
	{
		my $rowsPerCol = int(scalar(@{$self->{content}})/$self->{columns})+1;
		my @colData = ();

		my $col = 0;
		my $row = 0;
		foreach (@{$self->{content}})
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
		foreach (@{$self->{content}})
		{
			next if ($_->{flags} & FLDFLAG_INVISIBLE);
			$_->setFlag(FLDFLAG_READONLY);
			$html .= $_->getHtml($page, $self, $command, $flags);
		}
	}

	#foreach (@{$self->{_footer}})
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

#---------------------- DIALOG (AS A) PAGE MANAGEMENT ------------------------

sub handle_page
{
	my ($self, $page, $command) = @_;

	# first "run" the dialog and get the flags to see what happened
	my $dlgHtml = $self->getHtml($page, $command);
	my $dlgFlags = $page->property(PAGEPROPNAME_FLAGS . '_' . $self->id());

	# if we executed the dialog (performed some action), then we
	# want to leave because execute should have setup the redirect already
	if($dlgFlags & CGI::Dialog::DLGFLAG_EXECUTE)
	{
		$page->addContent($dlgHtml);
	}
	else
	{
		my ($supplType, $supplHtml) = $self->getSupplementaryHtml($page, $command);
		if(my $method = $self->can("handle_page_supplType_$supplType"))
		{
			&{$method}($self, $page, $command, $dlgHtml, $supplHtml);
		}
	}

	#$page->printContents() unless $testDebug;
	#$page->printContents2() if $testDebug;
}

sub getSupplementaryHtml
{
	return (PAGE_SUPPLEMENTARYHTML_NONE, '');
}

sub handle_page_supplType_0  #NONE
{
	my ($self, $page, $command, $dlgHtml, $supplHtml) = @_;
	$page->addContent($dlgHtml);
}

sub handle_page_supplType_1  # LEFT
{
	my ($self, $page, $command, $dlgHtml, $supplHtml) = @_;
	$page->addContent(qq{
		<table border=0 cellpadding=0 cellspacing=0>
			<tr valign=top align=center>
				<td><font face="arial,helvetica" size=2>$supplHtml</font></td>
				<td>&nbsp;&nbsp;&nbsp;</td>
				<td>
					<font color=navy face="arial,helvetica" size=3>
						<b>$dlgHtml</b>
					</font>
				</td>
			</tr>
		</table>
	});
}

sub handle_page_supplType_2  # RIGHT
{
	my ($self, $page, $command, $dlgHtml, $supplHtml) = @_;
	$page->addContent(qq{
		<table border=0 cellpadding=0 cellspacing=0>
			<tr valign=top align=center>
				<td>
					<font color=navy face="arial,helvetica" size=3>
						<b>$dlgHtml</b>
					</font>
				</td>
				<td>&nbsp;&nbsp;&nbsp;</td>
				<td><font face="arial,helvetica" size=2>$supplHtml</font></td>
			</tr>
		</table>
	});
}

sub handle_page_supplType_3  # TOP
{
	my ($self, $page, $command, $dlgHtml, $supplHtml) = @_;
	$page->addContent(qq{
		<table border=0 cellpadding=0 cellspacing=0>
			<tr valign=top align=center>
				<td>
					<font color=navy face="arial,helvetica" size=3>
						<b>$dlgHtml</b>
					</font>
				</td>
			</tr>
			<tr><td>&nbsp;<p></td></tr>
			<tr>
				<td><font face="arial,helvetica" size=2>$supplHtml</font></td>
			</tr>
		</table>
	});
}

sub handle_page_supplType_4  # BOTTOM
{
	my ($self, $page, $command, $dlgHtml, $supplHtml) = @_;
	$page->addContent(qq{
		<table border=0 cellpadding=0 cellspacing=0>
			<tr>
				<td><font face="arial,helvetica" size=2>$supplHtml</font></td>
			</tr>
			<tr><td>&nbsp;<p></td></tr>
			<tr valign=top align=center>
				<td>
					<font color=navy face="arial,helvetica" size=3>
						<b>$dlgHtml</b>
					</font>
				</td>
			</tr>
		</table>
	});
}

1;
