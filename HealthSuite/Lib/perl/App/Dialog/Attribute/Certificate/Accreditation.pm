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
use Devel::ChangeLog;
use App::Statements::Person;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Dialog::Attribute::Certificate);

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

			new CGI::Dialog::Field(type => 'date', caption => 'Expiration Date', name => 'value_dateend', options => FLDFLAG_REQUIRED, futureOnly => 1, defaultValue => ''),
	);

	$self->SUPER::initialize();
}


use constant PANEDIALOG_CERTIFICATE => 'Dialog/Certificate/Accreditation';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/30/2000', 'MAF',
		PANEDIALOG_CERTIFICATE,
		'Created new dialog for Accreditation.'],
);

1;