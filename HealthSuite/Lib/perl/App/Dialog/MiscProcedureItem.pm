##############################################################################
package App::Dialog::MiscProcedureItem;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Person;
use App::Statements::Search::Code;
use App::Statements::Catalog;
use Carp;

use CGI::Validator::Field;
use App::Dialog::Field::Catalog;
use Date::Manip;

use base 'CGI::Dialog';
use vars qw(%RESOURCE_MAP);

my $CPT_CODE =App::Universal::CATALOGENTRYTYPE_CPT;
my $HCPCS_CODE = App::Universal::CATALOGENTRYTYPE_HCPCS;
my $MISC_CODE = App::Universal::CATALOGENTRYTYPE_MISC_PROCEDURE;

%RESOURCE_MAP = (
	'misc-procedure-item' => { 
	_arl_add =>['parent_entry_id'],
	_arl_modify => ['entry_id']},
);

sub new
{
	my $self = CGI::Dialog::new(@_);
	my $command;
	($self, $command) = CGI::Dialog::new(@_, id => 'misc-procedure-item', heading => '$Command Misc Procedure Item');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'catalog_id'),
		new CGI::Dialog::Field(caption => 'Procedure Code',
			name => 'proc_code',
			type => 'text',
			size =>10,			
			options => FLDFLAG_READONLY,			
		),
		
		new CGI::Dialog::Field(caption => 'Procedure Name',
					name => 'name',
					size => 25,	
					options => FLDFLAG_READONLY,
				),
				new CGI::Dialog::Field(caption => 'Procedure Description',
					name => 'description',			
					size => 50,	
					options => FLDFLAG_READONLY,
				),
		
		new CGI::Dialog::MultiField(
			name => 'code_modifier1',
			fields => [
				new CGI::Dialog::Field(caption => 'CPT',
					name => 'cpt_code',										
					size => 10,
					findPopup => '/lookup/cpt',
					findPopupControlField => '_f_cpt_code1',
					options => FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(caption => 'Modifier',
					name => 'modifier',
					size => 10,					
				),
			]
		),
		
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
	);

	$self->{activityLog} =
		{
			scope =>'offering_catalog_entry',
		key => "#field.catalog_id#",
			data => "Fee Schedule Entry '#param.entry_id# #field.entry_id#' <a href='/search/catalog/detail/#field.catalog_id#'>#field.catalog_id#</a>"
	};
	
	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_add => [
			['Add Another Misc Procedure Item', "/org/#session.org_id#/dlg-add-misc-procedure-item/#param.parent_entry_id#"],
			['Show Current Misc Procedure Items', '/search/miscprocedure/detail/#param.parent_entry_id#'],
			],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub customValidate
{
	my ($self, $page) = @_;
	my $code=$page->field('cpt_code');
	my $codeInfo = $STMTMGR_CPT_CODE_SEARCH->getRowAsHash($page, STMTMGRFLAG_NONE,'sel_cpt_code', $code );	
	$page->param("code_type",$CPT_CODE);		
	unless ($codeInfo)
	{		
		$codeInfo = $STMTMGR_HCPCS_CODE_SEARCH->getRowAsHash($page, STMTMGRFLAG_NONE,'sel_hcpcs_code',$code) ;
		$page->param("code_type",$HCPCS_CODE);			
	}	
	my $cpt_code = $self->getField('code_modifier1')->{fields}->[0];
	$cpt_code->invalidate($page,qq{Invalid CPT code '$code'})unless ($codeInfo);
	$page->param("cpt_name",$codeInfo->{name});	
	$page->param("cpt_desc",$codeInfo->{description});
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;	
	my $proc = $STMTMGR_CATALOG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE,'selMiscProcedureNameById',$page->param('parent_entry_id'));		
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;	
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	my $proc = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selMiscProcedureByChildId', $page->param('entry_id'))
		if ($page->param('entry_id'));	
	$page->field('name',$proc->{name} );
	$page->field('description',$proc->{description});
	$page->field('proc_code',$proc->{proc_code});
	$page->param("entry_id",$proc->{entry_id});
	$page->field("cpt_code",$proc->{code}); 			
	$page->field("modifier",$proc->{modifier});	
	$page->field("catalog_id",$proc->{catalog_id});
	$page->param('parent_entry_id',$proc->{parent_entry_id});
	
}

sub populateData_remove
{
	populateData_update(@_);
}



sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $orgId = $page->session('org_id');		
	my $entry_id = $page->param('entry_id')||undef;
	my $id = $page->field('catalog_id') || undef;
	my $parent_id = $page->param('parent_entry_id');
	$page->schemaAction
	(	
		'Offering_Catalog_Entry', $command,
		catalog_id=> $id,
		entry_type=>$page->param("code_type"),
		code=>$page->field("cpt_code"),
		modifier =>$page->field("modifier")||undef,
		entry_id =>$entry_id,
		parent_entry_id =>$parent_id,
		name=>$page->param("cpt_name"),
		description=>$page->param("cpt_desc"),
	)if $page->field("cpt_code");

	$page->param('_dialogreturnurl', "/search/miscprocedure/detail/$parent_id") if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags);
}

1;
