##############################################################################
package App::Dialog::Field::Organization::ID;
##############################################################################

use strict;
use App::Statements::Org;
use CGI::Validator::Field;
use DBI::StatementManager;
use CGI::Dialog;
use base qw(CGI::Dialog::Field);


sub new
{
	my ($type, %params) = @_;
	
	$params{caption} = 'Organization ID' unless $params{caption};
	$params{name} = 'org_id' unless $params{name};
	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;
	$params{type} = 'identifier' unless exists $params{type};
	$params{size} = 16 unless exists $params{size};
	$params{maxLength} = 16 unless exists $params{maxLength};
	$params{findPopup} = '/lookup/org/id' unless defined $params{findPopup};
	return CGI::Dialog::Field::new($type, %params);
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	my $flags = $self->{flags};
	if ($flags & FLDFLAG_READONLY)
	{
		$self->{postHtml} = '' if $self->{postHtml};
	}
	my $html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags);
	return $html;
}

sub isValid
{
	my ($self, $page, $validator) = @_;
	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $validator->id());
	my $value = $page->field($self->{name});
	
	if ($self->SUPER::isValid($page, $validator))
	{
		if ($command eq 'add')
		{
			$self->isValidOrgIdAdd($page, $value);
		}
		else
		{
			$self->isValidOrgId($page,$value);
		}
	}
	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}


sub isValidOrgId
{
	my ($self, $page, $value) = @_;
	
	return 1 unless $value;
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $value);
	unless ($orgIntId)
	{
		my $pre = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-org-";
		my $post = "/$value');";
		$self->invalidate($page, qq{
			$self->{caption} '$value' does not exist.<br>
			<img src="/resources/icons/arrow_right_red.gif">
			Add '$value' Organization now as a:
			<a href="${pre}main${post}">Main</a>,
			<a href="${pre}dept${post}">Dept</a>,
			<a href="${pre}provider${post}">Provider</a>,
			<a href="${pre}insurance${post}">Insurance</a>,
			<a href="${pre}employer${post}">Employer</a>, or
			<a href="${pre}ipa${post}">IPA</a>
		});
		return 0;
	}
	return 1;
}


sub isValidOrgIdAdd
{
	my ($self, $page, $value) = @_;
	return $self->isValidOrgId($page, $value);
}


##############################################################################
package App::Dialog::Field::Organization::ID::New;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Org;
use CGI::Validator::Field;
use base qw(App::Dialog::Field::Organization::ID);


sub new
{
	my ($type, %params) = @_;

	$params{findPopup} = '' unless $params{findPopup};
	$params{postHtml} = "&nbsp;<a href=\"javascript:doActionPopup('/lookup/org');\">Lookup organizations</a>" unless $params{findPopup};
	return App::Dialog::Field::Organization::ID::new($type, %params);
}


sub isValidOrgIdAdd
{
	my ($self, $page, $value) = @_;
	if ($STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,'selOrgId', $page->session('org_internal_id'), $value))
	{
		$self->invalidate($page, "$self->{caption} '$value' already exists.");
		return 0;
	}
	return 1;
}


##############################################################################
package App::Dialog::Field::Organization::ID::Main;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Org;
use base qw(App::Dialog::Field::Organization::ID);


sub new
{
	my ($type, %params) = @_;

	return App::Dialog::Field::Organization::ID::new($type, %params);
}


sub isValidOrgId
{
	my ($self, $page, $value) = @_;
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOwnerOrgId', $value);

	unless ($orgIntId)
	{
		my $pre = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-org-";
		my $post = "/$value');";
		$self->invalidate($page, qq{
			$self->{caption} '$value' does not exist.<br>
			<img src="/resources/icons/arrow_right_red.gif">
			<a href="${pre}main${post}">Add Main Organization '$value' now?</a>
		});
		return 0;
	}
	return 1;
}


sub isValidOrgIdAdd
{
	my ($self, $page, $value) = @_;
	return $self->isValidOrgId($page, $value);
}


##############################################################################
package App::Dialog::Field::Organization::ID::Main::New;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Org;
use CGI::Validator::Field;
use base qw(App::Dialog::Field::Organization::ID::Main);

sub new
{
	my ($type, %params) = @_;

	$params{findPopup} = '' unless $params{findPopup};
	$params{postHtml} = "&nbsp;<a href=\"javascript:doActionPopup('/lookup/org');\">Lookup organizations</a>" unless $params{findPopup};
	return App::Dialog::Field::Organization::ID::Main::new($type, %params);
}

sub isValidOrgIdAdd
{
	my ($self, $page, $value) = @_;
	if ($STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE, 'selOwnerOrgId', $value))
	{
		$self->invalidate($page, "$self->{caption} '$value' already exists.");
		return 0;
	}
	return 1;
}


##############################################################################
package App::Dialog::Field::OrgType;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Org;
use base qw(CGI::Dialog::Field);


sub new
{
	my ($type, %params) = @_;

	$params{types} = "'CLINIC', 'FACILITY/SITE'" unless $params{types};
	my $sqlStmt = qq{
		select distinct org_internal_id, name_primary
		from Org_Category, Org
		where Org.owner_org_id = ?
			and Org_Category.parent_id = Org.org_internal_id 
			and ltrim(rtrim(upper(Org_Category.member_name))) in ($params{types})
		order by name_primary
	};
	
	return new CGI::Dialog::Field(
		fKeyDisplayCol => 1,
		fKeyValueCol => 0,
		fKeyStmtMgr => $STMTMGR_ORG,
		fKeyStmt => $sqlStmt,
		fKeyStmtFlags => STMTMGRFLAG_DYNAMICSQL,
		fKeyStmtBindSession => ['org_internal_id'],
		%params
	);
}


1;
