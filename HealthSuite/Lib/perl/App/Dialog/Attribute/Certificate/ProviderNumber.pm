##############################################################################
package App::Dialog::Attribute::Certificate::ProviderNumber;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Dialog::Attribute::Certificate;
use App::Statements::Org;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Attribute::Certificate);

%RESOURCE_MAP = (
	'certificate-provider-number' => {
		valueType => App::Universal::ATTRTYPE_PROVIDER_NUMBER,
		heading => '$Command Provider Number',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::ATTRTYPE_PROVIDER_NUMBER()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Provider Number');

	$self->addContent(
		new CGI::Dialog::Field(
			type => 'select',
			selOptions => 'BCBS;Memorial Sisters Charity;EPSDT;Medicaid;Medicare;UPIN;Tax ID;Railroad Medicare;Champus;WC#;National Provider Identification',
			caption => 'Name',
			name => 'value_textb',
			options => FLDFLAG_REQUIRED,
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE
		),
		new CGI::Dialog::Field(caption => 'Number', name => 'value_text', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'date', caption => 'Expiration Date', name => 'value_dateend', futureOnly => 0, defaultValue => ''),
		new CGI::Dialog::Field(	name => 'name_sort',
					caption => 'Facility ID',
					fKeyStmtMgr => $STMTMGR_ORG,
					fKeyStmt => 'selChildFacilityOrgs',
					fKeyDisplayCol => 0,
					fKeyValueCol => 0,
					type => 'select',
					fKeyStmtBindSession => ['org_internal_id'],
					options => FLDFLAG_PREPENDBLANK),
		new CGI::Dialog::Field(type => 'bool', name => 'value_int', caption => 'Required',	style => 'check'),
	);

	$self->SUPER::initialize();
}

1;
