##############################################################################
package App::Dialog::Catalog;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use Date::Manip;
use Text::Abbrev;
use App::Universal;

use vars qw(@ISA %PROCENTRYABBREV %RESOURCE_MAP %ITEMTOFIELDMAP %CODE_TYPE_MAP);
@ISA = qw(CGI::Dialog);

%PROCENTRYABBREV = abbrev qw(feescheduleentryid name modifier units description);

%ITEMTOFIELDMAP =
(
	'feescheduleentryid' => 'entry_id',
	'name' => 'name',	#name stands for itemname
	'modifier' => 'modifier',
	'units' => 'default_units',
	'description' => 'description'
);

%CODE_TYPE_MAP =
(
	'item' => 0,
	'icd' => 80,
	'cpt' => 100,
	'proc'=> 110,
	'procert' => 120,
	'service' => 150,
	'sercert' => 160,
	'product' => 200,
	'hcpcs' => 210
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', heading => '$Command Fee Schedule');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
		new CGI::Dialog::Field(caption => 'Internal Catalog ID',
			name => 'internal_catalog_id',
			options => FLDFLAG_READONLY,
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDATE,
		),

		new App::Dialog::Field::Catalog::ID::New(caption => 'Fee Schedule ID',
			name => 'catalog_id', 
			size => 20,
			options => FLDFLAG_REQUIRED,
			findPopup => '/lookup/catalog',
		),
		new CGI::Dialog::Field::TableColumn(
			name => 'catalog_type',
			type => 'hidden',
			column => 'offering_catalog_type.id',
			schema => $schema, 
			value => 0
		),
		new CGI::Dialog::Field(caption => 'Fee Schedule Name', 
			name => 'caption', 
			options => FLDFLAG_REQUIRED,
			size => 45,
		),
		new CGI::Dialog::Field(caption => 'Description',
			name => 'description',
			type => 'memo',
		),
		new CGI::Dialog::Field(caption => 'RVRBS Multiplier',
			name => 'rvrbs_multiplier',
			type => 'float', 
			minValue => 0,
		),
		new CGI::Dialog::Field::TableColumn(caption => 'Parent Fee Schedule ID', 
			name => 'parent_catalog_id',
			schema => $schema, 
			column => 'Offering_Catalog_Entry.catalog_id',
			findPopup => '/lookup/catalog/'
		),
		new CGI::Dialog::Field(caption => 'Capitated Contract',
			name => 'capitated_contract',
			type => 'bool',
			style => 'check',
			defaultValue => 0,
		),
	);
	
	$self->{activityLog} =
	{
		scope =>'offering_catalog',
		key => "#field.catalog_id#",
		data => "FeeSchedule '#field.caption#' <a href='/search/catalog/detail/#field.internal_catalog_id#'>#field.catalog_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_add => [
			['Add Another Fee Schedule', "/org/#session.org_id#/dlg-add-catalog", 1],
			['Show Current Fee Schedule', '/search/catalog/detail/%field.catalog_id%'],
			['Show List of Fee Schedules', '/search/catalog']
			],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub customValidate
{
	my ($self, $page) = @_;
	#	validateFeeScheduleEntryTextArea($self, $page);
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	#return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	$page->field('parent_catalog_id', $page->param('parent_catalog_id'));
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $catalogId = $page->param('internal_catalog_id');
	if(! $STMTMGR_CATALOG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selCatalogById',$catalogId))
	{
		$page->addError("Catalog ID '$catalogId' not found.");
	}
	
	if (my $decimal = $page->field('rvrbs_multiplier'))
	{
		$decimal =~ s/^\./0./;
		$page->field('rvrbs_multiplier', $decimal)
	}
	
	my $recExist = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'sel_Catalog_Attribute',
		$page->field('internal_catalog_id'), App::Universal::ATTRTYPE_BOOLEAN,
		'Capitated Contract'
	);
	
	$page->field('capitated_contract', 1) if $recExist->{value_int};
}

sub populateData_remove
{
	populateData_update(@_);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $id = $self->{'id'};
	my $orgId = $page->param('org_id');
	my $catalogType = $page->field('catalog_type');
	my $status = $page->field('status');
	my $internalCatalogId = $page->field('internal_catalog_id');
		
	$page->schemaAction(
		'Offering_Catalog', $command,
		internal_catalog_id => $command eq 'add' ? undef : $internalCatalogId,
		catalog_id => $page->field('catalog_id') || undef,
		org_id => $orgId || undef,
		catalog_type => defined $catalogType ? $catalogType : 0,
		caption => $page->field('caption') || undef,
		description => $page->field('description') || undef,
		rvrbs_multiplier => $page->field('rvrbs_multiplier') || undef,
		parent_catalog_id => $page->field('parent_catalog_id') || undef,
		_debug => 0
	);

	saveAttribute($page, 'OfCatalog_Attribute', $internalCatalogId, 'Capitated Contract', 
		App::Universal::ATTRTYPE_BOOLEAN, $STMTMGR_CATALOG, 'sel_Catalog_Attribute',
		value_int => defined $page->field('capitated_contract') ? 1 : 0,
	);

	$page->param('_dialogreturnurl', "/org/$orgId/catalog") if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags);
}

sub saveAttribute
{
	my ($page, $table, $parentId, $itemName, $valueType, $stmtMgr, $stmt, %data) = @_;
	
	my $recExist = $stmtMgr->getRowAsHash($page, STMTMGRFLAG_NONE, $stmt, 
		$parentId, $valueType, $itemName);
	
	my $itemId = $recExist->{item_id};
	my $command = $itemId ? 'update' : 'add';
	
	my $newItemId = $page->schemaAction(
		$table, $command,
		item_id    => $command eq 'add' ? undef : $itemId,
		parent_id  => $parentId,
		item_name  => $itemName,
		value_type => $valueType,
		%data
	);

	return $newItemId;
}

%RESOURCE_MAP = (
	'catalog' => {
		_class => 'App::Dialog::Catalog',
		_arl_add => ['parent_catalog_id'],
		_arl_modify => ['internal_catalog_id'],
		_arl_remove => ['internal_catalog_id'],
	},
);

1;