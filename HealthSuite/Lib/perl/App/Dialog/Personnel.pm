##############################################################################
package App::Dialog::Personnel;
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
	'personnel' => {
		heading => '$Command Personnel',
		_arl => ['person_id']
	},
);

sub new
{
 	my ($self, $command) = CGI::Dialog::new(@_, id => 'personnel', heading => '$Command Personnel');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Person::ID(
			caption =>'Person ID',
			name => 'person_id',
			hints => 'Please provide an existing Person ID.',
			options => FLDFLAG_REQUIRED,
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(caption => 'Category',
			type => 'select',
			selOptions => 'Physician;Nurse;Staff;Patient;Guarantor;Administrator;Referring-Doctor',
			name => 'category',
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'org',
		key => "#param.org_id#",
		data => "\u$self->{id} to <a href='/org/#param.org_id#/profile'>#param.org_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
	return $self;
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
	my $orgId = $page->param('org_id');
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
