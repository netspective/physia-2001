##############################################################################
package App::Dialog::MiscProcedureItem;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Person;
use App::Statements::Search::Code;

use Carp;

use CGI::Validator::Field;
use App::Dialog::Field::Catalog;
use Date::Manip;

use base 'CGI::Dialog';
use vars qw(%RESOURCE_MAP);
my $ACTIVE  = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;

%RESOURCE_MAP = (
	'misc-procedure-item' => { 
	_arl_add =>['trans_id'],
	_arl_modify => ['item_id'],},
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
		new CGI::Dialog::Field(type => 'hidden', name => 'next_id'),
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
					name => 'cpt_code1',										
					size => 10,
					findPopup => '/lookup/cpt',
					findPopupControlField => '_f_cpt_code1',
					options => FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(caption => 'Modifier',
					name => 'modifier1',
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
			['Add Another Misc Procedure Item', "/org/#session.org_id#/dlg-add-misc-procedure-item/#param.trans_id#"],
			['Show Current Misc Procedure Items', '/search/miscprocedure/detail/#param.trans_id#'],
			],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub customValidate
{
	my ($self, $page) = @_;
	my $code=$page->field('cpt_code1');
	my $codeInfo = $STMTMGR_CPT_CODE_SEARCH->getRowAsHash($page, STMTMGRFLAG_NONE,'sel_cpt_code', $code );	
	my $cpt_code1 = $self->getField('code_modifier1')->{fields}->[0];
	$cpt_code1->invalidate($page,qq{Invalid CPT code '$code'})unless ($codeInfo);
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;	
	my $proc = $STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE,'selMiscProcedureNameById',$page->param('trans_id'));		
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;	
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	my $proc = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selMiscProcedureById', $page->param('item_id'))
		if ($page->param('item_id'));	
	if ($proc)
	{
		$page->field('name',$proc->{name} );
		$page->field('description',$proc->{description});
		$page->field('proc_code',$proc->{proc_code});
		$page->field("cpt_code1",$proc->{cpt_code1}); 			
		$page->field("modifier1",$proc->{modifier1});
		$page->param("item_id1",$proc->{item_id1});	
		$page->param('trans_id',$proc->{trans_id});
		$page->field("next_id",$proc->{nextId});
	}
}

sub populateData_remove
{
	populateData_update(@_);
}



sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $orgId = $page->session('org_id');		
	my $proc_name = $page->field('name');
	my $proc_descr = $page->field('description');	
	my $proc_code = $page->field('proc_code');
	my $trans_id = $page->param('trans_id');
	my $status = $ACTIVE;
	
	$page->schemaAction(
	'Trans_Attribute', $command,
	parent_id=> $trans_id,
	item_type=>0,
	item_name=>App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT,
	value_type =>App::Universal::ATTRTYPE_CPT_CODE,
	value_text =>$page->field("cpt_code1"),		
	value_textB =>$page->field("modifier1"),
	item_id => $page->param("item_id1")||undef,
	_debug => 0
	) if $page->field("cpt_code1");

	$page->param('_dialogreturnurl', "/search/miscprocedure/detail/$trans_id") if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags);
}

1;
