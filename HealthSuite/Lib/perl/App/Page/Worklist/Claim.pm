##############################################################################
package App::Page::Worklist::Claim;
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
use App::Statements::Worklist::WorklistCollection;

use Data::Publish;
use CGI::ImageManager;

use base qw{App::Page::WorkList};

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'worklist/claim' => {
		_views => [
			{caption => 'WorkList', name => 'wl',},
			{caption => 'Setup', name => 'setup',},
			],

		_title => 'Claims Work List',
		_iconSmall => 'images/page-icons/worklist-referral',
		_iconMedium => 'images/page-icons/worklist-referral',
		_iconLarge => 'images/page-icons/worklist-referral',
		},
	);

my $baseArl = '/worklist/claim';

my $QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'ClaimWorkList.qdl');

my %pubDefn = (
	name => 'claim',
	columnDefn => [
		{head => '#', dataFmt => '#{auto_row_number}#',},

		{head => 'ACTIONS', options => PUBLCOLFLAG_DONTWRAP,
			dataFmt => qq{
				<a href="/invoice/#{invoice_id}#/dlg-add-claim-notes"
					title='Add Claim Notes'>$IMAGETAGS{'icons/black_n'}</a>
				<a href="$baseArl/dlg-add-transfer-claims-wl-invoice/#{invoice_id}#" title='Transfer Invoice #{invoice_id}#'>$IMAGETAGS{'icons/black_t'}</a>
				<a href="$baseArl/dlg-add-reckdate-claims-wl-invoice/#{invoice_id}#" title='Recheck Date'>$IMAGETAGS{'icons/black_r'}</a>
				<a href="$baseArl/resubmit/#{invoice_id}#" title='Re-Submit Claim #{invoice_id}#'>$IMAGETAGS{'icons/black_s'}</a>
				<a href="$baseArl/dlg-add-close-claims-wl-invoice/#{invoice_id}#" title='Close Invoice #{invoice_id}#'>$IMAGETAGS{'icons/black_c'}</a>
			},
		},
		{	head => 'Patient', dataFmt => '<a href="/person/#{patient_id}#/account" title="View #{patient_id}# Account">#{patient_name}#</a>',
			hAlign => 'left', options => PUBLCOLFLAG_DONTWRAP,
		},
		{head => 'Claim ID', dataFmt => '<a href="/invoice/#{invoice_id}#/history" title="View Claim #{invoice_id}# History">#{invoice_id}#</a>',},
		{	head => 'Ins Org ID', dataFmt => '<a href="/org/#{ins_org_id}#/profile" title="View #{ins_org_id}# Profile">#{ins_org_id}#</a>',
			hAlign => 'left',
		},
		{head => 'Carrier Phone', dataFmt => '#{ins_phone}#', options => PUBLCOLFLAG_DONTWRAP,},
		{head => 'Claim Status', dataFmt => '#{invoice_status}#', dAlign => 'center'},
		{head => 'Balance', colIdx => '#{balance}#', dformat => 'currency'},
		{head => 'Age', dataFmt => '#{invoice_age}#',},
		{head => 'DOS', colIdx => '#{invoice_date}#', dformat => 'date'},
		{head => 'Member ID', dataFmt => '#{member_number}#', options => PUBLCOLFLAG_DONTWRAP,},
	],
	dnAncestorFmt => 'Insurance Claims',
	dnQuery => \&claimQuery,
	dnOutRows => 20,
);

my $itemNamePrefix = 'WorkList-Claims-Setup';

sub claimQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $query = $sqlGen->WHERE('owner_id', 'is', $self->session('org_internal_id'));

	$query->outColumns(
		'patient_id',
		'invoice_id',
		'ins_org_id',
		'ins_phone',
		'invoice_status',
		'balance',
		'invoice_age',
		'invoice_date',
		'member_number',
		'patient_name',
	);

	return $query;
}

