##############################################################################
package App::Dialog::Attribute::EmploymentBenefit;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use App::Dialog::Field::Attribute;
use DBI::StatementManager;
use App::Statements::Person;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
use Devel::ChangeLog;
@ISA = qw(CGI::Dialog);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'benefit');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
			new App::Dialog::Field::Attribute::Name(
							name => 'attr_name',
							caption => 'Caption',
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
							attrNameFmt => "#field.attr_name#",
							fKeyStmtMgr => $STMTMGR_PERSON,
							valueType => $self->{valueType},
							selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),

			new CGI::Dialog::Field(name => 'value_text', caption => 'Value', options => FLDFLAG_REQUIRED),
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'person_attribute',
			key => "#param.person_id#",
			data => "Benefit to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
		};
	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');

	my $benefits = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
	$page->field('attr_name', $benefits->{'item_name'});
	$page->field('value_text', $benefits->{'value_text'});

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $valueType = $self->{valueType};

	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->param('person_id') || undef,
		item_id => $page->param('item_id') || undef,
		item_name => $page->field('attr_name') || undef,
		value_type => $valueType || undef,
		value_text => $page->field('value_text') || undef,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}
use constant BENEFIT_DIALOG => 'Dialog/EmploymentBenefit';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/28/2000', 'RK',
		BENEFIT_DIALOG,
		'Moved the dialog for Employment Benifits Pane  from property.pm to a seperate file in Property Directory.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '03/14/2000', 'MAF',
		BENEFIT_DIALOG,
		'Removed item paths from item names.'],

);
1;