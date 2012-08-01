##############################################################################
package App::Dialog::Attribute::Directive;
##############################################################################
use strict;
use DBI::StatementManager;
use App::Statements::Person;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Attribute;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = ();

sub initialize
{
	my $self = shift;

	$self->addContent(
		new CGI::Dialog::Field(type => 'date', name => 'value_date', caption => 'Date',	options => FLDFLAG_REQUIRED, futureOnly => 0, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

	);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
}

sub populateData_remove
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $itemId = $page->param('item_id');

	my $directive = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
	$page->field('directive', $directive->{'item_name'});
	$page->field('value_date', $directive->{value_date});
}

use constant PANEDIALOG_DIRECTIVE => 'Dialog/Advance Directive';

1;
