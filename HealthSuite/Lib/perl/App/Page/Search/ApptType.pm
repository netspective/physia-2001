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
		my $r_ids = $pathItems->[2];
		my $caption = $pathItems->[3];

		$self->param('r_ids', $r_ids);
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
		<font size=2>	Resource: </font>
		<input name='r_ids' size=30 maxlength=255 value="@{[$self->param('r_ids')]}">
			<a href="javascript:doFindLookup(this.form, search_form.r_ids, '/lookup/physician/id');">
			<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Resource ID"></a>

		<font size=2>	Caption: </font>
		<input name='caption' size=30 maxlength=255 value="@{[$self->param('caption')]}">

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

	my $r_ids = $self->param('r_ids') || '%';
	$r_ids =~ s/\*/\%/g;
	my $r_ids_p = $self->param('r_ids') . '%';
	$r_ids_p =~ s/\*/\%/g;
	my $caption = '%' . $self->param('caption') . '%';
	$caption =~ s/\*/\%/g;

	my @bindCols = ($self->session('org_internal_id'), $r_ids, $r_ids_p, $caption);

	$self->addContent(
	'<CENTER>',
		$STMTMGR_SCHEDULING->createHtml($self, STMTMGRFLAG_NONE, 'selApptTypeSearch', \@bindCols,
		),
		'</CENTER>'
	);

	return 1;
}

1;
