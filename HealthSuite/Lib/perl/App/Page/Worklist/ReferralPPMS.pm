##############################################################################
package App::Page::Worklist::ReferralPPMS;
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

use base qw{App::Page::WorkList};

use vars qw(
	$REFERRALARL
	%RESOURCE_MAP
	%PUB_REFERRAL
	%PUB_REFERRAL_EXP
	$QDL
	$LIMIT
);

%RESOURCE_MAP = (
	'worklist/referralPPMS' => {
			_title =>'Referrals Work List',
			_iconSmall =>'images/page-icons/worklist-patient-flow',
			_iconMedium =>'images/page-icons/worklist-patient-flow',
			_views => [
				{caption => 'Referrals Work List' , name=>'wl'},
#				{caption => 'Referral Expiry Items' , name=>'exp'},
				{caption => 'Setup', name => 'setup',},
				],
		},
	);

$LIMIT =250;
$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'ReferralPPMS.qdl');

$REFERRALARL='/worklist/referralPPMS';
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
			{head => 'Patient ID', hAlign=> 'left',dAlign => 'left',hint=>'#{name}#',url=>'/person/#{person_id}#/profile',dataFmt=>'#{person_id}#',},
#			{head => 'Patient Name', hAlign=> 'left',dAlign => 'left',dataFmt=>'#{name}#',},
			{head => 'Physician', colIdx=>'#{requester_id}#', hAlign=> 'left',},
			{head => 'Insurance Org', colIdx=>'#{ins_org}#', hAlign=> 'left',},
			{head => 'Product', dAlign => 'center', dataFmt=>'#{product_name}#' },
			{head => 'Speciality' , colIdx=>'#{speciality}#', dAlign => 'center', },
			{head => 'Begin Date' , colIdx=>'#{referral_begin_date}#', dAlign => 'center', },
			{head => 'End Date' , colIdx=>'#{referral_end_date}#', dAlign => 'center', },

			{head => "Actions", dAlign => 'left' ,
			   dataFmt => qq{
					<A HREF=""
						TITLE='Add Referral Notes'>
						<IMG SRC='/resources/icons/coll-account-notes.gif' BORDER=0></A>
					<A HREF=""
						TITLE='Transfer Referral to another person'>
						<IMG SRC='/resources/icons/coll-transfer-account.gif' BORDER=0></A>
					<A HREF=""
						TITLE='Add Recheck Date'>
						<IMG SRC='/resources/icons/coll-reck-date.gif' BORDER=0></A>
					<A HREF=""
						TITLE='Close Referral'>
						<IMG SRC='/resources/icons/coll-close-account.gif' BORDER=0></A>
					},

			},

	],
	dnQuery => \&referralQuery,
	dnAncestorFmt => 'Referrals Worklist',
);

%PUB_REFERRAL_EXP = (
	name => 'referral_exp',
	bodyRowAttr => {
		class => 'referral_#{referral_urgency}#'},
	columnDefn =>
		[
			{head => '#', dataFmt => '#{auto_row_number}#',},
			{head => 'Request Date', dAlign => 'center',colIdx=>'#{request_date}#'},
			{head => 'Patient ID', hAlign=> 'left',dAlign => 'left',hint=>'#{name}#',url=>'/person/#{person_id}#/profile',dataFmt=>'#{person_id}#',},
			{head => 'Physician', colIdx=>'#{requester_id}#', hAlign=> 'left',},
			{head => 'Insurance Org', colIdx=>'#{ins_org}#', hAlign=> 'left',},
			{head => 'Product', dAlign => 'center', dataFmt=>'#{product_name}#' },
			{head => 'Speciality' , colIdx=>'#{speciality}#', dAlign => 'center', },
			{head => 'Begin Date' , colIdx=>'#{referral_begin_date}#', dAlign => 'center', },
			{head => 'End Date' , colIdx=>'#{referral_end_date}#', dAlign => 'center', },

			{head => "Actions", dAlign => 'left' ,
			   dataFmt => qq{
						<IMG SRC='/resources/icons/coll-account-notes.gif' BORDER=0>
						<IMG SRC='/resources/icons/coll-transfer-account.gif' BORDER=0>
						<IMG SRC='/resources/icons/coll-reck-date.gif' BORDER=0>
						<IMG SRC='/resources/icons/coll-close-account.gif' BORDER=0>
					},

			},

	],
	dnQuery => \&referralExpQuery,
	dnAncestorFmt => 'Expiring Referrals Worklist',
);

