##############################################################################
package App::Page::Construct;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use DBI::StatementManager;

use App::Dialog::WorkersComp;
use App::Dialog::Person;
use App::Dialog::Person::Patient;
use App::Dialog::Person::Nurse;
use App::Dialog::Person::Physician;
use App::Dialog::Person::Staff;
use App::Dialog::Organization;
use App::Dialog::InsurancePlan;
use App::Dialog::Encounter;
use App::Dialog::Encounter::CreateClaim;
use App::Dialog::Catalog;
use App::Dialog::CatalogItem;
use App::Dialog::Appointment;
use App::Dialog::Template;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Page);

#use constant $self->param('dlg_command') => 'add';

sub getContentHandlers
{
	return ('prepare_$record_type$');
}

sub prepare
{
	return 1;
}

sub prepare_page_content_header
{
	my $self = shift;

	return if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	$self->SUPER::prepare_page_content_header(@_);

	return 1 unless $self->param('dlg_command') eq 'add';

	my $urlPrefix = '/org/#session.org_id#';
	push(@{$self->{page_content_header}},
		"<TABLE BGCOLOR=#CCCCCC CELLSPACING=1 WIDTH=100%><TR><TD BGCOLOR=#EEEEEE>",
		$self->getMenu_TwoLevelTable(App::Page::MENUFLAGS_DEFAULT | App::Page::MENUFLAG_HIDEUNSELLEVELS,
		'record_type',
		[
			['Person:', undef, undef, 0,
				[
					['Patient', "$urlPrefix/dlg-add-patient", "patient"],
					['Physician', "$urlPrefix/dlg-add-physician", "physician"],
					['Nurse', "$urlPrefix/dlg-add-nurse", "nurse"],
					['Staff Member', "$urlPrefix/dlg-add-staff", "staff"],
				]
			],
			['Accounting:', undef, undef, 0,
				[
					['Claim', "$urlPrefix/dlg-add-claim", 'claim'],
					['Fee Schedule', "$urlPrefix/dlg-add-catalog", 'catalog'],
					['Fee Schedule Item', "$urlPrefix/dlg-add-catalog-item", 'catalogitem'],
					['Insurance Product', "$urlPrefix/dlg-add-ins-product", 'insplan'],
					['Insurance Plan', "$urlPrefix/dlg-add-ins-plan", 'workerscomp'],
				]
			],
			['Scheduling:', undef, undef, 0,
				[
					['Appointment', "$urlPrefix/dlg-add-appointment", 'appointment'],
					['Schedule Template', "$urlPrefix/dlg-add-template", 'template'],
				]
			],
			['Organization:', undef, undef, 0,
				[
					['Facility', "$urlPrefix/dlg-add-org", 'insfirm'],
					['Insurance Firm', "$urlPrefix/dlg-add-org", 'insfirm'],
					['Pharmacy', "$urlPrefix/dlg-add-org", 'insfirm'],
					['Employer', "$urlPrefix/dlg-add-org", 'insfirm'],
				]
			],
		], ' <b>|</b> '), "</TD></TR></TABLE><BR>");

	return 1;
}

sub prepare_patient
{
	my ($self) = @_;
	my @pathItems = $self->param('arl_pathItems');
	$self->field('person_id', $pathItems[1]) if $pathItems[1];
	my $dialog = new App::Dialog::Person::Patient(schema => $self->getSchema(), id => 'patient');
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}

sub prepare_physician
{
	my ($self) = @_;
	my @pathItems = $self->param('arl_pathItems');
	$self->field('person_id', $pathItems[1]) if $pathItems[1];

	my $dialog = new App::Dialog::Person::Physician(schema => $self->getSchema(), id => 'physician');
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}

sub prepare_nurse
{
	my ($self) = @_;
	my @pathItems = $self->param('arl_pathItems');
	$self->field('person_id', $pathItems[1]) if $pathItems[1];

	my $dialog = new App::Dialog::Person::Nurse(schema => $self->getSchema(), id => 'nurse');
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}

sub prepare_staff
{
	my ($self) = @_;
	my @pathItems = $self->param('arl_pathItems');
	$self->field('person_id', $pathItems[1]) if $pathItems[1];

	my $dialog = new App::Dialog::Person::Staff(schema => $self->getSchema(), id => 'staff');
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}

sub prepare_claim
{
	my ($self) = @_;

	my @pathItems = $self->param('arl_pathItems');
	$self->param('invoice_id', $pathItems[1]) if $pathItems[1];

	if(scalar(@pathItems) > 1)
	{
		# set the "default" attendee_id (but don't touch if it's already set)
		$self->param('_f_person_id', $pathItems[1]) unless $self->param('_f_person_id');
	}
	my $dialog = new App::Dialog::Encounter::CreateClaim(schema => $self->getSchema());
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}

sub prepare_insfirm
{
	my ($self) = @_;
	my $dialog = new App::Dialog::Organization(schema => $self->getSchema());
	if($self->param('_lcm_wantnewinsplan'))
	{
		my @pathItems = $self->param('arl_pathItems');
		$self->field('org_id', $pathItems[1]) if $pathItems[1];

		$self->addContent('Note<hr size=1 color=navy>After adding all your information, please be sure to select <i>Add Insurance Policy</i> as your <b>Next Action</b>.<p>');
	}
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}

