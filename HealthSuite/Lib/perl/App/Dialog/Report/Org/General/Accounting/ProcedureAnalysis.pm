##############################################################################
package App::Dialog::Report::Org::General::Accounting::ProcAnalysis;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Component::Invoice;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-proc-receipt-analysis', heading => 'Procedure Analysis');

	$self->addContent(
			new CGI::Dialog::Field(
				name => 'batch_date',
				caption => 'Batch Report Date',
				type =>'date',
				options=>FLDFLAG_REQUIRED,
				),
			new App::Dialog::Field::Organization::ID(caption =>'Site Organization ID', name => 'org_id'),
			new App::Dialog::Field::Person::ID(caption =>'Physican ID', name => 'person_id', ),
			new CGI::Dialog::MultiField(caption => 'CPT From/To', name => 'cpt_field', 
						fields => [
			new CGI::Dialog::Field(caption => 'CPT From', name => 'cpt_from', size => 12),
			new CGI::Dialog::Field(caption => 'CPT To', name => 'cpt_to', size => 12),
				]),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $batchDate = $page->field('batch_date');
	my $orgId = $page->field('org_id');
	my $cptFrom = $page->field('cpt_from');
	my $cptTo = $page->field('cpt_to');
	my $orgIntId='';
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;
	return $STMTMGR_COMPONENT_INVOICE->createHtml($page, STMTMGRFLAG_NONE, 'invoice.procAnalysis', [$personId,$batchDate,	
		$orgIntId,$cptFrom,$cptTo,$page->session('org_internal_id')]);



}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;