##############################################################################
package App::Dialog::ServiceCatalog;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Org;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use Date::Manip;
use Text::Abbrev;
use App::Universal;

use vars qw(@ISA %RESOURCE_MAP );
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'service-catalog' => {
		_arl => ['internal_catalog_id'],
		_arl_modify=> ['entry_id']},
);

my $FS_ATTRR_TYPE = App::Universal::ATTRTYPE_INTEGER;
my $FS_TEXT = 'Service Catalog Text';
my $FS_CATALOG_TYPE = 1;
sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', heading => '$Command Service Catalog Entry');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
					
	my $sqlStmt = qq{
		select distinct serv_category,name
		from REF_SERVICE_CATEGORY
		order by  name
		};		
	$self->addContent(

		new CGI::Dialog::Field(
			name => 'internal_catalog_id',
			type => 'hidden'
		),
		new App::Dialog::Field::Catalog::ID::New(caption => 'Service Catalog ID',
			name => 'catalog_id', 
			size => 20,
			options => FLDFLAG_READONLY,
			#postHtml => "&nbsp; <a href=\"javascript:doActionPopup('/lookup/catalog');\">Lookup Fee Schedules</a>",
		),
		new CGI::Dialog::Field(caption => 'Service Catalog Name', 
			name => 'caption', 
			options => FLDFLAG_READONLY,
			size => 45,
		),
		
		new CGI::Dialog::Field(caption =>'Service Category',
					name => 'code',
					fKeyStmtMgr => $STMTMGR_CATALOG,
					fKeyStmt => $sqlStmt,
					fKeyStmtFlags => STMTMGRFLAG_DYNAMICSQL,
					fKeyDisplayCol => 1,
					fKeyValueCol => 0),
		
		
	);
	
	$self->{activityLog} =
	{
		scope =>'offering_catalog',
		key => "#field.catalog_id#",
		data => "Service Catalog '#field.catalog#'"
	};
	$self->addFooter(new CGI::Dialog::Buttons(		
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	my $catalogId = $page->param('internal_catalog_id');
	$page->field('internal_catalog_id',$catalogId);
	if(! $STMTMGR_CATALOG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selCatalogById',$catalogId))
	{
		$page->addError("Catalog ID '$catalogId' not found.");
	};		
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	my $entry_id = $page->param('entry_id');
	if(! $STMTMGR_CATALOG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selCatalogItemNameById',$entry_id))
	{
		$page->addError("Entry ID '$entry_id' not found.");
	};	


}

sub populateData_remove
{
	populateData_update(@_);
}

sub checkDupName
{
	my ($self, $page) = @_;
	

}

sub customValidate
{
	my ($self, $page) = @_;
	#Check to Make sure catalog type has not already be added
	my $code = $page->field('code');
	my $catalog_id = $page->field('catalog_id');
	my $internalCatalogId = $page->field('internal_catalog_id');
	my $check = $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selCodeByOrgIdCode',$code,$internalCatalogId);
	if ($check)
	{
		my $field = $self->getField('code');
		$field->invalidate($page, qq{This code already exists for catalog $catalog_id});	
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $entryId = $page->schemaAction(
		'Offering_Catalog_Entry', $command,
		catalog_id => $page->field('internal_catalog_id'),
		entry_id =>$page->param('entry_id') || undef,
		entry_type => 250,
		flags=>0,
		status=>1,
		default_units=>1,
		cost_type=>0,
		code => $page->field('code'),
		);	

	$self->handlePostExecute($page, $command, $flags);
};
#1;
