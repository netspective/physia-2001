##############################################################################
package App::Dialog::WorklistSetup::Claim;
##############################################################################

use strict;
use Carp;

use vars qw(%RESOURCE_MAP);
use base qw(App::Dialog::CollectionSetup);

use DBI::StatementManager;
use App::Statements::Worklist::WorklistCollection;
use App::Statements::Org;

%RESOURCE_MAP = (
	'wl-claim-setup' => {},
);

sub initialize
{
	my $self = shift;

	$self->heading('Claims Worklist Setup');
	$self->SUPER::initialize();

	$self->addContent(
		new CGI::Dialog::Subhead(heading => 'Claims Status'),
		new CGI::Dialog::Field(
			name => 'claim_status_list',
			style => 'multidual',
			type => 'select',
			caption => '',
			multiDualCaptionLeft => 'Available Status',
			multiDualCaptionRight => 'Selected Status',
			size => '5',
			fKeyStmtMgr => $STMTMGR_WORKLIST_COLLECTION,
			fKeyStmt => 'sel_claim_statuses',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			hints => '',
		),

		new CGI::Dialog::Subhead(heading => 'Sort Order'),
		new CGI::Dialog::Field(type => 'select',
			style => 'radio',
			selOptions => 'Patient Last Name:1;Claim Status:2;Claim Balance:3',
			caption => '',
			name => 'sorting',
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	
	$page->param('itemNamePrefix', 'WorkList-Claims-Setup');
	$page->param('wl_LNameRange', 'WorkList-Claims-Setup-LnameRange');
	
	$self->SUPER::populateData($page, $command, $activeExecMode, $flags);

	my $userId =  $page->session('user_id');
	my $sessOrgId = $page->session('org_internal_id');
	
	my $claimStatusList = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page,
		STMTMGRFLAG_NONE, 'sel_worklist_claim_status', $userId, $sessOrgId, 
		$page->param('itemNamePrefix') . '-ClaimStatus');

	my @claimStats = ();
	for (@$claimStatusList)
	{
		push(@claimStats, $_->{status_id});
	}
	$page->field('claim_status_list', @claimStats);

	my $sorting = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page,
		STMTMGRFLAG_NONE, 'sel_worklist_claim_status', $userId, $sessOrgId, 
		$page->param('itemNamePrefix') . '-Sorting');
	$page->field('sorting', $sorting->{status_id});
	
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	$self->SUPER::execute($page, $command, $flags);

	my $userId = $page->session('user_id');
	my $orgId =  $page->session('org_id') || undef;

	my $orgIntId = $orgId ? $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', 
		$page->session('org_internal_id'), $orgId) : undef;
	
	$STMTMGR_WORKLIST_COLLECTION->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_claim_status', $userId, $orgIntId, $page->param('itemNamePrefix') . '-ClaimStatus');
	my @claimStats = $page->field('claim_status_list');
	for (@claimStats) 
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $orgIntId,
			item_name => $page->param('itemNamePrefix') . '-ClaimStatus',
			value_int => $_,
			_debug => 0
		);
	}

	$STMTMGR_WORKLIST_COLLECTION->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_claim_status', $userId, $orgIntId, $page->param('itemNamePrefix') . '-Sorting');

	$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $orgIntId,
			value_type => 110,
			item_name =>  $page->param('itemNamePrefix') . '-Sorting',
			value_int => $page->field('sorting'),
			_debug => 0
	);
		
	$self->handlePostExecute($page, $command, $flags, '/worklist/claim');
}

1;
