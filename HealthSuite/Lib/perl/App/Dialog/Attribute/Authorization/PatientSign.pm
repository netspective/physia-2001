##############################################################################
package App::Dialog::Attribute::Authorization::PatientSign;
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
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Attribute::Authorization);

%RESOURCE_MAP = (
	'auth-patientsign' => {
		valueType => App::Universal::ATTRTYPE_AUTHPATIENTSIGN,
		heading => '$Command Patient Signature Authorization',
		_arl => ['[person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_AUTHPATIENTSIGN()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Patient Signature Authorization');

	$self->addContent(
				new App::Dialog::Field::Attribute::Name(
						caption => 'Patient Signature',
						name => 'value_textb',
						fKeyStmtMgr => $STMTMGR_PERSON,
						fKeyStmt => 'selPatientSign',
						fKeyDisplayCol => 1,
						fKeyValueCol => 0,
						attrNameFmt => 'Signature Source',
						valueType => $self->{valueType},
						selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),
				new CGI::Dialog::Field(name => 'value_date', caption => 'Date', type => 'date'),
	);

	$self->SUPER::initialize();
}

1;
