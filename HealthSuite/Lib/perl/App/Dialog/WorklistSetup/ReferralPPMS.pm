##############################################################################
package App::Dialog::WorklistSetup::ReferralPPMS;
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
use App::Statements::Worklist::WorklistCollection;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'wl-referral-setup' => {},	
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'ReferralPPMSSetup', heading => 'Referral Worklist Setup');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	my $resourcesField = new CGI::Dialog::Field(
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
	
	$self->addContent(

		new CGI::Dialog::Subhead(heading => 'Physicians'),
		$resourcesField,

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
		
		new CGI::Dialog::Subhead(heading => 'Patients Last Name'),
		new CGI::Dialog::MultiField(caption =>'Enter range:',
			name => 'LastNameRange',
			hints => 'Enter only the first letter of the last name.',
			fields => [
				new CGI::Dialog::Field(type=>'text',
						caption => 'Beginning of the range of last names',
						size => 2,
						type => 'alphaonly',
						maxLength => 1,
						name => 'LastNameFrom',
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
				new CGI::Dialog::Field(type=>'text',
						caption => 'End of the range of last names',
						size => 2,
						type => 'alphaonly',
						maxLength => 1,
						name => 'LastNameTo',
						invisibleWhen => CGI::Dialog::DLGFLAG_UPDATE),
			]),

		new CGI::Dialog::Subhead(heading => 'Expiring within days'),
		new CGI::Dialog::Field(
			name => 'expiryDays',
			caption => 'No. of Days',
			size => 5,
			maxLength => 5,
			type => 'integer',
			minValue=>1,
		),

		new CGI::Dialog::Subhead(heading => 'Sort Order'),
		new CGI::Dialog::Field(type => 'select',
			style => 'radio',
			selOptions => 'Insurance Org:1;Product:2;Speciality:3;Request Date:4',
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

	$page->param('itemNamePrefix', 'Referral-Worklist-Setup');

	my $userId =  $page->session('user_id');
	my $orgInternalId = $page->session('org_internal_id');
	
	my $itemNamePrefix = $page->param('itemNamePrefix');

	my $physicansList = $STMTMGR_WORKLIST_CREDIT->getRowsAsHashList($page, 
		STMTMGRFLAG_NONE, 'sel_worklist_credit_physician', $page->session('user_id'), $orgInternalId, $itemNamePrefix . '-Physician');

	my @physicians = ();
	for (@$physicansList)
	{
		push(@physicians, $_->{value_text});
	}
	$page->field('physician_list', @physicians);
	
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

	my $LastNameRange = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_lastname_range2', $userId, $orgInternalId,
		$itemNamePrefix . '-LNameRange');
	$page->field('LastNameFrom', $LastNameRange->{value_text});
	$page->field('LastNameTo', $LastNameRange->{lnameto});

	my $expiry = $STMTMGR_WORKLIST_CREDIT->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_credit_sorting', $userId, $orgInternalId, $itemNamePrefix . '-ExpiryDays');
	$page->field('expiryDays', $expiry->{value_int});

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

	# Add the Last-name range preference
	$STMTMGR_WORKLIST_COLLECTION->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_lastname_range', $userId, $orgInternalId, $itemNamePrefix . '-LNameRange');
	my $strLastNameFrom = $page->field('LastNameFrom');
	my $strLastNameTo = $page->field('LastNameTo');
	$strLastNameFrom =~ s/\s+//g;
	$strLastNameTo =~ s/\s+//g;
	if (length $strLastNameFrom == 0 && length $strLastNameTo == 0)
	{
		$strLastNameFrom = undef;
		$strLastNameTo = undef;
	}
	$page->schemaAction(
		'Person_Attribute',	'add',
		item_id => undef,
		parent_id => $userId,
		parent_org_id => $orgInternalId,
		value_type => App::Universal::ATTRTYPE_TEXT,,
		item_name => $itemNamePrefix . '-LNameRange',
		value_text => $strLastNameFrom,
		value_textB => $strLastNameTo,
		_debug => 0
	);

	# Update expiry days
	$STMTMGR_WORKLIST_CREDIT->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_credit_sorting', $userId, $orgInternalId, $itemNamePrefix . '-ExpiryDays');

	$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_internal_id') || undef,
			value_type => 110,
			item_name => $itemNamePrefix . '-ExpiryDays',
			value_int => $page->field('expiryDays'),
			parent_org_id => $orgInternalId,
			_debug => 0
	);


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
		
	$page->field('expiryDays') ?
	$self->handlePostExecute($page, $command, $flags, "/worklist/referralPPMS/exp") :
	$self->handlePostExecute($page, $command, $flags);
	
}

sub customValidate
{
	my ($self, $page) = @_;

	my ($strFrom, $strTo) = ($page->field('LastNameFrom'), $page->field('LastNameTo'));
	my $nameRangeFields = $self->getField('LastNameRange')->{fields}->[0];

	# Trim the strings white space
	$strFrom =~ s/\s+//g;
	$strTo =~ s/\s+//g;

	if ($strFrom gt $strTo  && length $strTo gt 0)
	{
		$nameRangeFields->invalidate($page, 'Invalid Last-Name range. The value on the left must be equal to or less than the value on the right.');
	}
}

1;