##############################################################################
package App::Dialog::Field::Insurance::ID::New;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Insurance;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Universal;
use Schema::Utilities;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	#
	# you can pass in a "types => ['x', 'y']" and "notTypes => ['a']"
	# to restrict/expand the selection
	#

	$params{name} = 'ins_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	$params{type} = 'text';
	$params{size} = 16;
	$params{maxLength} = 32;

	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;

	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $validator->id());

	return () if $command ne 'add';

	if($self->SUPER::isValid($page, $validator))
	{
		my $value = $page->field($self->{name});
		my $personId = $page->param('person_id');
		my $recordType = App::Universal::RECORDTYPE_PERSONALCOVERAGE;

		my $newPersonPlanExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selPersonPlanExists',$value, $recordType, $personId);
		my $newPlanExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selNewPlanExists',$value);

		$self->invalidate($page, "Plan ID '$value' already exists.") if $newPlanExists ne '' || $newPersonPlanExists ne '';
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

##############################################################################
package App::Dialog::Field::Insurance::ID;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Insurance;
use CGI::Dialog;
use Schema::Utilities;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog::Field);

use enum qw(:IDENTRYSTYLE_ TEXT SELECT);

sub new
{
	my ($type, %params) = @_;

	#
	# you can pass in a "types => ['x', 'y']" and "notTypes => ['a']"
	# to restrict/expand the selection
	#

	$params{idEntryStyle} = IDENTRYSTYLE_TEXT unless exists $params{idEntryStyle};
	$params{name} = 'ins_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	if($params{idEntryStyle} == IDENTRYSTYLE_SELECT)
	{
		$params{type} = 'foreignKey';
		$params{fKeyTable} = 'INSURANCE outer';
		$params{fKeySelCols} = 'INS_ID, GROUP_NAME, ct.CAPTION';
		$params{fKeyValueCol} = 0;
		$params{fKeyDisplayCol} = 1;
		#$params{fKeyOrderBy} = 'name_last, name_first';

		my $typeCond =
			$params{types} || $params{notTypes} ?
				Schema::Utilities::createInclusionExclusionConds('ct.CAPTION', $params{types}, $params{notTypes}, 1) :
				'';
		$params{fKeyWhere} = "exists (select 1 from INSURANCE inner, CLAIM_TYPE ct where outer.INS_ID = inner.INS_ID and inner.INS_TYPE = ct.ID and $typeCond)" if $typeCond;
	}
	else
	{
		$params{type} = 'text';
		$params{size} = 16;
		$params{maxLength} = 32;
		$params{findPopup} = '/lookup/insurance/id';
	}
	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;

	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $validator->id());
	my $value = $page->field($self->{name});

	return 1 if $command ne 'add' || $value eq '';

	return 0 unless $self->SUPER::isValid($page, $validator);

	my $personId = $page->param('person_id');
	my $recordTypeUnique = App::Universal::RECORDTYPE_PERSONALCOVERAGE;
	my $insTypeWrkCmp = App::Universal::CLAIMTYPE_WORKERSCOMP;

	my $doesPlanExist = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selDoesPlanExists',$value);

	my $planForPersonExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selDoesPlanExistsForPerson',$value, $personId);

	my $isPlanUnique = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selIsPlanUnique',$value, $recordTypeUnique);

	my $isPlanWorkComp = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selIsPlanWorkComp',$value, $insTypeWrkCmp);

	my $createInsPlanHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-ins-newplan/$value');";
	$self->invalidate($page, qq{$self->{caption} '$value' does not exist.<br><img src="/resources/icons/arrow_right_red.gif">
			<a href="$createInsPlanHref">Create Plan '$value' now</a>
		}) if $doesPlanExist eq '';

	$self->invalidate($page, "$self->{caption} '$value' already exists for '$personId'.") if $planForPersonExists ne '';

	$self->invalidate($page, "$self->{caption} '$value' is a unique plan.") if $isPlanUnique ne '';

	$self->invalidate($page, "$self->{caption} '$value' is a workers compensation plan.") if $isPlanWorkComp ne '';

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/06/1999', 'MAF',
		'Dialog/Insurance ID Field',
		"Fixed the link for 'Create Plan now' for when the ins_id does not exist."],
);

