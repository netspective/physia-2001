##############################################################################
package App::Dialog::Catalog;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Org;
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
my $FS_ATTRR_TYPE = App::Universal::ATTRTYPE_INTEGER;
my $FS_TEXT = 'Fee Schedule';
my $FS_CATALOG_TYPE = 0;
sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', heading => '$Command Fee Schedule');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	my $phy_field = new App::Dialog::Field::MultiPerson::ID(caption => 'Physician ID',
			name => 'physician_id',
			types => ['Physician'],
	);
	my $org_field =new App::Dialog::Field::MultiOrg::ID(caption => ' Site Organization ID ',
			name => 'org_id',
			),

	$phy_field->clearFlag(FLDFLAG_IDENTIFIER);

	$self->addContent(

		new CGI::Dialog::Field(type=>'hidden',
					name=>'org_item_id',
					),
		new CGI::Dialog::Field(type=>'hidden',
					name=>'phy_item_id',
					),
		new CGI::Dialog::Field(type=>'hidden',
					name=>'phy_item_id',
					),
		new CGI::Dialog::Field(caption => 'Internal Catalog ID',
			name => 'parent_catalog_id',
			type=>'hidden'
		),

		new CGI::Dialog::Field(caption => 'Internal Catalog ID',
			name => 'internal_catalog_id',
			type=>'hidden'
		),

		new App::Dialog::Field::Catalog::ID::New(caption => 'Fee Schedule Name',
			name => 'catalog_id',
			size => 20,
			options => FLDFLAG_REQUIRED,
			postHtml => "&nbsp; <a href=\"javascript:doActionPopup('/lookup/catalog');\">Lookup Fee Schedules</a>",
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

                new CGI::Dialog::Field::Duration(
                        name => 'effective',
                        caption => 'Effective Date Range',
                ),
		new CGI::Dialog::Field(caption => 'RVRBS Multiplier',
			name => 'rvrbs_multiplier',
			type => 'float',
			minValue => 0,
		),
		$phy_field,
		$org_field,
		new App::Dialog::Field::Catalog::ID(caption => 'Parent Fee Schedule ID',
	      		name => 'parent_catalog_name',
	      		#type => 'integer',
	      		findPopup => '/lookup/catalog',
	      		#hints => 'Numeric Fee Schedule ID',
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
			['Add RVRBS Fee Schedule Entries', '/org/#session.org_id#/dlg-add-feescheduledataentry/%field.catalog_id%'],
			#['Show Current Fee Schedule', '/org/#session.org_id#/catalog/%field.internal_catalog_id%/%field.catalog_id%'],
			['Show Current Fee Schedule', '/org/#session.org_id#/catalog?catalog=fee_schedule_detail&fee_schedule_detail=%field.internal_catalog_id%'],
			['Show List of Fee Schedules', '/org/#session.org_id#/catalog?catalog=fee_schedule'],
			['Go to Work List', "/worklist"],
			],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	$page->field('parent_catalog_id', $page->param('parent_catalog_id'));
	if ($page->field('parent_catalog_id'))
	{
		my $parentCatalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogById',$page->field('parent_catalog_id')) ;
		$page->field('parent_catalog_name',$parentCatalog->{catalog_id});
	};
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
	};
	if ($page->field('parent_catalog_id'))
	{
		my $parentCatalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogById',$page->field('parent_catalog_id')) ;
		$page->field('parent_catalog_name',$parentCatalog->{catalog_id});
	};
	if (my $decimal = $page->field('rvrbs_multiplier'))
	{
		$decimal =~ s/^\./0./;
		$page->field('rvrbs_multiplier', $decimal)
	}

	my $recExist = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'sel_Catalog_Attribute',
		$page->field('internal_catalog_id'), App::Universal::ATTRTYPE_BOOLEAN,
		'Capitated Contract'
	);
	my $data_range = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'sel_Catalog_Attribute',$page->field('internal_catalog_id'),
	App::Universal::ATTRTYPE_DATE,'Effective/Date/Range');
	my $orgFS = $STMTMGR_CATALOG->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selOrgIdLinkedFS',$page->field('internal_catalog_id'));
	my $orgList=undef;
	foreach my $org_fs_data (@$orgFS)
	{
		$orgList .=$orgList ? ",$org_fs_data->{'org_id'}" :  $org_fs_data->{'org_id'};
	}

	my $perFS = $STMTMGR_CATALOG->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selPersonIdLinkedFS',$page->field('internal_catalog_id'));
	my $perList=undef;
	foreach my $phy_fs_data (@$perFS)
	{
		$perList .=$perList ? ",$phy_fs_data->{'person_id'}" :  $phy_fs_data->{'person_id'};
	}
	$page->field('capitated_contract', 1) if $recExist->{value_int};
	$page->field('add_mode', 0);
	$page->field('org_id',$orgList);
	$page->field('physician_id',$perList);
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
	my $phy_Id = $page->field('physician_id');
	my $org_Id = $page->field('org_id');
	my $parentCatalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selInternalCatalogIdByIdType',$page->session('org_internal_id'),$page->field('parent_catalog_name'),$FS_CATALOG_TYPE);

	my $newId = $page->schemaAction(
		'Offering_Catalog', $command,
		internal_catalog_id => $command eq 'add' ? undef : $internalCatalogId,
		catalog_id => $page->field('catalog_id') || undef,
		org_internal_id => $orgInternalId || undef,
		catalog_type => defined $catalogType ? $catalogType : 0,
		caption => $page->field('caption') || undef,
		description => $page->field('description') || undef,
		rvrbs_multiplier => $page->field('rvrbs_multiplier') || undef,
		parent_catalog_id => $parentCatalog->{internal_catalog_id} || undef,
		effective_begin_date  =>$page->field('effective_begin_date')||undef,
		effective_end_date => $page->field('effective_end_date') ||undef,
		_debug => 0
	);

	$page->field('internal_catalog_id', $newId) if $command eq 'add';

	saveAttribute($page, 'OfCatalog_Attribute', $internalCatalogId || $newId , 'Capitated Contract',
		App::Universal::ATTRTYPE_BOOLEAN, $STMTMGR_CATALOG, 'sel_Catalog_Attribute',
		value_int => defined $page->field('capitated_contract') ? 1 : 0,
	) if $command ne 'remove';

	savePerOrgAttr ($page,$phy_Id,$org_Id,$command);

	$page->param('_dialogreturnurl', "/org/$orgId/catalog?catalog=fee_schedule") if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags);
}

