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

		new CGI::Dialog::Field(name => 'valid_flag', type => 'hidden'),

		new CGI::Dialog::Subhead(heading => 'Carrier', name => 'carrier_plan_heading'),
		new CGI::Dialog::Field(caption => 'Insurance Organization', name => 'org_name', type => 'text', size => 40), #, options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::Organization::ID(caption => 'Insurance Org Id', name => 'ins_org_id', options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::Insurance::Product(caption => 'Product Name', name => 'product_name', options => FLDFLAG_REQUIRED,
			findPopup => '/lookup/insproduct/insorgid/itemValue', findPopupControlField => '_f_ins_org_id'),
#		new App::Dialog::Field::Insurance::Product(caption => 'Product Name', name => 'product_name', options => FLDFLAG_REQUIRED,
#			findPopup => '/lookup/insproduct/insorgid', findPopupControlField => '_f_ins_org_id')

	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $flags);

}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	if($flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL)
	{
		$self->updateFieldFlags('org_name', FLDFLAG_INVISIBLE, 1);
	}
	else
	{
		my $ins_org_id = $page->field('ins_org_id');
		my $product_name = $page->field('product_name');

		$self->updateFieldFlags('org_name', FLDFLAG_INVISIBLE, 0);
		$self->updateFieldFlags('org_name', FLDFLAG_READONLY, 1);
		$self->updateFieldFlags('ins_org_id', FLDFLAG_READONLY, 1);
		$self->updateFieldFlags('product_name', FLDFLAG_READONLY, 1);

		my $orgData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $ins_org_id);

		$page->field('org_name', $orgData->{name_primary});
		$page->field('valid_flag', 1);

		$self->addContent(
			new CGI::Dialog::Subhead(heading => 'Patient', name => 'patient_heading'),
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

sub customValidate
{
	my ($self, $page) = @_;

	unless($page->field('valid_flag') == 1)
	{
		my $productField = $self->getField('product_name');
		$productField->invalidate($page, '');
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
		$page->param('_dialogreturnurl', "/org/@{[$page->param('org_id')]}/personnel");
	}

	$self->handlePostExecute($page, $command, $flags);
}

1;