##############################################################################
package App::Dialog::Field::Insurance::WorkersComp::ID;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use DBI::StatementManager;
#use App::Statements::Org;
use App::Statements::Insurance;
use CGI::Dialog;
use Schema::Utilities;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog::Field);

use enum qw(:IDENTRYSTYLE_ TEXT SELECT);

sub new
{
	my ($type, %params) = @_;

	#
	# you can pass in a "types => ['x', 'y']" and "notTypes => ['a']"
	# to restrict/expand the selection
	#

	$params{idEntryStyle} = IDENTRYSTYLE_TEXT unless exists $params{idEntryStyle};
	$params{name} = 'ins_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	if($params{idEntryStyle} == IDENTRYSTYLE_SELECT)
	{
		$params{type} = 'foreignKey';
		$params{fKeyTable} = 'INSURANCE outer';
		$params{fKeySelCols} = 'INS_ID, GROUP_NAME, ct.CAPTION';
		$params{fKeyValueCol} = 0;
		$params{fKeyDisplayCol} = 1;
		#$params{fKeyOrderBy} = 'name_last, name_first';

		my $typeCond =
			$params{types} || $params{notTypes} ?
				Schema::Utilities::createInclusionExclusionConds('ct.CAPTION', $params{types}, $params{notTypes}, 1) :
				'';
		$params{fKeyWhere} = "exists (select 1 from INSURANCE inner, CLAIM_TYPE ct where outer.INS_ID = inner.INS_ID and inner.INS_TYPE = ct.ID and $typeCond)" if $typeCond;
	}
	else
	{
		$params{type} = 'text';
		$params{size} = 16;
		$params{maxLength} = 32;
		$params{findPopup} = '/lookup/insurance/id';
	}
	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;

	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $validator->id());
	my $value = $page->field($self->{name});

	return 1 if $command ne 'add' || $value eq '';

	return 0 unless $self->SUPER::isValid($page, $validator);

	my $createWrkCompHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-ins-workerscomp/$value');";
	if(my $orgId = $page->param('org_id'))
	{
		my $items = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selGroupInsurance', $value);
		my $claimType = App::Universal::CLAIMTYPE_WORKERSCOMP;

		if($items->{ins_internal_id} eq '')
		{
			$self->invalidate($page, qq{$self->{caption} '$value' does not exist.<br><img src="/resources/icons/arrow_right_red.gif">
					<a href="$createWrkCompHref">Create Workers Comp Plan '$value' now</a>
				});
		}
		elsif($items->{ins_type} != $claimType)
		{
			$self->invalidate($page, "ID '$value' is not a Workers Compensation Plan.");
		}
		elsif($STMTMGR_INSURANCE->recordExists($page,STMTMGRFLAG_NONE, 'selSpecificWrkCmpAttr', $orgId, $items->{ins_internal_id}, App::Universal::ATTRTYPE_INSGRPWORKCOMP))
		{
			$self->invalidate($page, "$self->{caption} '$value' already exists for '$orgId'.");

		}
	}
	else
	{
		my $personId = $page->param('person_id');
		my $insTypeWrkCmp = App::Universal::CLAIMTYPE_WORKERSCOMP;

		#CHECK TO SEE IF PLAN EVEN EXISTS
		my $doesPlanExist = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selDoesPlanExists',$value);

		$self->invalidate($page, qq{$self->{caption} '$value' does not exist.<br><img src="/resources/icons/arrow_right_red.gif">
				<a href="$createWrkCompHref">Create Workers Comp Plan '$value' now</a>
			}) if $doesPlanExist eq '';


		if($doesPlanExist ne '')
		{
			#CHECK TO SEE IF WORK COMP PLAN ALREADY EXISTS FOR THIS PERSON
			my $workCompExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selPatientHasPlan', $value, $personId, $insTypeWrkCmp);

			$self->invalidate($page, "$self->{caption} '$value' already exists for '$personId'.") if $workCompExists ne '';

			#CHECK TO SEE IF IT IS A VALID WORK COMP PLAN
			my $isPlanWorkComp = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selIsPlanWorkComp',$value, $insTypeWrkCmp);

			$self->invalidate($page, "ID '$value' is not a workers compensation plan.") if $isPlanWorkComp eq '';
		}
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '12/29/1999', 'MAF',
		'Dialog/Lookups',
		'Fixed create link and lookup for workers comp.'],
);

1;
