##############################################################################
package App::Dialog::Contract;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Contract;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Insurance;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Contract;
use Date::Manip;
use Text::Abbrev;
use App::Universal;
use App::Statements::Insurance;
use vars qw(@ISA %RESOURCE_MAP  );
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'contract' => {
		_arl_modify => ['internal_contract_id'],
		_arl_remove => ['internal_contract_id'],
	},
);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', heading => '$Command Contract Catalog');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	my $edit=1;
	$edit = 0 if ($command eq 'add');

	$self->addContent(
				$command,
		new App::Dialog::Field::Catalog::ID(caption => 'Fee Schedule ID',
			name => 'fee_schedule_id',
			type => 'text',
			options => FLDFLAG_REQUIRED | FLDFLAG_IDENTIFIER,
			findPopup => '/lookup/catalog',
		),
		new App::Dialog::Field::Insurance::Product(caption => 'Product Name',
			name => 'product_name',
			size => 30,
			options => FLDFLAG_REQUIRED,
			findPopup => '/lookup/insproduct',
			#findPopupControlField => '_f_ins_org_id',
		),
		new App::Dialog::Field::Contract::ID::New(caption => 'Contract Catalog Name',
			name => 'contract_id',
			size => 20,
			options => FLDFLAG_REQUIRED,
			byPassEdit=>$edit,
		),
		new CGI::Dialog::Field(caption => 'Contract Catalog Caption',
			name => 'caption',
			options => FLDFLAG_REQUIRED,
			size => 45,
		),



		new CGI::Dialog::Field(caption => 'Description',
			name => 'description',
			type => 'memo',
		),

		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode',value=>$command),
		new CGI::Dialog::Field(type => 'hidden', name => 'parent_catalog_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'product_ins_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),


	);

	$self->{activityLog} =
	{
		scope =>'Contract_catalog',
		key => "#field.contract_id#",
		data => "Contract Catalog '#field.contract_id#'"
	};
	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_add => [
			['Add Another Contract Schedule', '/org/#session.org_id#/dlg-add-contract'],
			['Show List of Contract Catalog', '/org/%session.org_id%/catalog?catalog=contract',1],
			['Go to Work List', "/worklist"],
			],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('add_mode',1);
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;


}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $contractID = $page->param('internal_contract_id');
	if(! $STMTMGR_CONTRACT->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selContractByID',$contractID))
	{
		$page->addError("Contract ID '$contractID' not found.");
	}
	#Get Text ID for Fee Schedule
	if ($page->field('parent_catalog_id'))
	{
		my $parentCatalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogById',$page->field('parent_catalog_id')) ;
		$page->field('fee_schedule_id',$parentCatalog->{catalog_id});
	};
	#Get Text for Insurance Product ID
	if($page->field('product_ins_id'))
	{
		my $insuranceData = $STMTMGR_INSURANCE->getRowAsHash($page,STMTMGRFLAG_NONE,'selInsuranceData',$page->field('product_ins_id')) ;
		$page->field('product_name',$insuranceData->{product_name});
	}
}

sub populateData_remove
{
	populateData_update(@_);
}

sub customValidate
{
	my ($self, $page) = @_;
	#check if Insurance Product Exists
	#Get Insurance Product Record
	my $productName = $page->field('product_name');
	my $fs = $page->field('fee_schedule_id');
	my $catalog_id;
	my $insId = $STMTMGR_INSURANCE->getRowAsHash($page,STMTMGRFLAG_NONE,'selProductRecord',$page->session('org_internal_id'),$page->field('product_name'));

	if ($insId)
	{
		#Get Numeric ID of Fee Schedule Parent
		my $fs_catalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selInternalCatalogIdByIdType',$page->session('org_internal_id') ,$page->field('fee_schedule_id'), 0);
		$catalog_id = $fs_catalog->{internal_catalog_id};
		$page->field('product_ins_id',$insId->{ins_internal_id});

		#Check if product and fee schedule already have a Contract
		if($page->field('add_mode'))
		{
			my $recExist = $STMTMGR_CONTRACT->getRowAsHash($page,STMTMGRFLAG_NONE,'selContractMatch',$page->session('org_internal_id'),
			$catalog_id,$insId->{ins_internal_id});
			my $field = $self->getField('product_name');
			$field->invalidate($page, qq{Contract Already exist for Product '$productName' and Fee Schedule  '$fs'.}) if $recExist;
		}
	}
	else
	{
		my $field = $self->getField('product_name');
		$field->invalidate($page, qq{Insurance Product '$productName' does not exists.})
	}

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $id = $self->{'id'};
	my $orgInternalId = $page->session('org_internal_id');
	my $orgId = $page->session('org_id');
	my $internalContractId = $page->param('internal_contract_id');

	#Get Numeric ID of Fee Schedule Parent
	my $fs_catalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selInternalCatalogIdByIdType',
		$page->session('org_internal_id') ,$page->field('fee_schedule_id'), 0);

	#Get Insurance Product Record
	my $insId = $STMTMGR_INSURANCE->getRowAsHash($page,STMTMGRFLAG_NONE,'selProductRecord',$page->session('org_internal_id'),
	$page->field('product_name'));
	my $newId = $page->schemaAction(
		'Contract_Catalog', $command,
		internal_contract_id => $command eq 'add' ? undef : $internalContractId,
		contract_id => $page->field('contract_id') || undef,
		org_internal_id => $orgInternalId || undef,
		caption => $page->field('caption') || undef,
		description => $page->field('description') || undef,
		parent_catalog_id =>$fs_catalog->{internal_catalog_id},
		product_ins_id =>$insId->{ins_internal_id}
	);

	$page->param('_dialogreturnurl', '/org/%session.org_id%/catalog?catalog=contract') if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags);
}

1;

