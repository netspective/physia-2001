##############################################################################
package App::Dialog::CollectionSetup;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::Worklist::WorklistCollection;
use App::Statements::Org;

use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP @ITEM_TYPES @EXPORT
	%PATIENT_URLS
	%PHYSICIAN_URLS
	%ORG_URLS
	%APPT_URLS
	$patientDefault
	$physicianDefault
	$orgDefault
	$apptDefault
);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'wl-collection-setup' => {},
);

@ITEM_TYPES = ('patient', 'physician', 'org', 'appt');

%PATIENT_URLS = (
	'View Profile' => {arl => '/person/itemValue/profile', title => 'View Profile'},
	'View Chart' => {arl => '/person/itemValue/chart', title => 'View Chart'},
	'View Account' => {arl => '/person/itemValue/account', title => 'View Account'},
	'Make Appointment' => {arl => '/worklist/patientflow/dlg-add-appointment/itemValue', title => 'Make Appointment'},
);

%PHYSICIAN_URLS = (
	'View Profile' => {arl => '/person/itemValue/profile', title => 'View Profile'},
	'View Schedule' => {arl => '/schedule/apptcol/itemValue', title => 'View Schedule'},
	'Add Template' => {arl => '/worklist/patientflow/dlg-add-template/itemValue', title => 'Add Schedule Template'},
);

%ORG_URLS = (
	'View Profile' => {arl => '/org/itemValue/profile', title => 'View Profile'},
	'View Fee Schedules' => {arl => '/org/itemValue/catalog', title => 'View Fee Schedules'},
);

%APPT_URLS = (
	'Reschedule' => {arl => '/worklist/patientflow/dlg-reschedule-appointment/itemValue', title => 'Reschedule Appointment'},
	'Cancel' => {arl => '/worklist/patientflow/dlg-cancel-appointment/itemValue', title => 'Cancel Appointment'},
	'No-Show' => {arl => '/worklist/patientflow/dlg-noshow-appointment/itemValue', title => 'No-Show Appointment'},
	'Update' => {arl => '/worklist/patientflow/dlg-update-appointment/itemValue', title => 'Update Appointment'},
);

$patientDefault = 'View Profile';
$physicianDefault = 'View Profile';
$orgDefault = 'View Profile';
$apptDefault = 'Update';

@EXPORT = qw(%PATIENT_URLS %PHYSICIAN_URLS %ORG_URLS %APPT_URLS @ITEM_TYPES);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'worklistCollectionSetup',
	heading => 'Collection Worklist Setup',
	headColor => "LIGHTSTEELBLUE",
	);

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	my $resourcesField = new CGI::Dialog::Field(
		name => 'physician_list',
		style => 'multidual',
		type => 'select',
		caption => '',
		multiDualCaptionLeft => 'Available Physicians',
		multiDualCaptionRight => 'Selected Physicians',
		width => '150',
		size => '5',
		fKeyStmtMgr => $STMTMGR_WORKLIST_COLLECTION,
		fKeyStmt => 'sel_worklist_available_physicians',
		fKeyStmtBindSession => ['org_internal_id'],
		hints => ''
	);

	my $facilitiesField = new App::Dialog::Field::OrgType(
		caption => '',
		types => "'CLINIC', 'FACILITY/SITE','PRACTICE'",
		name => 'facility_list',
		style => 'multidual',
		multiDualCaptionLeft => 'Available Facilities',
		multiDualCaptionRight => 'Selected Facilities',		
		type => 'select',
		width => '150',
		size => '5',
		#hints => 'Choose one or more Facilities to monitor.'
	);
	$facilitiesField->clearFlag(FLDFLAG_REQUIRED);

	my $patientSelOptions;
	for my $key (reverse sort(keys %PATIENT_URLS))
	{
		#$patientSelOptions .= "$key:$PATIENT_URLS{$key}->{arl},";
		$patientSelOptions .= "$key:$key,";
	}

	my $physSelOptions;
	for my $key (reverse sort(keys %PHYSICIAN_URLS))
	{
		#$physSelOptions .= "$key:$PHYSICIAN_URLS{$key}->{arl},";
		$physSelOptions .= "$key:$key,";
	}

	my $orgSelOptions;
	for my $key (reverse sort(keys %ORG_URLS))
	{
		#$orgSelOptions .= "$key:$ORG_URLS{$key}->{arl},";
		$orgSelOptions .= "$key:$key,";
	}

	my $apptSelOptions;
	for my $key (reverse sort(keys %APPT_URLS))
	{
		#$apptSelOptions .= "$key:$APPT_URLS{$key}->{arl},";
		$apptSelOptions .= "$key:$key,";
	}

	$self->addContent(		

		new CGI::Dialog::Subhead(heading => 'Physicians'),
		$resourcesField,

		new CGI::Dialog::Subhead(heading => 'Service Facilities'),
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
				width => '150',
				size => '5',
				fKeyStmtMgr => $STMTMGR_WORKLIST_COLLECTION,
				fKeyStmt => 'sel_worklist_available_products',
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

		new CGI::Dialog::Subhead(heading => 'Age of the Balance'),
		new CGI::Dialog::MultiField(caption =>'Age range:',
			name => 'BalanceAge',
			hints => 'Enter minimum and maximum age of balance in days.',			
			fields => [
				new CGI::Dialog::Field(
					name => 'BalanceAgeMin',
					caption => 'Age greater than:',
					size => 5,
					maxLength => 5,
					type => 'integer',
					minValue=>1,
				),
				new CGI::Dialog::Field(
					name => 'BalanceAgeMax',
					caption => 'Age less than:',
					size => 5,
					maxLength => 5,
					type => 'integer',
					minValue=>1,
				),
			]),

		new CGI::Dialog::Subhead(heading => 'Amount of Balance'),
		new CGI::Dialog::MultiField(caption =>'Amount range:',
			name => 'BalanceAmountRange',
			hints => 'Enter minimum and maximum balance amount.',
			fields => [
				new CGI::Dialog::Field(
					name => 'BalanceAmountMin',
					caption => 'Amounts over:',
					size => 5,
					maxLength => 5,
					type => 'integer',
					minValue=>1,					
				),
				new CGI::Dialog::Field(
					name => 'BalanceAmountMax',
					caption => 'Amounts under:',
					size => 5,
					maxLength => 5,
					type => 'integer',
					minValue=>1,					
				),
			]),

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
	my $userId =  $page->session('user_id');
	my $sessOrgId = $page->session('org_internal_id');
	
	#Check if the all products option was selected if so get all products move to list
	#if so hide the product list box
	my $productsAll = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_all_products', $userId, $sessOrgId);
	if($productsAll->{value_int} == -1)
	{
		$self->addPostHtml(
	       	qq{
			<script language="JavaScript1.2">	
			setIdDisplay("products",'none');
			</script>
		});
	}
}

