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

	$params{name} = 'catalog_id' unless exists $params{name};
	$params{type} = 'text' unless exists $params{type};
	$params{size} = 16 unless exists $params{size};
	$params{maxLength} = 32 unless exists $params{maxLength};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	return CGI::Dialog::Field::new($type, %params);
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
		$params{type} = 'text' unless exists $params{type};
		$params{size} = 16 unless exists $params{size};
		$params{maxLength} = 32 unless exists $params{maxLength};
		$params{findPopup} = '/lookup/catalog' unless exists $params{findPopup};
	}
	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;

	return 0 unless $self->SUPER::isValid($page, $validator);
	
	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $validator->id());
	my $value = $page->field($self->{name});

	$self->invalidate($page, qq{$self->{caption} '$value' does not exist.}) 
		unless $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE, 'selCatalogById', $value);

	return $page->haveValidationErrors() ? 0 : 1;
}

1;