##############################################################################
package App::Dialog::Directory::Org::General::ServiceDrillDownLookup;
##############################################################################

use strict;
use Carp;
use App::Dialog::Directory;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Component::Org;
use App::Statements::Search::OrgDirectory;
use vars qw(@ISA $INSTANCE);
use Data::Publish;

@ISA = qw(App::Dialog::Directory);

sub new
{
	my $self = App::Dialog::Directory::new(@_, heading => 'Service Drill Down');

	$self->addContent(
			new CGI::Dialog::Field(caption =>'Service',
						name => 'service',
						options => FLDFLAG_PREPENDBLANK|FLDFLAG_REQUIRED,
						fKeyStmtMgr => $STMTMGR_TRANSACTION,
						fKeyStmt => 'selReferralType',
						fKeyDisplayCol => 1,
						fKeyValueCol => 0),
			new CGI::Dialog::Field(caption =>'State',
						name => 'state',
						size => 2,
						maxLength => 2),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub prepare_detail_service
{
	my ($self, $page) = @_;
	my $city = $page->param('city');
	my $code = $page->field('service');
	my $sessionId = $page->session('org_internal_id');
	my $html =undef;
	my $actionURL = q{javascript:doActionPopup('/org/#9#/profile')};
	#my $lookupFeeSched = q{javascript:doActionPopup('/org/#0#/catalog/#6#/#7#')};


	#$orgIntId = $page->param('org_internal_id');#$STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;
	my @data = ();
	my $pub = {
		columnDefn =>
		[
			{colIdx => 0, head => 'Code', url => q{javascript:if(isLookupWindow()) populateControl('#0#', true, '#1#'); else window.location.href ='/org/#0#/profile';},},
			{colIdx => 1,head => 'Primary Name'},
			{colIdx => 2,head => 'State'},
			{colIdx => 3,head => 'City'},
			{colIdx => 4,head => 'Street'},
			{colIdx => 5,head => 'Phone'},
			{colIdx => 7,head => 'Fee Schedule', url => q{javascript:doActionPopup('/org/#0#/catalog/#6#/#7#')},},
			{colIdx => 8,head => 'Type'},
			{colIdx => 9,head => 'Parent Provider',  dataFmt => "<a href=\"$actionURL\" style=\"text-decoration:none\"><img src=\"/resources/images/icons/hand-pointing-to-folder-sm.gif\" border=0></a>" },


		],
	};

	my $providerName = $STMTMGR_ORG_SERVICE_DIR_SEARCH->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'sel_sub_service_search',	$sessionId, uc($code), $city);
	foreach(@$providerName)
	{
		my @rowData =
		(
			$_->{org_id},
			$_->{name_primary},
			$_->{state},
			$_->{city},
			$_->{line1},
			$_->{value_text},
			$_->{internal_catalog_id},
			$_->{catalog_id},
			$_->{type},
			$_->{parent_org},

		);
		push(@data, \@rowData);
	}

	$html = 'Click <a href="javascript:history.back()">here</a> to go back<br><br>' . $html;

	$html .= createHtmlFromData($page, 0, \@data,$pub);
	$page->addContent($html);
}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $service = $page->field('service') eq '' ? '*' : $page->field('service');
	my $state = $page->field('state') eq '' ? '*' : $page->field('state');


	my $serviceLike = $service =~ s/\*/%/g ? 'service' : '';
	my $stateLike  = $state =~ s/\*/%/g ? 'state' : '';
	$service = uc($service);
	my $sessionId = $page->session('org_internal_id');
	my $like = $serviceLike || $stateLike? '_like' : 'servicestate';

	#my $like = $serviceLike ? '_like' : 'donlyservice';
	#my $appendStmtName = "sel_$serviceLike$like";
	my $appendStmtName = "sel_donly$serviceLike$stateLike$like";

	return 'Click <a href="javascript:history.back()">here</a> to go back<br><br>' . $STMTMGR_ORG_SERVICE_DIR_SEARCH->createHtml($page, STMTMGRFLAG_NONE, "$appendStmtName",[uc($service), uc($state), $sessionId]);
}

#						[uc($service),
#					$sessionId]);


$INSTANCE = new __PACKAGE__;