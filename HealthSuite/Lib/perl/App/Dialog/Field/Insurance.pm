##############################################################################
package App::Dialog::Field::Insurance::Product::New;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
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
	#$params{options} |= FLDFLAG_IDENTIFIER;

	$params{type} = 'text';
	$params{size} = 16 unless exists $params{size};
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
		my $recordType = App::Universal::RECORDTYPE_PERSONALCOVERAGE;
		#my $insOrg = $page->field('ins_org_id');
		my $ownerOrgId = $page->session('org_internal_id');
		#my $orgId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrgId, $insOrg);
		#my $planName = $page->field('plan_name');
		#my $personPlanExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selPersonPlanExists',$value, $planName, $recordType, $ownerId, $orgId);
		my $newProductExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selNewProductExists',$value, $ownerOrgId);


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
use CGI::Dialog;
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
	#$params{options} |= FLDFLAG_IDENTIFIER;

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
		$params{type} = 'text' unless exists $params{type};
		$params{size} = 16 unless exists $params{size};
		$params{maxLength} = 32 unless exists $params{maxLength};
		$params{findPopup} = '/lookup/insproduct' unless exists $params{findPopup};
		$params{addPopup} = "/org/#session.org_id#/dlg-add-ins-product" unless exists $params{addPopup};
		$params{addPopupControlField} = '_f_product_name' unless exists $params{addPopupControlField};
	}
	return CGI::Dialog::Field::new($type, %params);
}

##############################################################################
package App::Dialog::Field::Insurance::Plan::New;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
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
	#$params{options} |= FLDFLAG_IDENTIFIER;

	$params{type} = 'text';
	$params{size} = 16 unless exists $params{size};
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

		#my $orgId = $page->field('ins_org_id');
		my $ownerOrgId = $page->session('org_internal_id');
		#my $insOrgInternalId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrgId, $orgId);

		my $productName = $page->field('product_name');
		my $planName = $page->field('plan_name');
		my $orgPlanExists = $STMTMGR_INSURANCE->getSingleValue($page,STMTMGRFLAG_NONE,'selNewPlanExists', $planName, $ownerOrgId);

		$self->invalidate($page, "Plan Name '$value' already exists.") if $orgPlanExists ne '';	}

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
	#$params{options} |= FLDFLAG_IDENTIFIER;

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
		$params{type} = 'text' unless exists $params{type};
		$params{size} = 16 unless exists $params{size};
		$params{maxLength} = 32 unless exists $params{maxLength};
		$params{findPopup} = '/lookup/insplan' unless exists $params{findPopup};
		$params{addPopup} = "/org/#session.org_id#/dlg-add-ins-plan" unless exists $params{addPopup};
		$params{addPopupControlField} = '_f_plan_name' unless exists $params{addPopupControlField};
	}
	return CGI::Dialog::Field::new($type, %params);
}


1;
