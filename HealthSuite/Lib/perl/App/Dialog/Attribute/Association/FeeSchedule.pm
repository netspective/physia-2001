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
use App::Statements::Catalog;
use App::Statements::Org;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

my $FS_ATTRR_TYPE = App::Universal::ATTRTYPE_INTEGER;
my $FS_CATALOG_TYPE = 0;

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
	my ($self, $command) = CGI::Dialog::new(@_, id => 'associate-fs-person', heading => 'Associate Fee Schedule');

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
                        new CGI::Dialog::Field(	name => 'value_int',
						type => 'hidden',		
						),		
                        new App::Dialog::Field::Catalog::ID(caption => 'Fee Schedule ID',
						name => 'catalog_id',
						options => FLDFLAG_REQUIRED,
						),							
			
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
	my $catalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,'selCatalogById', $page->field('value_int'));	
	$page->field('catalog_id',$catalog->{catalog_id});
}

sub customValidate
{
	my ($self, $page) = @_;
	my $table = $self->{table};
	my $field = $self->getField('catalog_id');
	#Check if Fee Schedule is Already assoicated with this provider/org
	my $msg = "Fee Schedule Already Assoicated with " . $page->field('parent_id');
	my $command = $self->getActiveCommand($page);	
	my $catalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,'selInternalCatalogIdByIdType', $page->session('org_internal_id'),$page->field('catalog_id'),$FS_CATALOG_TYPE);	
	$page->field('value_int',$catalog->{internal_catalog_id});	
	return if $command eq 'update' or $command eq 'remove';
	if($table eq 'Org_Attribute')
	{	
		my $parent_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id'));		
		$field->invalidate($page,$msg) if $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selAttributeByIdValueIntParent',
						$parent_id,$page->field('value_int'),'Fee Schedule');
	}
	else
	{
		$field->invalidate($page,$msg) if $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selAttributeByIdValueIntParent',
						$page->field('parent_id'),$page->field('value_int'),'Fee Schedule');
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
			item_name => 'Fee Schedule',
			item_type => 0,
			value_type => $FS_ATTRR_TYPE,
			value_int => $page->field('value_int'),			
	);

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}


1;