sub prepare_insplan
{
	my ($self) = @_;
	my @pathItems = $self->param('arl_pathItems');
	my $instype = $self->param('_lcm_insplantype');
	unless($self->param('dlg_command') eq 'add')
	{
		$self->param('_inne_ins_internal_id', $pathItems[1]);
		$self->param('_lcm_insplantype', $pathItems[2]);
		#$self->param('_lcm_insplantype', $pathItems[3]);
		my $insurancePlan = $self->param('_inne_ins_internal_id', $pathItems[1]);
		my $insType = $self->param('_lcm_insplantype', $pathItems[2]);

		$self->addDebugStmt("insId Ins: $insurancePlan");
		$self->addDebugStmt("Insurance Type : $insType");
	}

	if($self->param('_lcm_insplantype'))
	{
		my $dialog = new App::Dialog::InsurancePlan::NewPlan(schema => $self->getSchema(), id => 'newplan');
		$dialog->handle_page($self, $self->param('dlg_command'));
	}
	else
	{

		my $newPlanHref = $self->selfRef(_lcm_insplantype => 'newinsplan');
		my $newInsOrgHref = $self->selfRef(_lcm_mframe => undef, _lcm_mcreateitem => 'insfirm', _lcm_wantnewinsplan => 1);
		$self->addContent(qq{
			<center>
			<font face="arial" color=navy size=2><b>Please choose an Insurance Record type.</b></font>
			<table>
				<tr valign=top>
					<td><img src='/resources/icons/arrow_right_red.gif'></td>
					<td>Create a <a href='$newPlanHref'>new plan for an insurance firm (organization) already in the system</a>.</td>
				</tr>
				<tr valign=top>
					<td><img src='/resources/icons/arrow_right_red.gif'></td>
					<td>
						Create a <a href='$newInsOrgHref' target="dcontent">new plan for an insurance firm (organization) <b>not</b> already in the system</a>.
						<br>
						<i>You will be prompted to first create an insurance firm record, then you can choose to create one or more insurance plans.</i>
					</td>
				</tr>
			</table>
			</center>
		});
	}

	return 1;
}

sub prepare_workerscomp
{
	my ($self) = @_;

	my @pathItems = $self->param('arl_pathItems');
	$self->param('ins_id', $pathItems[1]) if $pathItems[1];

	my $dialog = new App::Dialog::WorkersComp(schema => $self->getSchema(), id => 'workerscomp');
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}
sub prepare_catalog
{
	my ($self) = @_;
	my @pathItems = $self->param('arl_pathItems');

	$self->field('catalog_id', $pathItems[1]) if $pathItems[1];

	my $dialog = new App::Dialog::Catalog(schema => $self->getSchema(), id => 'catalog');
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}
sub prepare_catalogitem
{
	my ($self) = @_;
	my @pathItems = $self->param('arl_pathItems');

	$self->param('entry_id', $pathItems[1]) if $pathItems[1];

	my $dialog = new App::Dialog::CatalogItem(schema => $self->getSchema(), id => 'catalogitem');
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}

sub prepare_appointment
{
	my ($self) = @_;

	my @pathItems = $self->param('arl_pathItems');
	$self->field('event_id', $pathItems[2]) if $pathItems[2];

	if(scalar(@pathItems) > 1)
	{
		# set the "default" attendee_id (but don't touch if it's already set)
		$self->param('_f_attendee_id', $pathItems[1]) unless $self->param('_f_attendee_id');
	}
	my $dialog = new App::Dialog::Appointment(schema => $self->getSchema());
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}

sub prepare_template
{
	my ($self) = @_;
	my $dialog = new App::Dialog::Template(schema => $self->getSchema());
	$dialog->handle_page($self, $self->param('dlg_command'));

	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	my $dlgCmd = $rsrc eq 'create' ? 'add' : ($rsrc eq 'modify' ? 'update' : ($rsrc eq 'delete' ? 'remove' : 'add'));
	if(($dlgCmd eq 'update' || $dlgCmd eq 'remove') && scalar(@$pathItems) < 2)
	{
		$self->addError("Primary key not provided for dialog '$pathItems->[0]' (command '$dlgCmd')");
	}

	$self->param('dlg_command', $dlgCmd);
	$self->param('record_type', $pathItems->[0]);
	$self->addLocatorLinks(
			['<IMG SRC="/resources/icons/home-sm.gif" BORDER=0> Home', '/home'],
			['Practice', '/practice'],
			["\u$rsrc Record", '', undef, App::Page::MENUITEMFLAG_FORCESELECTED],
		);
	$self->printContents();
	return 0;
}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hiearchies
# 4: any text notes about the actual change/action
#
@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/06/2000', 'SNS',
		'Page/Construct',
		'Add ability for Construct to act as create/modify/delete instead of just /create.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/09/2000', 'RK',
		'Page/Construct',
		'Added ability for Claims, Catalog, Catalogitem, Person, Insurance to act as create/modify/delete instead of just /create.'],
);
1;