sub prepare_view_resubmit
{
	my ($self) = @_;

	my $invoiceId = $self->param('invoice_id');

	$self->addContent(qq{
		<h3><u>Resubmit Claim</u></h3>
		<font face=Verdana size=3>
		This function will resubmit Claim <b>$invoiceId</b>. &nbsp;
		Click here to <a href="/invoice/$invoiceId/submit?resubmit=2"> resubmit</a>.
		</font>
	});
	return 1;
}

sub prepare_view_wl
{
	my ($self) = @_;

	my ($sqlStmt, $bindParams) = $self->buildSqlStmt();

	my $dlg = new CGI::Dialog::DataNavigator(
		publDefn => \%pubDefn,
		page => $self,
		sqlStmt => $sqlStmt,
		bindParams => $bindParams,
	);
	my $dlgHtml = $dlg->getHtml($self, 'sql');

	$self->addContent($dlgHtml);
}

sub buildSqlStmt
{
	my ($self) = @_;

	my $arrSorting = [11,5,6];
	my $sorting = $arrSorting->[$self->getSorting() - 1];

	my $sqlStmt = qq{
		Select *
		From (
			SELECT
				invoice.client_id AS patient_id,
				invoice.invoice_id AS invoice_id,
				org.org_id AS ins_org_id,
				org_attribute.value_text AS ins_phone,
				invoice_status.caption AS invoice_status,
				invoice.balance,
				trunc(sysdate - invoice.invoice_date) AS invoice_age,
				TO_CHAR(invoice.invoice_date,'IYYYMMDD') AS invoice_date,
				insurance.member_number AS member_number,
				initcap(simple_name) as patient_name,
				name_last
			FROM
				person,
				transaction,
				org_attribute,
				org,
				invoice_status,
				insurance,
				invoice_billing,
				invoice
			WHERE
				(invoice.owner_id = ?)
				AND (invoice_billing.bill_id = invoice.billing_id)
				AND (insurance.ins_internal_id = invoice_billing.bill_ins_id)
				AND (invoice_status.id = invoice.invoice_status)
				AND (org.org_internal_id = invoice_billing.bill_to_id)
				AND (org_attribute.parent_id (+) = org.org_internal_id and org_attribute.value_type (+) = 10
					and org_attribute.item_name (+) = 'Primary')
				AND (transaction.trans_id = invoice.main_transaction)
				AND (transaction.care_provider_id in (select value_text from person_attribute
					where parent_id = ? and parent_org_id = ? and item_name = ?))
				AND (to_char(transaction.service_facility_id) in (select value_text from person_attribute
					where parent_id = ? and parent_org_id = ? and item_name = ?))
				AND (invoice.invoice_status in (select value_int from person_attribute
					where parent_id = ? and parent_org_id = ? and item_name = ?))
				AND (person.person_id = invoice.client_id)
				insuranceProductsConstraints
				lastNameFromConstraint
				lastNameToConstraint
				balanceFromConstraint
				balanceToConstraint
				ageFromConstraint
				ageToConstraint
				AND NOT exists (select 'x' from invoice_worklist iw where iw.invoice_id = invoice.invoice_id
					and (iw.worklist_status = 'CLOSED'
						or (iw.reck_date > sysdate and iw.responsible_id = ?)
						or (iw.owner_id = ? and iw.worklist_status = 'TRANSFERRED')
					)
				)
		UNION
			SELECT
				invoice.client_id AS patient_id,
				invoice.invoice_id AS invoice_id,
				org.org_id AS ins_org_id,
				org_attribute.value_text AS ins_phone,
				invoice_status.caption AS invoice_status,
				invoice.balance,
				trunc(sysdate - invoice.invoice_date) AS invoice_age,
				TO_CHAR(invoice.invoice_date,'IYYYMMDD') AS invoice_date,
				insurance.member_number AS member_number,
				initcap(simple_name) as patient_name,
				name_last
			FROM
				person,
				org_attribute,
				org,
				invoice_status,
				insurance,
				invoice_billing,
				invoice_worklist,
				invoice
			WHERE
				(invoice.owner_id = ?)
				AND (invoice_worklist.invoice_id = invoice.invoice_id)
				AND (invoice_worklist.worklist_status = 'TRANSFERRED')
				AND (invoice_worklist.worklist_type = 'CLAIMS')
				AND (invoice_worklist.responsible_id = ?)
				AND (invoice_billing.bill_id = invoice.billing_id)
				AND (insurance.ins_internal_id = invoice_billing.bill_ins_id)
				AND (invoice_status.id = invoice.invoice_status)
				AND (to_char(org.org_internal_id) = invoice_billing.bill_to_id)
				AND (org_attribute.parent_id = org.org_internal_id and org_attribute.value_type = 10
					and org_attribute.item_name = 'Primary')
				AND NOT exists (select 'x' from invoice_worklist iw where iw.invoice_id = invoice.invoice_id
					and (iw.worklist_status = 'CLOSED'
						or (iw.reck_date > sysdate and iw.responsible_id = ?)
						or (iw.owner_id = ? and iw.worklist_status = 'TRANSFERRED' and iw.invoice_worklist_id =
							(select max(iw1.invoice_worklist_id) from invoice_worklist iw1 where
								iw1.invoice_id = iw.invoice_id
								and iw1.worklist_status = iw.worklist_status)
						)
					)
				)
				AND person.person_id = invoice.client_id
			) unionized
			ORDER BY $sorting
	};

	my $orgInternalId = $self->session('org_internal_id');
	my $userId = $self->session('user_id');

	my @bindParams = (
		$orgInternalId,
		$userId,
		$orgInternalId,
		$itemNamePrefix . '-Physician',
		$userId,
		$orgInternalId,
		$itemNamePrefix . '-Org',
		$userId,
		$orgInternalId,
		$itemNamePrefix . '-ClaimStatus',
	);

	my @products = $self->getInsProducts();
	if (@products && $products[0] ne 'ALL')
	{
		my $insProductsWhereClause = qq{
			AND (insurance.product_name in (select product_name from insurance where ins_internal_id in
			(select value_int from person_attribute where parent_id = ? and parent_org_id = ?
			and item_name = ?)))
		};

		push(@bindParams, $userId, $orgInternalId, $itemNamePrefix . '-Product');
		$sqlStmt =~ s/insuranceProductsConstraints/$insProductsWhereClause/;
	}
	else
	{
		$sqlStmt =~ s/insuranceProductsConstraints//;
	}

	my ($lnFrom, $lnTo) = $self->getLastNameRange();

	if ($lnFrom)
	{
		my $lastNameFromWhereClause = qq{AND upper(person.name_last) >= ?};
		$sqlStmt =~ s/lastNameFromConstraint/$lastNameFromWhereClause/;
		push(@bindParams, uc($lnFrom));
	}
	else
	{
		$sqlStmt =~ s/lastNameFromConstraint//;
	}

	if ($lnTo)
	{
		my $lastNameToWhereClause = qq{AND upper(person.name_last) <= ?};
		$sqlStmt =~ s/lastNameToConstraint/$lastNameToWhereClause/;
		push(@bindParams, uc($lnTo) . 'ZZZZ');
	}
	else
	{
		$sqlStmt =~ s/lastNameToConstraint//;
	}

	my ($balanceFrom, $balanceTo) = $self->getBalanceAmountRange();

	if ($balanceFrom)
	{
		$sqlStmt =~ s/balanceFromConstraint/AND invoice.balance >= \?/;
		push(@bindParams, $balanceFrom);
	}
	else
	{
		$sqlStmt =~ s/balanceFromConstraint//;
	}

	if ($balanceTo)
	{
		$sqlStmt =~ s/balanceToConstraint/AND invoice.balance <= \?/;
		push(@bindParams, $balanceTo);
	}
	else
	{
		$sqlStmt =~ s/balanceToConstraint//;
	}

	my ($ageFrom, $ageTo) = $self->getBalanceAgeRange();

	if ($ageFrom)
	{
		$sqlStmt =~ s/ageFromConstraint/AND invoice.invoice_date <= trunc(sysdate) - ?/;
		push(@bindParams, $ageFrom);
	}
	else
	{
		$sqlStmt =~ s/ageFromConstraint//;
	}

	if ($ageTo)
	{
		$sqlStmt =~ s/ageToConstraint/AND invoice.invoice_date >= trunc(sysdate) - ?/;
		push(@bindParams, $ageTo);
	}
	else
	{
		$sqlStmt =~ s/ageToConstraint//;
	}

	push(@bindParams, $userId, $userId, $orgInternalId, $userId, $userId, $userId); # last 6 params
	return ($sqlStmt, \@bindParams);
}

