##############################################################################
package App::Dialog::Attribute::Certificate::License;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Dialog::Attribute::Certificate;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Dialog::Attribute::Certificate);

sub initialize
{
	my $self = shift;

	$self->heading('$Command License');

	$self->addContent(
		new App::Dialog::Field::Attribute::Name(
			type => 'select',
			selOptions => 'DEA;DPS;Medicaid;Medicare;UPIN;Tax ID;IRS;Board Certification',
			caption => 'License',
			name => 'value_textb',
			options => FLDFLAG_REQUIRED,
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			attrNameFmt => "#field.value_textb#",
			fKeyStmtMgr => $STMTMGR_PERSON,
			valueType => $self->{valueType},
			selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),

		new CGI::Dialog::Field(caption => 'Number', name => 'value_text', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'date', caption => 'Expiration Date', name => 'value_dateend', options => FLDFLAG_REQUIRED),

	);

	$self->SUPER::initialize();
}


use constant PANEDIALOG_CERTIFICATE => 'Dialog/Certificate/License';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/30/2000', 'MAF',
		PANEDIALOG_CERTIFICATE,
		'Created new dialog for License.'],
);

1;