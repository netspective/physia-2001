##############################################################################
package App::Dialog::AutoForwardMsg;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Statements::Org;
use App::Statements::Person;
use App::Dialog::Field::Person;

use DBI::StatementManager;

use App::Universal;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'auto-forward-msg' => {
		heading => '$Command Auto Forward',
		_arl => ['person_id'],
		_modes => ['set'],
	},
);

sub new
{
 	my ($self, $command) = CGI::Dialog::new(@_, heading => '$Command Auto Forward');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
	
		new CGI::Dialog::Field(type => 'hidden', name => 'phone_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'internal_id'),		
		new CGI::Dialog::Field(type => 'hidden', name => 'prescription_id'),				
	
		new CGI::Dialog::MultiField(caption => 'Phone Message', name => 'phone_fields',
			fields => [	
		new App::Dialog::Field::Person::ID(caption => 'Phone Message', 
						name => 'phone_msg_id', 
						options => FLDFLAG_REQUIRED, 
						),	
		new CGI::Dialog::Field(type => 'select',
						style => 'radio',
						selOptions => 'Active:1;Inactive:0',
						caption => 'Auto Forward',
						preHtml => "<B><FONT COLOR=DARKRED>",
						postHtml => "</FONT></B>",
						name => 'phone_status',options=>FLDFLAG_REQUIRED,
			defaultValue => '0',),						
				]),
	new CGI::Dialog::MultiField(caption => 'Internal Message', name => 'internal_fields',
			fields => [					
		new App::Dialog::Field::Person::ID(caption => 'Internal Message', 
						name => 'internal_msg_id', 
						options => FLDFLAG_REQUIRED, 
						),	
		new CGI::Dialog::Field(type => 'select',
						style => 'radio',
						selOptions => 'Active:1;Inactive:0',
						caption => 'Auto Forward',
						preHtml => "<B><FONT COLOR=DARKRED>",
						postHtml => "</FONT></B>",
						name => 'internal_status',options=>FLDFLAG_REQUIRED,
			defaultValue => '0',),						
				]),
	new CGI::Dialog::MultiField(caption => 'Prescription Message', name => 'prescription_fields',
			fields => [							
		new App::Dialog::Field::Person::ID(caption => 'Prescription Message', 
						name => 'prescription_msg_id', 
						options => FLDFLAG_REQUIRED, 
						),		
			
		new CGI::Dialog::Field(type => 'select',
						style => 'radio',
						selOptions => 'Active:1;Inactive:0',
						caption => 'Auto Forward',
						preHtml => "<B><FONT COLOR=DARKRED>",
						postHtml => "</FONT></B>",
						name => 'prescription_status',options=>FLDFLAG_REQUIRED,
			defaultValue => '0',),		
			]),			
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Auto Foward Message <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	my $phoneData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent',
	$page->param('person_id')||undef,'AUTO_FORWARD_PHONE_MSG',App::Universal::ATTRTYPE_TEXT);
	if($phoneData)
	{
		$page->field('phone_id',$phoneData->{item_id});
		$page->field('phone_status',$phoneData->{value_int});
		$page->field('phone_msg_id',$phoneData->{value_text});
	};

	my $internalData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent',
	$page->param('person_id')||undef,'AUTO_FORWARD_INTERNAL_MSG',App::Universal::ATTRTYPE_TEXT);
	if($internalData)
	{
		$page->field('internal_id',$internalData->{item_id});
		$page->field('internal_status',$internalData->{value_int});
		$page->field('internal_msg_id',$internalData->{value_text});
	};

	my $prescriptionData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent',
	$page->param('person_id')||undef,'AUTO_FORWARD_PRESCRIPTION_MSG',App::Universal::ATTRTYPE_TEXT);
	if($prescriptionData)
	{
		$page->field('prescription_id',$prescriptionData->{item_id});
		$page->field('prescription_status',$prescriptionData->{value_int});
		$page->field('prescription_msg_id',$prescriptionData->{value_text});
	};	
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $phone_id = $page->field('phone_id');
	my $phone_status=$page->field('phone_status');	
	my $phone_msg_id = $page->field('phone_msg_id');
	my $prescription_id = $page->field('prescription_id');
	my $prescription_msg_id = $page->field('prescription_msg_id');
	my $prescription_status=$page->field('prescription_status');	
	my $internal_id = $page->field('internal_id');
	my $internal_msg_id = $page->field('internal_msg_id');	
	my $internal_status=$page->field('internal_status');

	my $person_id = $page->param('person_id');	
	my $item_type=0;
	$command =  $phone_id ? 'update' : 'add' ;
	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id=> $person_id,
		item_id=>$phone_id,
		item_type=>$item_type,
		value_type=>App::Universal::ATTRTYPE_TEXT,
		item_name=>'AUTO_FORWARD_PHONE_MSG',
		value_text=>$phone_msg_id,
		value_int=>$phone_status
		);
	$command =  $internal_id ? 'update' : 'add' ;		
	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id=> $person_id,
		item_id=>$internal_id,
		item_type=>$item_type,
		value_type=>App::Universal::ATTRTYPE_TEXT,
		item_name=>'AUTO_FORWARD_INTERNAL_MSG',
		value_text=>$internal_msg_id,
		value_int=>$internal_status
		);
	$command =  $prescription_id ? 'update' : 'add' ;				
	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id=> $person_id,
		item_id=>$prescription_id,
		item_type=>$item_type,
		value_type=>App::Universal::ATTRTYPE_TEXT,
		item_name=>'AUTO_FORWARD_PRESCRIPTION_MSG',
		value_text=>$prescription_msg_id,
		value_int=>$prescription_status
		);

		
	$self->handlePostExecute($page, $command, $flags);
	
	return "\u$command completed.";
}



1;