sub getInsProducts
{
	my ($self) = @_;

	my $productsAll = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($self, STMTMGRFLAG_NONE,
		'sel_worklist_all_products', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-Product');

	return ('ALL') if $productsAll->{value_int} == -1;

	my $productsList = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($self, STMTMGRFLAG_NONE,
		'sel_worklist_associated_products', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-Product');

	my @products = ();
	for (@$productsList)
	{
		push(@products, $_->{product_name});
	}

	return @products ? @products : ('');
}

sub getClaimStatuses
{
	my ($self) = @_;

	my $claimStatusList = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($self, STMTMGRFLAG_NONE,
		'sel_worklist_claim_status', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-ClaimStatus');

	my @claimStats = ();
	for (@$claimStatusList)
	{
		push(@claimStats, $_->{status_id});
	}

	return @claimStats ? @claimStats : ('');
}

sub getBalanceAgeRange
{
	my ($self) = @_;

	my $balanceAgeRange = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($self, STMTMGRFLAG_NONE,
		'sel_worklist_balance_age_range', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-BalanceAge-Range');

	return ($balanceAgeRange->{value_int} || undef, $balanceAgeRange->{balance_age_to} || undef);
}

sub getBalanceAmountRange
{
	my ($self) = @_;

	my $balanceAmountRange = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($self, STMTMGRFLAG_NONE,
		'sel_worklist_balance_amount_range', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-BalanceAmount-Range');

	return ($balanceAmountRange->{value_float} || undef, $balanceAmountRange->{balance_amount_to} || undef);
}

sub getLastNameRange
{
	my ($self) = @_;

	my $lastNameRange = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($self, STMTMGRFLAG_NONE,
		'sel_worklist_lastname_range2', $self->session('user_id'), $self->session('org_internal_id'),
		'WorkList-Claims-Setup-LnameRange');

	 return ($lastNameRange->{value_text} || undef, $lastNameRange->{lnameto} || undef);
}

sub getSelectedPhysicians
{
	my ($self) = @_;

	my $physicianList = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($self,	STMTMGRFLAG_NONE,
		'sel_worklist_associated_physicians', $self->session('user_id'), $itemNamePrefix . '-Physician');

	my @physicians = ();
	for (@$physicianList)
	{
		push(@physicians, $_->{person_id});
	}

	return @physicians ? @physicians : ('');
}

sub getServiceFacilities
{
	my ($self) = @_;

	my $facilityList = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($self, STMTMGRFLAG_NONE,
		'sel_worklist_facilities', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-Org');

	my @facilities = ();
	for (@$facilityList)
	{
		push(@facilities, $_->{facility_id});
	}

	return @facilities ? @facilities : ('');
}

sub getSorting
{
	my ($self) = @_;

	my $sorting = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($self,	STMTMGRFLAG_NONE,
		'sel_worklist_claim_status', $self->session('user_id'), $self->session('org_internal_id'),
		$itemNamePrefix . '-Sorting');
	return $sorting->{status_id};
}

sub prepare_view_setup
{
	my ($self) = @_;

	my $dialog = new App::Dialog::WorklistSetup::Claim(schema => $self->{schema});
	$self->addContent('<br>');
	$dialog->handle_page($self, 'add');
	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);
	return 1 if $self->param('_pm_view') eq 'setup';
	return 1 if $self->param('_stdAction') eq 'dialog';

	$self->SUPER::prepare_page_content_footer(@_);

	return 1;
}

sub prepare_page_content_header
{
	my $self = shift;

	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);
	$self->SUPER::prepare_page_content_header(@_);

	return 1 if $self->param('_stdAction') eq 'dialog';
	return 1;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->addLocatorLinks(
		['Claims', '/worklist/claim'],
	);

	# Check user's permission to page
	my $activeView = $self->param('_pm_view');
	if ($activeView)
	{
		unless($self->hasPermission("page/worklist/claim"))
		{
			$self->disable(qq{<br>
				You do not have permission to view this information.
				Permission page/worklist/verify is required.
				Click <a href='javascript:history.back()'>here</a> to go back.
			});
		}
	}
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1] || 'wl');
		$self->param('invoice_id', $pathItems->[2]) if $pathItems->[2];
	}

	$self->param('_dialogreturnurl', $baseArl);
	$self->printContents();
	return 0;
}

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=wl$');
}

