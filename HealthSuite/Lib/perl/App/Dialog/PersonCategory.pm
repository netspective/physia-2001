##############################################################################
package App::Dialog::PersonCategory;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;

use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Person;

use App::Universal;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'person-category' => {
		heading => '$Command Person With A New Category',
		_arl => ['person_id']
	},
);

sub new
{
 	my ($self, $command) = CGI::Dialog::new(@_, id => 'person-category', heading => '$Command Person With A New Category');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Person::ID(
			caption =>'Person ID',
			name => 'person_id',
			types => ['Patient','Guarantor','Insured-Person'],
			hints => 'Please provide an existing Person ID.',
			options => FLDFLAG_REQUIRED
			),
		new CGI::Dialog::Field(caption => 'Category',
			type => 'select',
			selOptions => 'Patient;Guarantor;Insured-Person',
			name => 'category',
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person',
		key => "#field.person_id#",
		data => "person <a href='/person/#field.person_id#/profile'>#field.person_id#</a> as a #field.category#"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	my $personId = $page->param('person_id');
	$page->field('person_id', $personId);
	$self->setFieldFlags('person_id', FLDFLAG_READONLY);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $personId = $page->param('person_id');

	#$STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);
}


#sub _customValidate
#{
#	my ($self, $page) = @_;
#
#	my $cat = $self->getField('category');
#	my $personId = $page->field('person_id');
#	my $orgId = $page->field('org_id');
#	my $category = $page->field('category');
#	my $existCat = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selDoesCategoryExist', $personId, $orgId, $category);
#	if ($existCat ne '')
#	{
#		$cat->invalidate($page, "The Category '$category' already exists for the Person '$personId'");
#	}
#}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $orgId = $page->session('org_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId);

	$page->schemaAction(
			'Person_Org_Category', $command,
			person_id => $page->field('person_id') || undef,
			org_internal_id => $orgIntId || undef,
			category => $page->field('category') || undef,
			_debug => 0
			);
	$self->handlePostExecute($page, $command, $flags);
	return "\u$command completed.";
}

1;
