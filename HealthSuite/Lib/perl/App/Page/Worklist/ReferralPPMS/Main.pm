##############################################################################
package App::Page::Worklist::ReferralPPMS::Main;
##############################################################################

use strict;
use Date::Manip;
use Date::Calc qw(:all);

use App::Configuration;
use App::ImageManager;
use App::Dialog::WorklistSetup;

use CGI::Dialog::DataNavigator;
use SQL::GenerateQuery;

use DBI::StatementManager;
use App::Statements::Worklist::InvoiceCreditBalance;
use App::Statements::Worklist::WorklistCollection;
use Data::Publish;
use CGI::ImageManager;
use App::Page::Worklist::ReferralPPMS;

use base qw(App::Page::Worklist::ReferralPPMS);

use vars qw(
	%RESOURCE_MAP
	%PUB_REFERRAL
	$QDL
);

%RESOURCE_MAP = (
	'worklist/referralppms/main' => {
		_idSynonym => ['_default'],
		_title => 'Referrals Work List',
		_iconSmall => 'images/page-icons/worklist-patient-flow',
		_iconMedium => 'images/page-icons/worklist-patient-flow',
		_iconLarge => 'images/page-icons/worklist-patient-flow',
		_tabcaption => 'Referrals Work List',
		_views => [
				{caption => 'Work List' , name => 'main',},
				{caption => 'Setup', name => 'setup',},
			],
		},
	);

$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'ReferralPPMS.qdl');

my $itemNamePrefix = 'Referral-Worklist-Setup';

########################################################
# Worklist Data
########################################################

%PUB_REFERRAL = (
	name => 'referral',
	bodyRowAttr => {
		class => 'referral_#{referral_urgency}#'},
	columnDefn =>
		[
			{head => '#', dataFmt => '#{auto_row_number}#',},
			{head => 'Request Date', dAlign => 'center',colIdx=>'#{request_date}#'},
			{head => 'Patient ID', hAlign=> 'left',dAlign => 'left',hint=>'#{name}#',url=>'/worklist/referralppms/dlg-update-referral-ppms/#{referral_id}#/#{person_id}#',dataFmt=>'#{person_id}#',},
#			{head => 'Patient Name', hAlign=> 'left',dAlign => 'left',dataFmt=>'#{name}#',},
			{head => 'Physician', colIdx=>'#{requester_id}#', hAlign=> 'left',},
			{head => 'Insurance Org', colIdx=>'#{ins_org}#', hAlign=> 'left',},
			{head => 'Product', dAlign => 'left', dataFmt=>'#{product_name}#' },
			{head => 'Speciality' , colIdx=>'#{speciality}#', dAlign => 'left', },
			{head => 'Begin Date' , colIdx=>'#{referral_begin_date}#', dAlign => 'center', },
			{head => 'End Date' , colIdx=>'#{referral_end_date}#', dAlign => 'center', },

			{head => "Actions", dAlign => 'left' ,
			   dataFmt => qq{
					<A HREF="/worklist/referralppms/dlg-add-referral-notes/#{person_id}#/#{referral_id}#/#{requester_id}#"
						TITLE='Add Referral Notes'>
						<IMG SRC='/resources/icons/coll-account-notes.gif' BORDER=0></A>
					<A HREF="/worklist/referralppms/dlg-add-transfer-referral/#{person_id}#/#{referral_id}#/#{requester_id}#"
						TITLE='Transfer Referral to another person'>
						<IMG SRC='/resources/icons/coll-transfer-account.gif' BORDER=0></A>
					<A HREF="/worklist/referralppms/dlg-add-referral-reck-date/#{person_id}#/#{referral_id}#/#{requester_id}#"
						TITLE='Add Recheck Date'>
						<IMG SRC='/resources/icons/coll-reck-date.gif' BORDER=0></A>
					<A HREF="/worklist/referralppms/dlg-add-close-referral/#{person_id}#/#{referral_id}#/#{requester_id}#"
						TITLE='Close Referral'>
						<IMG SRC='/resources/icons/coll-close-account.gif' BORDER=0></A>
					},

			},

	],
	dnQuery => \&referralQuery,
	dnAncestorFmt => 'Referrals Worklist',
	dnARLParams => ['referral_id'],
);


