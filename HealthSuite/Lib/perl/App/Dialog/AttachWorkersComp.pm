##############################################################################
package App::Dialog::AttachWorkersComp;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Insurance;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Field::Insurance;
use App::Dialog::Field::Address;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'person-attachworkerscomp' => {
		_arl_add => ['ins_id'],
		_arl_modify => ['ins_internal_id'],
		},
	);

sub new
{
	my $self = CGI::Dialog::new(@_, heading => '$Command Workers Compensation Plan', id => 'workerscomp');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		#new CGI::Dialog::MultiField(caption => 'Workers Comp Plan ID/Employee Workers Comp Plan ID', name => 'ins_plan',
		#			fields => [
		#						new App::Dialog::Field::Insurance::WorkersComp::ID(caption => 'Workers Compensation Plan ID', name => 'ins_id'),
								#new CGI::Dialog::Field(caption => 'Employee Work Comp Plans',
								#		type => 'foreignKey',
								#		name => 'emp_plan',
								#		fKeyTable => 'person_attribute patt, insurance ins',
								#		fKeySelCols => "distinct ins.ins_id",
								#		fKeyDisplayCol => 0,
								#		fKeyValueCol => 0
										#fKeyWhere => "patt.item_name like 'Association/Employment/%' and patt.value_text=ins.ins_org_id and ins.record_type = '6'"
								#		)
		#				]));

 	new App::Dialog::Field::Insurance::WorkersComp::ID(caption => 'Workers Compensation Plan ID',
						name => 'ins_id',
 						options => FLDFLAG_REQUIRED),
 	);
	$self->{activityLog} =
	{
		scope =>'insurance',
		key => "#field.ins_org_id#",
		data => "Attach Workers Comp Plan '#field.ins_id#' to <a href='/org/#field.ins_org_id#/profile'>#field.ins_org_id#</a>"
 	};
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $insIntId = $page->param('_inne_ins_internal_id') || $page->param('ins_internal_id');
	$STMTMGR_INSURANCE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId);
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	if(my $wrkcompId = $page->param('ins_id'))
	{
		$page->field('ins_id', $wrkcompId);
	}
	#$self->getField('ins_plan')->{fields}->[1]->{fKeyWhere} = "patt.parent_id = '@{[ $page->param('person_id') ]}' and patt.item_name like 'Association/Employment/%' and patt.value_text = ins.ins_org_id and ins.record_type = 5 ";
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $insId = $page->field('ins_id') ne '' ? $page->field('ins_id') : $page->field('emp_plan');
	my $workCompInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selWorkersCompPlanInfo', $insId);

	#CONSTANTS
	my $wrkcmpInsType = App::Universal::CLAIMTYPE_WORKERSCOMP;
	my $recordType = App::Universal::RECORDTYPE_PERSONALCOVERAGE;

	my $remitType = $workCompInfo->{remit_type};

	my $insIntId = $page->schemaAction(
 			'Insurance', $command,
 			ins_internal_id => $page->param('ins_internal_id') || undef,
 			ins_id => $insId || undef,
 			parent_ins_id => $workCompInfo->{ins_internal_id} || undef,
 			owner_id => $page->param('person_id') || undef,
 			ins_org_id => $workCompInfo->{ins_org_id} || undef,
 			ins_type => defined $wrkcmpInsType ? $wrkcmpInsType : undef,
 			remit_type => defined $remitType ? $remitType : undef,
 			remit_payer_id => $workCompInfo->{remit_payer_id} || undef,
 			remit_payer_name => $workCompInfo->{remit_payer_name} || undef,
 			record_type => defined $recordType ? $recordType : undef,
 			_debug => 0
 		);

	return "\u$command completed.";

}

1;
