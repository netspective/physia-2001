##############################################################################
package App::Dialog::WorklistSetup::InvoiceCreditBalance;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Component::Scheduling;
use App::Statements::Worklist::InvoiceCreditBalance;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'wl-credit-setup' => {},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'invCreditSetup', heading => 'Invoice Credit Balance Setup');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	my $resourcesField = 	new CGI::Dialog::Field(
		caption => '',
		name => 'physician_list',
		style => 'multidual',
		fKeyStmtMgr => $STMTMGR_PERSON,
		fKeyStmt => 'selResourceAssociations',
		fKeyDisplayCol => 1,
		fKeyValueCol => 0,
		size => 5,
		multiDualCaptionLeft => 'Available Physicians',
		multiDualCaptionRight => 'Selected Physicians',
		fKeyStmtBindSession => ['org_internal_id'],
	);

	my $facilitiesField = new App::Dialog::Field::OrgType(
		caption => '',
		name => 'facility_list',
		style => 'multidual',
		types => qq{'CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE'},
		size => 5,
		multiDualCaptionLeft => 'Available Facilities',
		multiDualCaptionRight => 'Selected Facilities',
	);
	$facilitiesField->clearFlag(FLDFLAG_REQUIRED);

	$self->addContent(
		new CGI::Dialog::Subhead(heading => 'Date Range'),
		new CGI::Dialog::Field::Duration(name => 'invoice',
			caption => 'Start Date / End Date',
			),

		new CGI::Dialog::Subhead(heading => 'Physicians'),
		$resourcesField,

		new CGI::Dialog::Subhead(heading => 'Facilities'),
		$facilitiesField,

		new CGI::Dialog::Subhead(heading => 'Insurance Providers'),
		new CGI::Dialog::Field(type => 'select',
			defaultValue=>'0',
			selOptions=>"Selected:0;All:1",
			name => 'product_select',
			caption => 'Products',
			onChangeJS => qq{showFieldsOnValues(event, [0], ['products']);}),
		new CGI::Dialog::Field(
			name => 'products',
			style => 'multidual',
			type => 'select',
			caption => '',
			multiDualCaptionLeft => 'Available Products',
			multiDualCaptionRight => 'Selected Products',
			size => '5',
			fKeyStmtMgr => $STMTMGR_WORKLIST_CREDIT,
			fKeyStmt => 'sel_worklist_credit_available_products',
			fKeyStmtBindSession => ['org_internal_id'],
			hints => ''
		),

		new CGI::Dialog::Subhead(heading => 'Sort Order'),
		new CGI::Dialog::Field(type => 'select',
			style => 'radio',
			selOptions => 'Patients Alphabetically:1;Oldest Refund Due First:2',
			caption => '',
			name => 'sorting',
			),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

###############################
# makeStateChanges functions
###############################

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
}

