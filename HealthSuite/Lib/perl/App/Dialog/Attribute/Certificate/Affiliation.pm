##############################################################################
package App::Dialog::Attribute::Certificate::Affiliation;
##############################################################################

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
use Devel::ChangeLog;
use App::Statements::Person;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Dialog::Attribute::Certificate);

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


use constant PANEDIALOG_CERTIFICATE => 'Dialog/Certificate/Affiliation';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/30/2000', 'MAF',
		PANEDIALOG_CERTIFICATE,
		'Created new dialog for Affiliation.'],
);

1;