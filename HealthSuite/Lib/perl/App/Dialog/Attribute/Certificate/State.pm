##############################################################################
package App::Dialog::Attribute::Certificate::State;
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
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Attribute::Certificate);

%RESOURCE_MAP = (
	'certificate-state' => {
		valueType => App::Universal::ATTRTYPE_STATE,
		heading => '$Command State License',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_STATE()
	},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command State License');

	$self->addContent(
			new App::Dialog::Field::Attribute::Name(
					caption => 'State',
					name => 'value_textb',
					options => FLDFLAG_REQUIRED,
					size => 2,
					maxLength => 2,
					attrNameFmt => "#field.value_textb#",
					fKeyStmtMgr => $STMTMGR_PERSON,
					valueType => $self->{valueType},
					selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),

			new CGI::Dialog::Field(caption => 'Number',  name => 'value_text', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(type => 'date', caption => 'Effective Date', name => 'value_date', futureOnly => 0, defaultValue => ''),
			new CGI::Dialog::Field(type => 'date', caption => 'Expiration Date', name => 'value_dateend', options => FLDFLAG_REQUIRED),
	);

	$self->SUPER::initialize();
}

1;
