##############################################################################
package App::Dialog::CatalogItem;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Search::Code;

use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Catalog;

use vars qw(@ISA);
use Date::Manip;

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_);
	my $command;
	($self, $command) = CGI::Dialog::new(@_, id => 'catalogitem', heading => '$Command Fee Schedule Item');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
		new App::Dialog::Field::Catalog::ID(caption => 'Fee Schedule ID',
			name => 'catalog_id',
			options => FLDFLAG_REQUIRED,
			findPopup => '/lookup/catalog',
		),
		new CGI::Dialog::Field(type => 'enum',
			enum => 'Catalog_Entry_Type',
			caption => 'Fee Schedule Entry Type',
			name => 'entry_type',
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::MultiField(caption =>'Code/Modifier',
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
			#options => FLDFLAG_REQUIRED,
			size => 40,
			hints => 'autofill for CPT, ICD and HCPCS codes',
			#findPopup => '/lookup/catalog/detail/itemValue',
			#findPopupControlField => '_f_catalog_id',
		),
		new CGI::Dialog::Field::TableColumn(caption => 'Description',
			name => 'description',
			schema => $schema,
			column => 'Offering_Catalog_Entry.description',
			size => '50'
		),
		new CGI::Dialog::Field(type => 'enum',
			name => 'status',
			enum => 'Catalog_Entry_Status',
			caption => 'Status',
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(caption => 'Cost Type',
			name => 'cost_type',
			type => 'enum',
			enum => 'Catalog_Entry_Cost_Type',
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field( caption => 'Unit Cost',
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
			column => 'Offering_Catalog_Entry.parent_entry_id',
			findPopup => '/lookup/catalog/detail/itemValue',
			findPopupControlField => '_f_catalog_id',
		),
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
	);

	$self->{activityLog} =
		{
			scope =>'offering_catalog_entry',
			key => "#field.catalog_id#",
			data => "Fee Schedule Entry '#param.entry_id# #field.entry_id#' <a href='/search/catalog/detail/#field.catalog_id#'>#field.catalog_id#</a>"
	};
		# These 3 fields are only for Products, type 200 and up, not for Services
		#new CGI::Dialog::Field::TableColumn(caption => 'Taxable?', name => 'taxable',
		#	schema => $schema, column => 'Catalog_Item.taxable'),
		#new CGI::Dialog::Field::TableColumn(caption => 'Default Units', name => 'default_units',
		#	schema => $schema, column => 'Catalog_Item.default_units'),
		#new CGI::Dialog::Field::TableColumn(caption => 'Available Units', name => 'units_avail',
		#	schema => $schema, column => 'Catalog_Item.units_avail'),

	$self->addFooter(new CGI::Dialog::Buttons(
					nextActions_add => [
						['Add Another Fee Schedule Item', "/org/#session.org_id#/dlg-add-catalog-item/%field.catalog_id%", 1],
						['Show Current Fee Schedule Item', '/search/catalog/detail/%field.catalog_id%'],
						],
					cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('catalog_id', $page->param('catalog_id'));
	$page->field('parent_entry_id', $page->param('parent_entry_id'));
	$page->field('entry_type', 100);
	$page->field('status', 1);
	$page->field('cost_type', 1);
	$page->field('add_mode', 1);
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $entryId = $page->param('entry_id');
	if(! $STMTMGR_CATALOG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selCatalogItemById',$entryId))
	{
		$page->addError("Catalog Item ID '$entryId' not found.");
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
		
		my $field = $self->getField('catalog_id');
		$field->invalidate($page, qq{Entry already exists in the system.}) if $entryExists;
	}
}

sub customValidate
{
	my ($self, $page) = @_;
	
	my $fs = $page->param('_f_catalog_id');
	my $entryType = $page->param('_f_entry_type');
	my $code = $page->param('_f_code');
	my $modifier = $page->param('_f_modifier');
	
	$self->checkDupEntry($page, $fs, $entryType, $code, $modifier);
	
	if (
		(! $page->param('_f_name') || ! $page->param('_f_description')) &&
		(grep(/$entryType/, (App::Universal::CATALOGENTRYTYPE_ICD, App::Universal::CATALOGENTRYTYPE_CPT, App::Universal::CATALOGENTRYTYPE_HCPCS)) )
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

	my $catalogType = $page->field('catalog_type');
	my $status = $page->field('status');
	my $costType = $page->field('cost_type');
	my $entryType = $page->field('entry_type');

	my $entryId = $page->schemaAction(
		'Offering_Catalog_Entry', $command,
		catalog_id => $page->field('catalog_id') || undef,
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
		#taxable => $page->field('taxable') || undef,
		#default_units => $page->field('default_units') || undef,
		units_avail => $page->field('units_avail') || undef,
		_debug => 0
		);

	$page->param('_dialogreturnurl', '/search/catalog/detail/%field.catalog_id%') if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags);
}

1;
