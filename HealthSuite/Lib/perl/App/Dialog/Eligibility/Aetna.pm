##############################################################################
package App::Dialog::Eligibility::Aetna;
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
	'eligibility-aetna' => {
		heading => '$Command Eligibility', 
		_arl => ['org_id', 
		'product_name']
		},
	);

@ISA = qw(CGI::Dialog);


sub new
{
	my $self = CGI::Dialog::new(@_, id => 'eligibility-aetna', heading => '$Command Eligibility');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(name => 'input_option', type => 'hidden'),
		new CGI::Dialog::Subhead(heading => 'Carrier Details', name => 'carrier_product_heading'),
		new CGI::Dialog::Field(caption => "<img src='/resources/images/aetnalogo.gif'/>&nbsp;&nbsp;<b>AETNA<b>", options => FLDFLAG_READONLY),
		new CGI::Dialog::Subhead(heading => "Patient Details", name => 'patient_heading'),
		new CGI::Dialog::Field(caption => "Last Name", name => "last_name", type => "text", options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption => "First Name", name => "first_name", type => "text", options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption => "Date of Birth", name => "dob", type => "date", options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Subhead(heading => "Other Details", name => 'other_heading'),
		new CGI::Dialog::Field(caption => "Date to Check Eligibility", name => 'eligdate', type => 'date', options => FLDFLAG_REQUIRED),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}


sub customValidate
{
	my ($self, $page) = @_;

	my $dob = $page->field('dob');
#	unless($dob =~ m//)

}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	if ($page->field('whatToDo') ne 'cancel')
	{
		my $ins_org_id = $page->param('org_id');
		my $eligdate = $page->field('eligdate');
		my $last_name = $page->field('last_name');
		my $first_name = $page->field('first_name');
		my $dob = $page->field('dob');
		$eligdate =~ s/\//\-/g;
		$dob =~ s/\//\-/g;
		$page->param('_dialogreturnurl', "/eligibility/AETNA/$eligdate/2/$first_name/$last_name/$dob");
	}

	$self->handlePostExecute($page, $command, $flags);
}

1;
