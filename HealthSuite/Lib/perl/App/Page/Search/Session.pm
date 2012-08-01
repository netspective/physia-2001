##############################################################################
package App::Page::Search::Session;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Session;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/session' => {},
	);

sub getForm
{
	my ($self, $flags) = @_;

	my ($createFns, $itemFns) = ('', '');
	if($self->param('execute') && ! ($flags & (SEARCHFLAG_LOOKUPWINDOW | SEARCHFLAG_SEARCHBAR)))
	{
		$itemFns = qq{
			<BR>
			<FONT size=5 face='arial'>&nbsp;</FONT>
			On Select:
			<SELECT name="item_action_arl_select">
				<option value="/person/%itemValue%/profile">View Summary</option>
				<option value="/person/%itemValue%/dlg-add-appointment">Schedule Appointment</option>
				<option value="/person/%itemValue%/dlg-add-claim">Add Claim</option>
				<option value="/person/%itemValue%/update">Edit Registry</option>
				<option value="/person/%itemValue%/pane/Person::Medications?_paneredirect=/person/%itemValue%/chart">Prescribe Medication</option>
				<option value="/person/%itemValue%/pane/Person::Problems?_paneredirect=/person/%itemValue%/chart">Add Note</option>
				<option value="/person/%itemValue%/account">Apply Payment</option>
				<option value="/person/%itemValue%/account">View Account</option>
				<option value="/person/%itemValue%/remove">Delete Record</option>
			</SELECT>
			<SELECT name="item_action_arl_dest_select">
				<option>In this window</option>
				<option>In new window</option>
			</SELECT>
		};
	}

	return ('Lookup a session', qq{
		<CENTER>
		<NOBR>
		Find:
		<select name="search_type" style="color: darkred">
			<option value="active" selected>Active</option>
			<option value="inactive">Inactive</option>
		</select>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 0 ]}');
		</script>
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		$itemFns
		</CENTER>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	# oracle likes '%' instead of wildcard '*'
	$expression ||= '*';
	my $appendStmtName = $expression =~ s/\*/%/g ? '_like' : '';
	my ($statStart, $statEnd) = ();
	if($type eq 'active')
	{
		$statStart = 0;
		$statEnd = 0;
	}
	else
	{
		$statStart = 1;
		$statEnd = 99;
	}

	$self->addContent(
		'<CENTER>',
		$STMTMGR_SESSION_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_status_person$appendStmtName",
			[$statStart, $statEnd, uc($expression), $self->session('org_internal_id')],
			#[
			#	['User ID', '<A HREF=\'javascript:chooseEntry("%0")\' STYLE="text-decoration:none">%0</A>'],
			#	['Name'],
			#	['Start'],
			#	['Last'],
			#	['Location'],
			#]
		),
		'</CENTER>'
	);

	return 1;
}

1;
