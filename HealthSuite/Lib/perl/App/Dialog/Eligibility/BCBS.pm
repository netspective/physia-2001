##############################################################################
package App::Dialog::Eligibility::BCBS;
##############################################################################

use strict;
use Carp;

use App::Universal;
use CGI::Validator::Field;
use CGI::Dialog;

use DBI::StatementManager;
use App::Statements::Org;
use App::Dialog::Field::Insurance;

use Date::Manip;
use Date::Calc qw(:all);

use vars qw(@ISA %RESOURCE_MAP);

%RESOURCE_MAP = (
	'eligibility-bcbs' => {
		heading => '$Command Eligibility', 
		_arl => ['org_id', 'product_name']
		},
	);



@ISA = qw(CGI::Dialog);


sub new
{
	my $self = CGI::Dialog::new(@_, id => 'eligibility-bcbs', heading => '$Command Eligibility');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(name => 'input_option', type => 'hidden'),
		new CGI::Dialog::Subhead(heading => 'Carrier Detail', name => 'carrier_product_heading'),
		new CGI::Dialog::Field(caption => "<b>Blue Cross/Blue Shield<b>", options => FLDFLAG_READONLY),
		new CGI::Dialog::Subhead(heading => "Patient Details", name => 'patient_heading'),
		new CGI::Dialog::Field(caption => "Member Number", name => "member_number", type => "text", options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Subhead(heading => "Other Details", name => 'other_heading'),
		new CGI::Dialog::Field(caption => "Date to Check Eligibility", name => 'eligdate', type => 'date', options => FLDFLAG_REQUIRED),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	if ($page->field('whatToDo') ne 'cancel')
	{
		my $ins_org_id = $page->param('org_id');
		my $eligdate = $page->field('eligdate');
		my $member_number = $page->field('member_number');
		$eligdate =~ s/\//\-/g;
		$page->param('_dialogreturnurl', "/eligibility/BCBS/$eligdate/0/$member_number");
	}

	$self->handlePostExecute($page, $command, $flags);
}

1;
