##############################################################################
package App::Dialog::TestCatalog;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Org;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use App::Statements::Worklist::WorklistCollection;

use CGI::ImageManager;
use Date::Manip;
use Text::Abbrev;
use App::Universal;
use App::Statements::LabTest;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'test-catalog' => {
		_arl_add =>['org_id'],
		_arl_modify => ['internal_catalog_id']
	},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', heading => '$Command Ancillary Catalog');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
		new CGI::Dialog::Field(
			name => 'org_name',
			type => 'text',
			caption => 'Lab Org Name ',
			size=>15,
			maxLength=>30,
			options=>FLDFLAG_READONLY,
		),	

		new CGI::Dialog::Field(
			caption => 'Service Catalog ID',
			name=>'catalog_id',
			type => 'text',
			maxLength=>30,
			options=>FLDFLAG_REQUIRED | FLDFLAG_UPPERCASE,
		),				
		
		new CGI::Dialog::Field(
			caption => 'Service Catalog Name',
			name=>'caption',
			type => 'text',
			maxLength=>30,
			options=>FLDFLAG_REQUIRED,			
		),				
		
		new CGI::Dialog::Field(caption => 'Description',
			name => 'description',
			type => 'memo',
		),				
		new CGI::Dialog::Field(
			name => 'internal_catalog_id',
			type => 'hidden',
		),			
		new CGI::Dialog::Field(
			name => 'org_internal_id',
			type => 'hidden',
		),			
		
		
	);

	$self->{activityLog} =
	{
		scope =>'offering_catalog',
		key => "#field.catalog_id#",
		data => "Service Catalog"
	};
	$self->addFooter(new CGI::Dialog::Buttons(nextActions_add => [
				['Add Another Service Catalog', "/org/#param.org_id#/dlg-add-test-catalog/#field.internal_catalog_id#", 1],
				['Show Service Catalog', "/org/#param.org_id#/catalog?catalog=labtest"],
	],
	 cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}


 sub makeStateChanges
 {
       	my ($self, $page, $command, $dlgFlags) = @_;
       	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

}
sub populateData_add
{
	my ($self, $page, $command, $flags) = @_;
	my $orgData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selOrg', $page->session('org_internal_id'),$page->param('org_id')||undef);	
	$page->field('org_name',$orgData->{org_id});
	$page->field('org_internal_id',$orgData->{'org_internal_id'});		
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	my $catalogId = $page->param('internal_catalog_id');	
	if(! $STMTMGR_CATALOG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selCatalogById',$catalogId))
	{
		$page->addError("Catalog ID '$catalogId' not found.");
	}
	else
	{
		#Get org name
		my $orgData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $page->field('org_internal_id'));	
		$page->field('org_name',$orgData->{org_id});			
	}
	

}

sub populateData_remove
{
	populateData_update(@_);
	
	#Hide the caption if panel test;
}
sub customValidate
{
	my ($self, $page) = @_;		
};

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $catalogType = 5;
	#Store Lab Test Catalog 
	$page->schemaAction(
		'Offering_Catalog', $command,
		internal_catalog_id =>$page->field('internal_catalog_id')||undef,
		catalog_id => $page->field('catalog_id') || undef,
		org_internal_id => $page->field('org_internal_id') || undef,
		catalog_type => $catalogType,
		caption=>$page->field('caption'),
		description => $page->field('description') || undef,
	);	
	#Check if this is panel of test of single test
	$page->param('_dialogreturnurl', '/org/%param.org_id%/catalog?catalog=labtest_detail&labtest_detail=%field.internal_catalog_id%') if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags, undef);			
	return ;
}

1;

