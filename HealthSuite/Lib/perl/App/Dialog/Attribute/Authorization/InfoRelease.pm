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
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Attribute::Authorization);


%RESOURCE_MAP = (
	'auth-inforelease' => {
		 valueType => App::Universal::ATTRTYPE_AUTHINFORELEASE,
		 heading => '$Command Information Release Indicator',
		 _arl => ['person_id'],
		 _arl_modify => ['item_id'],
		 _idSynonym => 'attr-' .App::Universal::ATTRTYPE_AUTHINFORELEASE()
		 },
);

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
				new CGI::Dialog::Field(name => 'value_date', caption => 'Date', type => 'date'),
			);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "'Information Release Authorization' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->SUPER::initialize();
}

1;
