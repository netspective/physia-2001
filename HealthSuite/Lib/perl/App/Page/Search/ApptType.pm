##############################################################################
package App::Page::Search::ApptType;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Scheduling;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/appttype' => {},
	);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->param('_pm_view', $pathItems->[0]);

	unless ($self->param('searchAgain')) {
		my $resource_id = $pathItems->[2];
		my $caption = $pathItems->[3];

		$self->param('resource_id', $resource_id);
		$self->param('caption', $caption);
		$self->param('searchAgain', 1);
	}

	$self->param('execute', 'Go') if $pathItems->[1];  # Auto-execute
	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
}

sub getForm
{
	my ($self, $flags) = @_;

	my $createFns = '';
	unless($flags & SEARCHFLAG_LOOKUPWINDOW)
	{
		$createFns = qq{
			|
			<font size=2 face='Tahoma'>&nbsp &nbsp
			<a href="/org/#session.org_id#/dlg-add-appttype">Add Appointment Type</a>
			</font>
		};
	}

	my ($selected0, $selected1, $selected2);
	my $selected;

	my @available = split (/,/, $self->param('template_type'));

	return ('Lookup an appointment type', qq{
		<CENTER>
		<NOBR>
		<font size=1>	Resource: </font>
		<input name='resource_id' size=25 maxlength=32 value="@{[$self->param('resource_id')]}">
		<font size=1>	Caption: </font>
		<input name='caption' size=25 maxlength=32 value="@{[$self->param('caption')]}">

		<input type=hidden name='searchAgain' value="@{[$self->param('searchAgain')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		$createFns
		</CENTER>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	my @bindCols = ($self->param('resource_id').'%', $self->param('caption').'%');

	$self->addContent(
	'<CENTER>',
		$STMTMGR_SCHEDULING->createHtml($self, STMTMGRFLAG_NONE, 'selApptTypeInfo', \@bindCols,
		),
		'</CENTER>'
	);

	return 1;
}

1;
