##############################################################################
package App::Dialog::LabLocation;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Org;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use App::Statements::LabTest;

use Date::Manip;
use Text::Abbrev;
use App::Universal;

use vars qw(@ISA %RESOURCE_MAP %PROCENTRYABBREV %RESOURCE_MAP %ITEMTOFIELDMAP %CODE_TYPE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'ancillary-location' => {
			_arl_update => ['item_id'],
			_arl_remove => ['item_id'],
			heading => '$Command Ancillary Location',
			addressName => 'Ancillary',
			org_category=>'Ancillary Service'
			},
	
	'pharmacy-location' => {
		heading => '$Command Pharmacy Location',
		org_category=>'Pharmacy',
		addressName => 'Pharmacy',
		_arl_update => ['item_id'],
		_arl_remove => ['item_id'],
	},	
);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', );

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Field( name => 'org_internal_id', type=>'hidden'),	
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
		new CGI::Dialog::Field( name => 'address_item_id', type=>'hidden'),						
		new CGI::Dialog::Field( name => 'phone_item_id', type=>'hidden'),								
		new CGI::Dialog::Field( name => 'fax_item_id', type=>'hidden'),										
		new App::Dialog::Field::Organization::ID(caption=>'Ancillary Org ID', 
					name=>'org_id',
					addType=>'ancillary',
					options=>FLDFLAG_REQUIRED | FLDFLAG_READONLY,
					),
		new CGI::Dialog::Field( caption=>'Location Name',name => 'location_name',options=>FLDFLAG_REQUIRED, type=>'text',size=>'20',maxLength=>'30'),						
		new App::Dialog::Field::Address(
			caption=>$self->{'addressName'} . " Address" ,
			name => 'address',
			options=>FLDFLAG_REQUIRED,
		),		
		new CGI::Dialog::MultiField(
			name => 'phone_fax',
			fields => [
				new CGI::Dialog::Field(
					caption => 'Phone',
					type=>'phone',
					name => 'phone',
				),
				new CGI::Dialog::Field(
					caption => 'Fax',
					type=>'phone',
					name => 'fax',
				),
			],
		),		
		
		);
		

	$self->{activityLog} =
	{
		scope =>'org_address',
		key => "#field.loc_name#",
		data => "Location",
	},
	$self->addFooter(new CGI::Dialog::Buttons(
	nextActions_add => [	['View Org Summary', "/org/%field.org_id%/profile", 1],
				['Add Ancillary Location', "/org/#session.org_id#/dlg-add-lab-location?_f_org_id=%field.org_id%"],
			],
	cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}



sub customValidate
{
	my ($self, $page) = @_;
	
	#get/store Org Internal Id 
	my $value = $page->field('org_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $value);
	$page->field('org_internal_id',$orgIntId);
	

	my $field = $self->getField('org_id');		
	my $fieldValue = $page->field('org_id');
	my $locValue = $page->field('location_name');		
	
	#Verfiy Org is Ancillary Type	
	my $id =  $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selFindOrgWithMemberId', $orgIntId,$self->{org_category});	
	$field->invalidate($page, qq{'$fieldValue' is not $self->{org_category} Organization }) unless($id);
	
	#Verfiy Location Name is unquie 
	if ($page->field('add_mode'))
	{
		my $address = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selOrgAddressByAddrName',$orgIntId,$locValue);
		if ($address)
		{
			my $locField = $self->getField('location_name');
			$locField->invalidate($page, qq{'$locValue' address already exists for '$fieldValue'.});
		}
	}
	
}


sub populateData_add
{
	my ($self, $page, $command, $flags) = @_;
	$page->field('add_mode', 1);
}
sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('add_mode', 0);
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	#Get Address Info
	my $address = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selOrgAddressById',$page->param('item_id')||undef);
	$page->field('org_internal_id',$address->{parent_id});
	$page->field('addr_line1',$address->{line1});
	$page->field('addr_line2',$address->{line2});
	$page->field('addr_city',$address->{city});
	$page->field('addr_state',$address->{state});
	$page->field('addr_zip',$address->{zip});
	$page->field('location_name',$address->{address_name});
	$page->field('address_item_id',$address->{item_id});
	
	#Get Org ID
	my $orgId = $STMTMGR_ORG->getSingleValue($page,STMTMGRFLAG_NONE,'selId',$page->field('org_internal_id'));
	$page->field('org_id',$orgId);

	
	#Get Phone Info
	my $phone = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selAttributeByItemNameAndValueTypeAndParent',
		$page->field('org_internal_id'),$page->field('location_name'),App::Universal::ATTRTYPE_PHONE);
	$page->field('phone_item_id',$phone->{item_id});
	$page->field('phone',$phone->{value_text});	
	#Get Fax Info


	my $fax = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selAttributeByItemNameAndValueTypeAndParent',
		$page->field('org_internal_id'),$page->field('location_name'),App::Universal::ATTRTYPE_FAX);
	$page->field('fax_item_id',$fax->{item_id});
	$page->field('fax',$fax->{value_text});	
		
}
sub populateData_remove
{
	populateData_update(@_);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $orgIntId = $page->field('org_internal_id');
	my $locName = $page->field('location_name');

	#store address
	$page->schemaAction(
			'Org_Address', $command,
			item_id =>$page->field('address_item_id'),
			parent_id => $orgIntId || undef,
			address_name => $locName,,
			line1 => $page->field('addr_line1') || undef,
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city') || undef,
			state => $page->field('addr_state') || undef,
			zip => $page->field('addr_zip')|| undef,);
	#store Phone numbers
	my $action = $command eq 'remove' ? $command : $page->field('phone_item_id') ? 'update' : 'add'	;
	$page->schemaAction(
			'Org_Attribute',$action,
			item_id =>$page->field('phone_item_id')	,		
			parent_id => $orgIntId,
			item_name => $locName,
			value_type => App::Universal::ATTRTYPE_PHONE ,
			value_text => $page->field('phone') ,
		) if $page->field('phone') ne '' ;

	#store Fax Number
	$action = $command eq 'remove' ? $command :  $page->field('fax_item_id') ? 'update' : 'add';	
	$page->schemaAction(
			'Org_Attribute', $action,
			item_id =>$page->field('fax_item_id'),
			parent_id => $orgIntId,
			item_name => $locName,
			value_type => App::Universal::ATTRTYPE_FAX ,
			value_text => $page->field('fax') ,

		) if $page->field('fax') ne'';	
	$self->handlePostExecute($page, $command, $flags, undef);
};

1;
