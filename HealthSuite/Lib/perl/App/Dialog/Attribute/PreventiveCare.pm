######################################################################################################################################
package App::Dialog::Attribute::PreventiveCare;
#####################################################################################################################################

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Person;
use App::Statements::Catalog;
use App::Statements::Transaction;
use strict;
use Carp;
use CGI::Dialog;
use App::Dialog::Field::Attribute;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use Date::Calc qw(:all);
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'preventivecare' => {
		valueType => App::Universal::PREVENTIVE_CARE,
		heading => '$Command Measure',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-' .App::Universal::PREVENTIVE_CARE()
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'preventivecare', heading => '$Command Measure');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'cpt_name'),
		new App::Dialog::Field::Attribute::Name(
							name => 'attr_name',
							caption => 'Problem',
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
							attrNameFmt => "#field.attr_name#",
							fKeyStmtMgr => $STMTMGR_PERSON,
							valueType => $self->{valueType},
							selAttrNameStmtName => 'selAttributeByItemNameAndValueTypeAndParent'),

		new CGI::Dialog::Field(caption => 'Measure', name => 'value_text', options => FLDFLAG_REQUIRED, findPopup => "/lookup/cpt/detail?_f_search_expression=%field.attr_name%"),
		new CGI::Dialog::MultiField(caption =>'Measure Frequency/Number Of Times',
					fields => [
						new CGI::Dialog::Field(caption => 'Frequency', name => 'frequency', type => 'select', selOptions => ' : 0;Weekly:1;Monthly:2;Annually:3',value => ''),
						new CGI::Dialog::Field(caption => 'Measure', name => 'measure', size => '3')
				]),

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

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->updateFieldFlags('freq_measure', FLDFLAG_INVISIBLE, 1);
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
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
	$page->field('value_text', $preventiveCare->{'value_text'});
	$page->field('frequency', $preventiveCare->{'value_int'});
	$page->field('measure', $preventiveCare->{'value_intb'});

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $cptCode = $page->field('value_text');
	my $cptName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $cptCode);
	my $cptCodeName = $cptName->{'name'} ne '' ? $cptName->{'name'} : '';
	$page->field('cpt_name',$cptCodeName);
	#my $cptCodeName = $page->field('cpt_name');

	my $itemId = $page->schemaAction(
						'Person_Attribute', $command,
						parent_id => $page->param('person_id'),
						item_id => $page->param('item_id') || undef,
						item_name => $page->field('attr_name') || undef,
						value_type => $self->{valueType} || undef,
						value_date => $page->field('value_date') || undef,
						value_text => $page->field('value_text') || undef,
						value_textB => $page->field('cpt_name') || undef,
						value_dateEnd => $page->field('value_dateend') || undef,
						value_int => $page->field('frequency') || undef,
						value_intB => $page->field('measure') || undef,
						_debug => 0
					);

	my $dataTextB = $command eq 'add' ? $itemId : $page->param('item_id');

	my $todayDate = Date_to_Days(Decode_Date_US2($page->getDate()));

	my $dueDate = Date_to_Days(Decode_Date_US2($page->field('value_dateend')));


	my $test = $dueDate - $todayDate;
	my $transStatus = $dueDate >= $todayDate ?
							App::Universal::TRANSSTATUS_ACTIVE : App::Universal::TRANSSTATUS_INACTIVE;

	my $transData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selByDataTextB', $dataTextB, $page->param('person_id'));

	my $transId = $command ne 'add' ? $transData->{trans_id} : undef;
	$page->schemaAction(
			'Transaction', $command,
			trans_id => $transId || undef,
			trans_owner_type => 0,
			trans_owner_id => $page->param('person_id') || undef,
			trans_type => App::Universal::TRANSTYPE_ALERTPATIENT,
			trans_subtype => 'Medium' || undef,
			caption => 'Preventive Care' || undef,
			detail => $page->field('attr_name') || undef,
			trans_status => $transStatus || undef,
			initiator_id => $page->session('user_id') || undef,
			initiator_type => 0,
			trans_status => $transStatus,
			trans_begin_stamp => $page->field('value_date') || undef,
			trans_end_stamp => $page->field('value_dateend') || undef,
			data_text_b => $dataTextB || undef,
			_debug => 0
	) if $command eq 'add' || $transData->{trans_id} ne '';

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;
