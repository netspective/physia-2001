##############################################################################
package App::Page::Search::Insurance;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Insurance;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Page::Search);

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
				<option value="/org/%itemValue%/profile">View Summary</option>
				<option value="/org/%itemValue%/update">Edit Registry</option>
				<option value="/org/#session.org_id#/dlg-add-ins-product">Create Insurance Product</option>
				<option value="/org/#session.org_id#/dlg-add-ins-plan">Create Insurance Plan</option>
				<option value="/org/%itemValue%/remove">Delete Record</option>
			</SELECT>
			<SELECT name="item_action_arl_dest_select">
				<option>In this window</option>
				<option>In new window</option>
			</SELECT>
		};
	}
	unless($flags & SEARCHFLAG_LOOKUPWINDOW)
	{
		$createFns = qq{
			|
			<select name="create_newrec_select" style="color: green" onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
				<option>Create New Record</option>
				<option value="/org/#session.org_id#/dlg-add-ins-product">Insurance Product</option>
				<option value="/org/#session.org_id#/dlg-add-ins-plan">Insurance Plan</option>
			</select>
		};
	}

	return ('Lookup an insurance plan', qq{
		<CENTER>
		<NOBR>
		Find:
		<select name="search_type" style="color: darkred">
			<option value="id">Product Name</option>
			<option value="groupname" selected>Group Name</option>
			<option value="groupnum">Group Number</option>
			<option value="insorgid">Insurance Org ID</option>
		</select>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 0 ]}');
		</script>
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		$createFns
		$itemFns
		</CENTER>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	# oracle likes '%' instead of wildcard '*'
	my $appendStmtName = $expression =~ s/\*/%/g ? '_like' : '';

	$self->addContent(
		'<CENTER>',
		$STMTMGR_INSURANCE_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_$type$appendStmtName",
			[uc($expression)],
			#[
			#	['ID', '<A HREF=\'javascript:chooseEntry("%0")\' STYLE="text-decoration:none">%0</A>'],
			#	['Group Name'],
			#	['Group Number'],
			#	['Organization'],
			#]
			),
		'</CENTER>'
		);

	return 1;
}
@CHANGELOG =
(
	
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/19/2000', 'RK',
		'Search/Insurance',
		'Created simple reports instead of using createOutput function.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/29/2000', 'RK',
			'Search/Insurance',
		'Changed the urls from create/... to org/.... '],
);
1;