###############################################################################
package App::Dialog::Attribute::Certificate::Affiliation;
###############################################################################

use DBI::StatementManager;
use App::Statements::Invoice;

use strict;
use Carp;
use CGI::Dialog;
use App::Dialog::Attribute::Certificate;
use App::Dialog::Field::Attribute;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use App::Statements::Person;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Attribute::Certificate);

%RESOURCE_MAP = (
	'affiliation' => {
		valueType => App::Universal::ATTRTYPE_AFFILIATION,
		heading => '$Command Affiliation',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_AFFILIATION()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Affiliation');

	$self->addContent(
			#new CGI::Dialog::Field(caption => 'Affiliation', name => 'value_text'),
			new App::Dialog::Field::Attribute::Name(
						caption => 'Affiliation',
						name => 'value_text',
						options => FLDFLAG_REQUIRED,
						readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						attrNameFmt => "#field.value_text#",
						fKeyStmtMgr => $STMTMGR_PERSON,
						valueType => $self->{valueType},
						selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),

			new CGI::Dialog::Field(type => 'date', caption => 'Date', name => 'value_dateend', futureOnly => 0, defaultValue => '', options => FLDFLAG_REQUIRED),
	);

	$self->SUPER::initialize();
}

1;
