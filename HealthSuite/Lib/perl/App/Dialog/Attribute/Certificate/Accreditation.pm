##############################################################################
package App::Dialog::Attribute::Certificate::Accreditation;
##############################################################################

use DBI::StatementManager;
use App::Statements::Invoice;

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Attribute::Certificate;
use App::Dialog::Field::Attribute;
use App::Universal;
use Date::Manip;
use App::Statements::Person;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Attribute::Certificate);

%RESOURCE_MAP = (
	'certificate-accreditation' => {
		valueType => App::Universal::ATTRTYPE_ACCREDITATION,
		heading => '$Command Accreditation',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_ACCREDITATION()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Accreditation');

	$self->addContent(
				#new CGI::Dialog::Field(caption => 'Accreditation', name => 'value_text', options => FLDFLAG_REQUIRED),
			new App::Dialog::Field::Attribute::Name(
						caption => 'Accreditation',
						name => 'value_text',
						options => FLDFLAG_REQUIRED,
						attrNameFmt => "#field.value_text#",
						fKeyStmtMgr => $STMTMGR_PERSON,
						valueType => $self->{valueType},
						selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),

			new CGI::Dialog::Field(type => 'date', caption => 'Effective Date', name => 'value_date', futureOnly => 0, defaultValue => ''),
			new CGI::Dialog::Field(type => 'date', caption => 'Expiration Date', name => 'value_dateend', options => FLDFLAG_REQUIRED, futureOnly => 0, defaultValue => ''),
	);

	$self->SUPER::initialize();
}

1;
