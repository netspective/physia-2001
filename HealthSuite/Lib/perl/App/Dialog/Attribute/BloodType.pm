##############################################################################
package App::Dialog::Attribute::BloodType;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;
use App::Universal;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'blood-type' => {
		valueType => App::Universal::ATTRTYPE_TEXT,
		heading => '$Command Blood Type',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'miscnotes', heading => '$Command Blood Type');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type=> 'enum', enum => 'Blood_Type', caption => 'Blood Type', name => 'value_text'),
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Blood Type to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');
	my $bloodType = 'BloodType';
	my $bloodTypecap =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $page->param('person_id'), $bloodType);
	$page->field('blood_item_id', $bloodTypecap->{'item_id'});
	$page->field('value_text', $bloodTypecap->{'value_text'});}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	my $bloodTypecap = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $page->param('person_id'), 'BloodType');
	my $commandBlood =  $bloodTypecap->{'item_id'} ne '' && $command eq 'add' ? 'update' : $command;

	$page->schemaAction(
				'Person_Attribute', $commandBlood,
				parent_id => $page->param('person_id') || undef,
				item_id => $bloodTypecap->{'item_id'} || undef,
				item_name => 'BloodType' || undef,
				value_type => App::Universal::ATTRTYPE_TEXT,
				value_text => $page->field('value_text') || undef,
				_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);
	return "\u$command completed.";
}

1;
