##############################################################################
package App::Dialog::InvoiceWorklist::Collection::CloseCollection;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Worklist::WorklistCollection;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;

%RESOURCE_MAP=(
	'close-collection' => {
		heading => 'Close Invoice Collection',
		_arl => ['person_id','invoice_id'],
		},
	);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'close-collection', heading => 'Close Invoice Collection');


	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new App::Dialog::Field::Person::ID(types => ['Patient'],name => 'person_id', caption => 'Person ID', type => 'text', options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'invoice_id', caption => 'Invoice', type => 'text', options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(type => 'select',
							style => 'radio',
							selOptions => 'Retain Notes:0;Delete Notes:1',
							caption => 'notes: ',
							preHtml => "<B><FONT COLOR=DARKRED>",
							postHtml => "</FONT></B>",
							name => 'notes',
				defaultValue => '0',),

		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'Invoice_Worklist',
			key => "#session.person_id#",		
			data => "Invoice <a href='/invoice/#param.invoice_id#/summary/'>#param.invoice_id#</a> closed on collector <a href='/person/#session.person_id#/profile'>#session.person_id#</a> worklist"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('person_id',$page->param('person_id'));
	$page->field('invoice_id',$page->param('invoice_id'));
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	#$command = 'update';
	my $closed_by = $page->session('user_id');
	my $del_notes  = $page->field('notes');
	my $close_msg = "Account Closed by $closed_by";
	my $first =1;
	#
	my $dataInvoice = $STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'closeInvoiceCollection',$page->param('invoice_id')||undef,
	$page->session('person_id')||undef,$page->session('org_internal_id')||undef);
	#Mark notes records inactive for current collector
	$STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'delAccountNotesById',$page->session('user_id'),$page->param('person_id')) if $page->field('notes');	
	$self->handlePostExecute($page, $command, $flags );
	return "\u$command completed.";
}


use constant ALERT_DIALOG => 'Dialog/Pane/Alert';


1;
