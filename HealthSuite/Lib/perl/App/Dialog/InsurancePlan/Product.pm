##############################################################################
package App::Dialog::InsurancePlan::Product;
##############################################################################
use strict;
use Carp;
use DBI::StatementManager;
use CGI::Validator::Field;
use App::Dialog::InsurancePlan;
use App::Dialog::Field::Insurance;
use App::Statements::Org;
use App::Statements::Insurance;
use CGI::Dialog;
use App::Universal;

use vars qw(@ISA %RESOURCE_MAP);

%RESOURCE_MAP = (
	'ins-product' => {
			heading => '$Command Insurance Product',
			_arl_add => ['product_name'],
			_arl_modify => ['ins_internal_id'],
			},
		);

use Date::Manip;

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'product', heading => '$Command Insurance Product');

		#my $id = $self->{'id'}; 	# id = 'insur_pay' | 'personal_pay'

		my $schema = $self->{schema};
		delete $self->{schema};  # make sure we don't store this!

		croak 'schema parameter required' unless $schema;

		$self->addContent(
			new CGI::Dialog::Field(type => 'hidden', name => 'phone_item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'fax_item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'fee_item_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'pre_product_id'),
			new CGI::Dialog::Field(type => 'hidden', name => 'pre_org_id'),

			new App::Dialog::Field::Organization::ID(caption => 'Insurance Company Id',
				name => 'ins_org_id',
				options => FLDFLAG_REQUIRED
			),
			new App::Dialog::Field::Insurance::Product::New(caption => 'Product Name',
				name => 'product_name',
				size => 24,
				findPopup => '/lookup/insproduct/insorgid/itemValue',
				findPopupControlField => '_f_ins_org_id',
				options => FLDFLAG_REQUIRED,
			),
			new CGI::Dialog::Field::TableColumn(caption => 'Product Type',
				schema => $schema,
				column => 'Insurance.ins_type',
				typeGroup => ['insurance', 'workers compensation']
			),
			new App::Dialog::Field::Catalog::ID(caption => 'Fee Schedule ID',
				name => 'fee_schedules',
				type => 'integer',
				findPopup => '/lookup/catalog',
				hints => 'Numeric Fee Schedule ID',
			),
			new App::Dialog::Field::Address(caption=>'Billing Address',
				name => 'billing_addr',
				options => FLDFLAG_REQUIRED
			),
			new CGI::Dialog::MultiField(caption =>'Phone/Fax', name => 'phone_fax',
				fields => [
					new CGI::Dialog::Field(type=>'phone',
							caption => 'Phone',
							name => 'phone',
							options => FLDFLAG_REQUIRED,
							invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
					new CGI::Dialog::Field(type=>'phone',
							caption => 'Fax',
							name => 'fax',
							invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
				]
			),
			new CGI::Dialog::Subhead(heading => 'Remittance Information',
				name => 'remittance_heading'
			),
			new CGI::Dialog::Field(caption => 'Remittance Type',
				name => 'remit_type',
				#schema => $schema,
				#column => 'Insurance.Remit_Type'
				choiceDelim =>',',
				selOptions => "Paper:0,Electronic:1",
				type => 'select',
			),
			new CGI::Dialog::Field(caption => 'E-Remittance Payer ID',
				name => 'remit_payer_id',
				hints=> '(Only for non-Paper types)',
				findPopup => '/lookup/epayer'
			),
			new CGI::Dialog::Field(caption => 'Remit Payer Name', 
				name => 'remit_payer_name'
			),
		);

		$self->{activityLog} =
		{
			scope =>'insurance',
			key => "#field.ins_org_id#",
			data => "Insurance '#field.product_name#' in <a href='/org/#field.ins_org_id#/profile'>#field.ins_org_id#</a>"
		};

		$self->addFooter(new CGI::Dialog::Buttons(
				nextActions_add => [
					['Add Insurance Plan', "/org/%param.org_id%/dlg-add-ins-plan?_f_product_name=%field.product_name%&_f_ins_org_id=%field.ins_org_id%", 1],
					['Add Another Insurance Product', "/org/%param.org_id%/dlg-add-ins-product?_f_ins_org_id=%field.ins_org_id%"],
					['Go to Org Profile', "/org/%param.org_id%/profile"],
				],
					cancelUrl => $self->{cancelUrl} || undef
			)
		);
	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);


	my $insOrgId =  $page->field('org_id');
	my $category = $STMTMGR_ORG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selMemberNames', $insOrgId);

	foreach my $cat (@{$category})
	{
		$cat->{'member_name'} eq 'Insurance' ? $page->field('ins_org_id', $insOrgId) : $page->field('ins_org_id', '');
	}

}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless ($flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL);
	my $insIntId = $page->param('ins_internal_id');
		if(! $STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId))
		{
			$page->addError("Ins Internal ID '$insIntId' not found.");
		}

	my $preProductName = $page->field('product_name');
	my $preOrgId = $page->field('ins_org_id');
	$page->field('pre_product_id', $preProductName);
	$page->field('pre_org_id', $preOrgId);

	$STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsuranceAddr', $insIntId);
	my $insPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selInsuranceAttr_Org',	$insIntId, 'Contact Method/Telephone/Primary',
		$page->session('org_id')
	);
	$page->field('phone_item_id', $insPhone->{'item_id'});
	$page->field('phone', $insPhone->{'value_text'});

	my $insFax = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selInsuranceAttr_Org', $insIntId, 'Contact Method/Fax/Primary',
		$page->session('org_id')
	);
	$page->field('fax_item_id', $insFax->{'item_id'});
	$page->field('fax', $insFax->{'value_text'});

	my $feeSched = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_NONE,
		'selInsuranceAttr_Org', $insIntId, 'Fee Schedule', $page->session('org_id'));
	my @feeList = ();
	my @feeItemList = ();
	my $fee = '';
	my $feeItem = '';
	foreach my $feeSchedule (@{$feeSched})
	{
		push (@feeItemList, $feeSchedule->{'item_id'});
		push(@feeList, $feeSchedule->{'value_text'});
		$fee = join(',', @feeList);
		$feeItem = join(',', @feeItemList);
	}

	$page->field('fee_schedules', $fee);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $editInsIntId = $page->param('ins_internal_id');
	my $productName = $page->field('product_name');
	my $insType = $page->field('ins_type');
	my $insOrgId = $page->field('ins_org_id');
	my $insIntId = $page->schemaAction(
		'Insurance', $command,
		ins_internal_id => $editInsIntId || undef,
		product_name => $productName || undef,
		record_type => App::Universal::RECORDTYPE_INSURANCEPRODUCT || undef,
		#fee_schedule => $page->param('fee_schedule') || undef,
		owner_org_id => $page->session('org_id'),
		ins_org_id => $page->field('ins_org_id') || undef,
		ins_type => $insType || undef,
		remit_type => $page->field('remit_type') || undef,
		remit_payer_id => $page->field('remit_payer_id') || undef,
		remit_payer_name => $page->field('remit_payer_name') || undef,
		_debug => 0
	);

	if ($command eq 'update')
	{
		my $preProductName = $page->field('pre_product_id');
		my $preOrgId = $page->field('pre_org_id');
		my $updateData = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selUpdatePlanAndCoverage', $insType, $productName, $insOrgId, $preProductName, $preOrgId);
	}

	$insIntId = $command eq 'add' ? $insIntId : $editInsIntId;

	$self->handleAttributes($page, $command, $flags, $insIntId);
}

