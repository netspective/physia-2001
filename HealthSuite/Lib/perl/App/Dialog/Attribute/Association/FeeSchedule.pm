##############################################################################
package App::Dialog::Association::FeeSchedule;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;
use Date::Manip;
use App::Statements::Person;
use App::Statements::Org;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

my $FS_ATTRR_TYPE = App::Universal::ATTRTYPE_TEXT;#App::Universal::ATTRTYPE_FEE_SCHEDULE;


%RESOURCE_MAP = (
	'feeschedule-person' => {
		valueType => App::Universal::ATTRTYPE_FEE_SCHEDULE,
		 heading => '$Command Assoicated Fee Schedule',
		 table => 'Person_Attribute',
		 _arl => ['person_id'],
		 _arl_modify => ['item_id'],
		_idSynonym => 'attr-person-' .App::Universal::ATTRTYPE_FEE_SCHEDULE()
		},
	'feeschedule-org' => {
		valueType => App::Universal::ATTRTYPE_FEE_SCHEDULE,
		heading => '$Command Assoicated Fee Schedule',
		table => 'Org_Attribute',
		_arl => ['org_id'],
		_arl_modify => ['item_id'],
		_idSynonym => 'attr-org-' .App::Universal::ATTRTYPE_FEE_SCHEDULE()
		},
		);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'associate-fs-person', heading => '$Command Associated Fee Schedule');

	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	my $table = $self->{table};
	my $caption;
	delete $self->{schema};  # make sure we don't store this!
	
	if($table eq 'Person_Attribute')
	{
		$caption ='Person ID';
		$self->{activityLog} =
		{
			level => 1,
			scope =>'person',
			key => "#param.person_id#",
			data => "Associate Fee Schedule '"
		};
	}
	else
	{
		$caption ='Organization ID';
		$self->{activityLog} =
		{
			level => 1,
			scope =>'org',
			key => "#param.org_id#",
			data => "Associate Fee Schedule '"
		};
	}
	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(type => 'hidden', name => 'item_id'),
			new CGI::Dialog::Field(	name => 'parent_id', 
						caption => $caption,
						type => 'text',
						options => FLDFLAG_READONLY),
                        new App::Dialog::Field::Catalog::ID(caption => 'Fee Schedule ID',
						name => 'value_int',
						type => 'integer',
						options => FLDFLAG_REQUIRED,
						hints => 'Numeric Fee Schedule ID'),
			new CGI::Dialog::Field(type => 'select',
							style => 'radio',
							selOptions => 'Yes:0;No:1',
							caption => "Override Insurance Fee Schedule(s): ",
							preHtml => "<B><FONT COLOR=DARKRED>",
							postHtml => "</FONT></B>",
							name => 'value_intb', defaultValue => '0',
							hints =>'Indicates Fee Schedule Precedence'),
														
			
		);

		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	my $table = $self->{table};

	$page->field('parent_id',$page->param('org_id')||$page->param('person_id'));		
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;	
	if($table eq 'Org_Attribute')
	{	
		$STMTMGR_ORG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById',$page->param('item_id') );	
		$page->field('parent_id',$page->param('org_id')||$page->param('person_id'));		
	}
	else
	{
		$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selAttributeById',$page->param('item_id') ) if
		$page->param('item_id');	
	}
	
}

sub customValidate
{
	my ($self, $page) = @_;
	my $table = $self->{table};
	my $field = $self->getField('value_int');
	#Check if Fee Schedule is Already assoicated with this provider/org
	my $msg = "Fee Schedule Already Assoicated with " . $page->field('parent_id');
	my $command = $self->getActiveCommand($page);	
	return if $command eq 'update' or $command eq 'remove';
	if($table eq 'Org_Attribute')
	{	
		my $parent_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id'));		
		$field->invalidate($page,$msg) if $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selAttributeByIdValueIntParent',
						$parent_id,$page->field('value_int'),'Fee Schedules');
	}
	else
	{
		$field->invalidate($page,$msg) if $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selAttributeByIdValueIntParent',
						$page->field('parent_id'),$page->field('value_int'),'Fee Schedules');
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $parent_id;
	if($page->param('org_id'))
	{
		$parent_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id'));		
	}
	else	
	{
		$parent_id = $page->field('parent_id');
	}
	my $table = $self->{table};
	$page->schemaAction(
			$table, $command,
			item_id => $page->param('item_id') || undef,
			parent_id => $parent_id,
			item_name => 'Fee Schedules',
			item_type => 0,
			value_type => $FS_ATTRR_TYPE,
			value_int => $page->field('value_int'),
			value_intB => $page->field('value_intb'),			
	);

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}


1;