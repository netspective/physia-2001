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
use App::Statements::Person;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Attribute::Certificate);

%RESOURCE_MAP = (
	'certificate-specialty' => {
		valueType => App::Universal::ATTRTYPE_SPECIALTY,
		heading => '$Command Specialty',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_SPECIALTY()
	},
);

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
		new CGI::Dialog::Field(caption => 'Specialty Sequence', name => 'value_int', type => 'select',
					selOptions => "Unknown:" . $self->SEQUENCE_SPECIALTY_UNKNOWN . ";Primary:" .
					$self->SEQUENCE_SPECIALTY_PRIMARY . ";Secondary:" . $self->SEQUENCE_SPECIALTY_SECONDARY . ";Tertiary:"
					. $self->SEQUENCE_SPECIALTY_TERTIARY . ";Quaternary:" . $self->SEQUENCE_SPECIALTY_QUATERNARY,
					value => $self->SEQUENCE_SPECIALTY_UNKNOWN)
	);

	$self->SUPER::initialize();
}