sub savePerOrgAttr
{
	my ($page,$phyId,$orgId,$command) =@_;
	my @phyList = split(/\s*,\s*/,$phyId);
	my @orgList = split(/\s*,\s*/,$orgId);
	my $fsId = $page->field('internal_catalog_id');
	#Clear out old Assoicatation if this is and update
	$STMTMGR_CATALOG->execute($page,STMTMGRFLAG_NONE,'delPersonIdLinkedFS',$fsId);
	$STMTMGR_CATALOG->execute($page,STMTMGRFLAG_NONE,'delOrgIdLinkedFS',$fsId);
	if($command ne 'remove')
	{
		foreach (@phyList)
		{
			$page->schemaAction(
					'Person_Attribute', 'add' ,
					item_id => $page->field('phy_item_id') || undef,
					parent_id => $_,
					item_name => $FS_TEXT,
					item_type => 0,
					value_type => $FS_ATTRR_TYPE,
				value_int => $fsId,
			)if $_;
		}

		foreach (@orgList)
		{
			my $orgParentId =  $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $_);
			$page->schemaAction(
					'Org_Attribute', 'add',
					item_id => $page->field('org_item_id') || undef,
					parent_id => $orgParentId,
					item_name => $FS_TEXT,
					item_type => 0,
					value_type => $FS_ATTRR_TYPE,
					value_int => $fsId,
			) if $orgParentId;
		}
	}

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
		new CGI::Dialog::Field(type => 'hidden', name => 'checkbox_validation'),
		new CGI::Dialog::Field(type => 'hidden', name => 'internal_catalog_id'),
		new App::Dialog::Field::Catalog::ID(caption => 'Existing Fee Schedule ID',
			name => 'catalog_id',
			#type => 'integer',
			options => FLDFLAG_REQUIRED,
			findPopup => '/lookup/catalog',
			#hints => 'Numeric Fee Schedule ID',
		),
		new CGI::Dialog::Subhead(heading => '', name => ''),

		new App::Dialog::Field::Catalog::ID::New(caption => 'New Fee Schedule Name',
			name => 'new_catalog_id',
			size => 25,
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
		new CGI::Dialog::Field(caption => 'Make all entries capitated',
			type => 'select',
			style => 'radio',
			selOptions => 'Capitated;FFS;Copy As Is',
			name => 'copy_entries_as'
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->setFieldFlags('copy_entries_as', FLDFLAG_INVISIBLE, 1);
}

sub checkDupName
{
	my ($self, $page) = @_;

	my $catalogExists = $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE,
		'selInternalCatalogIdByIdType', $page->session('org_internal_id'),$page->field('new_catalog_id'),$FS_CATALOG_TYPE);

	my $field = $self->getField('new_catalog_id');
	$field->invalidate($page, qq{Fee Schedule Name already exists for this Org.})
		if $catalogExists;
}

