##############################################################################
package App::Page::Search::Org;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Org;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/org' => {},
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
				<option value="/org/%itemValue%/profile">View Summary</option>
				<option value="/org/%itemValue%/dlg-update-org-%itemCategory%">Edit Profile</option>
				<option value="/org/%itemValue%/dlg-add-ins-product">Add Insurance Product</option>
				<option value="/org/%itemValue%/dlg-add-ins-plan">Add Insurance Plan</option>
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
				<option>Add New Record</option>
				<option value="/org/#session.org_id#/dlg-add-org-main">Main</option>
				<option value="/org/#session.org_id#/dlg-add-org-dept">Department</option>
				<option value="/org/#session.org_id#/dlg-add-org-provider">Provider</option>
				<option value="/org/#session.org_id#/dlg-add-org-employer">Employer</option>
				<option value="/org/#session.org_id#/dlg-add-org-insurance">Insurance</option>
				<option value="/org/#session.org_id#/dlg-add-org-ipa">IPA</option>
			</select>
		};
	}

	return ('Lookup an organization', qq{
		<CENTER>
		<NOBR>
		Find:
		<select name="search_type" style="color: darkred">
			<option value="id">Org ID</option>
			<option value="primname" selected>Primary Name</option>
			<option value="category">Type of Org</option>
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
		$STMTMGR_ORG_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_$type$appendStmtName",
			[uc($expression), $self->session('org_internal_id')]
			),
		'</CENTER>'
		);


	return 1;
}

1;