########################################################
# Referral Worklist Query
########################################################
sub referralQuery
{
	my $self = shift;
#	my $date=  UnixDate('tomorrow','%d-%b-%y');
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('completion_date', 'isnotdefined');
	my @setupConditions = ();

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
		'referral_urgency'
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

########################################################
# Expiring Referrals Query
########################################################
sub referralExpQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('completion_date', 'isnotdefined');
	my @setupConditions = ();

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

	my $expiryDays = $self->getExpiryDays;
	push(@setupConditions, $sqlGen->WHERE('expiryDays', 'leall', $expiryDays)) if $expiryDays;

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
		'referral_urgency'
	);

	my $arrSorting = ["ins_org", "product_name", "speciality", "request_date"];
	my $arrOrder = ["Ascending", "Ascending", "Ascending", "Ascending"];
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

########################################################
# Worklist view
########################################################
sub prepare_view_wl
{
	my $self = shift;

	my $tabsHtml = $self->setupTabs();

	# Create the work list dialog
	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUB_REFERRAL,
	topHtml => $tabsHtml,
	page => $self);
	my $dlgHtml = $dlg->getHtml($self, 'add');

	$self->addContent(
		q{
			<STYLE>
				.referral_ {}
				.referral_1 {background-color: BEIGE;}
				.referral_2 {background-color: #EADCCE;}
				.referral_3 {background-color: #EEEEEE;}
			</STYLE>
		},
		$dlgHtml
	);

}

########################################################
# Expiry view
########################################################
sub prepare_view_exp
{
	my $self = shift;

	my $tabsHtml = $self->setupTabs();

	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUB_REFERRAL_EXP,
		topHtml => $tabsHtml,
		page => $self);
	my $dlgHtml = $dlg->getHtml($self, 'add');

	$self->addContent(
		q{
			<STYLE>
				.referral_ {}
				.referral_1 {background-color: BEIGE;}
				.referral_2 {background-color: #EADCCE;}
				.referral_3 {background-color: #EEEEEE;}
			</STYLE>
		},
		$dlgHtml
	);
}

########################################################
# Setup Tabs for  Worklist
########################################################
sub setupTabs
{
	my $self = shift;
	my $RESOURCES = \%App::ResourceDirectory::RESOURCES;

	my $children = $self->getChildResources($RESOURCES->{'page-worklist'}->{'referralPPMS'});

	my @tabs = ();
#	foreach my $child (keys %$children)
#	{
#		my $childRes = $children->{$child};
#		my $id = $childRes->{_id};
#		$id =~ s/^page\-//;
#		my $caption = defined $childRes->{_tabCaption} ? $childRes->{_tabCaption} : (defined $childRes->{_title} ? $childRes->{_title} : 'caption');
#		push @tabs, [ $caption, "/$id", $id ];
#	}

	push @tabs, [ 'Referrals Work List', "$REFERRALARL?refresh=1", $REFERRALARL ];
	push @tabs, [ 'Expiring Referrals Work List', "$REFERRALARL" . '/exp', $REFERRALARL ];
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


########################################################
# Handle the page display
########################################################
sub handleARL
{
        my ($self, $arl, $params, $rsrc, $pathItems) = @_;

        unless($self->arlHasStdAction($rsrc, $pathItems, 1))
        {
                $self->param('_pm_view', $pathItems->[1] || 'wl');
        };

        #If the refresh option is not set then set refresh param to zero
        unless($params=~m/refresh=1/)
        {
        	$self->param('refresh',0) ;
        }
        $self->param('_dialogreturnurl', $REFERRALARL);
        $self->printContents();
        return 0;
}


sub getContentHandlers
{
     return ('prepare_view_$_pm_view=wl$');
}


sub initialize
{
        my $self = shift;
        $self->SUPER::initialize(@_);

        $self->addLocatorLinks(
                ['ReferralPPMS', $REFERRALARL],
        );

        # Check user's permission to page
        my $activeView = $self->param('_pm_view');
        if ($activeView)
        {
                unless($self->hasPermission("page/worklist/referralPPMS"))
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