sub handleAttributes
{
	my ($self, $page, $command, $flags, $insIntId) = @_;

	$page->schemaAction(
			'Insurance_Address', $command,
			item_id => $page->field('item_id') || undef,
			parent_id => $insIntId || undef,
			address_name => 'Billing',
			line1 => $page->field('addr_line1') || undef,
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city') || undef,
			state => $page->field('addr_state') || undef,
			zip => $page->field('addr_zip') || undef,
			_debug => 0
		);

	my $textAttrType = App::Universal::ATTRTYPE_TEXT;
	my $phoneAttrType = App::Universal::ATTRTYPE_PHONE;
	my $faxAttrType = App::Universal::ATTRTYPE_FAX;

	$page->schemaAction(
			'Insurance_Attribute', $command,
			item_id => $page->field('phone_item_id') || undef,
			parent_id => $insIntId || undef,
			item_name => 'Contact Method/Telephone/Primary',
			value_type => defined $phoneAttrType ? $phoneAttrType : undef,
			value_text => $page->field('phone') || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Insurance_Attribute', $command,
			item_id => $page->field('fax_item_id') || undef,
			parent_id => $insIntId || undef,
			item_name => 'Contact Method/Fax/Primary',
			value_type => defined $faxAttrType ? $faxAttrType : undef,
			value_text => $page->field('fax') || undef,
			_debug => 0
		);


	my @feeSched =split(',', $page->field('fee_schedules'));

	$STMTMGR_INSURANCE->getRowsAsHashList($page,STMTMGRFLAG_NONE, 'selDeleteFeeSchedule',
		$insIntId, $page->session('org_id'));

	foreach my $fee (@feeSched)
	{
		$page->schemaAction(
			'Insurance_Attribute', 'add',
			item_id => $page->field('fee_item_id') || undef,
			parent_id => $insIntId || undef,
			item_name => 'Fee Schedule' || undef,
			value_text => $fee || undef,
			value_type => 0,
			_debug => 0
		);
	}

	$page->param('_dialogreturnurl', "/search/insproduct");
	$self->handlePostExecute($page, $command, $flags);
	return '';
}

1;