sub customValidate
{
	my ($self, $page) = @_;
	$self->checkDupName($page);

	my $catalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,'selInternalCatalogIdByIdType',
			$page->session('org_internal_id'),$page->field('catalog_id'),$FS_CATALOG_TYPE);
	$page->field('internal_catalog_id',$catalog->{internal_catalog_id});
	my $attribute = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_Catalog_Attribute', $catalog->{internal_catalog_id}, App::Universal::ATTRTYPE_BOOLEAN,
		'Capitated Contract');

	if($attribute->{value_int} && ! $page->field('checkbox_validation'))
	{
		$self->updateFieldFlags('copy_entries_as', FLDFLAG_INVISIBLE, 0);
		$page->field('copy_entries_as', 'Copy As Is');

		my $getCapCheckboxField = $self->getField('copy_entries_as');
		$getCapCheckboxField->invalidate($page, 'Existing Fee Schedule ID is a capitated contract. Make all items capitated?');

		$page->field('checkbox_validation', 1); #this is so this validation doesn't run again
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $orgId = $page->session('org_internal_id');
	my $orgName = $page->session('org_id');
	my $existingCatalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selCatalogById', $page->field('internal_catalog_id'));

	my $newInternalCatalogId = $page->schemaAction(
		'Offering_Catalog', 'add',
		internal_catalog_id => undef,
		catalog_id => $page->field('new_catalog_id') || undef,
		catalog_type => 0,
		caption => $page->field('caption') || $existingCatalog->{caption} || undef,
		description => $page->field('description') || $existingCatalog->{description} || undef,
		rvrbs_multiplier =>  $existingCatalog->{rvrbs_multiplier} || undef,
		parent_catalog_id => $existingCatalog->{parent_catalog_id} || undef,
		org_internal_id => $orgId,
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
	my $copyEntriesAs = $page->field('copy_entries_as');
	my $insertStmt = '';

	if($copyEntriesAs eq 'Capitated' || $copyEntriesAs eq 'FFS')
	{
		my $flags = $copyEntriesAs eq 'Capitated' ? 0 : 1;
		$insertStmt = qq{
			insert into Offering_Catalog_Entry (cr_session_id, cr_stamp, cr_user_id, cr_org_internal_id,
				catalog_id, parent_entry_id, entry_type, flags, status, code, modifier, name, default_units,
				cost_type, unit_cost, description, units_avail,data_text)
			(select '$sessionId', sysdate, '$userId', '$orgId', $newInternalCatalogId, parent_entry_id,
				entry_type, $flags, status, code, modifier, name, default_units, cost_type, unit_cost,
				description, units_avail ,data_text
			from Offering_Catalog_Entry where catalog_id = $internalCatalogId)
		};
	}
	else
	{
		$insertStmt = qq{
			insert into Offering_Catalog_Entry (cr_session_id, cr_stamp, cr_user_id, cr_org_internal_id,
				catalog_id, parent_entry_id, entry_type, flags, status, code, modifier, name, default_units,
				cost_type, unit_cost, description, units_avail,data_text)
			(select '$sessionId', sysdate, '$userId', '$orgId', $newInternalCatalogId, parent_entry_id,
				entry_type, flags, status, code, modifier, name, default_units, cost_type, unit_cost,
				description, units_avail ,data_text
			from Offering_Catalog_Entry where catalog_id = $internalCatalogId)
		};
	}

	$STMTMGR_CATALOG->execute($page, STMTMGRFLAG_DYNAMICSQL, $insertStmt);
	$page->param('_dialogreturnurl', "/org/$orgName/catalog?catalog=fee_schedule") ;
	$self->handlePostExecute($page, $command, $flags);
}


1;
