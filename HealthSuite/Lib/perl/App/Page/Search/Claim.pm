##############################################################################
package App::Page::Search::Claim;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Claim;
use Date::Manip qw(ParseDate UnixDate);
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/claim' => {},
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
				<option value="/invoice/%itemValue%/summary">View Claim</option>
				<option value="/invoice/%itemValue%/dialog/claim/update">Edit Claim</option>
				<!-- <option value="/invoice/%itemValue%/dialog/postpayment/personal,%itemValue%">*Post Payment</option> -->
				<option value="/invoice/%itemValue%/dialog/procedure/add">Add Procedure</option>
				<option value="/invoice/%itemValue%/submit">Submit Claim for Transfer</option>
				<option value="/invoice/%itemValue%/dialog/hold">Place On Hold</option>
				<option value="/invoice/%itemValue%/dialog/claim/remove">Delete Claim</option>
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
				<option>Add New Claim</option>
				<option value="/org/#session.org_id#/dlg-add-invoice">Claim</option>
			</select>
		};
	}

	return ('Lookup a claim', qq{
		<CENTER>
		<NOBR>
		Find:
		<select name="search_status" style="color: darkred">
			<option value="all">All</option>
			<option value="14">Appealed</option>
			<option value="0">Created</option>
			<!-- <option value="2">Pending</option> -->
			<option value="3">On Hold</option>
			<option value="17">Paper Claim Printed</option>
			<option value="11">Rejected</option>
			<option value="4">Submitted</option>
			<option value="5">Transferred</option>
			<option value="16">Voided</option>
		</select>
		<script>
			setSelectedValue(document.search_form.search_status, '@{[ $self->param('search_status') ]}');
		</script>
		<select name="search_type" style="color: darkred">
			<option value="id">Claim #</option>
			<option value="patientid">Patient ID</option>
			<option value="lastname">Patient Last Name</option>
			<option value="ssn">Patient SSN</option>
			<option value="date">Date of Visit</option>
			<option value="servicedate">Service Date</option>
			<option value="upin">Physician UPIN</option>
			<option value="insurance">Payer</option>
			<option value="employer">Employer</option>
		</select>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 0 ]}');
		</script>
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		@{[ $flags & SEARCHFLAG_LOOKUPWINDOW ? '' : ' | <a href="/org/#session.org_id#/dlg-add-claim">Add Claim</a>' ]}
		$itemFns
		</CENTER>
	});
}

sub execute
{
	my ($self) = @_;

	my $expression = $self->param('search_expression') || '*';
	my $status = $self->param('search_status');
	my $type = $self->param('search_type');

	if(($type eq 'date' || $type eq 'servicedate') && $expression ne '*' && ! ParseDate($expression))
	{
		$self->addContent("<font face='arial' color='darkred'>Invalid date format '$expression'. Please enter date as 'MM/DD/YYYY'.</font>");

		return;
	}

	if($type eq 'id' && $expression ne '*' && $expression !~ /^\d+$/)
	{
		$self->addContent("<font face='arial' color='darkred'>Invalid claim # format.</font>");

		return;
	}

	if($status ne 'all')
	{
		$type = $type . '_status';
	}

	# oracle likes '%' instead of wildcard '*'
	my $appendStmtName = $expression =~ s/\*/%/g ? '_like' : '';
	my $orgId = $self->session('org_internal_id');

	$self->addContent(
		'<CENTER>',
		$STMTMGR_CLAIM_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_$type$appendStmtName",
			$status eq 'all' || $status eq 'incomplete' ? [uc($expression), $orgId] : [$status, uc($expression), $orgId],
		),
		'</CENTER>'
	);

	return 1;
}

1;
