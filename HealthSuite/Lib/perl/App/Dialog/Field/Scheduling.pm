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

1;

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

1;
