##############################################################################
package App::Dialog::UserProblems;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use vars qw(@ISA);

use Date::Manip;

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'userproblems', heading => '$Command Problem');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Field(caption => 'User', name => 'user'),
		new CGI::Dialog::Field(type => 'date', caption => 'Date', name => 'problem_date'),
		new CGI::Dialog::Field(type => 'memo', caption => 'Problem', name => 'problem'),
	);
	$self->addFooter(new CGI::Dialog::PersonButtons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $personId = $page->param('person_id');
	if(! $STMTMGR_PERSON->createFieldsFromSingleRow($page,STMTMGRFLAG_NONE,'selPersonData',$personId))

	#(! $page->createFieldsFromSingleQueryRow(qq{
					#select *
					#from person
					#where person_id = '$personId'
					#}))
	{
		$page->addError("Person ID '$personId' not found.");
	}
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => 'MFARIDI',
			item_name => 'Software Problems/User',
			value_type => 0,
			value_text => $page->field('problem'),
			value_textB => $page->field('user'),
			value_date => $page->field('problem_date'),
			_debug => 0
		);


		$page->redirect($self->getReferer($page));
}

1;