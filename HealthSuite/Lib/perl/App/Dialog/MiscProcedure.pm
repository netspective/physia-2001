########################### ###################################################
package App::Dialog::MiscProcedure;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Person;
use App::Statements::Search::Code;
use App::Universal;

use Carp;

use CGI::Validator::Field;
use Date::Manip;

use base 'CGI::Dialog';
use vars qw(%RESOURCE_MAP);
my $ACTIVE  = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;
my $lines=4;

%RESOURCE_MAP = (
	'misc-procedure' => { 
	_arl_modify => ['trans_id']},
);

sub new
{
	my $self = CGI::Dialog::new(@_);
	my $command;
	($self, $command) = CGI::Dialog::new(@_, id => 'misc-procedure', heading => '$Command Misc Procedure Code');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'trans_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
		new CGI::Dialog::Field(caption => 'Procedure Code',
			name => 'proc_code',
			type => 'text',
			size =>10,			
			options => FLDFLAG_REQUIRED,			
		),
		
		new CGI::Dialog::Field(caption => 'Procedure Name',
					name => 'name',
					size => 25,			
				),
				new CGI::Dialog::Field(caption => 'Procedure Description',
					name => 'description',			
					size => 50,
				),
		
		new CGI::Dialog::MultiField(
			name => 'code_modifier1',
			fields => [
				new CGI::Dialog::Field(caption => 'CPT',
					name => 'cpt_code1',										
					size => 10,
					findPopup => '/lookup/cpt',
					findPopupControlField => '_f_cpt_code1',
				),
				new CGI::Dialog::Field(caption => 'Modifier',
					name => 'modifier1',
					size => 10,					
				),
			]
		),
		new CGI::Dialog::MultiField(
					name => 'code_modifier2',
					fields => [
						new CGI::Dialog::Field(caption => 'CPT',
							name => 'cpt_code2',												
							size => 10,
							findPopup => '/lookup/cpt',
							findPopupControlField => '_f_cpt_code2',
						),
						new CGI::Dialog::Field(caption => 'Modifier',
							name => 'modifier2',
							size => 10,					
						),
					]
		),
		
		new CGI::Dialog::MultiField(
					name => 'code_modifier3',
					fields => [
						new CGI::Dialog::Field(caption => 'CPT',
							name => 'cpt_code3',												
							size => 10,
							findPopup => '/lookup/cpt',
							findPopupControlField => '_f_cpt_code2',
						),
						new CGI::Dialog::Field(caption => 'Modifier',
							name => 'modifier3',
							size => 10,					
						),
					]
		),

		new CGI::Dialog::MultiField(
					name => 'code_modifier4',
					fields => [
						new CGI::Dialog::Field(caption => 'CPT',
							name => 'cpt_code4',												
							size => 10,
							findPopup => '/lookup/cpt',
							findPopupControlField => '_f_code2',
						),
						new CGI::Dialog::Field(caption => 'Modifier',
							name => 'modifier4',
							size => 10,					
						),
					]
		),
		
		
		
		
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
	);

	$self->{activityLog} =
		{
			scope =>'transaction',
		key => "#field.trans_id#",
			data => "Misc Procedure Code '#param.proc_code# #field.proc_code#' <a href='/search/miscprocedure/detail/#field.trans_id#'>#field.proc_code#</a>"
	};
	
	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_add => [
			['Add Another Misc Procedure Code', "/org/#session.org_id#/dlg-add-misc-procedure"],
			['Show Misc Procedure Codes', '/search/miscprocedure/code/%field.proc_code%'],
			],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}


sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('add_mode', 1);	
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	$page->field('trans_id',$page->param('trans_id'));
	
	#Get the first 4 created CPT codes for a Procedure based on item_id order
	my $proc = $STMTMGR_TRANSACTION->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'sel4MiscProcedureById', $page->param('trans_id'))
		if ($page->param('trans_id'));	
	my $loop=1;
	foreach (@{$proc})
	{
		$page->field('name',$_->{name} );
		$page->field('description',$_->{description});
		$page->field('proc_code',$_->{proc_code});
		$page->field("cpt_code$loop",$_->{"cpt_code"}); 			
		$page->field("modifier$loop",$_->{"modifier"});
		$page->param("item_id$loop",$_->{"item_id"});
		$loop++;
	}
}

