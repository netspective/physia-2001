##############################################################################
package App::Dialog::Field::Scheduling::Date;
##############################################################################

use strict;
use base 'CGI::Dialog::Field';

sub new
{
	my ($type, %params) = @_;
	$params{size} = 10 unless $params{size};
	$params{type} = 'date' unless $params{type};
	return CGI::Dialog::Field::new($type, %params);
}

sub findPopup_as_html
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $dialogName = $dialog->formName();
	my $fieldName = $page->fieldPName($self->{name});

	return qq{
		<SCRIPT SRC='/lib/calendar.js'></SCRIPT>
		<a href="javascript:showCalendar(document.$dialogName.$fieldName);">
			<img src='/resources/icons/calendar2.gif' title='Show calendar' BORDER=0></a>
	};
}

##############################################################################
package App::Dialog::Field::Scheduling::DateTime;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use base 'CGI::Dialog::MultiField';

sub new
{
	my ($type, %params) = @_;

	return CGI::Dialog::MultiField::new($type, %params,
		fields => [
			new App::Dialog::Field::Scheduling::Date(
				name => 'appt_date_' . $params{ordinal},
				options => FLDFLAG_REQUIRED,
			),
			new CGI::Dialog::Field(
				name => 'appt_time_' . $params{ordinal},
				type => 'time',
				options => FLDFLAG_REQUIRED,
			),
		],
	);
}

sub findPopup_as_html
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $dialogName = $dialog->formName();
	my $dateField = $self->{fields}[0]->{name};
	my $timeField = $self->{fields}[1]->{name};
	
	return qq{
		<a href="javascript:doFindLookup(this.form, document.dialog._f_$dateField,
			'/lookup/apptslot/' + document.dialog._f_resource_id.value +	','
			+ document.dialog._f_facility_id.value + ',,' + document.dialog._f_duration.value
			+ ',' + document.dialog._f_patient_type.value + ',' + document.dialog._f_appt_type.value
			+ '/1', null, false, 'location, status, width=700,height=600,scrollbars,resizable',
			null, document.dialog._f_$timeField);">
			<img src='/resources/icons/dbdd_ts.gif' title='Find Next Available Slot' 
			BORDER=0></a>
	};
}

##############################################################################
package App::Dialog::Field::Scheduling::Minutes;
##############################################################################

use strict;
use base 'CGI::Dialog::ContentItem';

sub new
{
	my ($type, %params) = @_;
	return CGI::Dialog::Field::new($type, %params);
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	
	my $dialogName = $dialog->formName();
	my $fieldName = $self->{timeField};
	my $jsField = "document.$dialogName.$fieldName";

	my $selOptions = $self->{selOptions} || "00, 15, 30, 45";
	
	my $inputs = '';
	for (split(/\s*,\s*/, $selOptions))
	{
		$inputs .= qq{
			<nobr><input type=radio onClick="setField($jsField, ':'+this.value, ':..', '12:00 AM')" name='minute' id='$_' value='$_' > <label for='$_'>$_</label>&nbsp;&nbsp;</nobr>
		};
	}
	
	my $html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $inputs);	
	return $html;
}

##############################################################################
package App::Dialog::Field::Scheduling::Hours;
##############################################################################

use strict;
use base 'CGI::Dialog::ContentItem';

sub new
{
	my ($type, %params) = @_;
	return CGI::Dialog::Field::new($type, %params);
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	
	my $dialogName = $dialog->formName();
	my $fieldName = $self->{timeField};
	my $jsField = "document.$dialogName.$fieldName";

	my $selOptions = $self->{selOptions} || "1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12";
	
	my $inputs = '';
	for (split(/\s*,\s*/, $selOptions))
	{
		my $value = sprintf("%02d", $_);
		$inputs .= qq{
			<nobr><input type=radio onClick="setField($jsField, this.value+':', '..:', '12:00 AM')" name='minute' id='$_' value='$value' > <label for='$_'>$_</label>&nbsp;&nbsp;</nobr>
		};
	}
	
	my $html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $inputs);	
	return $html;
}

##############################################################################
package App::Dialog::Field::Scheduling::AMPM;
##############################################################################

use strict;
use base 'CGI::Dialog::ContentItem';

sub new
{
	my ($type, %params) = @_;
	return CGI::Dialog::Field::new($type, %params);
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	
	my $dialogName = $dialog->formName();
	my $fieldName = $self->{timeField};
	my $jsField = "document.$dialogName.$fieldName";

	my $selOptions = $self->{selOptions} || "AM, PM";
	
	my $inputs = '';
	for (split(/\s*,\s*/, $selOptions))
	{
		$inputs .= qq{
			<nobr><input type=radio onClick="setField($jsField, ' '+this.value, ' ..', '12:00 AM')" name='ampm' id='$_' value='$_' > <label for='$_'>$_</label>&nbsp;&nbsp;</nobr>
		};
	}
	
	my $html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $inputs);	
	return $html;
}

##############################################################################
package App::Dialog::Field::Scheduling::ApptType;
##############################################################################

use strict;
use base 'CGI::Dialog::ContentItem';
use CGI::Dialog;
use CGI::Validator::Field;

sub new
{
	my ($type, %params) = @_;
	$params{READONLY} = 'READONLY';
		
	return CGI::Dialog::Field::new($type, %params);
}

sub findPopup_as_html
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $dialogName = $dialog->formName();
	my $fieldName = $page->fieldPName($self->{name});

	if(my $arl = $self->{findPopup})
	{
		my $controlField = 'null';
		$controlField = "document.$dialogName.$self->{findPopupControlField}" 
			if $self->{findPopupControlField};

		my $secondaryFindField = 'null';
		$secondaryFindField = "document.$dialogName.$self->{secondaryFindField}" 
			if $self->{secondaryFindField};
		
		return qq{
			<a href="javascript:doFindLookup(document.$dialogName, document.$dialogName.$fieldName, '$arl', '$self->{findPopupAppendValue}', false, null, $controlField, $secondaryFindField);"><img src='$self->{popup}->{imgsrc}' border=0></a>
		};
	}
	return '';
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

		if(! $readOnly)
		{
			my $javaScript = $self->generateJavaScript($page);
			my $onFocus = $self->{hint} ? " onFocus='clearField(this)'" : '';
			$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, qq{<input $self->{READONLY}  name="$fieldName" type=$self->{type} value="$value" size=$self->{size} maxlength=$self->{maxLength} $javaScript$onFocus $required>});
		}
		else
		{
			$html = qq{<input type='hidden' name='$fieldName' value="$value">};
			$html .= $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags, $value);
		}
	}

	return $html;
}

1;