###############################
# populateData functions
###############################

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $userId =  $page->session('user_id');
	my $sessOrgId = $page->session('org_internal_id');

	# Populate the selected physicians
	my $physicianList = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page,
		STMTMGRFLAG_NONE, 'sel_worklist_associated_physicians', $userId);
	my @physicians = ();
	for (@$physicianList)
	{
		push(@physicians, $_->{person_id});
	}
	$page->field('physician_list', @physicians);

	#Get products
	
	#Check if the all products option was selected if so get all products move to list
	my $productsAll = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_all_products', $userId, $sessOrgId);
	if($productsAll->{value_int} == -1)
	{
		$page->field('product_select',1);
		my $productsList = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page,
			STMTMGRFLAG_NONE, 'sel_worklist_available_products',  $sessOrgId);
		my @products = ();
		for (@$productsList)
		{
	#		push(@products, $_->{product_id});
		}
		$page->field('products', @products);		
	}
	else
	{
		my $productsList = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page,
			STMTMGRFLAG_NONE, 'sel_worklist_associated_products', $userId, $sessOrgId);
		my @products = ();
		for (@$productsList)
		{
			push(@products, $_->{product_id});
		}
		$page->field('products', @products);
	}
	# Populate the selected facilities
	my $facilityList = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page,
		STMTMGRFLAG_NONE, 'sel_worklist_facilities', $userId, $sessOrgId);
	my @facilities = ();
	for (@$facilityList)
	{
		push(@facilities, $_->{facility_id});
	}
	$page->field('facility_list', @facilities);

	for my $itemType (@ITEM_TYPES)
	{
		my $name = $itemType . 'OnSelect';

		if ($page->session($name))
		{
			$page->field($name, $page->session($name));
		}
		else
		{
			my $itemName = 'WorklistCollection/' . "\u$itemType" . '/OnSelect';
			my $preference = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page, STMTMGRFLAG_NONE,
				'selSchedulePreferences', $userId, $itemName);

			if (my $itemUrl = $preference->{resource_id})
			{
				$page->session($name, $itemUrl);
				$page->field($name, $itemUrl);
			}
		}
	}

	my $LastNameRange = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_lastname_range', $userId, $sessOrgId);
	$page->field('LastNameFrom', $LastNameRange->{value_text});
	$page->field('LastNameTo', $LastNameRange->{lnameto});

	my $BalanceAgeRange = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_balance_age_range', $userId, $sessOrgId);
	$page->field('BalanceAgeMin', $BalanceAgeRange->{value_int});
	$page->field('BalanceAgeMax', $BalanceAgeRange->{balance_age_to});

	my $BalanceAmountRange = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_balance_amount_range', $userId, $sessOrgId);
	$page->field('BalanceAmountMin', $BalanceAmountRange->{value_float});
	$page->field('BalanceAmountMax', $BalanceAmountRange->{balance_amount_to});
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $userId =  $page->session('user_id');
	my $orgId =  $page->session('org_id') || undef;
	my $orgIntId = undef;
	if ($orgId)
	{
		$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId);	
	}
	else 
	{
		$orgIntId = undef;	
	}


	$STMTMGR_WORKLIST_COLLECTION->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_associated_physicians', $userId, $orgIntId);
	my @physicians = $page->field('physician_list');
	for (@physicians)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $orgIntId,
			value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
			item_name => 'WorkList-Collection-Setup-Physician',
			value_text => $_,
			_debug => 0
		);
	}

	$STMTMGR_WORKLIST_COLLECTION->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_orgvalue', $userId, $orgIntId);
	my @facilities = $page->field('facility_list');
	for (@facilities)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $orgIntId,
			value_type => App::Universal::ATTRTYPE_RESOURCEORG || undef,
			item_name => 'WorkList-Collection-Setup-Org',
			value_text => $_,
			_debug => 0
		);
	}

	$STMTMGR_WORKLIST_COLLECTION->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_associated_products', $userId, $orgIntId);
	if($page->field('product_select'))
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $orgIntId,
			value_type => App::Universal::ATTRTYPE_INTEGER || undef,
			item_name => 'WorkList-Collection-Setup-Product',
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
				parent_org_id => $orgIntId,
				value_type => App::Universal::ATTRTYPE_INTEGER || undef,
				item_name => 'WorkList-Collection-Setup-Product',
				value_int => $_,
				_debug => 0
			);
		}
	}


	# Add the Last-name range preference
	$STMTMGR_WORKLIST_COLLECTION->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_lastname_range', $userId, $orgIntId);
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
		parent_org_id => $orgIntId,
		value_type => App::Universal::ATTRTYPE_TEXT,,
		item_name => 'WorkListCollectionLNameRange',
		value_text => $strLastNameFrom,
		value_textB => $strLastNameTo,
		_debug => 0
	);

	# Update balance age
	$STMTMGR_WORKLIST_COLLECTION->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_balance_age_range', $userId, $orgIntId);
	my $intMinAge = $page->field('BalanceAgeMin');
	my $intMaxAge = $page->field('BalanceAgeMax');
	if (length $intMinAge == 0)
	{
		$intMinAge = undef;
	}
	if (length $intMaxAge == 0)
	{
		$intMaxAge = undef;
	}
	$page->schemaAction(
		'Person_Attribute',	'add',
		item_id => undef,
		parent_id => $userId,
		parent_org_id => $orgIntId,
		value_type => App::Universal::ATTRTYPE_INTEGER,,
		item_name => 'WorkList-Collection-Setup-BalanceAge-Range',
		value_int => $intMinAge,
		value_intB => $intMaxAge,
		_debug => 0
	);

	# Update balance amount range
	$STMTMGR_WORKLIST_COLLECTION->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_balance_amount_range', $userId, $orgIntId);
	my $intMinAmount = $page->field('BalanceAmountMin');
	my $intMaxAmount = $page->field('BalanceAmountMax');
	if (length $intMinAmount == 0)
	{
		$intMinAmount = undef;
	}
	if (length $intMaxAmount == 0)
	{
		$intMaxAmount = undef;
	}
	$page->schemaAction(
		'Person_Attribute',	'add',
		item_id => undef,
		parent_id => $userId,
		parent_org_id => $orgIntId,
		value_type => App::Universal::ATTRTYPE_FLOAT,,
		item_name => 'WorkList-Collection-Setup-BalanceAmount-Range',
		value_float => $intMinAmount,
		value_floatB => $intMaxAmount,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags, '/worklist/collection');
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
	my ($intBalanceAgeMin, $intBalanceAgeMax) = ($page->field('BalanceAgeMin'), $page->field('BalanceAgeMax'));
	if (length $intBalanceAgeMin > 0 && length $intBalanceAgeMax > 0)
	{
		my $balanceAgeFields = $self->getField('BalanceAge')->{fields}->[0];	
		if ($intBalanceAgeMin > $intBalanceAgeMax)
		{

			$balanceAgeFields->invalidate($page, "Invalid \"Balance Age\" range. The value on the left must be equal to or less than the value on the right.");
		}
		if ($intBalanceAgeMin == 0 || $intBalanceAgeMax == 0)		
		{
			$balanceAgeFields->invalidate($page, "Invalid \"Balance Age\" range. Min and Max value must be greater than 0.");		
		}
	}
	
	my ($intBalanceAmountMin, $intBalanceAmountMax) = ($page->field('BalanceAmountMin'), $page->field('BalanceAmountMax'));
	if (length $intBalanceAmountMin > 0 && length $intBalanceAmountMax > 0)
	{
		my $balanceAmountFields = $self->getField('BalanceAmountRange')->{fields}->[0];
		if ($intBalanceAmountMin > $intBalanceAmountMax)
		{

			$balanceAmountFields->invalidate($page, "Invalid \"Balance Amount\" range. The value on the left must be equal to or less than the value on the right.");
		}
		if ($intBalanceAmountMin == 0 || $intBalanceAmountMax == 0)
		{

			$balanceAmountFields->invalidate($page, "Invalid \"Balance Amount\" range. Min and Max value must be greater than 0.");
		}
		
	}
}

1;
