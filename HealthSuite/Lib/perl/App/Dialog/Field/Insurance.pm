##############################################################################
package App::Dialog::Field::Insurance::Product::New;
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

	$params{name} = 'product_name' unless $params{name};

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
		my $ownerId = $page->param('person_id');
		#my $recordType = App::Universal::RECORDTYPE_PERSONALCOVERAGE;
		my $orgId = $page->field('ins_org_id');
		my $planName = $page->field('plan_name');
		#my $personPlanExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selPersonPlanExists',$value, $planName, $recordType, $ownerId);
		my $newProductExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selNewProductExists',$value, $orgId);


		$self->invalidate($page, "Product Name '$value' already exists.") if $newProductExists ne '';
		#$self->invalidate($page, "This Personal Coverage already exists for '$ownerId'.") if  $personPlanExists ne '';
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

##############################################################################
package App::Dialog::Field::Insurance::Product;
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
	$params{name} = 'product_name' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	if($params{idEntryStyle} == IDENTRYSTYLE_SELECT)
	{
		$params{type} = 'foreignKey';
		$params{fKeyTable} = 'INSURANCE outer';
		$params{fKeySelCols} = 'PRODUCT_NAME, GROUP_NAME, ct.CAPTION';
		$params{fKeyValueCol} = 0;
		$params{fKeyDisplayCol} = 1;
		#$params{fKeyOrderBy} = 'name_last, name_first';

		my $typeCond =
			$params{types} || $params{notTypes} ?
				Schema::Utilities::createInclusionExclusionConds('ct.CAPTION', $params{types}, $params{notTypes}, 1) :
				'';
		$params{fKeyWhere} = "exists (select 1 from INSURANCE inner, CLAIM_TYPE ct where outer.PRODUCT_NAME = inner.PRODUCT_NAME and inner.INS_TYPE = ct.ID and $typeCond)" if $typeCond;
	}
	else
	{
		$params{type} = 'text';
		$params{size} = 16;
		$params{maxLength} = 32;
		$params{findPopup} = '/lookup/insurance/product_name';
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
	my $orgId = $page->field('ins_org_id');
	my $planName = $page->field('plan_name');
	my $productName = $page->field('product_name');
	my $preFilledOrg = $page->field('ins_comp');
	my $preFilledProduct = $page->field('product');
	my $doesProductExist = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selDoesProductExists',$productName, $orgId);
	my $doesPreFilledProductExist = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selDoesProductExists',$preFilledProduct, $preFilledOrg);
	#my $planForOrgExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selNewPlanExists',$productName, $planName, $orgId);

	my $isPlanUnique = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selIsPlanUnique',$productName, $recordTypeUnique);

	my $isPlanWorkComp = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selIsPlanWorkComp',$value, $insTypeWrkCmp);

	my $createInsProductHref = "javascript:doActionPopup('/org-p/$orgId/dlg-add-ins-product?_f_ins_org_id=$orgId&_f_product_name=$value');";
	$self->invalidate($page, qq{$self->{caption} '$productName' does not exist.<br><img src="/resources/icons/arrow_right_red.gif">
			<a href="$createInsProductHref">Create Product '$productName' now</a>
		}) if $doesProductExist eq '' && $productName ne '';

	my $createInsProductPreHref = "javascript:doActionPopup('/org-p/$preFilledOrg/dlg-add-ins-product?_f_ins_org_id=$preFilledOrg&_f_product_name=$preFilledProduct');";
	$self->invalidate($page, qq{$self->{caption} '$preFilledProduct' does not exist.<br><img src="/resources/icons/arrow_right_red.gif">
			<a href="$createInsProductPreHref">Create Product '$preFilledProduct' now</a>
		}) if $doesPreFilledProductExist eq '' &&  $preFilledProduct ne '';


	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}


##############################################################################
package App::Dialog::Field::Insurance::Plan::New;
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

	$params{name} = 'plan_name' unless $params{name};

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

		my $orgId = $page->field('ins_org_id');
		my $productName = $page->field('product_name');
		my $planName = $page->field('plan_name');
		my $orgPlanExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selNewPlanExists',$productName, $planName, $orgId);


		$self->invalidate($page, "Plan Name '$value' already exists.") if $orgPlanExists ne '';
		#$self->invalidate($page, "This Personal Coverage already exists for '$ownerId'.") if  $personPlanExists ne '';
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

##############################################################################
package App::Dialog::Field::Insurance::Plan;
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
	$params{name} = 'plan_name' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	if($params{idEntryStyle} == IDENTRYSTYLE_SELECT)
	{
		$params{type} = 'foreignKey';
		$params{fKeyTable} = 'INSURANCE outer';
		$params{fKeySelCols} = 'PRODUCT_NAME, GROUP_NAME, ct.CAPTION';
		$params{fKeyValueCol} = 0;
		$params{fKeyDisplayCol} = 1;
		#$params{fKeyOrderBy} = 'name_last, name_first';

		my $typeCond =
			$params{types} || $params{notTypes} ?
				Schema::Utilities::createInclusionExclusionConds('ct.CAPTION', $params{types}, $params{notTypes}, 1) :
				'';
		$params{fKeyWhere} = "exists (select 1 from INSURANCE inner, CLAIM_TYPE ct where outer.PRODUCT_NAME = inner.PRODUCT_NAME and inner.INS_TYPE = ct.ID and $typeCond)" if $typeCond;
	}
	else
	{
		$params{type} = 'text';
		$params{size} = 16;
		$params{maxLength} = 32;
		$params{findPopup} = '/lookup/insurance/plan_name';
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

	my $insTypeWrkCmp = App::Universal::CLAIMTYPE_WORKERSCOMP;
	my $orgId = $page->field('ins_org_id');
	my $planName = $page->field('plan_name');
	my $productName = $page->field('product_name');
	my $preFilledOrg = $page->field('ins_comp');
	my $preFilledProduct = $page->field('product');
	my $preFilledPlan =  $page->field('plan');
	my $planForOrgExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selNewPlanExists',$productName, $planName, $orgId);
	my $preFilledplanExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selNewPlanExists',$preFilledProduct, $preFilledPlan, $preFilledOrg);

	my $createInsPlanPreHref = "javascript:doActionPopup('/org-p/$orgId/dlg-add-ins-plan?_f_ins_org_id=$orgId&_f_product_name=$productName&_f_plan_name=$planName');";
	$self->invalidate($page, qq{ Plan Name '$planName' does not exist.<br><img src="/resources/icons/arrow_right_red.gif">
			<a href="$createInsPlanPreHref">Create Plan '$planName' now</a>
		}) if $planForOrgExists eq '' && $planName ne '';

	my $createPreInsPlanPreHref = "javascript:doActionPopup('/org-p/$preFilledOrg/dlg-add-ins-plan?_f_ins_org_id=$preFilledOrg&_f_product_name=$preFilledProduct&_f_plan_name=$preFilledPlan');";
	$self->invalidate($page, qq{ Plan Name '$preFilledPlan' does not exist.<br><img src="/resources/icons/arrow_right_red.gif">
			<a href="$createPreInsPlanPreHref">Create Plan '$preFilledPlan' now</a>
		}) if $preFilledplanExists eq '' && $preFilledPlan ne '';
	return $page->haveValidationErrors() ? 0 : 1;
}


1;
