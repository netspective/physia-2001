##############################################################################
package App::Dialog::Attribute::Authorization;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Person;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

sub initialize
{
	my $self = shift;

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Authorization to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');

	my $data = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
	$page->field('value_int', $data->{value_int});
	$page->field('value_textb', $data->{value_textb});
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $todaysDate = $page->getDate();
	my $valueType = $self->{valueType};

	my $authorization = $page->field('value_textb');
	my $itemName = '';
	my $authCaption = '';
	my $indicator = undef;

	if($valueType == App::Universal::ATTRTYPE_AUTHPATIENTSIGN)
	{
		$itemName = 'Signature Source';
		$authCaption = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selAuthSignatureCaption', $authorization);
	}
	
	elsif($valueType == App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN)
	{
		$itemName = 'Provider Assignment';
		$authCaption = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selAuthAssignCaption', $authorization);
	}
	
	elsif($valueType == App::Universal::ATTRTYPE_AUTHINFORELEASE)
	{
		$itemName = 'Information Release';
		$authCaption = $page->field('value_int') ? 'Yes' : 'No';
		$indicator = $authorization eq 'Yes' ? 1 : 0;
	}

	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id => $page->param('person_id'),
		parent_org_id => $page->session('org_id') || undef,
		item_id => $page->param('item_id') || undef,
		item_name => $itemName || undef,
		value_type => $valueType || undef,
		value_text => $authCaption || undef,
		value_textB => $authorization || undef,
		value_int => defined $indicator ? $indicator : undef,
		value_date => $todaysDate || undef,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

use constant PANEDIALOG_AUTHORIZATION => 'Dialog/Authorization';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/28/2000', 'MAF',
		PANEDIALOG_AUTHORIZATION,
		'Created new dialog for authorizations.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/14/2000', 'RK',
		PANEDIALOG_AUTHORIZATION,
		'Removed Item Path from Item Name'],
);

1;