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
					options => FLDFLAG_READONLY,
			),
			new CGI::Dialog::Field(name => 'close_date', 
						caption => 'Close Date',
						futureOnly => 1,
						type => 'date',
						options=>FLDFLAG_REQUIRED,
						hints=>'Only batch date(s) greater than the Close Date will be valid',),																
		#	new CGI::Dialog::Field(type => 'select',
		#					style => 'radio',
		#					selOptions => 'Creation Date:0;Payment Date:1;Both:2',
		#					caption => 'Close ',
		#					preHtml => "<B><FONT COLOR=DARKRED>",
		#					postHtml => "</FONT></B>",
		#					name => 'close_type',
		#					defaultValue => '0',
		#					options=>FLDFLAG_REQUIRED),
																	
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
	my $item = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $parent_id,'Retire Batch Date',$TEXT_ATTRR_TYPE);
	$page->field('org_id',$page->param('org_id'));
	if($item)
	{
		$page->param('item_id',$item->{item_id});
		$page->field('close_type',$item->{value_int});
		$page->field('close_date',$item->{value_date});
	}
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	my $parent_id;
	$parent_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id'));		
	$command = $page->param('item_id') ? 'update' : 'add' ;
	$page->schemaAction(
			'Org_Attribute', $command,
			item_id => $page->param('item_id') || undef,
			parent_id => $parent_id,
			item_name => 'Retire Batch Date',
			item_type => 0,
			value_type => $TEXT_ATTRR_TYPE,
			#value_int => $page->field('close_type'),
			value_date => $page->field('close_date')
	);

	$self->handlePostExecute($page, $command, $flags);	
	
}



1;