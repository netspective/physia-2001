##############################################################################
package App::Dialog::Report::Org::General::Accounting::AppointmentCharges;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;

use App::Statements::Component::Invoice;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-appointment-charges', heading => 'Appointment Charges');

	$self->addContent(
			new CGI::Dialog::Field::Duration(
				name => 'daily',
				caption => 'Start/End Appointment Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				invisibleWhen => CGI::Dialog::DLGFLAG_ADD
				),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('daily_begin_date', $startDate);
	$page->field('daily_end_date', $startDate);
	$page->field('org_id', $page->session('org_id'));
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $reportBeginDate = $page->field('daily_begin_date');
	my $reportEndDate = $page->field('daily_end_date');

	return $STMTMGR_COMPONENT_INVOICE->createHtml($page, 0, 'invoice.appointmentCharges', 
		[$reportBeginDate, $reportEndDate, $page->session('org_internal_id'), $page->session('GMT_DAYOFFSET')]);

}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;