##############################################################################
package App::Dialog::Field::Catalog::ID::New;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
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

	$params{name} = 'catalog_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	$params{type} = 'text';
	$params{size} = 16 unless $params{size};
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
		$self->invalidate($page, "$self->{caption} '$value' already exists.")
			if $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selCatalogById', $value);
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}




##############################################################################
package App::Dialog::Field::Catalog::ID;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use Carp;
use CGI::Validator::Field;
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
	$params{name} = 'catalog_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	if($params{idEntryStyle} == IDENTRYSTYLE_SELECT)
	{
		$params{type} = 'foreignKey';
		$params{fKeyTable} = 'OFFERING_CATALOG outer';
		$params{fKeySelCols} = 'CATALOG_ID';
		$params{fKeyValueCol} = 0;
		$params{fKeyDisplayCol} = 0;
		#$params{fKeyOrderBy} = 'name_last, name_first';

		my $typeCond =
			$params{types} || $params{notTypes} ?
				Schema::Utilities::createInclusionExclusionConds('ct.CAPTION', $params{types}, $params{notTypes}, 1) :
				'';
		#$params{fKeyWhere} = "exists (select 1 from OFFERING_CATALOG inner where outer.INS_ID = inner.INS_ID and inner.INS_TYPE = ct.ID and $typeCond)" if $typeCond;
	}
	else
	{
		$params{type} = 'text';
		$params{size} = 16;
		$params{maxLength} = 32;
		$params{findPopup} = '/lookup/catalog';
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

	my $createCatalogHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-catalog/$value');";
	#my $createCatalogHref = "javascript:doActionPopup('/create-p/catalog/$value');";

	$self->invalidate($page, qq{$self->{caption} '$value' does not exist.<br><img src="/resources/icons/arrow_right_red.gif">
			<a href="$createCatalogHref">Create Catalog '$value' now</a>
		}) unless $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE, 'selCatalogById', $value);

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/20/2000', 'MAF',
		'Dialog/Field/Catalog',
		'Created new field type for catalog id.'],
);

1;