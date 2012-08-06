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
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'benefit-insurance' => {
		valueType => App::Universal::BENEFIT_INSURANCE,
		heading => '$Command Insurance Benefit',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::BENEFIT_INSURANCE()
		},
	'benefit-retirement' => {
		valueType => App::Universal::BENEFIT_RETIREMENT,
		heading => '$Command Retirement Benefit',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::BENEFIT_RETIREMENT()
		},
	'benefit-other' => {
		valueType => App::Universal::BENEFIT_OTHER,
		heading => '$Command Other Benefit',
		_arl => ['person_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::BENEFIT_OTHER()
		},
);

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

1;
