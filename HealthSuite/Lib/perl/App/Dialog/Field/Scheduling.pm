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
		<SCRIPT>
			function updatePage(dummy)
			{
				return;		
			}
		</SCRIPT>
		<a href="javascript:showCalendar(document.$dialogName.$fieldName);">
		<img src='/resources/icons/calendar2.gif' title='Show calendar' BORDER=0></a>
	};
}

##############################################################################
package App::Dialog::Field::Scheduling::Time;
##############################################################################

use strict;
use base 'CGI::Dialog::Field';

sub new
{
	my ($type, %params) = @_;
	$params{size} = 10 unless $params{size};
	$params{type} = 'time' unless $params{type};
	return CGI::Dialog::Field::new($type, %params);
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
use base 'CGI::Dialog::Field';

sub new
{
	my ($type, %params) = @_;
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
1;

1;
