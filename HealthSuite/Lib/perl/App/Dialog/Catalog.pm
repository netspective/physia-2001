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

use vars qw(@ISA %RESOURCE_MAP %PROCENTRYABBREV %RESOURCE_MAP %ITEMTOFIELDMAP %CODE_TYPE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'catalog' => {
		_arl_add => ['parent_catalog_id'],
		_arl_modify => ['internal_catalog_id'],
		_arl_remove => ['internal_catalog_id'],
	},
);

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
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDATE | CGI::Dialog::DLGFLAG_REMOVE,
		),

		new App::Dialog::Field::Catalog::ID::New(caption => 'Fee Schedule Name',
			name => 'catalog_id', 
			size => 20,
			options => FLDFLAG_REQUIRED,
			postHtml => "&nbsp; <a href=\"javascript:doActionPopup('/lookup/catalog');\">Lookup Fee Schedules</a>",
			hints => 'Textual Fee Schedule Name',
		),
		new CGI::Dialog::Field::TableColumn(
			name => 'catalog_type',
			type => 'hidden',
			column => 'offering_catalog_type.id',
			schema => $schema, 
			value => 0
		),
		new CGI::Dialog::Field(caption => 'Fee Schedule Caption', 
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
    new App::Dialog::Field::Catalog::ID(caption => 'Parent Fee Schedule ID',
      name => 'parent_catalog_id',
      type => 'integer',
      findPopup => '/lookup/catalog',
      hints => 'Numeric Fee Schedule ID',
    ),
		new CGI::Dialog::Field(caption => 'Capitated Contract',
			name => 'capitated_contract',
			type => 'bool',
			style => 'check',
			defaultValue => 0,
		),
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
	);
	
	$self->{activityLog} =
	{
		scope =>'offering_catalog',
		key => "#field.catalog_id#",
		data => "FeeSchedule '#field.caption#' <a href='/search/catalog/detail/#field.internal_catalog_id#'>#field.catalog_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_add => [
			['Add Another Fee Schedule', '/org/#session.org_id#/dlg-add-catalog', 1],
			['Show Current Fee Schedule', '/org/#session.org_id#/catalog/%field.internal_catalog_id%/%field.catalog_id%'],
			['Show List of Fee Schedules', '/org/#session.org_id#/catalog']
			],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	$page->field('parent_catalog_id', $page->param('parent_catalog_id'));
	$page->field('add_mode', 1);
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
	$page->field('add_mode', 0);
}

sub populateData_remove
{
	populateData_update(@_);
}

sub checkDupName
{
	my ($self, $page) = @_;
	
	my $catalogExists = $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE,
		'sel_catalog_by_id_orgId', $page->field('catalog_id'), $page->session('org_internal_id'));

	my $field = $self->getField('catalog_id');
	my $fieldValue = $page->field('catalog_id');
	
	$field->invalidate($page, qq{Fee Schedule Name '$fieldValue' already exists for this Org.}) 
		if $catalogExists;
}

