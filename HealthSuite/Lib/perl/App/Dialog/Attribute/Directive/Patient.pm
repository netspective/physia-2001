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
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Dialog::Attribute::Directive);

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

use constant PANEDIALOG_DIRECTIVE => 'Dialog/Pane/Advance Directive (Patient)';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/14/2000', 'RK',
			PANEDIALOG_DIRECTIVE,
		'Removed Item Path from Item Name'],

);

1;