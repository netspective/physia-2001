##############################################################################
package App::Dialog::Attribute::RefillRequest;
##############################################################################

use DBI::StatementManager;
use App::Statements::Person;
use App::Universal;
use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'refillrequest', heading => '$Command Refill Request');
	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		#new CGI::Dialog::Field(type => 'hidden', name => 'refill_item_id'),
		#new CGI::Dialog::Field(type => 'hidden', name => 'refill2_item_id'),
		new CGI::Dialog::Field(name => 'value_text', caption => 'Refill', type => 'memo', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'value_date', caption => 'Date', type => 'date'),
		new App::Dialog::Field::Person::ID(caption => 'Physician', name => 'value_textb', types => ['Physician'], options => FLDFLAG_REQUIRED, hints => 'Physician approving the refill.'),
		new App::Dialog::Field::Person::ID(caption => 'Refill Processor', name => 'filler', options => FLDFLAG_REQUIRED, hints => 'Person processing the refill.'),
		#new CGI::Dialog::Field(name => 'value_int', type => 'select', selOptions => "Pending:0;Filled:1", caption => 'Status'),
		new CGI::Dialog::Field(type => 'select',
				style => 'radio',
				selOptions => 'Pending;Filled',
				caption => 'Status',
				preHtml => "<B><FONT COLOR=DARKRED>",
				postHtml => "</FONT></B>",
				name => 'status',
				defaultValue => 'Pending'),
		);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Refill Request for <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $itemId = $page->param('item_id');
	my $refillData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

	my $refillStatus = $refillData->{value_intb}  == 1 ? 'Filled' : 'Pending';

	#$page->field('refill_item_id', $refillData->{'item_id'});
	$page->field('value_text', $refillData->{value_text});
	$page->field('value_date', $refillData->{value_date});
	$page->field('status', $refillStatus);
	$page->field('value_textb', $refillData->{value_textb});

	if($refillData->{value_int} eq '')
	{
		my $refillValueIntData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByValueInt', $itemId);
		$page->field('filler', $refillValueIntData->{parent_id});
	}
	else
	{
		$page->field('filler', $refillData->{parent_id});
	}
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	my $refillStatus = $page->field('status') eq 'Pending' ? 0 : 1;


	if($command eq 'add')
	{
		my $item_id = $page->schemaAction(
			'Person_Attribute', $command,
			item_id => $page->param('item_id') || undef,
			parent_id => $page->param('person_id') || undef,
			item_name =>'Refill Request',
			value_type => 0,
			value_text => $page->field('value_text') || undef,
			value_textB => $page->field('value_textb') || undef,
			value_intB => $refillStatus,
			value_date => $page->field('value_date') || undef,
			_debug => 0
		);

		my $refillInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $item_id);
		$page->schemaAction(
			'Person_Attribute', $command,
			item_id => $page->param('item_id') || undef,
			parent_id => $page->field('filler') || undef,
			item_name =>'Refill Request',
			value_type => 0,
			value_text => $page->field('value_text') || undef,
			value_textB => $page->field('value_textb') || undef,
			value_int => $refillInfo->{item_id},
			value_intB => $refillStatus,
			value_date => $page->field('value_date') || undef,
			_debug => 0
		);
	}
	elsif($command eq 'update' || $command eq 'remove')
	{
		my $ItemId = $page->param('item_id');
		my $refillDataInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $ItemId);
		if($refillDataInfo->{value_int} eq '')
		{
			my $item_id = $page->schemaAction(
				'Person_Attribute', $command,
				item_id => $page->param('item_id') || undef,
				parent_id => $page->param('person_id') || undef,
				item_name =>'Refill Request',
				value_type => 0,
				value_text => $page->field('value_text') || undef,
				value_textB => $page->field('value_textb') || undef,
				value_intB => $refillStatus,
				value_date => $page->field('value_date') || undef,
				_debug => 0
			);
			my $processorData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByValueInt', $ItemId);
			$page->schemaAction(
				'Person_Attribute', $command,
				item_id => $processorData->{'item_id'} || undef,
				item_name =>'Refill Request',
				value_type => 0,
				value_text => $page->field('value_text') || undef,
				value_textB => $page->field('value_textb') || undef,
				value_intB => $refillStatus,
				value_date => $page->field('value_date') || undef,
				_debug => 0
			);

		}
		elsif($refillDataInfo->{value_int} ne '')
		{
			$page->schemaAction(
				'Person_Attribute', $command,
				item_id => $page->param('item_id') || undef,
				parent_id => $page->field('filler') || undef,
				item_name =>'Refill Request',
				value_type => 0,
				value_text => $page->field('value_text') || undef,
				value_textB => $page->field('value_textb') || undef,
				value_intB => $refillStatus,
				value_date => $page->field('value_date') || undef,
				_debug => 0
			);
			my $parentItemId = $refillDataInfo->{value_int};
			my $personData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $parentItemId);

			$page->schemaAction(
				'Person_Attribute', $command,
				item_id => $personData->{item_id} || undef,
				item_name =>'Refill Request',
				value_type => 0,
				value_text => $page->field('value_text') || undef,
				value_textB => $page->field('value_textb') || undef,
				value_intB => $refillStatus,
				value_date => $page->field('value_date') || undef,
				_debug => 0
			);

		}

	}


	$self->handlePostExecute($page, $command, $flags);
}

1;
