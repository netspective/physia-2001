##############################################################################
package App::Dialog::Attribute::Default;
##############################################################################
use strict;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'employment-empinfo' => {
		entityType => 'person',
		valueType => App::Universal::ATTRTYPE_EMPLOYMENTRECORD,
		propNameCaption => 'Property Name',
		propValueCaption => 'Property Value',
		heading => '$Command Employment Information',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_EMPLOYMENTRECORD()
		},
	'employment-salinfo' => {
		entityType => 'person',
		valueType => App::Universal::ATTRTYPE_EMPLOYMENTRECORD,
		propNameCaption => 'Property Name',
		propValueCaption => 'Property Value',
		heading => '$Command Salary Information',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_TEXT()
		},
	'person-additional' => {
		entityType => 'person',
		propNameCaption => 'Property Name',
		valueType => App::Universal::ATTRTYPE_PERSONALGENERAL,
		attrNameFmt => 'General/Personal',
		propValueCaption => 'Property Value',
		heading => '$Command Additional Data',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' . App::Universal::ATTRTYPE_PERSONALGENERAL()
		},
	'contact-personphone' => {
		heading => '$Command Telephone',
		propNameCaption => 'Name',
		propNameLookup => 'Person_Contact_Phones',
		propValueCaption => 'Telephone',
		propValueType => 'phone',
		propValueSize => 24,
		prefFlgCaption => 'Preferred phone',
		entityType => 'person',
		#attrNameFmt => 'Contact Method/Telephone',
		valueType => App::Universal::ATTRTYPE_PHONE,
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_PHONE()
		},
	'contact-personfax' => {
		heading => '$Command Fax',
		propNameCaption => 'Name',
		propNameLookup => 'Person_Contact_Phones',
		propValueCaption => 'Fax',
		propValueType => 'phone',
		propValueSize => 24,
		prefFlgCaption => 'Preferred fax',
		entityType => 'person',
		#attrNameFmt => 'Contact Method/Fax',
		valueType => App::Universal::ATTRTYPE_FAX,
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_FAX()
		},
	'contact-personpager' => {
		heading => '$Command Pager',
		propNameCaption => 'Name',
		propNameLookup => 'Person_Contact_Order',
		propValueCaption => 'Pager',
		propValueType => 'pager',
		propValueSize => 24,
		prefFlgCaption => 'Preferred pager',
		entityType => 'person',
		#attrNameFmt => 'Contact Method/Pager',
		valueType => App::Universal::ATTRTYPE_PAGER,
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_PAGER()
		},
	'contact-personemail' => {
		heading => '$Command E-mail',
		propNameCaption => 'Name',
		propNameLookup => 'Person_Contact_Order',
		propValueCaption => 'E-mail',
		propValueType => 'email',
		propValueSize => 24,
		prefFlgCaption => 'Preferred email',
		entityType => 'person',
		#attrNameFmt => 'Contact Method/EMail',
		valueType => App::Universal::ATTRTYPE_EMAIL,
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_EMAIL()
		},
	'contact-personinternet' => {
		heading => '$Command URL',
		propNameCaption => 'Name',
		propNameLookup => 'Person_Contact_Order',
		propValueCaption => 'URL',
		propValueType => 'url',
		propValueSize => 24,
		prefFlgCaption => 'Preferred internet address',
		entityType => 'person',
		#attrNameFmt => 'Contact Method/Internet',
		valueType => App::Universal::ATTRTYPE_URL,
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_URL()
		},
	'contact-orgphone' => {
		heading => '$Command Telephone',
		propNameCaption => 'Name',
		propNameLookup => 'Org_Contact_Name',
		propValueCaption => 'Telephone',
		propValueType => 'phone',
		propValueSize => 24,
		prefFlgCaption => 'Preferred phone',
		entityType => 'org',
		#attrNameFmt => 'Contact Method/Telephone',
		valueType => App::Universal::ATTRTYPE_PHONE,
		_arl => ['org_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Org-' .App::Universal::ATTRTYPE_PHONE()
		},
	'contact-orgfax' => {
		heading => '$Command Fax',
		propNameCaption => 'Name',
		propNameLookup => 'Org_Contact_Name',
		propValueCaption => 'Fax',
		propValueType => 'phone',
		propValueSize => 24,
		prefFlgCaption => 'Preferred fax',
		entityType => 'org',
		#attrNameFmt => 'Contact Method/Fax',
		valueType => App::Universal::ATTRTYPE_FAX,
		_arl => ['org_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Org-' .App::Universal::ATTRTYPE_FAX()
		},
	'contact-orgemail' => {
		heading => '$Command E-mail',
		propNameCaption => 'Name',
		propNameLookup => 'Org_Contact_Name',
		propValueCaption => 'E-mail',
		propValueType => 'email',
		propValueSize => 24,
		prefFlgCaption => 'Preferred email',
		entityType => 'org',
		#attrNameFmt => 'Contact Method/EMail',
		valueType => App::Universal::ATTRTYPE_EMAIL,
		_arl => ['org_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Org-' .App::Universal::ATTRTYPE_EMAIL()
		},
	'contact-orginternet' => {
		heading => '$Command URL',
		propNameCaption => 'Name',
		propNameLookup => 'Org_Contact_Name',
		propValueCaption => 'URL',
		propValueType => 'url',
		propValueSize => 24,
		prefFlgCaption => 'Preferred internet address',
		entityType => 'org',
		#attrNameFmt => 'Contact Method/Internet',
		valueType => App::Universal::ATTRTYPE_URL,
		_arl => ['org_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Org-' .App::Universal::ATTRTYPE_URL()
		},
	'contact-orgbilling' => {
		heading => '$Command Billing Contact Information',
		propNameCaption => 'Name',
		propValueCaption => 'Phone',
		propValueType => 'phone',
		propValueSize => 24,
		entityType => 'org',
		#attrNameFmt => 'Contact Method/Internet',
		valueType => App::Universal::ATTRTYPE_BILLING_PHONE,
		_arl => ['org_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-Org-' .App::Universal::ATTRTYPE_BILLING_PHONE()
		},
);


sub initialize
{
	my $self = shift;

	my $attrNameCaption = $self->{propNameCaption};
	my $attrNameLookup = $self->{propNameLookup};
	my $prefFlagCaption = $self->{prefFlgCaption};
	my $entityType = $self->{entityType};

	my $nameField =	$attrNameLookup ?
		new App::Dialog::Field::Attribute::Name(
				name => 'attr_name',
				lookup => $attrNameLookup,
				caption => $attrNameCaption,
				priKey => 1,
				attrNameFmt => "#field.attr_name#",
				fKeyStmtMgr => $entityType eq 'person' ? $STMTMGR_PERSON : $STMTMGR_ORG,
				valueType => $self->{valueType},
				selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent') :
		new App::Dialog::Field::Attribute::Name(
				name => 'attr_name',
				caption => $attrNameCaption,
				#priKey => 1,
				attrNameFmt => "#field.attr_name#",
				fKeyStmtMgr => $entityType eq 'person' ? $STMTMGR_PERSON : $STMTMGR_ORG,
				valueType => $self->{valueType},
				selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent');

	$self->addContent(
		$nameField,
		new CGI::Dialog::Field(
				type => $self->{propValueType},
				name => 'value_text',
				caption => $self->{propValueCaption},
				size => $self->{propValueSize},
				options => FLDFLAG_REQUIRED),
	);

	if($prefFlagCaption)
	{
		$self->addContent(
			new CGI::Dialog::Field(type => 'bool',
						caption => $prefFlagCaption,
						style => 'check',
						name => 'preferred_flag')
		);
	}

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

}

sub customValidate
{
	my ($self, $page) = @_;
	my $command = $self->getActiveCommand($page);
	my $billing = $self->getField('attr_name');
	my $parentId = $page->param('org_id');
	my $valueType = App::Universal::ATTRTYPE_BILLING_PHONE;
	my $billingExists = $STMTMGR_ORG->recordExists($page,STMTMGRFLAG_NONE, 'selAttributeByValueType', $parentId, $valueType);
	if($command eq 'add' && $billingExists eq 1)
	{

		$billing->invalidate($page, "'Billing Contact Phone' already exists for this Org");
	}
}

#THIS IS FOR URLs
#sub populateDialogData
#{
#	my ($self, $page, $dialog, $command, $activeExecMode, $flags) = @_;

#	if($flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL)
#	{
#		$self->getPage()->field('value_text', 'http://');
#	}
#	$self->SUPER::populateDialogData($page, $dialog, $command, $activeExecMode, $flags);
#}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');

	if($page->param('person_id'))
	{
		my $data = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
		$page->field('value_text', $data->{value_text});
		$page->field('attr_name', $data->{value_textb});
		$page->field('preferred_flag', 1) if $data->{value_int};
	}
	else
	{
		my $data = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
		$page->field('value_text', $data->{value_text});
		$page->field('attr_name', $data->{value_textb});
		$page->field('preferred_flag', 1) if $data->{value_int};
	}
}


sub execute_add
{
	my ($self, $page, $command,$flags) = @_;

	my $personId = $page->param('person_id');

	my $valueType = $self->{valueType} || '0';
	my $prefFlag = $page->field('preferred_flag') eq '' ? 0 : 1;
	my $itemName = '';
	#get table name
	my $tableName = '';

	if($personId)
	{
		$tableName = 'Person_Attribute';
	}

	else
	{
		$tableName = 'Org_Attribute';
	}

	if($valueType == App::Universal::ATTRTYPE_BILLING_PHONE)
	{
		$itemName = 'Contact Information';
	}

	else
	{
		$itemName = $page->field('attr_name');
	}

	my $parentId = $personId || $page->param('org_id');

	$page->schemaAction(
		$tableName, 'add',
		parent_id => $parentId,
		item_id => $page->param('item_id') || undef,
		item_name => $itemName || undef,
		value_type => defined $valueType ? $valueType : undef,
		value_text => $page->field('value_text') || undef,
		value_textB => $page->field('attr_name') || undef,
		value_int => defined $prefFlag ? $prefFlag : undef,
		_debug => 0
	);

	return "\u$command completed.";
}

sub execute_update
{
	my ($self, $page, $command,$flags) = @_;

	my $prefFlag = $page->field('preferred_flag') eq '' ? 0 : 1;

	#get table name
	my $tableName = '';
	if($page->param('person_id'))
	{
		$tableName = 'Person_Attribute';
	}
	else
	{
		$tableName = 'Org_Attribute';
	}

	$page->schemaAction(
		$tableName, 'update',
		item_id => $page->param('item_id') || undef,
		value_text => $page->field('value_text') || undef,
		value_textB => $page->field('attr_name') || undef,
		value_int => defined $prefFlag ? $prefFlag : undef,
		_debug => 0
	);

	return "\u$command completed.";
}

sub execute_remove
{
	my ($self, $page, $command,$flags) = @_;

	#get table name
	my $tableName = '';
	if($page->param('person_id'))
	{
		$tableName = 'Person_Attribute';
	}
	else
	{
		$tableName = 'Org_Attribute';
	}

	$page->schemaAction(
		$tableName, 'remove',
		item_id => $page->param('item_id') || undef,
		_debug => 0
	);

	return "\u$command completed.";
}

1;
