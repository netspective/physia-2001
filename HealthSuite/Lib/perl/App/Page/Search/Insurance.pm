##############################################################################
package App::Page::Search::Insurance;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Insurance;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/insurance' => {},
	'search/insproduct' => {},
	'search/insplan' => {},
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
				<option value="/org/%itemValue%/update">Edit Registry</option>
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
				<option value="/org/#session.org_id#/dlg-add-ins-product">Insurance Product</option>
				<option value="/org/#session.org_id#/dlg-add-ins-plan">Insurance Plan</option>
			</select>
		};
	}

	my $optionPlan = $self->param('_pm_view') eq 'insplan' ? '<option value="plan" selected>Plan Name</option>' : '';
	my $type = $self->param('_pm_view') eq 'insplan' ? 'plan' : 'product';
	return ("Lookup an insurance $type", qq{
		<CENTER>
		<NOBR>
		Find:
		<select name="search_type" style="color: darkred">
			<option value="product">Product Name</option>
			$optionPlan
			<option value="insorgid">Insurance Org ID</option>
			<option value="street">Street</option>
			<option value="city">City</option>
			<option value="state">State</option>
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
	my $category = "";
	for ($self->param('_pm_view'))
	{
		$_ eq 'insurance' and do {last};
		$category = "_$_";
	}

	#$expression =~ s/%20/ /g;
	#$self->param('search_expression', $expression);

	$self->addContent(
		'<CENTER>',
		$STMTMGR_INSURANCE_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_$type$appendStmtName$category",
			[uc($expression), $self->session('org_internal_id')], 
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

1;
