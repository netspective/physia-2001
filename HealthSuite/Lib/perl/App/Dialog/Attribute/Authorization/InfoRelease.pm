##############################################################################
package App::Dialog::Attribute::Authorization::InfoRelease;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Dialog::Attribute::Authorization;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Dialog::Attribute::Authorization);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Information Release Indicator');

	$self->addContent(
				new App::Dialog::Field::Attribute::Name(
						caption => 'Patient has authorized release of medical information',
						name => 'value_int',
						type => 'bool',
						style => 'check',
						defaultValue => 1,
						attrNameFmt => 'Information Release',
						fKeyStmtMgr => $STMTMGR_PERSON,
						valueType => $self->{valueType},
						selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),
			);

	$self->SUPER::initialize();
}

use constant PANEDIALOG_AUTHORIZATION => 'Dialog/Authorization/Info Release';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/03/2000', 'MAF',
		PANEDIALOG_AUTHORIZATION,
		'Created new dialog for Info Release.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/14/2000', 'RK',
		PANEDIALOG_AUTHORIZATION,
		'Removed Item Path from Item Name'],
);

1;