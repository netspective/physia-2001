##############################################################################
package App::Dialog::Report::Org::General::Accounting::InsuranceAnalysis;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;
use Date::Calc qw(:all);
use Date::Manip;
use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Org;
use Data::Publish;
use App::Statements::Component::Invoice;
use App::Statements::Report::InsuranceAnalysis;
use App::Dialog::Field::Organization;
use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-ins-receipt-analysis', heading => 'Insurance Receipt Analysis');

	$self->addContent(
		new CGI::Dialog::Field::Duration(
			name => 'batch',
			caption => 'Batch Report Date',
			begin_caption => 'Report Begin Date',
			end_caption => 'Report End Date',
			),
		new CGI::Dialog::Field::Duration(
			name => 'service',
			caption => 'Service Date',
			begin_caption => 'Service Begin Date',
			end_caption => 'Service End Date',
			),
		new CGI::Dialog::MultiField(caption => 'CPT From/To', name => 'cpt_field',
						fields => [
			new CGI::Dialog::Field(caption => 'CPT From', name => 'cpt_from', size => 12),
			new CGI::Dialog::Field(caption => 'CPT To', name => 'cpt_to', size => 12),
				]),
		new App::Dialog::Field::Organization::ID(caption => 'Insurance Company Id',
				name => 'ins_org_id',
				addType => 'insurance',
			),
		new CGI::Dialog::Field (
			caption => 'Sort Order',
			name => 'sort_order',
			type => 'select',
			style => 'radio',
			selOptions => 'Insurance Org:1;Cpt Code:2',
			defaultValue => '1'
			),
		);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $stmt = ($page->field('sort_order') == 1) ? 'selInsuranceAnalysisByInsurance' : 'selInsuranceAnalysisByCpt';

	my $html = $STMTMGR_REPORT_INSURANCE_ANALYSIS->createHtml($page, STMTMGRFLAG_NONE, $stmt,
		[
			$page->field('batch_begin_date'),
			$page->field('batch_end_date'),
			$page->field('service_begin_date'),
			$page->field('service_end_date'),
			$page->field('cpt_from'),
			$page->field('cpt_to'),
			$page->field('ins_org_id'),
			$page->session('org_internal_id')
		]
	);

	return $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
