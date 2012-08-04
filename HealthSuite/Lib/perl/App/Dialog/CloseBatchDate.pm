##############################################################################
package App::Dialog::Transaction::CloseBatchDate;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use App::Dialog::Field::Scheduling;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Invoice;
use Date::Manip;
use Date::Calc qw(:all);
use App::Statements::Org;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $CLOSE_ATTRR_TYPE = App::Universal::ATTRTYPE_DATE;

%RESOURCE_MAP=('close-date' => {	heading => 'Close Date',  
					_arl => ['org_id'], 					
				  },
	);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'close-date', heading => 'Close Date');


	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
		new App::Dialog::Field::Organization::ID(caption => 'Organization ID',
			name => 'org_id',
			options => FLDFLAG_REQUIRED,
		),
		new App::Dialog::Field::Scheduling::Date(caption => 'Close Date',
			name => 'close_date', 
			type => 'date',
			options => FLDFLAG_REQUIRED,
			hints => 'Only batch date(s) greater than the Close Date will be valid',
			defaultValue => '',
		),	
		new CGI::Dialog::Field(caption => 'Set Close Date',
			name => 'create_record',
			type => 'bool',
			style => 'check',
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD | CGI::Dialog::DLGFLAG_UPDORREMOVE
		),
		new CGI::Dialog::Field(caption => 'Apply to Child Organizations',
			name => 'children',
			type => 'select',
			style => 'radio',
			selOptions => 'Yes:1;No:0',
			preHtml => "<B><FONT COLOR=DARKRED>",
			postHtml => "</FONT></B>",
			options=>FLDFLAG_REQUIRED,
			defaultValue => '0',
		),
		new CGI::Dialog::Field(caption => 'Run Close Date Report',
			name => 'run_report',
			type => 'bool',
			style => 'check',
		),
);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'org_attribute',
		key => "#field.org_id#",
		data => "Create Close Date Include children : #field.children#"
	};
	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	my $parent_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id'));			
	$page->field('org_id',$page->param('org_id'));
	return unless $flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL;	
}

sub customValidate
{
	my ($self, $page) = @_;
	

	my $children = $page->field('children');
	my $parent_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->field('org_id'));			
	my $children_orgs = $STMTMGR_ORG->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selCloseDateChildParentOrgIds',
		$page->session('org_internal_id'), $parent_id, $children );
	my $closeDate = $page->field('close_date');	
	my $closeField	=$self->getField('close_date');
	my $setField = $self->getField('create_record');
	my $one=0;

	#Only validation done is to check that the Close Date are in sequence. If create_record has been selected then we do not need to
	#perform this validation
	
	return 1 if $page->field('create_record') ne '';
	#Check if Org or If Select children Org have a closed date that will not be in sequence		
	foreach (@$children_orgs)
	{
		my $item = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeItemDateByItemNameAndValueTypeAndParent', $_->{org_internal_id},'Retire Batch Date',$CLOSE_ATTRR_TYPE);	
		if($item->{value_date})
		{
			my @closeDateArray ;
			my @currentDataArray;
			#If there is an invalid date let the date field handle the error
			eval{
				@closeDateArray = Decode_Date_US($closeDate) if$closeDate;
				@currentDataArray = Decode_Date_US($item->{value_date});

				if(Delta_Days($closeDateArray[0],$closeDateArray[1],$closeDateArray[2],$currentDataArray[0],$currentDataArray[1],$currentDataArray[2])!=-1)
				{
					#Check if open date has open invoice assoicated
					my $checkRec = $STMTMGR_INVOICE->recordExists($page, STMTMGRFLAG_NONE, 'selInvoiceTransaction', $_->{org_internal_id},$item->{value_date},$closeDate);
					my $msg = qq{Close date '$closeDate' is not the next date after current close date '$item->{value_date}' for $item->{org_id} };
					$msg =    qq{There are transactions on the open dates between '$item->{value_date}' and '$closeDate' for $item->{org_id}} if ($checkRec);					
					$closeField->invalidate($page,$msg); 					
					$self->updateFieldFlags('create_record', FLDFLAG_INVISIBLE,0);									
					$one++;
				}	
			}
		}		
	}
	$setField->invalidate($page, qq{If you still want to set the close date, enter the check-box 'Set Close Date'.}) if ($one);

}

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	my $children = $page->field('children');
	my $parent_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->field('org_id'));		
	
	
	my $children_orgs = $STMTMGR_ORG->getRowsAsHashList($page,STMTMGRFLAG_NONE, 
		'selCloseDateChildParentOrgIds',$page->session('org_internal_id'), $parent_id, $children );
	foreach (@$children_orgs)
	{		
		#Check if Org Id already has a close batch date if so do an update otherwise do an insert	
		my $item = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $_->{org_internal_id},'Retire Batch Date',$CLOSE_ATTRR_TYPE);
		$command = $item->{item_id} ? 'update' : 'add' ;
		$page->schemaAction(
				'Org_Attribute', $command,
				item_id => $item->{item_id}|| undef,
				parent_id => $_->{org_internal_id},
				item_name => 'Retire Batch Date',
				item_type => 0,
				value_type => $CLOSE_ATTRR_TYPE,
				value_date => $page->field('close_date')
			);
	}
	
	#$page->param('home','/') unless $page->param('home') ;#Set home value if it is not set
	
	$page->param('_dialogreturnurl', $page->field('run_report') ? 
		"/report/Accounting/CloseDate?close_date=@{[$page->field('close_date')]}" : 
		$page->param('home') ? $page->param('home') : '/');
		
	$self->handlePostExecute($page, $command, $flags);	
}



1;