##############################################################################
package App::Page::Worklist::InvoiceCreditBalance;
##############################################################################

use strict;
use Date::Manip;
use Date::Calc qw(:all);

use App::Configuration;
use App::ImageManager;
use App::Dialog::WorklistSetup;
use App::Dialog::WorklistSetup::InvoiceCreditBalance;

use CGI::Dialog::DataNavigator;
use SQL::GenerateQuery;

use DBI::StatementManager;
use App::Statements::Worklist::InvoiceCreditBalance;

use Data::Publish;
use CGI::ImageManager;

use base qw{App::Page::WorkList};

use vars qw(
	$CREDITARL
	%RESOURCE_MAP
	%PUB_CREDIT
	$QDL
	$LIMIT
);

%RESOURCE_MAP = (
	'worklist/credit' => {
			_title =>'Invoice Credit Balance Work List',
			_iconSmall =>'images/page-icons/worklist-collections',
			_iconMedium =>'images/page-icons/worklist-collections',
			_views => [
				{caption => 'Credit Balances', name=>'crbal'},
				{caption => 'Setup', name => 'setup',},
				],
		},
	);

$LIMIT =250;
$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'InvoiceCreditBalance.qdl');

$CREDITARL='/worklist/credit';

my $itemNamePrefix = 'WorkList-Credit-Setup';

%PUB_CREDIT = (
	name => 'crbal',
	columnDefn =>
		[
			{head => '#', dataFmt => '#{auto_row_number}#',},
			{id => 'person_id', head =>'Patient ID', hAlign=> 'left',dAlign => 'left',hint=>'#{person_name}#',url=>'/person/#{person_id}#/profile',dataFmt=>'#{person_id}#',},
			{head =>'Patient Name', hAlign=> 'left',dAlign => 'left',dataFmt=>'#{person_name}#',},
			{head =>'Invoice ID', colIdx=>'#{invoice_id}#', hAlign=> 'left',url =>'/invoice/#{invoice_id}#/summary'},
			{head => 'Credit Balance' , colIdx=>'#{balance}#', dformat => 'currency', dAlign => 'center'},
			{id => 'age', head => 'Age', dAlign => 'right',dataFmt=>'#{age}#'},
		],
	dnQuery => \&creditQuery,
	dnARLParams => ['invoice_id'],
	dnAncestorFmt => 'Credit Balance Worklist',
);

sub creditQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('balance','lessthan', 0);

	my @setupConditions = ();
	push(@setupConditions, $sqlGen->WHERE('invoice_status', 'isnot', 16));

	my ($fromDate, $toDate) = $self->getInvoiceDates();

	push(@setupConditions, $sqlGen->WHERE('invoice_date', 'between', $fromDate, $toDate)) if ($fromDate ne '' && $toDate ne '');
	push(@setupConditions, $sqlGen->WHERE('invoice_date', 'geall', $fromDate))  if ($fromDate ne '' && $toDate eq '');
	push(@setupConditions, $sqlGen->WHERE('invoice_date', 'leall', $toDate))  if ($fromDate eq '' && $toDate ne '');

	if (my @physicians = $self->getSelectedPhysicians())
	{
		push(@setupConditions, $sqlGen->WHERE('physician_id', 'oneof', @physicians));
	}

	if (my @facilities = $self->getServiceFacilities())
	{
		push(@setupConditions, $sqlGen->WHERE('service_facility_id', 'oneof', @facilities));
	}

	my @products = $self->getInsProducts();
	if (@products && $products[0] ne 'ALL')
	{
		push(@setupConditions, $sqlGen->WHERE('product_name', 'oneof', @products));
	}

	my $query = $sqlGen->AND($cond1, @setupConditions);

	$query->outColumns(
		'person_id',
		'person_name',
		'invoice_id',
		'balance',
		'age',
	);

	my $arrSorting = ["person_id", "age", "physician_id", "service_facility_id", "product_name"];
	my $arrOrder = ["Ascending", "Descending", "Ascending", "Ascending", "Ascending"];
	my $sorting = $self->getSorting;
	if ($sorting ne '')
	{
		$query->orderBy({id => $arrSorting->[$sorting-1], order => $arrOrder->[$sorting-1]}); #$arrSorting->[$sorting-1]);
	}

	return $query;
}

sub getInvoiceDates
{
	my ($self) = @_;

	my $dates = $STMTMGR_WORKLIST_CREDIT->getRowAsHash($self,	STMTMGRFLAG_NONE,
		'sel_worklist_credit_dates', $self->session('user_id'), $self->session('org_internal_id'), $itemNamePrefix . '-Dates');

	my $dateFrom = $dates->{value_date};
	my $dateTo =  $dates->{value_dateend};
	return ($dateFrom, $dateTo);
}

sub getSelectedPhysicians
{
	my ($self) = @_;

	my $physicianList = $STMTMGR_WORKLIST_CREDIT->getRowsAsHashList($self,	STMTMGRFLAG_NONE,
		'sel_worklist_credit_physician', $self->session('user_id'), $self->session('org_internal_id'), $itemNamePrefix . '-Physician');

	my @physicians = ();
	for (@$physicianList)
	{
		push(@physicians, $_->{value_text});
	}

	return @physicians ? @physicians : ('');
}

