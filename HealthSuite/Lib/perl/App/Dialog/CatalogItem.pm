##############################################################################
package App::Dialog::CatalogItem;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Search::Code;
use App::Statements::Search::MiscProcedure;
use App::Statements::IntelliCode;
use App::Statements::Person;
use Carp;

use CGI::Validator::Field;
use App::Dialog::Field::Catalog;
use Date::Manip;

use base 'CGI::Dialog';
use vars qw(%RESOURCE_MAP);


%RESOURCE_MAP = (
	'catalog-item' => {
		_arl_add => ['internal_catalog_id', 'parent_entry_id'],
		_arl_modify => ['entry_id']
	},
);

my $FS_CATALOG_TYPE = 0;
sub new
{
	my $self = CGI::Dialog::new(@_);
	my $command;
	($self, $command) = CGI::Dialog::new(@_, id => 'catalogitem', heading => '$Command Fee Schedule Item');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(

		new CGI::Dialog::Field(
			name => 'show_cap',
			type => 'hidden'
		),	
		new App::Dialog::Field::Catalog::ID(caption => 'Fee Schedule ID',
			name => 'catalog_id',
			options => FLDFLAG_REQUIRED,
			findPopup => '/lookup/catalog',
		),
		new CGI::Dialog::Field(caption => 'Fee Schedule Entry Type',
			name => 'entry_type',
			fKeyStmtMgr => $STMTMGR_CATALOG,
			fKeyStmt => 'selFeeScheduleEntryTypes',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(caption => 'Entry Cost Type',
			name => 'flags',
			choiceDelim =>',',
			selOptions => "Capitated:0,FFS:1",
			type => 'select',
			style => 'radio',
			defaultValue=>0,
		),
		new CGI::Dialog::MultiField(
			name => 'code_modifier',
			fields => [
				new CGI::Dialog::Field::TableColumn(caption => 'Code',
					name => 'code',
					schema => $schema,
					column => 'Offering_Catalog_Entry.code',
					options => FLDFLAG_REQUIRED,
					size => 10,
					findPopup => '/lookup/itemValue',
					findPopupControlField => '_f_entry_type',
				),
				new CGI::Dialog::Field::TableColumn(caption => 'Modifier',
					name => 'modifier',
					size => 10,
					schema => $schema,
					column => 'Offering_Catalog_Entry.modifier'
				),
			]
		),
		new CGI::Dialog::Field::TableColumn(caption => 'Item Name',
			name => 'name',
			schema => $schema,
			column => 'Offering_Catalog_Entry.name',
			size => 40,
			hints => 'autofill for CPT, EPSDT and HCPCS codes',
		),
		new CGI::Dialog::Field::TableColumn(caption => 'Description',
			name => 'description',
			schema => $schema,
			column => 'Offering_Catalog_Entry.description',
			size => '50'
		),

		new CGI::Dialog::Field(caption => 'Service Type',
			name => 'data_text',
			type => 'text',
			size => 2,
			maxLength => 2,
			findPopup => '/lookup/servicetype',
			#options => FLDFLAG_REQUIRED,

		),
		new CGI::Dialog::Field(caption => 'Status',
			name => 'status',
			type => 'enum',
			enum => 'Catalog_Entry_Status',
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(caption => 'Cost Type',
			name => 'cost_type',
			type => 'enum',
			enum => 'Catalog_Entry_Cost_Type',
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(caption => 'Unit Cost',
			name => 'unit_cost',
			size => 10,
			maxLength => 8,
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field( caption => 'Units Available',
			name => 'units_avail',
			size => 5,
			maxLength => 8
		),
		new CGI::Dialog::Field::TableColumn(caption => 'Parent Entry ID',
			name => 'parent_entry_id',
			schema => $schema,
			size => 16,
			column => 'Offering_Catalog_Entry.parent_entry_id',
			findPopup => '/lookup/catalog/detailname/itemValue',
			findPopupControlField => '_f_catalog_id',
			hints => 'Numeric Entry ID',
		),
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
	);

	$self->{activityLog} =
		{
			scope =>'offering_catalog_entry',
		key => "#field.catalog_id#",
			data => "Fee Schedule Entry '#field.code#' to <a href='/search/catalog/detail/#field.catalog_id#'>#field.catalog_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_add => [
			['Add Another Fee Schedule Item', "/org/#session.org_id#/dlg-add-catalog-item/#param.internal_catalog_id#", 1],
			['Show Current Fee Schedule Item', "/org/#session.org_id#/catalog?catalog=fee_schedule_detail&fee_schedule_detail=#param.internal_catalog_id#"],
			['Go to Work List', "/worklist"],
			],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges_special
{
	my ($self, $page) = @_;

	my $recExist;
	$recExist = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'sel_Catalog_Attribute',
		$page->param('internal_catalog_id'), App::Universal::ATTRTYPE_BOOLEAN, 'Capitated Contract')
		if ($page->param('internal_catalog_id'));

	$self->updateFieldFlags('flags', FLDFLAG_INVISIBLE, ! $recExist->{value_int});
	my $result = $recExist->{value_int} ? 1 :0;
	$page->field('show_cap',$result);
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	if ($page->param('internal_catalog_id'))
	{
		my $parentCatalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogById',$page->param('internal_catalog_id')) ;
		$page->field('catalog_id',$parentCatalog->{catalog_id});
	}
	$self->makeStateChanges_special($page);
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	#if($page->param('parent_entry_id'))
	#{
	#	my $parentEntry = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogItemById',$page->param('parent_entry_id')) ;
	#	$page->field('parent_entry_id', $parentEntry->{name});
	#}
	$page->field('parent_entry_id',$page->param('parent_entry_id'));
	$page->field('entry_type', 100);
	$page->field('status', 1);
	$page->field('cost_type', 1);
	$page->field('add_mode', 1);
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	#if Entry Id then Need to set up param with internal_catalog_id
	my $entry = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogItemById',$page->param('entry_id'));
	$page->param('internal_catalog_id',$entry->{catalog_id});
	$self->makeStateChanges_special($page);
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $entryId = $page->param('entry_id');
	if ($STMTMGR_CATALOG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE,
		'selCatalogItemById', $entryId))
	{
		my $parentCatalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogById',$page->field('catalog_id')) ;
		$page->field('catalog_id',$parentCatalog->{catalog_id});
		$self->makeStateChanges_special($page);
	}
	else
	{
		$page->addError("Entry ID $entryId does not exist.");
	}
}

sub populateData_remove
{
	populateData_update(@_);
}

sub checkDupEntry
{
	my ($self, $page, $fs, $entryType, $code, $modifier) = @_;

	if ($page->field('add_mode'))
	{
		my $entryExists;

		if ($modifier)
		{
			$entryExists = $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE,
				'sel_catalogEntry_by_catalogTypeCodeModifier', $code, $modifier, $entryType, $fs);
		}
		else
		{
			$entryExists = $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE,
				'sel_catalogEntry_by_catalogTypeCode', $code, $entryType, $fs);
		}

		my $field = $self->getField('code_modifier');
 		if ($entryExists)
 		{
			$field->invalidate($page, qq{Entry '$code' already exists in the system for Fee Schedule '$fs'.});
			return 0;
		}		
	}
	return 1;
}


sub customValidate
{
	my ($self, $page) = @_;

	my $fs = $page->param('_f_catalog_id');
	my $entryType = $page->param('_f_entry_type');

	my $code = $page->param('_f_code');
	my $modifier = $page->param('_f_modifier');
	my $svc_type = $page->field('data_text');
	my $svc_field =$self->getField('data_text');
	my $parentCatalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selInternalCatalogIdByIdType',$page->session('org_internal_id'),$page->field('catalog_id'),$FS_CATALOG_TYPE);
	$page->param('internal_catalog_id',$parentCatalog->{internal_catalog_id});
	my $result = $self->checkDupEntry($page, $parentCatalog->{internal_catalog_id}, $entryType, $code, $modifier);

	return unless $result;

	#If FS is not capitated just set flags to FFS to be safe
	my $recExist = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'sel_Catalog_Attribute',
			$page->param('internal_catalog_id')||undef, App::Universal::ATTRTYPE_BOOLEAN, 'Capitated Contract');

	#$page->addError($recExist->{value_int});
	$page->field('flags',1) unless ($recExist->{value_int});

	#Attempt to determine serivce type if user does not provide one
	if ($svc_type eq '')
	{

		#Service Type for EPSDT is S
		if ($entryType == App::Universal::CATALOGENTRYTYPE_EPSDT)
		{
			$svc_type = 'S';
		}
		else
		{
			#Query REF_Code_Service_Type table for the Service Type for this procedure
			$svc_type = $STMTMGR_INTELLICODE->getSingleValue($page,STMTMGRFLAG_NONE,
					'selServTypeByCode',$code,$entryType);
		}

		#
		#Autofill service type if we were able to determine it
		$page->field('data_text',$svc_type);
		my $itemNameField = $self->getField('data_text');
		$itemNameField->invalidate($page, qq{
		@{[ $svc_type ? "Autofilled Service Type" : "Unable to find a Service Type for code '$code'" ]}
		});
	}


	if($svc_type ne '' && not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericServiceTypeByAbbr', $svc_type)))
	{
		$svc_field->invalidate($page, "The service type code $svc_type is not valid. Please verify");
	}

	if (
		(! $page->param('_f_name') || ! $page->param('_f_description')) &&
		(grep(/^$entryType$/, (App::Universal::CATALOGENTRYTYPE_MISC_PROCEDURE,App::Universal::CATALOGENTRYTYPE_EPSDT,App::Universal::CATALOGENTRYTYPE_ICD, App::Universal::CATALOGENTRYTYPE_CPT, App::Universal::CATALOGENTRYTYPE_HCPCS)) )
	)
	{
		my $codeInfo;

		CASE: {
			if ($entryType == App::Universal::CATALOGENTRYTYPE_ICD) {
				$codeInfo = $STMTMGR_CATALOG_CODE_SEARCH->getRowAsHash($page, STMTMGRFLAG_NONE,
					'sel_icd_code', $code);
				last CASE;
			}
			if ($entryType == App::Universal::CATALOGENTRYTYPE_CPT) {
				$codeInfo = $STMTMGR_CPT_CODE_SEARCH->getRowAsHash($page, STMTMGRFLAG_NONE,
					'sel_cpt_code', $code);
				last CASE;
			}
			if ($entryType == App::Universal::CATALOGENTRYTYPE_HCPCS) {
				$codeInfo = $STMTMGR_HCPCS_CODE_SEARCH->getRowAsHash($page, STMTMGRFLAG_NONE,
					'sel_hcpcs_code', $code);
				last CASE;
			}
			if ($entryType == App::Universal::CATALOGENTRYTYPE_EPSDT) {
				$codeInfo = $STMTMGR_EPSDT_CODE_SEARCH->getRowAsHash($page,STMTMGRFLAG_NONE,
					'sel_epsdt_code',$code);
				last CASE;
			}
			if ($entryType == App::Universal::CATALOGENTRYTYPE_MISC_PROCEDURE) {
				$codeInfo = $STMTMGR_MISC_PROCEDURE_CODE_SEARCH->getRowAsHash($page,STMTMGRFLAG_NONE,
					'sel_misc_procedure_code',$code,$page->session('org_internal_id'));
				last CASE;
			}

		}

		unless ($page->param('_f_name'))
		{
			my $itemNameField = $self->getField('name');
			$page->field('name', $codeInfo->{name});
			$itemNameField->invalidate($page, qq{
				@{[ $codeInfo->{name} ? "Autofilled Item Name" : "Unable to find a name for code '$code'" ]}
			});
		}
		unless ($page->param('_f_description'))
		{
			my $descrField = $self->getField('description');
			$page->field('description', $codeInfo->{description} || $codeInfo->{descr});
			$descrField->invalidate($page, qq{
				@{[ $codeInfo->{description} || $codeInfo->{descr} ? "Autofilled Description" :
				"Unable to find a description for code '$code'" ]}
			});
		}
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $id = $self->{'id'};
	my $orgId = $page->param('org_id');



	my $recExist = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'sel_Catalog_Attribute',
			$page->param('internal_catalog_id'), App::Universal::ATTRTYPE_BOOLEAN, 'Capitated Contract');
	my $catalogType = $page->field('catalog_type');
	my $status = $page->field('status');
	my $costType = $page->field('cost_type');
	my $entryType = $page->field('entry_type');
	my $ffs_flag;
#	if($page->field('show_cap'))
#	{
#		$flag = $page->field('flags');
#	}
#	else
#	{
#		$flag= $recExist->{value_int} ? 0: 1;
#	}
	$ffs_flag = defined $page->field('flags') ? $page->field('flags') : 1;
	#$page->addError($ffs_flag);
	my $entryId = $page->schemaAction(
		'Offering_Catalog_Entry', $command,
		catalog_id => $page->param('internal_catalog_id') || undef,
		entry_id => $page->field('entry_id') || $page->param('entry_id') || undef,
		name => $page->field('name') || undef,
		entry_type => defined $entryType ? $entryType : undef,
		status => defined $status ? $status : undef,
		cost_type => defined $costType ? $costType : undef,
		unit_cost => $page->field('unit_cost') || undef,
		code => $page->field('code') || undef,
		modifier => $page->field('modifier') || undef,
		description => $page->field('description') || undef,
		parent_entry_id => $page->field('parent_entry_id') || undef,
		units_avail => $page->field('units_avail') || undef,
		flags => $ffs_flag,
		data_text => $page->field('data_text') || undef,
		_debug => 0
		);

	$page->param('_dialogreturnurl', '/org/%session.org_id%/catalog?catalog=fee_schedule_detail&fee_schedule_detail=%param.internal_catalog_id%') if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags, undef, "Fee Schedule Item $command was successful");
	return '';
}

1;
