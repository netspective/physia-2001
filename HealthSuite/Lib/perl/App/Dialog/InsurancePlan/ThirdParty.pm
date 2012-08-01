##############################################################################
package App::Dialog::InsurancePlan::ThirdParty;
##############################################################################
use strict;
use Carp;
use DBI::StatementManager;
use CGI::Validator::Field;
use App::Dialog::InsurancePlan;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Insurance;
use App::Dialog::Field::Insurance;
use CGI::Dialog;
use App::Universal;
use vars qw(@ISA %RESOURCE_MAP);

%RESOURCE_MAP = (
	'ins-thirdparty' => {
			heading => '$Command Third Party Payer',
			_arl_add => ['person_id'],
			_arl_modify => ['ins_internal_id'],
			},
		  );

use Date::Manip;

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'thirdparty', , heading => '$Command Third Party Payer');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
			new CGI::Dialog::MultiField(caption => 'Payer for Today ID/Type', name => 'other_payer_fields',
				fields => [
				new CGI::Dialog::Field(
					caption => 'Payer for Today ID',
					name => 'guarantor_id',
					findPopup => '/lookup/itemValue',
					findPopupControlField => '_f_guarantor_type',
					options => FLDFLAG_REQUIRED
					),
				new CGI::Dialog::Field(
					type => 'select',
					selOptions => 'Person:person;Organization:org',
					caption => 'Payer for Today Type',
					name => 'guarantor_type'),
				]),

				new CGI::Dialog::Field(
					caption => 'Begin Date',
					name => 'coverage_begin_date',
					type => 'date',
					options => FLDFLAG_REQUIRED,
					pastOnly => 1,
					defaultValue => '',
					),
				new CGI::Dialog::Field(
					caption => 'End Date',
					name => 'coverage_end_date',
					invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
					type => 'date',
					defaultValue => '',
					),
				new CGI::Dialog::Field(
					type => 'bool',
					style => 'check',
					caption => 'Inactive Payer',
					name => 'inactive_payer',
					invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
				),

			);

	$self->{activityLog} =
	{
		scope =>'insurance',
		key => "#field.other_payer_id#",
		data => "Third Party '#field.guarantor_id#' for <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub customValidate
{
	my ($self, $page) = @_;

	my $otherPayer = $page->field('guarantor_id');
	$otherPayer = uc($otherPayer);
	$page->field('guarantor_id', $otherPayer);
	my $otherPayerType = $page->field('guarantor_type');
	my $otherPayerField = $self->getField('other_payer_fields')->{fields}->[0];
	my $ownerOrgId = $page->session('org_internal_id');

	if($otherPayerType eq 'person')
	{
		my $createHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-guarantor/$otherPayer');";
		$otherPayerField->invalidate($page, qq{
			Person Id '$otherPayer' does not exist.<br>
			<img src="/resources/icons/arrow_right_red.gif">
			<a href="$createHref">Add Third Party Person Id '$otherPayer' now</a>
			})
			unless $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $otherPayer);
	}
	elsif($otherPayerType eq 'org')
	{
		my $createOrgHrefPre = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-org-";
		my $createOrgHrefPost = "/$otherPayer');";

		$otherPayerField->invalidate($page, qq{
			Org Id '$otherPayer' does not exist.<br>
			<img src="/resources/icons/arrow_right_red.gif">
			Add Third Party Organization Id '$otherPayer' now as an
			<a href="${createOrgHrefPre}insurance${createOrgHrefPost}">Insurance</a> or
			<a href="${createOrgHrefPre}employer${createOrgHrefPost}">Employer</a>
			})
			unless $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,'selOrgId', $ownerOrgId, $otherPayer);
	}

}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless ($flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL);
	my $insIntId = $page->param('ins_internal_id');
	my $thirdParty = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId);
	my $thirdPartyType = $thirdParty->{guarantor_type};
	my $guarantorType = $thirdPartyType eq 1 ? 'org' : 'person';
	$page->field('guarantor_type', $guarantorType);
	$thirdParty->{bill_sequence} eq App::Universal::INSURANCE_INACTIVE ? $page->field('inactive_payer', 1) : $page->field('inactive_payer', '');
	$page->field('coverage_begin_date', $thirdParty->{coverage_begin_date});
	$page->field('coverage_end_date', $thirdParty->{coverage_end_date});
	my $insOrgId = '';

	if ($guarantorType eq 'org')
	{
		$insOrgId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $thirdParty->{guarantor_id});
	}

	$guarantorType eq 'person' ? $page->field('guarantor_id', $thirdParty->{guarantor_id}) : $page->field('guarantor_id', $insOrgId);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;


	my $editInsIntId = $page->param('ins_internal_id');
	my $otherPayerType = $page->field('guarantor_type');
	my $insOrgInternalId = '';
	my $ownerOrgId = $page->session('org_internal_id');
	my $guarantorType = $otherPayerType eq 'person' ? App::Universal::ENTITYTYPE_PERSON : App::Universal::ENTITYTYPE_ORG;
	my $guarantor = $otherPayerType eq 'person' ? $page->field('guarantor_id') : $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrgId, $page->field('guarantor_id'));
	my $sequence = $page->field('inactive_payer');
	my $billSequence = $page->field('inactive_payer') ne '' ? App::Universal::INSURANCE_INACTIVE : undef;
	$page->addDebugStmt("TEST: $billSequence, $sequence, $command");
	$page->schemaAction(
			'Insurance', $command,
			ins_internal_id => $editInsIntId || undef,
			record_type => App::Universal::RECORDTYPE_PERSONALCOVERAGE || undef,
			owner_person_id => $page->param('person_id') || undef,
			owner_org_id => $page->session('org_internal_id'),
			ins_type => App::Universal::CLAIMTYPE_CLIENT || undef,
			guarantor_id => $guarantor || undef,
			guarantor_type  => $guarantorType,
			bill_sequence   => $billSequence,
			coverage_begin_date		=> $page->field('coverage_begin_date') || undef,
			coverage_end_date		=> $page->field('coverage_end_date') || undef,
			_debug => 0
		);

	$self->handlePostExecute($page, $command, $flags);
	return '';
}

1;
