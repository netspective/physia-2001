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
#use Schema::Utilities;

use vars qw(@ISA);
@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	$params{name} = 'catalog_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;
	$params{type} = 'text' unless exists $params{type};
	$params{size} = 16 unless exists $params{size};
	$params{maxLength} = 32 unless exists $params{maxLength};
	$params{findPopup} = '/lookup/catalog' unless exists $params{findPopup};

	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;

	return 0 unless $self->SUPER::isValid($page, $validator);
	
	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $validator->id());
	my $value = $page->field($self->{name});

	return if $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'sel_internalCatId_orgId', $value, $page->session('org_internal_id'));
	
	$self->invalidate($page, qq{$self->{caption} '$value' does not exist for this Org.}) ;

	return $page->haveValidationErrors() ? 0 : 1;
}

1;
