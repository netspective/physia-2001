##############################################################################
package App::Dialog::PostCapPayment;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Invoice;
use App::Dialog::Field::Person;
use App::Dialog::Field::BatchDateID;

use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'postcappayment' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'postcappayment', heading => '$Command Monthly Cap Payment');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::BatchDateID(caption => 'Batch ID Date', name => 'batch_fields',invoiceIdFieldName=>'sel_invoice_id'),
		new App::Dialog::Field::Person::ID(caption => 'Physician ID', name => 'provider_id', types => ['Physician']),
		new App::Dialog::Field::Insurance::Product(
			caption => 'Insurance Product',
			name => 'product_name',
			findPopup => '/lookup/insproduct/insorgid',
			),
		new App::Dialog::Field::Insurance::Plan(
			caption => 'Insurance Plan',
			name => 'plan_name',
			findPopup => '/lookup/insplan/product/itemValue',
			findPopupControlField => '_f_product_name',
			),
		new CGI::Dialog::Field(caption => 'Month', 
			name => 'month',
			type => 'enum',
			enum => 'Month',
			options => FLDFLAG_REQUIRED,
			),


		new CGI::Dialog::MultiField(caption => 'Check Amount/Number', name => 'check_fields',
			fields => [
					new CGI::Dialog::Field(caption => 'Check Amount', 
						name => 'check_amount',
						type => 'currency',
						options => FLDFLAG_REQUIRED,
					),
					new CGI::Dialog::Field(
						caption => 'Check Number/Pay Reference',
						name => 'check_number'),
					]),
		);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

#sub populateData
#{
#	my ($self, $page, $command, $activeExecMode, $flags) = @_;
#
#	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
#}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $sessOrgIntID = $page->session('org_internal_id');
	my $sessUser = $page->session('user_id');
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $entityTypePerson = App::Universal::ENTITYTYPE_PERSON;
	my $entityTypeOrg = App::Universal::ENTITYTYPE_ORG;
	my $timeStamp = $page->getTimeStamp();

	my $month = $page->field('month');
	my $transId = $page->schemaAction(
		'Transaction', $command,
		trans_type => App::Universal::TRANSTYPEACTION_PAYMENT,
		trans_status => App::Universal::TRANSSTATUS_FILLED,
		provider_id => $page->field('provider_id') || undef,
		#trans_owner_type => defined $entityTypePerson ? $entityTypePerson : undef,
		#trans_owner_id => $personId || undef,
		processor_type => defined $entityTypePerson ? $entityTypePerson : undef,
		processor_id => $sessUser || undef,
		receiver_type => defined $entityTypeOrg ? $entityTypeOrg : undef,
		receiver_id => $sessOrgIntID || undef,
		unit_cost => $page->field('check_amount') || undef,
		auth_ref => $page->field('check_number') || undef,
		data_text_a => $page->field('product_name') || undef,
		data_text_b => $page->field('plan_name') || undef,
		data_num_a => defined $month ? $month : undef,
		trans_begin_stamp => $timeStamp || undef,
		_debug => 0
	);

	## Add batch attribute
	$page->schemaAction(
		'Trans_Attribute', 'add',
		parent_id => $transId,
		item_name => 'Monthly Cap/Payment/Batch ID',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $page->field('batch_id') || undef,
		value_date => $page->field('batch_date') || undef,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);

}

1;