########################################################
# Referral Worklist Query
########################################################
sub referralQuery
{
	my $self = shift;
	my $date=  UnixDate('tomorrow','%d-%b-%y');
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('user_id', 'is', $self->session('user_id'));
	my $cond2 = $sqlGen->WHERE('recheck_date','lessthan',$date);
	my $cond3 = $sqlGen->WHERE('recheck_date', 'isnotdefined');
	my $cond4 = $sqlGen->OR($cond2,$cond3);

	my $cond5 = $sqlGen->WHERE('referral_status', 'isnotdefined');
	my $cond6 = $sqlGen->WHERE('referral_status', 'is', 0);
	my $cond7 = $sqlGen->OR($cond5,$cond6);

	my @setupConditions = ();
	push(@setupConditions, $cond4);
	push(@setupConditions, $cond7);

	if (my @physicians = $self->getSelectedPhysicians())
	{
		push(@setupConditions, $sqlGen->WHERE('requester_id', 'oneof', @physicians));
	}

	my @products = $self->getInsProducts();
	if (@products && $products[0] ne 'ALL')
	{
		push(@setupConditions, $sqlGen->WHERE('product_name', 'oneof', @products));
	}

	my ($lnFrom, $lnTo) = $self->getLastNameRange();
	push(@setupConditions, $sqlGen->WHERE('name_last', 'geall', $lnFrom)) if $lnFrom;
	push(@setupConditions, $sqlGen->WHERE('name_last', 'leall', $lnTo . 'ZZZZ')) if $lnTo;

	my $query = $sqlGen->AND($cond1, @setupConditions);
	$query->outColumns(
		'request_date',
		'person_id',
		'name',
		'ins_org',
		'product_name',
		'requester_id',
		'speciality',
		'referral_begin_date',
		'referral_end_date',
		'referral_urgency',
		'referral_id',
		'recheck_date'
	);

	my $arrSorting = ['ins_org', 'product_name', 'speciality', 'request_date'];
	my $arrOrder = ['Ascending', 'Ascending', 'Ascending', 'Ascending'];
	my $sorting = $self->getSorting;
	if ($sorting ne '')
	{
		$query->orderBy({id => 'referral_urgency', order => 'Ascending'},
						{id => $arrSorting->[$sorting-1], order => $arrOrder->[$sorting-1]});
	}

	return $query;
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

sub getLastNameRange
{
	my ($self) = @_;

	my $lastNameRange = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($self, STMTMGRFLAG_NONE,
		'sel_worklist_lastname_range2', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-LNameRange');
	return ($lastNameRange->{value_text} || undef, $lastNameRange->{lnameto} || undef);
}

sub getSorting
{
	my ($self) = @_;

	my $sorting = $STMTMGR_WORKLIST_CREDIT->getRowAsHash($self,	STMTMGRFLAG_NONE,
		'sel_worklist_credit_sorting', $self->session('user_id'), $self->session('org_internal_id'), $itemNamePrefix . '-Sorting');
	return $sorting->{value_int};
}

sub getExpiryDays
{
	my ($self) = @_;

	my $expiry = $STMTMGR_WORKLIST_CREDIT->getRowAsHash($self,	STMTMGRFLAG_NONE,
		'sel_worklist_credit_sorting', $self->session('user_id'), $self->session('org_internal_id'), $itemNamePrefix . '-ExpiryDays');
	return $expiry->{value_int};
}


########################################################
# Worklist view
########################################################
sub prepare_view_main
{
	my $self = shift;

	my $tabsHtml = $self->setupTabs();

	# Create the work list dialog
	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUB_REFERRAL, topHtml => $tabsHtml, page => $self);
	my $dlgHtml = $dlg->getHtml($self, 'add');

	$self->addContent(
		q{
			<STYLE>
				.referral_ {}
				.referral_0 {background-color: TAN;}
				.referral_1 {background-color: #EEEEEE;}
				.referral_2 {background-color: BEIGE;}
			</STYLE>
		},
		$dlgHtml
	);


}

########################################################
# Worklist Setup View
########################################################
sub prepare_view_setup
{
	my ($self) = @_;

	my $dialog = new App::Dialog::WorklistSetup::ReferralPPMS(schema => $self->{schema});
	$self->addContent('<br>');
	$dialog->handle_page($self, 'add');
	return 1;
}



1;
