##############################################################################
package App::Dialog::Report::Org::General::Accounting::ContractCompliance;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use Data::Publish;
use App::Statements::Report::ContractCompliance;
#use App::Statements::Org;
use App::Dialog::Field::BatchDateID;
use App::Dialog::Field::Insurance;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-contract-compliance', heading => 'Contract Compliance Report');

	$self->addContent(
		new CGI::Dialog::Field::Duration (
			name => 'service',
			caption => 'Service Date',
			begin_caption => 'Service Begin Date',
			end_caption => 'Service End Date',
		),
		new CGI::Dialog::MultiField (
			caption => 'Batch ID Range',
			name => 'batch_fields',
			fields => [
				new CGI::Dialog::Field (
					caption => 'Batch ID From',
					name => 'batch_id_from',
					size => 12
				),
				new CGI::Dialog::Field (
					caption => 'Batch ID To',
					name => 'batch_id_to',
					size => 12
				),
			]
		),
		new App::Dialog::Field::Insurance::Product (
			caption => 'Insurance Product',
			name => 'product_id',
			findPopup => '/lookup/insproduct/insorgid',
		),
		new CGI::Dialog::Field (
			caption => 'Sort Order',
			name => 'sort_order',
			type => 'select',
			selOptions => 'Date of Service:1;Insurance Product:2;CPT Code:3',
			defaultValue => '1'
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('service_begin_date', $startDate);
	$page->field('service_end_date', $startDate);

}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $serviceBeginDate = $page->field('service_begin_date');
	my $serviceEndDate = $page->field('service_end_date');
	my $batchIDFrom = $page->field('batch_id_from');
	my $batchIDTo = $page->field('batch_id_to');
	my $productID = $page->field('product_id');
	my $sortOrder = $page->field('sort_order');
	my $orgInternalID = $page->session('org_internal_id');

	my @stmtList = (
		'selCompliantInvoicesByServiceDate',
		'selCompliantInvoicesByProductName',
		'selCompliantInvoicesByCode'
	);

	my $stmt = $stmtList[$sortOrder-1];

	my $html = $STMTMGR_REPORT_CONTRACT_COMPLIANCE->createHtml(
		$page,
		STMTMGRFLAG_NONE,
		$stmt,
		[$orgInternalID, $serviceBeginDate, $serviceEndDate, $batchIDFrom, $batchIDTo, $productID]);

	return $html;

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