sub customValidate
{
	my ($self, $page) = @_;
	$self->checkDupName($page) if $page->field('add_mode');
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $id = $self->{'id'};
	my $orgInternalId = $page->session('org_internal_id');
	my $orgId = $page->session('org_id');
	my $catalogType = $page->field('catalog_type');
	my $status = $page->field('status');
	my $internalCatalogId = $page->field('internal_catalog_id');
		
	my $newId = $page->schemaAction(
		'Offering_Catalog', $command,
		internal_catalog_id => $command eq 'add' ? undef : $internalCatalogId,
		catalog_id => $page->field('catalog_id') || undef,
		org_internal_id => $orgInternalId || undef,
		catalog_type => defined $catalogType ? $catalogType : 0,
		caption => $page->field('caption') || undef,
		description => $page->field('description') || undef,
		rvrbs_multiplier => $page->field('rvrbs_multiplier') || undef,
		parent_catalog_id => $page->field('parent_catalog_id') || undef,
		_debug => 0
	);

	$page->field('internal_catalog_id', $newId);
	
	saveAttribute($page, 'OfCatalog_Attribute', $internalCatalogId || $newId , 'Capitated Contract', 
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

1;

##############################################################################
package App::Dialog::Catalog::Copy;
##############################################################################

use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Catalog;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'catalog-copy' => {},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'catalog-copy', heading => 'Copy Fee Schedule');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Catalog::ID(caption => 'Existing Fee Schedule ID',
			name => 'internal_catalog_id',
			type => 'integer',
			options => FLDFLAG_REQUIRED,
			findPopup => '/lookup/catalog',
			hints => 'Numeric Fee Schedule ID',
		),
		new CGI::Dialog::Subhead(heading => '', name => ''),
		
		new App::Dialog::Field::Catalog::ID::New(caption => 'New Fee Schedule Name',
			name => 'catalog_id',
			size => 25,
			hints => 'Textual Name, not the numeric ID',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(caption => 'New Fee Schedule Caption', 
			name => 'caption',
			size => 45,
			hints => 'Same as Source if not specified',			
		),
		new CGI::Dialog::Field(caption => 'New Fee Schedule Description',
			name => 'description',
			type => 'memo',
		),
	
	);
	
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub checkDupName
{
	my ($self, $page) = @_;
	
	my $catalogExists = $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE,
		'sel_catalog_by_id_orgId', $page->field('catalog_id'), $page->session('org_internal_id'));

	my $field = $self->getField('catalog_id');
	$field->invalidate($page, qq{Fee Schedule Name already exists for this Org.}) 
		if $catalogExists;
}

sub customValidate
{
	my ($self, $page) = @_;
	$self->checkDupName($page);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $orgId = $page->session('org_internal_id');
	
	my $existingCatalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selCatalogById', $page->field('internal_catalog_id'));
	
	my $newInternalCatalogId = $page->schemaAction(
		'Offering_Catalog', 'add',
		internal_catalog_id => undef,
		catalog_id => $page->field('catalog_id') || undef,		
		catalog_type => 0,
		caption => $page->field('caption') || $existingCatalog->{caption} || undef,
		description => $page->field('description') || $existingCatalog->{description} || undef,
		rvrbs_multiplier =>  $existingCatalog->{rvrbs_multiplier} || undef,
		parent_catalog_id => $existingCatalog->{parent_catalog_id} || undef,
		_debug => 0
	);

	my $attribute = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_Catalog_Attribute', $page->field('internal_catalog_id'), App::Universal::ATTRTYPE_BOOLEAN,
		'Capitated Contract');

	App::Dialog::Catalog::saveAttribute($page, 'OfCatalog_Attribute', $newInternalCatalogId, 
		'Capitated Contract', App::Universal::ATTRTYPE_BOOLEAN, $STMTMGR_CATALOG, 
		'sel_Catalog_Attribute', value_int => defined $attribute->{value_int} ? 
		$attribute->{value_int} : 0,
	);	

	my $sessionId = $page->session('_session_id');
	my $userId = $page->session('user_id');
	my $internalCatalogId = $page->field('internal_catalog_id');
	
	my $insertStmt = qq{
		insert into Offering_Catalog_Entry (cr_session_id, cr_stamp, cr_user_id, cr_org_internal_id,
			catalog_id, parent_entry_id, entry_type, flags, status, code, modifier, name, default_units,
			cost_type, unit_cost, description, units_avail)
		(select '$sessionId', sysdate, '$userId', '$orgId', $newInternalCatalogId, parent_entry_id, 
			entry_type, flags, status, code, modifier, name, default_units, cost_type, unit_cost,
			description, units_avail 
		from Offering_Catalog_Entry where catalog_id = $internalCatalogId)
	};	
	
	$STMTMGR_CATALOG->execute($page, STMTMGRFLAG_DYNAMICSQL, $insertStmt);
	$page->param('_dialogreturnurl', "/org/$orgId/catalog");
	$self->handlePostExecute($page, $command, $flags);
}


1;