sub __claimQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('owner_id', 'is', $self->session('org_internal_id'));
	my $cond2 = $sqlGen->WHERE('invoice_subtype', 'isnot', 0);
	my $cond3 = $sqlGen->WHERE('invoice_subtype', 'isnot', 7);

	my @setupConditions = ();

	if (my @physicians = $self->getSelectedPhysicians())
	{
		push(@setupConditions, $sqlGen->WHERE('physician_id', 'oneof', @physicians));
	}

	if (my @facilities = $self->getServiceFacilities())
	{
		push(@setupConditions, $sqlGen->WHERE('service_facility', 'oneof', @facilities));
	}

	my ($lnFrom, $lnTo) = $self->getLastNameRange();
	push(@setupConditions, $sqlGen->WHERE('name_last', 'geall', $lnFrom)) if $lnFrom;
	push(@setupConditions, $sqlGen->WHERE('name_last', 'leall', $lnTo . 'ZZZZ')) if $lnTo;

	my ($balanceFrom, $balanceTo) = $self->getBalanceAmountRange();
	push(@setupConditions, $sqlGen->WHERE('balance', 'geall', $balanceFrom)) if $balanceFrom;
	push(@setupConditions, $sqlGen->WHERE('balance', 'leall', $balanceTo)) if $balanceTo;

	if (my @claimStats = $self->getClaimStatuses())
	{
		push(@setupConditions, $sqlGen->WHERE('inv_status', 'oneof', @claimStats));
	}

	my @products = $self->getInsProducts();
	if (@products && $products[0] ne 'ALL')
	{
		push(@setupConditions, $sqlGen->WHERE('product_name', 'oneof', @products));
	}

	my ($ageFrom, $ageTo) = $self->getBalanceAgeRange();
	push(@setupConditions, $sqlGen->WHERE('invoice_age', 'geall', $ageFrom)) if $ageFrom;
	push(@setupConditions, $sqlGen->WHERE('invoice_age', 'leall', $ageTo)) if $ageTo;

	my $query = $sqlGen->AND($cond1, $cond2, $cond3, @setupConditions);
	$query->outColumns(
		'patient_id',
		'invoice_id',
		'ins_org_id',
		'ins_phone',
		'invoice_status',
		'balance',
		'invoice_age',
		'invoice_date',
		'member_number',
	);

	my $arrSorting = ['name_last', 'invoice_status', 'balance'];
	my $arrOrder = ['Ascending', 'Ascending', 'Ascending'];
	my $sorting = $self->getSorting;
	if ($sorting ne '')
	{
		$query->orderBy({id => $arrSorting->[$sorting-1], order => $arrOrder->[$sorting-1]});
	}

	return $query;
}

1;
