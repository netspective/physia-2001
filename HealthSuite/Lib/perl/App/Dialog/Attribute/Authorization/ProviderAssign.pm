##############################################################################
package App::Dialog::Attribute::Authorization::ProviderAssign;
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
	'auth-providerassign' => {
		valueType => App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN,
		heading => '$CommandProvider Assignment Indicator',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Provider Assignment Indicator');

	$self->addContent(
				new App::Dialog::Field::Attribute::Name(
						caption => 'Provider Assignment',
						name => 'value_textb',
						fKeyStmtMgr => $STMTMGR_PERSON,
						fKeyStmt => 'selProviderAssign',
						#type => 'foreignKey',
						#fKeyTable => 'auth_assign',
						#fKeySelCols => "abbrev, caption",
						fKeyDisplayCol => 1,
						fKeyValueCol => 0,
						attrNameFmt => 'Provider Assignment',
						valueType => $self->{valueType},
						selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),
	);

	$self->SUPER::initialize();
}

1;