###############################
# populateData functions
###############################

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	$page->param('itemNamePrefix', 'WorkList-Credit-Setup');

	my $userId =  $page->session('user_id');
	my $orgInternalId = $page->session('org_internal_id');

	my $itemNamePrefix = $page->param('itemNamePrefix');

	my $dates = $STMTMGR_WORKLIST_CREDIT->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_credit_dates', $userId, $orgInternalId, $itemNamePrefix . '-Dates');

	$page->field('invoice_begin_date', $dates->{value_date});
	$page->field('invoice_end_date', $dates->{value_dateend});

	my $physicansList = $STMTMGR_WORKLIST_CREDIT->getRowsAsHashList($page,
		STMTMGRFLAG_NONE, 'sel_worklist_credit_physician', $page->session('user_id'), $orgInternalId, $itemNamePrefix . '-Physician');

	my @physicians = ();
	for (@$physicansList)
	{
		push(@physicians, $_->{value_text});
	}

	$page->field('physician_list', @physicians);

	my $facilityList = $STMTMGR_WORKLIST_CREDIT->getRowsAsHashList($page,
		STMTMGRFLAG_NONE, 'sel_worklist_credit_org', $page->session('user_id'), $orgInternalId, $itemNamePrefix . '-Org');

	my @facilities = ();
	for (@$facilityList)
	{
		push(@facilities, $_->{value_text});
	}

	$page->field('facility_list', @facilities);

	my $insList = $STMTMGR_WORKLIST_CREDIT->getRowsAsHashList($page,
		STMTMGRFLAG_NONE, 'sel_worklist_credit_org', $page->session('user_id'), $orgInternalId, $itemNamePrefix . '-Org');

	#Get products
	#Check if the all products option was selected if so get all products move to list
	my $productsAll = $STMTMGR_WORKLIST_CREDIT->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_credit_all_products', $userId, $orgInternalId, $itemNamePrefix . '-Product');

	if($productsAll->{value_int} == -1)
	{
		$page->field('product_select', 1);
	}
	else
	{
		my $productsList = $STMTMGR_WORKLIST_CREDIT->getRowsAsHashList($page,
			STMTMGRFLAG_NONE, 'sel_worklist_credit_products', $userId, $orgInternalId,
			$itemNamePrefix . '-Product');
		my @products = ();
		for (@$productsList)
		{
			push(@products, $_->{product_id});
		}
		$page->field('products', @products);
	}

	my $sort = $STMTMGR_WORKLIST_CREDIT->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_credit_sorting', $userId, $orgInternalId, $itemNamePrefix . '-Sorting');

	$page->field('sorting', $sort->{value_int});

}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $userId =  $page->session('user_id');
	my $orgInternalId = $page->session('org_internal_id');
	my $itemNamePrefix = $page->param('itemNamePrefix');

	$STMTMGR_WORKLIST_CREDIT->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_credit_dates', $userId, $orgInternalId, $itemNamePrefix . '-Dates');

	$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_internal_id') || undef,
			value_type => 150,
			item_name => $itemNamePrefix . '-Dates',
			value_date => $page->field('invoice_begin_date'),
			value_dateEnd => $page->field('invoice_end_date'),
			parent_org_id => $orgInternalId,
			_debug => 0
	);

	$STMTMGR_WORKLIST_CREDIT->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_credit_physician', $userId, $orgInternalId, $itemNamePrefix . '-Physician');

	my @physicians = $page->field('physician_list');
	for (@physicians)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_internal_id') || undef,
			value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
			item_name => $itemNamePrefix . '-Physician',
			value_text => $_,
			parent_org_id => $orgInternalId,
			_debug => 0
		);
	}

	$STMTMGR_WORKLIST_CREDIT->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_credit_org', $userId, $orgInternalId,  $itemNamePrefix . '-Org');

	my @facilities = $page->field('facility_list');
	for (@facilities)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_internal_id') || undef,
			value_type => App::Universal::ATTRTYPE_RESOURCEORG || undef,
			item_name => $itemNamePrefix . '-Org',
			value_text => $_,
			parent_org_id => $orgInternalId,
			_debug => 0
		);
	}

	$STMTMGR_WORKLIST_CREDIT->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_credit_products', $userId, $orgInternalId, $itemNamePrefix . '-Product');
	if($page->field('product_select'))
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $orgInternalId,
			value_type => App::Universal::ATTRTYPE_INTEGER || undef,
			item_name => $itemNamePrefix . '-Product',
			value_int => -1,
			_debug => 0
		);
	}
	else
	{
		my @products = $page->field('products');
		for (@products)
		{
			$page->schemaAction(
				'Person_Attribute',	'add',
				item_id => undef,
				parent_id => $userId,
				parent_org_id => $orgInternalId,
				value_type => App::Universal::ATTRTYPE_INTEGER || undef,
				item_name => $itemNamePrefix . '-Product',
				value_int => $_,
				_debug => 0
			);
		}
	}

	$STMTMGR_WORKLIST_CREDIT->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_credit_sorting', $userId, $orgInternalId, $itemNamePrefix . '-Sorting');

	$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_internal_id') || undef,
			value_type => 110,
			item_name => $itemNamePrefix . '-Sorting',
			value_int => $page->field('sorting'),
			parent_org_id => $orgInternalId,
			_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);
}

1;
