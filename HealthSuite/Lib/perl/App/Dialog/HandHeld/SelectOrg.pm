##############################################################################
package App::Dialog::HandHeld::SelectOrg;
##############################################################################

use strict;
use SDE::CVS ('$Id: SelectOrg.pm,v 1.1 2001-01-31 19:07:50 thai_nguyen Exp $', '$Name:  $');

use base qw(CGI::Dialog);
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Org;

use vars qw($INSTANCE);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'selectOrg');

	my $sqlStmt = qq{
		select distinct o.org_id, o.org_internal_id || ';' || o.org_id
		from org o, person_org_category poc
		where poc.person_id = :1
			and o.org_internal_id = poc.org_internal_id
		order by 1
	};
	
	$self->addContent(
		new CGI::Dialog::Field(caption => 'Select Org',
			name => 'select_org',
			type => 'select',
			fKeyDisplayCol => 0,
			fKeyValueCol => 1,
			fKeyStmtMgr => $STMTMGR_ORG,
			fKeyStmt => $sqlStmt,
			fKeyStmtFlags => STMTMGRFLAG_DYNAMICSQL,
			fKeyStmtBindSession => ['user_id'],
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub hideEntry
{
	return 1;	
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	
	$page->field('select_org', $page->session('org_internal_id') . ';' . $page->session('org_id'));
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my ($orgInternalId, $orgId) = split(/;/, $page->field('select_org'));
	
	$page->session('handheld_select_org', $orgId);
	$page->session('org_id', $orgId);
	$page->session('org_internal_id', $orgInternalId);
	$page->addCookie(-name => 'defaultOrg', -value => $orgId, -expires => '+1y');
	
	$page->redirect('/mobile?acceptDup=1');
}

$INSTANCE = new __PACKAGE__;
$INSTANCE->heading("Select Org");

1;