sub getServiceFacilities
{
	my ($self) = @_;

	my $facilityList = $STMTMGR_WORKLIST_CREDIT->getRowsAsHashList($self, STMTMGRFLAG_NONE,
		'sel_worklist_credit_org', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-Org');

	my @facilities = ();
	for (@$facilityList)
	{
		push(@facilities, $_->{value_text});
	}

	return @facilities ? @facilities : ('');
}

sub getInsProducts
{
	my ($self) = @_;

	my $productsAll = $STMTMGR_WORKLIST_CREDIT->getRowAsHash($self, STMTMGRFLAG_NONE,
		'sel_worklist_credit_all_products', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-Product');

	return ('ALL') if $productsAll->{value_int} == -1;

	my $productsList = $STMTMGR_WORKLIST_CREDIT->getRowsAsHashList($self, STMTMGRFLAG_NONE,
		'sel_worklist_credit_products', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-Product');

	my @products = ();
	for (@$productsList)
	{
		push(@products, $_->{product_name});
	}

	return @products ? @products : ('');
}

sub getSorting
{
	my ($self) = @_;

	my $sorting = $STMTMGR_WORKLIST_CREDIT->getRowAsHash($self,	STMTMGRFLAG_NONE,
		'sel_worklist_credit_sorting', $self->session('user_id'), $self->session('org_internal_id'), $itemNamePrefix . '-Sorting');
	return $sorting->{value_int};
}

sub prepare_view_setup
{
	my ($self) = @_;

	my $dialog = new App::Dialog::WorklistSetup::InvoiceCreditBalance(schema => $self->{schema});
	$self->addContent('<br>');
	$dialog->handle_page($self, 'add');
	return 1;
}

sub prepare_view_crbal
{
	my $self = shift;

	# Create html file tabs for each document type
	my $tabsHtml = $self->setupTabs();
	#If Refresh value has been set then try to get new invoices to add to the worklist
	if ($self->param('refresh')==1)
	{
		$self->refreshCreditWorkList($self->session('user_id'),$self->session('org_internal_id'));
	}
	# Create the work list dialog
	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUB_CREDIT, topHtml => $tabsHtml, page => $self);

	my $dlgHtml = $dlg->getHtml($self, 'add');
	$self->addContent($dlgHtml);
}

sub setupTabs
{
	my $self = shift;
	my $RESOURCES = \%App::ResourceDirectory::RESOURCES;

	my $children = $self->getChildResources($RESOURCES->{'page-worklist'}->{'collection'});

	my @tabs = ();
	foreach my $child (keys %$children)
	{
		my $childRes = $children->{$child};
		my $id = $childRes->{_id};
		$id =~ s/^page\-//;
		my $caption = defined $childRes->{_tabCaption} ? $childRes->{_tabCaption} : (defined $childRes->{_title} ? $childRes->{_title} : 'caption');
		push @tabs, [ $caption, "/$id", $id ];
	}

	push @tabs, [ 'Refresh Work List', "$CREDITARL?refresh=1", $CREDITARL ];
	my $tabsHtml = $self->getMenu_Tabs(
		App::Page::MENUFLAGS_DEFAULT,
		'arl_resource',
		\@tabs,
		{
			selColor => '#CDD3DB',
			selTextColor => 'black',
			unselColor => '#E5E5E5',
			unselTextColor => '#555555',
			highColor => 'navy',
			leftImage => 'images/design/tab-top-left-corner-white',
			rightImage => 'images/design/tab-top-right-corner-white'
		}
	);

	return [qq{<br><div align="left"><table border="0" cellspacing="0" cellpadding="0" bgcolor="white"><tr>$tabsHtml</tr></table></div>}];
}

####################################
#Refresh the worklist with new data
####################################
sub refreshCreditWorkList
{
	my ($self, $user_id, $org_internal_id) = @_;
}


sub handleARL
{
        my ($self, $arl, $params, $rsrc, $pathItems) = @_;

        unless($self->arlHasStdAction($rsrc, $pathItems, 1))
        {
                $self->param('_pm_view', $pathItems->[1] || 'crbal');
        };

		$self->param('_dialogreturnurl', $CREDITARL);
        $self->printContents();
        return 0;
}

sub getContentHandlers
{
     return ('prepare_view_$_pm_view=crbal$');
}

sub initialize
{
        my $self = shift;
        $self->SUPER::initialize(@_);

        $self->addLocatorLinks(
                ['Credit Balances', $CREDITARL],
        );

        # Check user's permission to page
        my $activeView = $self->param('_pm_view');
        if ($activeView)
        {
                unless($self->hasPermission("page/worklist/credit"))
                {
                        $self->disable(qq{<br>
                                You do not have permission to view this information.
                                Permission page/worklist/verify is required.
                                Click <a href='javascript:history.back()'>here</a> to go back.
                        });
                }
        }
}

1;