##############################################################################
package App::Dialog::EligibilityPatient;
##############################################################################

use strict;
use Carp;

use App::Universal;
use CGI::Validator::Field;
use CGI::Dialog;

use DBI::StatementManager;
use App::Statements::Org;
use App::Dialog::Field::Insurance;

use vars qw(@ISA);
use Date::Manip;
use Date::Calc qw(:all);

use vars qw(@ISA);

@ISA = qw(CGI::Dialog);


sub new
{
	my $self = CGI::Dialog::new(@_, id => 'eligibilitypatient', heading => '$Command Eligibility'); #, holdInput => 1);

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Subhead(heading => 'Carrier', name => 'carrier_plan_heading'),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	if($flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL)
	{
		my $product_name = $page->param('product_name');
		my $ins_org_id = $page->param('org_id');


		my $org = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $ins_org_id);
		my $orgName = $org->{name_primary};

		$self->addContent(
			new CGI::Dialog::Field(caption => "$orgName -- $product_name", options => FLDFLAG_READONLY),
			new CGI::Dialog::Subhead(heading => "Patient Details", name => 'patient_heading'),
		);

		my $eligibilityFields = $STMTMGR_ORG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selOrgEligibilityInput', $product_name, $ins_org_id);

		foreach (@{$eligibilityFields})
		{
			$self->addContent(
				new CGI::Dialog::Field(name => "$_->{field_name}", caption => "$_->{field_caption}",
					type => "$_->{field_type}", options => FLDFLAG_REQUIRED),
			);
		}
	}
}


###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	if ($page->field('whatToDo') ne 'cancel')
	{
		$page->param('_dialogreturnurl', "/person/RHACKETT/profile");
	}

	$self->handlePostExecute($page, $command, $flags);
}

1;
