##############################################################################
package App::Dialog::Eligibility::Other;
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
	my $self = CGI::Dialog::new(@_, id => 'eligibility-other', heading => '$Command Eligibility');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(name => 'input_option', type => 'hidden'),
		new CGI::Dialog::Subhead(heading => 'Carrier Detail', name => 'carrier_product_heading'),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	if($flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL)
	{
#		my $product_name = $page->unescape($page->param('product_name'));
		my $ins_org_id = $page->param('org_id');


		my $org = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $ins_org_id);
		my $orgName = $org->{name_primary};

		$self->addContent(
			new CGI::Dialog::Field(caption => "<b>$orgName<b>", options => FLDFLAG_READONLY),
			new CGI::Dialog::Subhead(heading => "Patient Details", name => 'patient_heading'),
		);

		my $eligibilityFields = $STMTMGR_ORG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selOrgEligibilityInput', $ins_org_id);

		foreach (@{$eligibilityFields})
		{
			$self->addContent(
				new CGI::Dialog::Field(name => "$_->{field_name}", caption => "$_->{field_caption}", type => "$_->{field_type}",
					options => FLDFLAG_REQUIRED),
			);
			my $input_option = "$_->{field_name}";
			my $input_option_val = ($input_option eq 'member_number') ? '0' : (($input_option eq 'ssn') ? '1' : '2');
			$page->field('input_option', $input_option_val);
		}
		$self->addContent(
			new CGI::Dialog::Subhead(heading => "Other Details", name => 'other_heading'),
			new CGI::Dialog::Field(caption => "Date to Check Eligibility", name => 'eligdate', type => 'date', options => FLDFLAG_REQUIRED),
		);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	if ($page->field('whatToDo') ne 'cancel')
	{
		my $ins_org_id = $page->param('org_id');
		my $eligdate = $page->field('eligdate');
		$eligdate =~ s/\//\-/g;
		my $paramStr;
		my $input_option = $page->field('input_option');
		if($input_option eq '0')
		{
			$paramStr = $page->field('member_number');
		}
		elsif($input_option eq '1')
		{
			$paramStr = $page->field('ssn');
		}
		else
		{
			my $dob = $page->field('dob');
			$dob =~ s/\//\-/g;
			$paramStr = $page->field('first_name') . '/' . $page->field('last_name') . '/' . $dob;
		}
		$page->param('_dialogreturnurl', "/eligibility/$ins_org_id/$eligdate/$input_option/$paramStr");
	}

	$self->handlePostExecute($page, $command, $flags);
}

1;
