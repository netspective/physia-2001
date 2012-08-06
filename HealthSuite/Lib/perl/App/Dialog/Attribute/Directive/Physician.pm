##############################################################################
package App::Dialog::Attribute::Directive::Physician;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Attribute::Directive);

%RESOURCE_MAP = (
	'directive-physician' => {
		valueType => App::Universal::DIRECTIVE_PHYSICIAN,
		_arl_add => ['person_id'],
		_arl_remove => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::DIRECTIVE_PHYSICIAN()
		},
);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Physician Directive');

	$self->addContent(
		new App::Dialog::Field::Attribute::Name(
							name => 'directive',
							caption => 'Directive',
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
							attrNameFmt => "#field.directive#",
							fKeyStmtMgr => $STMTMGR_PERSON,
							valueType => $self->{valueType},
							selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),
	);

	$self->{activityLog} =
		{
			level => 1,
			scope =>'person_attribute',
			key => "#param.person_id#",
			data => "'Physician Advance Directive' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->SUPER::initialize();
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	$page->schemaAction(
		'Person_Attribute',	$command,
		item_id => $page->param('item_id') || undef,
		parent_id => $page->param('person_id') || undef,
		item_name => $page->field('directive'),
		value_type => App::Universal::DIRECTIVE_PHYSICIAN || undef,
		value_text => $page->field('directive') || undef,
		value_date => $page->field('value_date') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;
