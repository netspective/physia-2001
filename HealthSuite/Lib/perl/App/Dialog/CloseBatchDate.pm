##############################################################################
package App::Dialog::Transaction::CloseBatchDate;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;
use App::Statements::Transaction;
use Date::Manip;
use App::Statements::Org;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $TEXT_ATTRR_TYPE = App::Universal::ATTRTYPE_TEXT;

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
			new App::Dialog::Field::Organization::ID(
					caption => 'Organization ID',
					name => 'org_id',	
					options=>FLDFLAG_REQUIRED
			),
			new CGI::Dialog::Field(name => 'close_date', 
						caption => 'Close Date',						
						type => 'date',
						options=>FLDFLAG_REQUIRED,
						hints=>'Only batch date(s) greater than the Close Date will be valid',
						defaultValue=>''),																
			new CGI::Dialog::Field(type => 'select',
							style => 'radio',
							selOptions => 'Yes:1;No:0',
							caption => 'Apply to Child Organizations',
							preHtml => "<B><FONT COLOR=DARKRED>",
							postHtml => "</FONT></B>",
							name => 'childern',options=>FLDFLAG_REQUIRED,
				defaultValue => '0',)
																	
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'org_attribute',
			key => "#param.org_id#",
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

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	my $childern = $page->field('childern');
	my $parent_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->field('org_id'));		
	
	
	my $children_orgs = $STMTMGR_ORG->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selCloseDateChildParentOrgIds',$page->session('org_internal_id'),$parent_id,$childern );
	foreach (@$children_orgs)
	{		
		#Check if Org Id already has a close batch date	
		my $item = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $_->{org_internal_id},'Retire Batch Date',$TEXT_ATTRR_TYPE);
		$command = $item->{item_id} ? 'update' : 'add' ;
		$page->schemaAction(
				'Org_Attribute', $command,
				item_id => $item->{item_id}|| undef,
				parent_id => $_->{org_internal_id},
				item_name => 'Retire Batch Date',
				item_type => 0,
				value_type => $TEXT_ATTRR_TYPE,
				value_date => $page->field('close_date')
			);
	}
	$self->handlePostExecute($page, $command, $flags);	
	
}



1;