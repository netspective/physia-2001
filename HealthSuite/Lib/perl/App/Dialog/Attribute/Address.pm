##############################################################################
package App::Dialog::Attribute::Address;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'address-person' => {
		valueType => App::Universal::ATTRTYPE_FAKE_ADDRESS,
		 tableId => 'Person_Contact_Addrs',
		 heading => '$Command Address',
		 table => 'Person_Address',
		 _arl => ['person_id'],
		 _arl_modify => ['item_id'],
		_idSynonym => 'attr-person-' .App::Universal::ATTRTYPE_FAKE_ADDRESS()
		},
	'address-org' => {
		valueType => App::Universal::ATTRTYPE_FAKE_ADDRESS,
		tableId => 'Org_Contact_Addrs',
		heading => '$Command Address',
		table => 'Org_Address',
		_arl => ['org_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-org-' .App::Universal::ATTRTYPE_FAKE_ADDRESS()
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'contactmethod', heading => '$Command Address');

	my $schema = $self->{schema};
	my $table = $self->{table};
	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
			new CGI::Dialog::Field(priKey => 1, lookup => $self->{tableId}, caption => 'Name', name => 'address_name'),
			new App::Dialog::Field::Address(namePrefix => '', options => FLDFLAG_REQUIRED),
		);
		if($table eq 'Person_Address')
		{
			$self->{activityLog} =
			{
				level => 2,
				scope => 'person_address',
				key => "#param.person_id#",
				data => "Address '#field.address_name#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
			};
		}
		elsif($table eq 'Org_Address')
		{
			$self->{activityLog} =
			{
				level => 2,
				scope => 'org_address',
				key => "#param.org_id#",
				data => "Address '#field.address_name#' to <a href='/org/#param.org_id#/profile'>#param.org_id#</a>"
			};
	}
	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub customValidate
{
	my ($self, $page) = @_;

	my $command = $self->getActiveCommand($page);
	return () if $command ne 'add';

	my $table = $self->{table};
	my $addressName = $page->field('address_name');
	my $dialogItem = $self->getField('address_name');

	if($table eq 'Person_Address')
	{
		my $parentId = $page->param('person_id');
		return $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selPersonAddressByAddrName', $parentId, $addressName) ?
			$dialogItem->invalidate($page, "The '$addressName' address already exists for $parentId.") :
			();
	}

	elsif($table eq 'Org_Address')
	{
		my $parentId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id'));
		return $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE, 'selOrgAddressByAddrName', $parentId, $addressName) ?
			$dialogItem->invalidate($page, "The '$addressName' address already exists for $parentId.") :
			();
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $table = $self->{table};
	my $addrId = $page->param('item_id');

	if ($table eq 'Person_Address')
	{
		$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonAddressById', $addrId);
	}
	elsif ($table eq 'Org_Address')
	{
		$STMTMGR_ORG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selOrgAddressById', $addrId);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $parentId = $page->param('person_id');
	if ($page->param('org_id'))
	{
		$parentId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id'));
	}
	$page->schemaAction(
		$self->{table}, $command,
		parent_id => $parentId,
		address_name => $page->field('address_name'),
		item_id => $page->param('item_id') || undef,
		line1 => $page->field('line1'),
		line2 => $page->field('line2'),
		city => $page->field('city'),
		state => $page->field('state'),
		zip => $page->field('zip'),
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);

	return "\u$command completed.";
}

1;
