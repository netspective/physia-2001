##############################################################################
package App::Page::Search::Person;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Person;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/person' => {},
	'search/patient' => {},
	'search/physician' => {},
	'search/staff' => {},
	'search/nurse' => {},
	'search/associate' => {},
	'search/referring-Doctor' => {},
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
				<option value="/person/%itemValue%/dlg-update-%itemCategory%">Edit Profile</option>
				<option value="/person/%itemValue%/dlg-add-medication-prescribe">Prescribe Medication</option>
				<!-- <option value="/person/%itemValue%/dlg-add-">Add Note</OPTION> -->
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
	unless($flags & SEARCHFLAG_LOOKUPWINDOW)
	{
		$createFns = qq{
			|
			<select name="create_newrec_select" style="color: green" onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
				<option>Add New Record</option>
				<option value="/org/#session.org_id#/dlg-add-patient">Patient</option>
				<option value="/org/#session.org_id#/dlg-add-physician">Physician</option>
				<option value="/org/#session.org_id#/dlg-add-nurse">Nurse</option>
				<option value="/org/#session.org_id#/dlg-add-staff">Staff</option>
			</select>
		};
	}
	my $searchType = $flags & SEARCHFLAG_SEARCHBAR ? 'Person' : $self->param('_pm_view');
	$searchType = 'referring-doctor' if $searchType eq 'referring-Doctor';
	return ('Lookup a' . ((grep {$_ eq substr($self->param('_pm_view'),0,1)} ('a','e','i','o','u')) ? 'n ' : ' ') .
		$searchType,
		qq{
		<CENTER>
		<NOBR>
		Find:
		<select name="search_type" style="color: darkred">
			<option value="id">Person ID</option>
			<option value="lastname" selected>Last Name</option>
			<option value="anyname">First or Last Name</option>
			<option value="ssn">Social Security</option>
			<option value="dob">Date of Birth</option>
			<option value="phone">Phone Number</option>
			<option value="account">Account Number</option>
			<option value="chart">Chart Number</option>
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
	my $bindParams = $type eq 'anyname' ? [$self->session('org_internal_id'), uc($expression) , uc($expression)] : [$self->session('org_internal_id'), uc($expression)];
	my $category = "";
	for ($self->param('_pm_view'))
	{
		/person/ and do {last};
		$category = "_$_";
	}
	$self->addContent(
		'<CENTER>',
		$STMTMGR_PERSON_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_$type$appendStmtName$category", $bindParams,
			#[
			#	['ID', '<A HREF=\'javascript:chooseEntry("%0")\' STYLE="text-decoration:none">%0</A>'],
			#	['Name'],
			#	['SSN'],
			#	['Date of Birth'],
			#	['Home Phone'],
			#]
			),
		'</CENTER>'
		);

	return 1;
}

1;
