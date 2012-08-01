##############################################################################
package App::Dialog::ContractItem;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Contract;
use App::Statements::Person;
use App::Statements::Search::Code;
use App::Statements::Search::MiscProcedure;
use App::Statements::IntelliCode;

use Carp;

use CGI::Validator::Field;
use App::Dialog::Field::Catalog;
use Date::Manip;

use base 'CGI::Dialog';
use vars qw(%RESOURCE_MAP);


%RESOURCE_MAP = (
	'contract-item' => {
		_arl_add => ['internal_contract_id','entry_id'],
		_arl_modify => ['price_id']
	},
);

sub new
{
	my $self = CGI::Dialog::new(@_);
	my $command;
	($self, $command) = CGI::Dialog::new(@_, id => 'catalogitem', heading => '$Command Contract Item');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
		
		new CGI::Dialog::Field(caption => 'Contract ID',
			name => 'contract_id',
			type => 'text',
			options => FLDFLAG_READONLY,		
		),
		new CGI::Dialog::MultiField(
			name => 'code_modifier',
			options => FLDFLAG_READONLY,
			fields => [
				new CGI::Dialog::Field(caption => 'Code',
					name => 'code',
					options => FLDFLAG_READONLY,
					size => 10,
				),
				new CGI::Dialog::Field(caption => 'Modifier',
					name => 'modifier',
					options => FLDFLAG_READONLY,
					size => 10,
				),
			]
		),	
		new CGI::Dialog::Field(caption => 'Expected Amount',
			name => 'expected_cost',
			type => 'currency',
			#options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(caption => 'Allowed Amount',
			name => 'allowed_cost',
			type => 'currency',
			#options => FLDFLAG_REQUIRED,
		),		
		new CGI::Dialog::Field(type => 'hidden', name => 'add_mode'),
	);

	$self->{activityLog} =
		{
			scope =>'offering_catalog_entry',
			key => "#field.contract_id#",
			data => "Contract Catalog #field.contract_id#  code  '#field.code#  Modifier : #field.modifier#'</a>"
	};
	
	$self->addFooter(new CGI::Dialog::Buttons(
	#	nextActions_add => [
	#		['Add Next Contract Price', "/org/#session.org_id#/dlg-add-catalog-item/%field.catalog_id%", 1],
	#		['Show Current Contract Catalog Items', '/org/%session.org_id%/catalog?catalog=contract_detail&contract_detail=%param.internal_contract_id%'],
	#		],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	my $internalContractID=$page->param('internal_contract_id');
	my $entryId = $page->param('entry_id');
	my $catalog = $STMTMGR_CONTRACT->getRowAsHash($page,STMTMGRFLAG_NONE,'selContractPriceByEntryContractID',$internalContractID,$entryId);
	$page->field('contract_id',$catalog->{contract_id});
	$page->field('code',$catalog->{code});
	$page->field('modifier',$catalog->{modifier});
	$page->field('add_mode',1);
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	my $priceID=$page->param('price_id');
	my $catalog = $STMTMGR_CONTRACT->getRowAsHash($page,STMTMGRFLAG_NONE,'selContractPriceByPriceID',$priceID);
	if($catalog)
	{		
		$page->field('contract_id',$catalog->{contract_id});
		$page->field('code',$catalog->{code});
		$page->field('modifier',$catalog->{modifier});
		$page->field('expected_cost',$catalog->{expected_cost});
		$page->field('allowed_cost',$catalog->{allowed_cost});	
		$page->param('entry_id',$catalog->{entry_id});
		$page->param('internal_contract_id',$catalog->{internal_contract_id});
	}
	else
	{
		$page->addError("Price ID $$priceID does not exist.");
	}
}

sub populateData_remove
{
	populateData_update(@_);
}


sub customValidate
{
	my ($self, $page) = @_;
	

	#Make Sure we are not adding another Price to the same contract entry
	my $internalContractID=$page->param('internal_contract_id');
	my $entryId = $page->param('entry_id');	
	my $recExist = $STMTMGR_CONTRACT->getRowAsHash($page, STMTMGRFLAG_NONE, 'selContractPriceByPrEntryContractID',$internalContractID,$entryId);

	my $field = $self->getField('code_modifier')->{fields}->[0];
	my $contractID = $page->field('contract_id');
	my $code = $page->field('code');
	$field->invalidate($page, qq{Price Already exists in Contract '$contractID' for procedure '$code' use update instead of add}) if ($recExist && $page->field('add_mode'));
	
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $contract_id = $page->schemaAction(
		'Offering_CatEntry_Price', $command,
		price_id=>$page->param('price_id')||undef,
		entry_id=>$page->param('entry_id')|undef,
		internal_contract_id =>$page->param('internal_contract_id')||undef,
		expected_cost => $page->field('expected_cost')|undef,
		allowed_cost =>  $page->field('allowed_cost')|undef,
		) if $page->param('internal_contract_id') && $page->param('entry_id');

	$page->param('_dialogreturnurl', '/org/%session.org_id%/catalog?catalog=contract_detail&contract_detail=%param.internal_contract_id%');# if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags);
}

1;
