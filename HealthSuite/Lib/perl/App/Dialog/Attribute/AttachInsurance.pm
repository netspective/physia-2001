##############################################################################
package App::Dialog::Attribute::AttachInsurance;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Insurance;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);
%RESOURCE_MAP = (
	'org-attachinsurance' => {
		_arl_add => ['ins_id'],
		_arl_modify => ['item_id'],
		id => 'attachinsplan',
		heading => '$Command Insurance Plan',
		valueType => App::Universal::ATTRTYPE_INSGRPINSPLAN,
		_idSynonym => 'attr-' . App::Universal::ATTRTYPE_INSGRPINSPLAN
		},
	);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_);

	my $id = $self->{id};

	if($id eq 'attachinsplan')
	{
		$self->addContent(
			new App::Dialog::Field::Insurance::ID(
				name => 'ins_id',
				caption => 'Insurance Plan ID',
				options => FLDFLAG_REQUIRED,
				readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE,
				),
		);

	}
	
	elsif($id eq 'attachworkerscomp')
	{
		$self->addContent(
			new App::Dialog::Field::Insurance::WorkersComp::ID(
				caption => 'Workers Compensation Plan ID',
				name => 'ins_id',
				options => FLDFLAG_REQUIRED,
				readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE,
				),
		);
	}
	$self->{activityLog} =
	{
			scope =>'org',
			key => "#param.org_id#",
			data => "$id '#field.ins_id#' to <a href='/org/#param.org_id#/profile'>#param.org_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	$page->field('ins_id', $page->param('ins_id')) if $command ne 'add';
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');

	my $insId = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
	$page->field('ins_id', $insId->{value_text});
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $insId = $page->field('ins_id');

	#Get plan info

	my $planInfo = $STMTMGR_INSURANCE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selPlanByInsIdAndRecordType', $insId,
							App::Universal::RECORDTYPE_INSURANCEPLAN);

	my $itemName = $planInfo->{ins_org_id};
	my $primaryName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $itemName);

	$page->schemaAction(
		'Org_Attribute', $command,
		item_id => $page->param('item_id') || undef,
		parent_id => $page->param('org_id') || undef,
		item_name => $itemName || undef,
		value_type => $self->{valueType} || undef,
		value_text => $insId || undef,
		value_textB => $planInfo->{group_name} || $planInfo->{plan_name} || $primaryName || undef,
		value_int => $planInfo->{ins_internal_id} || undef,
		_debug => 0
	);

	return "\u$command completed.";
}

1;
