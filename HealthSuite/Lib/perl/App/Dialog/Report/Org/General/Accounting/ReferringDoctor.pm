##############################################################################
package App::Dialog::Report::Org::General::Accounting::ReferringDoctor;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use Data::Publish;
use App::Statements::Report::ReferringDoctor;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-referring-doctor', heading => 'Referring Doctor');

	$self->addContent(
		new CGI::Dialog::Field::Duration(
			name => 'report',
			caption => 'Start/End Report Date',
			begin_caption => 'Report Begin Date',
			end_caption => 'Report End Date',
		),
		new CGI::Dialog::Field::Duration(
			name => 'service',
			caption => 'Start/End Service Date',
			begin_caption => 'Service Begin Date',
			end_caption => 'Service End Date',
		),
		new CGI::Dialog::Field(
			name => 'insurance_select',
			caption => 'Insurance Org',
			type => 'bool',
			style => 'check',
			defaultValue => 0
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


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $pub =
	{
		columnDefn =>
		[
			{
				colIdx => 0,
				head => 'Doctor',
				hAlign => 'center',
				dAlign => 'left',
				dataFmt => '#0# <A HREF = "/person/#1#/profile">#1#</A>',
			},
			{
				colIdx => 1,
				head => '# of Patients',
				hAlign => 'center',
				dAlign => 'right',
				dataFmt => '#2#',
			},
			{
				colIdx => 2,
				head => '% of Patients',
				hAlign => 'center',
				dAlign => 'right',
				dataFmt => '#3#',
			},
		],
	};

	my $pubOrg =
	{
		columnDefn =>
		[
			{
				colIdx => 0,
				head => 'Doctor',
				hAlign => 'center',
				dAlign => 'left',
				dataFmt => '#0# <A HREF = "/person/#1#/profile">#1#</A>',
			},
			{
				colIdx => 1,
				head => 'Insurance Org',
				hAlign => 'center',
				dAlign => 'left',
				dataFmt => '#2#',
			},
			{
				colIdx => 2,
				head => '# of Patients',
				hAlign => 'center',
				dAlign => 'right',
				dataFmt => '#3#',
			},
			{
				colIdx => 3,
				head => '% of Patients',
				hAlign => 'center',
				dAlign => 'right',
				dataFmt => '#4#',
			},
		],
	};


	my $totalPatients = $STMTMGR_REPORT_REFERRING_DOCTOR->getSingleValue($page, STMTMGRFLAG_NONE, 'totalPatientCount', $page->field('report_begin_date'), $page->field('report_end_date'), $page->field('service_begin_date'), $page->field('service_end_date'));
	my @data = undef;

	if($page->field('insurance_select') ne '')
	{
		my $referringPhysician = $STMTMGR_REPORT_REFERRING_DOCTOR->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'patientOrgCount', $page->field('report_begin_date'), $page->field('report_end_date'), $page->field('service_begin_date'), $page->field('service_end_date'));
		my ($prvDoctor, $patients, $percent);

		foreach(@$referringPhysician)
		{
			if ($prvDoctor eq $_->{person_id})
			{
				my @rowData = (
					undef,
					undef,
					($_->{name_primary} eq '') ? 'Other' : $_->{name_primary},
					$_->{patientcount},
					sprintf  "%3.2f%", ($_->{patientcount} / $totalPatients) * 100
				);
				push(@data, \@rowData);
				$patients += $_->{patientcount};
				$percent += ($_->{patientcount} / $totalPatients) * 100;
				$prvDoctor = $_->{person_id}
			}
			else
			{
				if ($prvDoctor ne '')
				{
					my @rowData1 = ("<B>Subtotal for $prvDoctor</B>", undef, undef, "<B>$patients</B>",	"<B>" . sprintf  "%3.2f%", $percent . "</B>");
					push(@data, \@rowData1);
					my @rowData2 = (undef, undef, undef, undef, undef);
					push(@data, \@rowData2);
					$patients=0;
					$percent=0;
				}
				my @rowData =
				(
					$_->{name},
					$_->{person_id},
					($_->{name_primary} eq '') ? 'Other' : $_->{name_primary},
					$_->{patientcount},
					sprintf  "%3.2f%", ($_->{patientcount} / $totalPatients) * 100
				);
				push(@data, \@rowData);
				$patients += $_->{patientcount};
				$percent += ($_->{patientcount} / $totalPatients) * 100;
				$prvDoctor = $_->{person_id};
			}
		}
		if ($prvDoctor ne '')
		{
			my @rowData1 = ("<B>Subtotal for $prvDoctor </B>", undef, undef, "<B>$patients</B>", "<B>" . sprintf  "%3.2f%", $percent . "</B>");
			push(@data, \@rowData1);
			my @rowData2 = (undef, undef, undef, undef, undef);
			push(@data, \@rowData2);
		}
	}
	else
	{
		my $referringPhysician = $STMTMGR_REPORT_REFERRING_DOCTOR->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'patientCount', $page->field('report_begin_date'), $page->field('report_end_date'), $page->field('service_begin_date'), $page->field('service_end_date'));
		foreach(@$referringPhysician)
		{
			my $patientCountPercent = sprintf  "%3.2f%", ($_->{patientcount} / $totalPatients) * 100;
			my @rowData =
			(
				$_->{name},
				$_->{person_id},
				$_->{patientcount},
				$patientCountPercent,
			);
			push(@data, \@rowData);
		}
	}

	my $patientTotalPercent = '100.00%' if ($totalPatients !=0);
	my $html;

	if($page->field('insurance_select') ne '')
	{
		my @rowData = (	"<B>Grand Total</B>", undef, undef, "<B>$totalPatients</B>", "<B>$patientTotalPercent</B>");
		push(@data, \@rowData);
		$html = createHtmlFromData($page, 0, \@data, $pubOrg);
	}
	else
	{
		my @rowData = (	"<B>Total</B>", undef, "<B>$totalPatients</B>",	"<B>$patientTotalPercent</B>");
		push(@data, \@rowData);
		$html = createHtmlFromData($page, 0, \@data, $pub);
	}
	return $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;