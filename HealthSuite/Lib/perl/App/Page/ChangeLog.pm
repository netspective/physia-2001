##############################################################################
package App::Page::ChangeLog;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;

use vars qw(@ISA);
@ISA = qw(App::Page);

sub prepare
{
	my $self = shift;

	my ($log, $modules, @restricted) = Devel::ChangeLog::getChangeLog(0);
	if(my $person = $self->param('person'))
	{
		my @idList = split(/,/, $person);
		@restricted = grep { my $id = $_->[2]; grep { $_ eq $id } @idList } @$log;
		$self->addContent("Restricted to person $person<P>");
	}
	
	if(my $date = $self->param('date'))
	{
		# replace '-' with '/'
		$date =~ s{\-}{/}g;

		my ($startDate, $endDate) = split(/,/, $date);
		if($startDate && $endDate)
		{
			$self->addContent("Restricted to date range $startDate to $endDate<P>");
			($startDate, $endDate) = (ParseDate($startDate), ParseDate($endDate));
			@restricted = grep { my $logDate = ParseDate($_->[1]); $logDate ge $startDate && $logDate le $endDate } @$log;
		}
		else
		{
			my $compareDate = ParseDate($date);
			$self->addContent("Restricted to date $date ($compareDate)<P>");
			@restricted = grep { $compareDate eq ParseDate($_->[1]) } @$log;
		}
	}
	$log = \@restricted if @restricted;
	
	my $struct = Devel::ChangeLog::createLogStruct(0, $log);

	$self->addContent($self->getLogStructHtml(0, $log, $struct));
	$self->addContent('<HR SIZE=1 COLOR=LIGHTSTEELBLUE><FONT COLOR=333333><P><B>Searched the following modules</B>:<OL><LI>', join('<LI>', sort @$modules), '</OL>')
		if $self->flagIsSet(PAGEFLAG_ISADVANCED);

	undef $struct;
	undef $log;

	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->param($pathItems->[0], $pathItems->[1]) if $pathItems->[0];
	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

1;
