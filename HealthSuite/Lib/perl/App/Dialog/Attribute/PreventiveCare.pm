##############################################################################
package App::Dialog::Attribute::PreventiveCare;
##############################################################################

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Person;
use strict;
use Carp;
use CGI::Dialog;
use App::Dialog::Field::Attribute;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'preventivecare', heading => '$Command Measure');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Attribute::Name(
							name => 'attr_name',
							caption => 'Measure',
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
							attrNameFmt => "#field.attr_name#",
							fKeyStmtMgr => $STMTMGR_PERSON,
							valueType => $self->{valueType},
							selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),


		new CGI::Dialog::Field(type => 'date', name => 'value_date', caption => 'Last Performed', options => FLDFLAG_REQUIRED, futureOnly => 0),
		new CGI::Dialog::Field(type => 'date', caption => 'Due', name => 'value_dateend', options => FLDFLAG_REQUIRED, futureOnly => 0)
	);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Preventive Care to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');

	my $preventiveCare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

	$page->field('attr_name' , $preventiveCare->{'item_name'});
	$page->field('value_date' , $preventiveCare->{'value_date'});
	$page->field('value_dateend' , $preventiveCare->{'value_dateend'});

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id => $page->param('person_id'),
		item_id => $page->param('item_id') || undef,
		item_name => $page->field('attr_name') || undef,
		value_type => $self->{valueType} || undef,
		value_date => $page->field('value_date'),
		value_dateEnd => $page->field('value_dateend'),
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

use constant PANEDIALOG_PREVENTIVECARE => 'Dialog/Preventive Care';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/30/2000', 'MAF',
		PANEDIALOG_PREVENTIVECARE,
		'Created new dialog for preventive care.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/31/2000', 'RK',
		PANEDIALOG_PREVENTIVECARE,
		'Added execute and populate data subroutines.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '03/14/2000', 'MAF',
		PANEDIALOG_PREVENTIVECARE,
		'Removed item path from item name.'],

);

1;