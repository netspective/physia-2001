###############################################################################
package App::Dialog::Attribute::Certificate::Specialty;
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
use Devel::ChangeLog;
use App::Statements::Person;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Dialog::Attribute::Certificate);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Specialty');

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Specialty',
					#type => 'foreignKey',
					name => 'value_text',
					fKeyStmtMgr => $STMTMGR_PERSON,
					fKeyStmt => 'selMedicalSpeciality',
					fKeyDisplayCol => 0,
					fKeyValueCol => 1),
		new CGI::Dialog::Field(caption => 'Specialty Sequence', name => 'value_int', type => 'select', selOptions => ' : 1;Primary:2;Secondary:3;Tertiary:4;Quaternary:5', value => '1')
	);

	$self->SUPER::initialize();
}