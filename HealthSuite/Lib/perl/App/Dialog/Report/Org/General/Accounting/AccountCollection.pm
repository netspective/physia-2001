##############################################################################
package App::Dialog::Report::Org::General::Accounting::AccountCollection;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use Data::Publish;
use App::Statements::Report::AccountCollection;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-account-collection', heading => 'Account Collection');

	$self->addContent(
		new CGI::Dialog::Field::Duration(
			name => 'report',
			caption => 'Start/End Report Date',
			begin_caption => 'Report Begin Date',
			end_caption => 'Report End Date',
		),
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('report_begin_date', $startDate);
	$page->field('report_end_date', $startDate);
}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub prepare_detail_notes
{
	my ($self, $page) = @_;
	my $person_id = $page->param('person_id');

	$page->addContent($STMTMGR_REPORT_ACCOUNT_COLLECTION->createHtml($page, STMTMGRFLAG_NONE, 'selCollectorsNotes',
			[$person_id]));
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $orgInternalID = $page->session('org_internal_id');
	my @data = ();

	my $pub = $PUBLISH_DEFN;

	my $rows = $STMTMGR_REPORT_ACCOUNT_COLLECTION->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selCollectors', $page->field('report_begin_date'), $page->field('report_end_date'), $page->session('org_internal_id'));
	foreach my $row (@$rows)
	{
		my ($patientName, $patientId, $balance, $age) =  ($row->{patient_name}, $row->{patient_id}, $row->{balance}, $row->{age});
		my $notesCount = $STMTMGR_REPORT_ACCOUNT_COLLECTION->getSingleValue($page,STMTMGRFLAG_NONE,'selCollectorsNotesCount', $row->{patient_id});
		if($notesCount == 0)
		{
			$notesCount = undef;
		}

		my $rows1 = $STMTMGR_REPORT_ACCOUNT_COLLECTION->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selCollectorsOwners', $row->{patient_id});
		foreach my $row1 (@$rows1)
		{
			my @rowData = ($patientName, $patientId, $balance, $age, $row1->{provider_name}, $row1->{provider_id}, $notesCount);
			push(@data, \@rowData);
			($patientName, $patientId, $balance, $age, $notesCount) =(undef,undef,undef,undef,undef);
		}
	}

	my $html = createHtmlFromData($page, 0, \@data, $pub);
	return $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;