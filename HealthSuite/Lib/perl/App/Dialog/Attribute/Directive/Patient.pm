##############################################################################
package App::Dialog::Attribute::Directive::Patient;
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
	'directive-patient' => {
		valueType => App::Universal::DIRECTIVE_PATIENT,
		_arl_add => ['person_id'],
		_arl_remove => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::DIRECTIVE_PATIENT()
		},
);

sub initialize
{
	my $self = shift;
	$self->heading('$Command Patient Directive');

	$self->addContent(
		new App::Dialog::Field::Attribute::Name(
							name => 'directive',
							caption => 'Directive',
							type => 'select',
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
							selOptions => ';Living Will-Advanced Directive;Will;Durable Power of Attorney;Medical Power of Attorney;Triage Status-Do Not Resuscitate;Organ Donation;',
							attrNameFmt => "#field.directive#",
							fKeyStmtMgr => $STMTMGR_PERSON,
							valueType => $self->{valueType},
							selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),

	);

	$self->SUPER::initialize();
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $directive = $page->field('directive');
	$page->schemaAction(
		'Person_Attribute',	$command,
		item_id => $page->param('item_id') || undef,
		parent_id => $page->param('person_id') || undef,
		item_name => $page->field('directive') || undef,
		value_type => App::Universal::DIRECTIVE_PATIENT || undef,
		value_text => $directive || undef,
		value_date => $page->field('value_date') || undef,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}


1;
