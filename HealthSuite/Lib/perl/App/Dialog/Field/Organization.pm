##############################################################################
package App::Dialog::Field::Organization::ID::New;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Org;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use Schema::Utilities;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	#
	# you can pass in a "types => ['x', 'y']" and "notTypes => ['a']"
	# to restrict/expand the selection
	#

	$params{name} = 'org_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	$params{type} = 'identifier';
	$params{size} = 16;
	$params{maxLength} = 16;

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

		$self->invalidate($page, "$self->{caption} '$value' already exists.")
			if $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $value);
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

##############################################################################
package App::Dialog::Field::Organization::ID;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Org;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use Schema::Utilities;

use vars qw(@ISA);

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
	$params{name} = 'org_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_UPPERCASE;

	if($params{idEntryStyle} == IDENTRYSTYLE_SELECT)
	{
		$params{type} = 'foreignKey';
		$params{fKeyTable} = 'ORG outer';
		$params{fKeySelCols} = 'ORG_ID, NAME_PRIMARY';
		$params{fKeyValueCol} = 0;
		$params{fKeyDisplayCol} = 1;
		$params{fKeyOrderBy} = 'NAME_PRIMARY';

		my $typeCond =
			$params{types} || $params{notTypes} ?
				Schema::Utilities::createInclusionExclusionConds('oc.MEMBER_NAME', $params{types}, $params{notTypes}, 1) :
				'';
		$params{fKeyWhere} = "exists (select 1 from ORG inner, ORG_CATEGORY oc where outer.ORG_ID = inner.ORG_ID and inner.ORG_ID = oc.PARENT_ID and $typeCond)" if $typeCond;
	}
	else
	{
		$params{type} = 'identifier';
		$params{size} = 16;
		$params{maxLength} = 16;

		if(! $params{findPopup})
		{
			my $findModule = 'org';
			if(my $types = $params{types})
			{
				# note -- the following $modNames "override" each other
				#      -- i.e. if a person is a patient and physician, Physician overrides Patient
				#         because it comes later in the lsit
				foreach my $modName ('Clinic', 'Facility')
				{
					$findModule = "org/\l$modName" if grep { $_ eq $modName } @$types;
				}
			}
			#$params{findPopup} = "/lookup/$findModule/id";
			$params{findPopup} = "/lookup/org/id";
		}
		$params{findPopup} = '/lookup/org/id' unless $params{findPopup};
	}
	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;

	if($self->SUPER::isValid($page, $validator))
	{
		if(my $value = $page->field($self->{name}))
		{
			my $createOrgHrefPre = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-org-";
			my $createOrgHrefPost = "/$value');";
			$self->invalidate($page, qq{
				$self->{caption} '$value' does not exist.<br>
				<img src="/resources/icons/arrow_right_red.gif">
				Add '$value' Organization now as a:
				<a href="${createOrgHrefPre}main${createOrgHrefPost}">Main</a>,
				<a href="${createOrgHrefPre}dept${createOrgHrefPost}">Dept</a>,
				<a href="${createOrgHrefPre}provider${createOrgHrefPost}">Provider</a>,
				<a href="${createOrgHrefPre}insurance${createOrgHrefPost}">Insurance</a>,
				<a href="${createOrgHrefPre}employer${createOrgHrefPost}">Employer</a>, or
				<a href="${createOrgHrefPre}ipa${createOrgHrefPost}">IPA</a>
			})
			unless $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $value);

			my $personId = ($page->param('user_id') ne '') ? $page->param('user_id') : $page->session('user_id');
			$self->invalidate($page, "You do not have permission to modify an organization outside of your parent organization.")
				unless $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,'selPersonCategory', $personId, $personId, $value);
		}
	}
	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

##############################################################################
package App::Dialog::Field::OrgType;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;

use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	return CGI::Dialog::Field::new(
				$type,
				type => 'foreignKey',
				fKeyTable => 'org o, org_category oset',
				fKeySelCols => "distinct o.org_id, o.name_primary",
				fKeyDisplayCol => 1,
				fKeyValueCol => 0,
				fKeyWhere => "o.org_id=oset.parent_id and ltrim(rtrim(UPPER(oset.MEMBER_NAME))) in ('FACILITY','FACILITY/SITE','CLINIC')",
				options => FLDFLAG_REQUIRED,
				%params);
}

1;