sub populateData_remove
{
	populateData_update(@_);
}


sub customValidate
{
	my ($self, $page) = @_;	
	my $code;
	my $codeInfo;
	my $cpt_code1;
	
	#Validate all CPT_CODES
	for (my $loop=1;$loop<=$lines;$loop++)
	{
		$code=$page->field("cpt_code$loop");		
		next if $code eq '';
		$codeInfo = $STMTMGR_CPT_CODE_SEARCH->getRowAsHash($page, STMTMGRFLAG_NONE,'sel_cpt_code', $code );	
		$cpt_code1 = $self->getField("code_modifier$loop")->{fields}->[0];
		$cpt_code1->invalidate($page,qq{Invalid CPT code '$code'}) unless ($codeInfo);	
	}	
	
	#check to make sure the new Misc Code is unique for this Org but only if we are adding a new Procedure Code
	if($page->field('add_mode'))
	{
		my $proc_code = $page->field('proc_code');
		my $proc_field = $self->getField('proc_code');
		$proc_field->invalidate($page,qq{Misc Procedure Code '$proc_code' already exists.})if $STMTMGR_TRANSACTION->recordExists($page,STMTMGRFLAG_NONE,'selMiscProcedureByCode',$proc_code);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;	
	my $orgId = $page->session('org_internal_id');		
	my $proc_name = $page->field('name');
	my $proc_descr = $page->field('description');	
	my $proc_code = $page->field('proc_code');
	my $trans_id = $page->param('trans_id');
	my $status = $ACTIVE;
	my $number=0;
	
	# If command is remove change to update so we do not delete transaction and set flag to INACTIVE
	if ($command eq 'remove')
	{
		$command = 'update';
		$status = $INACTIVE
	}
	
	my $id = $page->schemaAction(	
		'Transaction', $command,
		trans_id =>$trans_id,
		trans_owner_id =>$orgId,
		trans_owner_type=>App::Universal::ENTITYTYPE_ORG,
		trans_type=> App::Universal::TRANSTYPEPROC_REGULAR,
		caption=>$proc_name,
		detail =>$proc_descr,	
		trans_status =>$status,
		code =>$proc_code,
		trans_subtype =>App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT,
		trans_id => $trans_id || undef,
		_debug => 0,
		);
	$id = $trans_id if ($command eq 'update');
		
	$page->field('trans_id',$id);
	
	#Loop through all fields add save cpt_code as attributes of the main transaction
	for (my $loop=1;$loop<=$lines;$loop++)
	{
	
		if ($page->field("cpt_code$loop"))
		{	
			#Even if the dialog is and update the user can add new CPT_CODE to a Procedure so determine
			#if current CPT_CODE has an item id
			$command =  $page->param("item_id$loop") ?  'update' : 'add';
			$page->schemaAction(	
			'Trans_Attribute', $command,
			parent_id=> $id,
			item_type=>0,
			item_name=>App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT,
			value_type =>App::Universal::ATTRTYPE_CPT_CODE,
			value_text =>$page->field("cpt_code$loop"),		
			value_textB =>$page->field("modifier$loop"),
			item_id => $page->param("item_id$loop")||undef,
			_debug => 0,
			) 
		}
		elsif($page->param("item_id$loop"))		
		{
			#user removed a CPT_CODE so delete the CPT_CODE
			$page->schemaAction(	
					'Trans_Attribute', 'remove',
					parent_id=> $id,
					item_type=>0,
					item_name=>App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT,
					value_type =>App::Universal::ATTRTYPE_CPT_CODE,
					value_text =>$page->field("cpt_code$loop"),		
					value_textB =>$page->field("modifier$loop"),
					item_id => $page->param("item_id$loop")||undef,
					_debug => 0,
			) 
		}
	}
	
	$page->param('_dialogreturnurl', '/search/miscprocedure/code/%field.proc_code%') if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags);
}

1;
