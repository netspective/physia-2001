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
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Attribute::Certificate);

%RESOURCE_MAP = (
	'certificate-license' => {
		valueType => App::Universal::ATTRTYPE_LICENSE,
		heading => '$Command License',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_LICENSE()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command License');

	$self->addContent(
		new App::Dialog::Field::Attribute::Name(
			type => 'select',
			selOptions => 'DEA;DPS;Medicaid;Medicare;UPIN;Tax ID;IRS;Board Certification;BCBS;Railroad Medicare;Champus;WC#;National Provider Identification;Nursing/License;Memorial Sisters Charity;Provider Number',
			caption => 'License',
			name => 'value_textb',
			options => FLDFLAG_REQUIRED,
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			attrNameFmt => "#field.value_textb#",
			fKeyStmtMgr => $STMTMGR_PERSON,
			valueType => $self->{valueType},
			selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),

		new CGI::Dialog::Field(caption => 'Number', name => 'value_text', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'date', caption => 'Expiration Date', name => 'value_dateend', futureOnly => 1, defaultValue => ''),
		new CGI::Dialog::Field(type => 'bool', name => 'value_int', caption => 'License Required',	style => 'check'),
	);

	$self->SUPER::initialize();
}

1;
