##############################################################################
package App::Dialog::Eligibility;
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
	my $self = CGI::Dialog::new(@_, id => 'eligibility', heading => 'Select Payer'); #, holdInput => 1);

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

#		new CGI::Dialog::Subhead(heading => 'Carrier', name => 'carrier_plan_heading'),
		new App::Dialog::Field::Organization::ID(caption => 'Insurance Org Id', name => 'ins_org_id', options => FLDFLAG_REQUIRED),
#		new App::Dialog::Field::Insurance::Product(caption => 'Product Name', name => 'product_name', options => FLDFLAG_REQUIRED,
#			findPopup => '/lookup/insproduct/insorgid/itemValue', findPopupControlField => '_f_ins_org_id'),
#		new App::Dialog::Field::Insurance::Product(caption => 'Product Name', name => 'product_name', options => FLDFLAG_REQUIRED,
#			findPopup => '/lookup/insproduct/insorgid', findPopupControlField => '_f_ins_org_id')

	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $ins_org_id = $page->field('ins_org_id');
#	my $product_name = $page->field('product_name');
	if($ins_org_id eq 'AETNA')
	{
		$page->param('_dialogreturnurl', "/org/@{[$page->param('org_id')]}/dlg-check-eligibility-aetna/$ins_org_id");
	}
	elsif($ins_org_id eq'BCBS')
	{
		$page->param('_dialogreturnurl', "/org/@{[$page->param('org_id')]}/dlg-check-eligibility-bcbs");
	}
	else
	{
		$page->param('_dialogreturnurl', "/org/@{[$page->param('org_id')]}/dlg-check-eligibility-other/$ins_org_id");
	}

	$self->handlePostExecute($page, $command, $flags);
}

1;
