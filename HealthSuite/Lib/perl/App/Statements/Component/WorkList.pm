##############################################################################
package App::Statements::Component::WorkList;
##############################################################################

use strict;
use Exporter;
use Date::Manip;
use DBI::StatementManager;
use App::Universal;
use Data::Publish;
use App::Statements::Component;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_WORKLIST
	);
@ISA    = qw(Exporter App::Statements::Component);
@EXPORT = qw($STMTMGR_COMPONENT_WORKLIST);

my $ACCOUNT_NOTES = App::Universal::TRANSTYPE_ACCOUNTNOTES;
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;

$STMTMGR_COMPONENT_WORKLIST = new App::Statements::Component::WorkList(
#----------------------------------------------------------------------------------------------------------------------
'worklist.account-notes' => 
{


	sqlStmt => qq	{
			select  trans_owner_id, detail,trans_id,trans_type,provider_id
			from transaction
			where trans_owner_id = :1 and					
			trans_status = 2 and
			trans_type = $ACCOUNT_NOTES 			
		    	},
	sqlStmtBindParamDescr => ['Person ID for transaction table'],
	publishDefn => {
			columnDefn => 	[
					{ head => 'Account Notes', dataFmt => '#&{?}#<br/><I>(#4#) : #1#</I>' },
					],
			bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#3#/#2#?home=#homeArl#',
			frame => {
					addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-account-notes?home=#homeArl#',
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
				},
			},
	publishDefn_panel =>
			{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel',
			frame => { heading => 'Account Notes' },
			},
			publishDefn_panelTransp =>
			{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel.transparent',
			inherit => 'panel',
			},
			publishDefn_panelEdit =>
			{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel.edit',
			frame => { heading => 'Edit Account Notes' },
			banner => {
				actionRows =>
				[
				{	url => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-alert-person?home=#param.home#',
				caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-account-notes/#param.person_id#?home=#param.home#'>Account Notes</A> },
				},
				],
			},
			stdIcons =>	{
					updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#3#/#param.person_id#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#3#/#2#/#0#?home=#param.home#'
				},
},

	publishComp_st => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id'); $sessionId||=$page->session('user_id'); $STMTMGR_COMPONENT_WORKLIST->createHtml($page, $flags, 'worklist.account-notes',  [$personId] ); },
	publishComp_stp => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id');$sessionId||=$page->session('user_id');  $STMTMGR_COMPONENT_WORKLIST->createHtml($page, $flags, 'worklist.account-notes', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id');$sessionId||=$page->session('user_id'); $STMTMGR_COMPONENT_WORKLIST->createHtml($page, $flags, 'worklist.account-notes', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id'); $sessionId||=$page->session('user_id');$STMTMGR_COMPONENT_WORKLIST->createHtml($page, $flags, 'worklist.account-notes', [$personId], 'panelTransp'); },
},

'worklist.group-account-notes' => {

			sqlStmt => qq{
				select simple_name, count (*) as count, min(trans_begin_stamp),max(trans_begin_stamp),
				trans_owner_id
				from transaction t, person
				where 	trans_owner_id = person.person_id and
				trans_status = $ACTIVE and
				trans_type = $ACCOUNT_NOTES and
				EXISTS
				(SELECT 1 FROM Invoice_Worklist iw
				 WHERE
					trans_owner_id = iw.person_id 
					AND	worklist_status = 'Account In Collection'
					AND	worklist_type = 'Collection'				
					AND 	owner_id = :1
					AND	responsible_id = :1
					AND 	org_internal_id = :2
				)
				group by simple_name,trans_owner_id
			},
			sqlStmtBindParamDescr => ['Person ID for transaction table'],

			publishDefn => {
				columnDefn => [
					{ head=> 'Patient Name', url => "/person/#4#/profile" },					
					{ head=> 'Notes#', dAlign => 'right' ,url => '/worklist/collection/stpe-worklist.account-notes/?home=#homeArl#&person_id=#4#' },
					#{ head=> 'Notes#', dAlign => 'right' ,url => '/person/#4#/stpe-person.account-notes?home=#homeArl#&person_id=#4#' },
					{ head=> 'First  Note Date' },
					{ head=> 'Last Note Date' },
				],
				frame => {
					#editUrl => '/worklist/collection/stpe-#my.stmtId#?home=#homeArl#',
				},
			},
			publishDefn_panel =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.static',
				flags => 0,
				frame => { heading => 'Account Notes' },
			},
			publishDefn_panelTransp =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.transparent.static',
				inherit => 'panel',
			},


			publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_WORKLIST->createHtml($page, $flags, 'worklist.group-account-notes', [$personId,$page->session('org_internal_id')] ); },
			publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_WORKLIST->createHtml($page, $flags, 'worklist.group-account-notes', [$personId,$page->session('org_internal_id')], 'panel'); },
			publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_WORKLIST->createHtml($page, $flags, 'worklist.group-account-notes', [$personId,$page->session('org_internal_id')], 'panelEdit'); },
			publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_WORKLIST->createHtml($page, $flags, 'worklist.group-account-notes', [$personId,$page->session('org_internal_id')], 'panelTransp'); },
	},

);

1;
