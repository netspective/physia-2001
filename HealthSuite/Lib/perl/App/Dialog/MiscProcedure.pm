########################### ###################################################
package App::Dialog::MiscProcedure;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Person;
use App::Statements::Catalog;
use App::Statements::Search::Code;
use App::Universal;

use Carp;

use CGI::Validator::Field;
use Date::Manip;

use base 'CGI::Dialog';
use vars qw(%RESOURCE_MAP);
my $CPT_CODE =App::Universal::CATALOGENTRYTYPE_CPT;
my $HCPCS_CODE = App::Universal::CATALOGENTRYTYPE_HCPCS;
my $MISC_CODE = App::Universal::CATALOGENTRYTYPE_MISC_PROCEDURE;
my $CATALOG_TYPE = 2;
my $lines=6;

%RESOURCE_MAP = (
	'misc-procedure' => {
	_arl_modify => ['entry_id']},
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
		new CGI::Dialog::Field(type => 'hidden', name => 'entry_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
		new CGI::Dialog::Field(caption => 'Procedure Code',
			name => 'proc_code',
			type => 'text',
			size =>10,
			options => FLDFLAG_REQUIRED | FLDFLAG_UPPERCASE,
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
							findPopupControlField => '_f_cpt_code3',
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
							findPopupControlField => '_f_code4',
						),
						new CGI::Dialog::Field(caption => 'Modifier',
							name => 'modifier4',
							size => 10,
						),
					]
		),

		new CGI::Dialog::MultiField(
					name => 'code_modifier5',
					fields => [
						new CGI::Dialog::Field(caption => 'CPT',
							name => 'cpt_code5',
							size => 10,
							findPopup => '/lookup/cpt',
							findPopupControlField => '_f_code5',
						),
						new CGI::Dialog::Field(caption => 'Modifier',
							name => 'modifier5',
							size => 10,
						),
					]
		),

		new CGI::Dialog::MultiField(
					name => 'code_modifier6',
					fields => [
						new CGI::Dialog::Field(caption => 'CPT',
							name => 'cpt_code6',
							size => 10,
							findPopup => '/lookup/cpt',
							findPopupControlField => '_f_code6',
						),
						new CGI::Dialog::Field(caption => 'Modifier',
							name => 'modifier6',
							size => 10,
						),
					]
		),


		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
	);

	$self->{activityLog} =
		{
			scope =>'transaction',
		key => "#field.entry_id#",
			data => "Misc Procedure Code '#param.proc_code# #field.proc_code#' <a href='/search/miscprocedure/detail/#field.entry_id#'>#field.proc_code#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_add => [
			['Add Another Misc Procedure Code', "/org/#session.org_id#/dlg-add-misc-procedure"],
			['Show Misc Procedure Codes', '/search/miscprocedure/code/*'],
			['Go to Work List', "/worklist"],
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
	$page->field('entry_id',$page->param('entry_id'));

	#Get the first 6 created CPT codes for a Procedure based on entry_id order
	my $proc = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selMiscProcedureById', $page->param('entry_id'))
		if ($page->param('entry_id'));
	my $loop=1;
	foreach (@{$proc})
	{
		if($_->{code_level} eq '1')
		{
			$page->field('name',$_->{name} );
			$page->field('description',$_->{description});
			$page->field('proc_code',$_->{code});
			$page->param("entry_id",$_->{entry_id});
		}
		else
		{
			$page->field("cpt_code$loop",$_->{code});
			$page->field("modifier$loop",$_->{modifier});
			$page->param("entry_id$loop",$_->{entry_id});
			$page->param("code_type$loop",$_->{entry_type});
			$page->param("parent_entry_id$loop",$_->{parent_entry_id});
			$loop++;
		};

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
		$page->param("code_type$loop",$CPT_CODE);
		$codeInfo = $STMTMGR_CPT_CODE_SEARCH->getRowAsHash($page, STMTMGRFLAG_NONE,'sel_cpt_code', $code );
		unless ($codeInfo)
		{
			$codeInfo = $STMTMGR_HCPCS_CODE_SEARCH->getRowAsHash($page, STMTMGRFLAG_NONE,'sel_hcpcs_code',$code) ;
			$page->param("code_type$loop",$HCPCS_CODE);
		}
		$cpt_code1 = $self->getField("code_modifier$loop")->{fields}->[0];
		$cpt_code1->invalidate($page,qq{Invalid CPT code '$code'}) unless ($codeInfo);
		$page->param("cpt_name$loop",$codeInfo->{name});
		$page->param("cpt_desc$loop",$codeInfo->{description});
	}

	#check to make sure the new Misc Code is unique for this Org but only if we are adding a new Procedure Code
	if($page->field('add_mode'))
	{
		my $proc_code = $page->field('proc_code');
		my $proc_field = $self->getField('proc_code');
		$proc_field->invalidate($page,qq{Misc Procedure Code '$proc_code' already exists.})if $STMTMGR_CATALOG->recordExists($page,STMTMGRFLAG_NONE,'selMiscProcedureByCode',$proc_code,$page->session('org_internal_id'));
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $orgId = $page->session('org_internal_id');
	my $proc_name = $page->field('name');
	my $proc_descr = $page->field('description');
	my $proc_code = $page->field('proc_code');
	my $number=0;
	my $orgInternalId = $page->session('org_internal_id') ||undef;
	my $id;
	my $procId;


	#Check if Main 'Misc Procedure Code' Record exists in the Offering_Catalog for this Org.  If not create one
	$id = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_NONE,'selMiscProcedureInternalID',$orgInternalId);
	$page->beginUnitWork();
	$id = $page->schemaAction
	(
		'Offering_Catalog', 'add',
		org_internal_id =>$orgInternalId,
		catalog_type =>$CATALOG_TYPE,
		caption =>App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT,
		description =>App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT,
		catalog_id =>App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT,
	)unless $id;

	#Misc Procedure Entry Code (Parent)
	$procId = $page->schemaAction
	(
		'Offering_Catalog_Entry',$command,
		catalog_id =>$id,
		entry_type =>$MISC_CODE,
		code => $proc_code,
		name => $proc_name,
		description => $proc_descr,
		entry_id => $page->param("entry_id")||undef,
	);

	my $parent_id = $page->param("entry_id") || $procId;
	$page->field('entry_id',$id);

	#Loop through all fields add save cpt/hcpcs codes as childern of Parent Code
	for (my $loop=1;$loop<=$lines;$loop++)
	{

		if ($page->field("cpt_code$loop"))
		{
			#Even if the dialog is an update the user can add new CPT_CODE to a Procedure so determine
			#if current CPT_CODE has an entry_id
			$command =  $page->param("entry_id$loop") ?  'update' : 'add';
			$page->schemaAction
			(
				'Offering_Catalog_Entry', $command,
				catalog_id=> $id,
				entry_type=>$page->param("code_type$loop"),
				code=>$page->field("cpt_code$loop"),
				modifier =>$page->field("modifier$loop")||undef,
				entry_id =>$page->param("entry_id$loop")||undef,
				parent_entry_id =>$parent_id||undef,
				name=>$page->param("cpt_name$loop"),
				description=>$page->param("cpt_desc$loop"),
			)

		}
		elsif($page->param("entry_id$loop"))
		{
			#user removed a CPT_CODE so delete the CPT_CODE
			$page->schemaAction
			(
					'Offering_Catalog_Entry', 'remove',
					catalog_id=> $id,
					entry_id => $page->param("entry_id$loop")||undef,
			)
		}
	}
	$page->endUnitWork();
	$page->param('_dialogreturnurl', '/search/miscprocedure/code/*') if $command eq 'remove';
	$page->param('_dialogreturnurl', '/search/miscprocedure/code/%field.proc_code%') if $command ne 'add' && $command ne 'remove';
	$self->handlePostExecute($page, $command, $flags);
}

1;
