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
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

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
		new CGI::Dialog::Field(
			name => 'printReport',
			type => 'bool',
			style => 'check',
			caption => 'Print report',
			defaultValue => 0
		),

		new CGI::Dialog::Field(
			caption =>'Printer',
			name => 'printerQueue',
			options => FLDFLAG_PREPENDBLANK,
			fKeyStmtMgr => $STMTMGR_DEVICE,
			fKeyStmt => 'sel_org_devices',
			fKeyDisplayCol => 0
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

	my $reportBeginDate = $page->field('report_begin_date');
	my $reportEndDate = $page->field('report_end_date');
	my $serviceBeginDate = $page->field('service_begin_date');
	my $serviceEndDate = $page->field('service_end_date');
	my $insuranceOrg = $page->field('insurance_select');

	my $pub =
	{
		reportTitle => "Referring Doctor",
		columnDefn =>
		[
			{
				colIdx => 0,
				head => 'Category',
				hAlign => 'center',
				dAlign => 'left',
				dataFmt => '#4#',
#				groupBy => '#4#',
			},
			{
				colIdx => 1,
				head => 'Doctor',
				hAlign => 'center',
				dAlign => 'left',
				dataFmt => '#0# <A HREF = "/person/#1#/profile">#1#</A>',
			},
			{
				colIdx => 2,
				head => '# of Patients',
				hAlign => 'center',
				dAlign => 'right',
				dataFmt => '#2#',
#				summarize => 'sum',
			},
			{
				colIdx => 3,
				head => '% of Patients',
				hAlign => 'center',
				dAlign => 'right',
				dataFmt => '#3#',
#				summarize => 'sum',
			},
		],
	};

	my $pubOrg =
	{
		reportTitle => "Referring Doctor",
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
	my @data = ();
	my @dataText = undef;

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
				push(@dataText, \@rowData);

				$patients += $_->{patientcount};
				$percent += ($_->{patientcount} / $totalPatients) * 100;
				$prvDoctor = $_->{person_id}
			}
			else
			{
				if ($prvDoctor ne '')
				{
					my @rowData1 = ("<B>Subtotal for $prvDoctor</B>", undef, undef, "<B>$patients</B>",	"<B>" . sprintf  "%3.2f%", $percent . "</B>");

					my @rowData1Text = (undef, "Subtotal for $prvDoctor",  undef, "$patients",	 sprintf  "%3.2f%", $percent );
					push(@data, \@rowData1);
					##
					push(@dataText, \@rowData1Text);
					##
					my @rowData2 = (undef, undef, undef, undef, undef);
					push(@data, \@rowData2);
					##
					push(@dataText, \@rowData2);
					##
					$patients = 0;
					$percent = 0;
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
				push(@dataText, \@rowData);
				$patients += $_->{patientcount};
				$percent += ($_->{patientcount} / $totalPatients) * 100;
				$prvDoctor = $_->{person_id};
			}
		}
		if ($prvDoctor ne '')
		{
			my @rowData1 = ("<B>Subtotal for $prvDoctor </B>", undef, undef, "<B>$patients</B>", "<B>" . sprintf  "%3.2f%", $percent . "</B>");

			my @rowData1Text = ( undef, "Subtotal for $prvDoctor ", undef, "$patients", sprintf  "%3.2f%", $percent);

			push(@data, \@rowData1);
			##
			push(@dataText, \@rowData1Text);
			##
			my @rowData2 = (undef, undef, undef, undef, undef);
			push(@data, \@rowData2);
			##
			push(@dataText, \@rowData2);
			##
		}
	}
	else
	{
		my $referringPhysician = $STMTMGR_REPORT_REFERRING_DOCTOR->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'patientCount', $page->field('report_begin_date'), $page->field('report_end_date'), $page->field('service_begin_date'), $page->field('service_end_date'));

		my $groupCount = 0;
		my $groupPercent = 0;
		my $prevCategory;
		my $category;

		foreach(@$referringPhysician)
		{

#			my $patientCountPercent = sprintf  "%3.2f%", ($_->{patientcount} / $totalPatients) * 100;
			if(($_->{category} ne $prevCategory) && ($groupCount > 0))
			{
				$category = $_->{category};

				my @rowData =
				(
					undef,
					undef,
					"<B>$groupCount</B>",
					"<B>$groupPercent%</B>",
					"<B>$prevCategory</B>",
				);

				my @rowDataText =
				(
					undef,
					undef,
					"$groupCount",
					"$groupPercent%",
					"$prevCategory",
				);

				push(@data, \@rowData);
				##
				push(@dataText, \@rowDataText);
				##
				my @rowDataBlank =
				(
					undef,
					undef,
					undef,
					undef,
					undef,
				);
				push(@data, \@rowDataBlank);
				##
				push(@dataText, \@rowDataBlank);
				##
				$groupCount = 0;
				$groupPercent = 0;

			}
			elsif($groupCount == 0)
			{
				$category = $_->{category};
			}
			else
			{
				$category = '';
			}
			$prevCategory = $_->{category};


			my @rowData =
			(
				$_->{name},
				$_->{person_id},
				$_->{patientcount},
				$_->{patientpercent},
				$category,
			);
			push(@data, \@rowData);
			push(@dataText, \@rowData);

			$groupCount += $_->{patientcount};
			$groupPercent += substr($_->{patientpercent}, 0, length($_->{patientpercent})-1);

		}
		if($groupCount > 0)
		{
			if($prevCategory eq '')
			{
				$prevCategory = 'Unknown';
			}
			my @rowData =
			(
				undef,
				undef,
				"<B>$groupCount</B>",
				"<B>$groupPercent%</B>",
				"<B>$prevCategory</B>",
			);

			my @rowDataText =
			(
				undef,
				undef,
				"$groupCount",
				"$groupPercent%",
				"$prevCategory",
			);

			push(@data, \@rowData);
			##
			push(@dataText, \@rowDataText);
			##
			my @rowDataBlank =
			(
				undef,
				undef,
				undef,
				undef,
				undef,
			);
			push(@data, \@rowDataBlank);
			##
			push(@dataText, \@rowDataBlank);
			##
		}

	}

	my $patientTotalPercent = '100.00%' if ($totalPatients !=0);
	my $html;

	my $hardCopy = $page->field('printReport');
	my $textOutputFilename;

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");
	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');

	if($page->field('insurance_select') ne '')
	{
		my @rowData = (	"<B>Grand Total</B>", undef, undef, "<B>$totalPatients</B>", "<B>$patientTotalPercent</B>");
		my @rowDataText = (	 undef, "Grand Total", undef, "$totalPatients", "$patientTotalPercent");

		push(@data, \@rowData);
		push(@dataText, \@rowDataText);
		$html = createHtmlFromData($page, 0, \@data, $pubOrg);
		$textOutputFilename = createTextRowsFromData($page, 0, \@dataText, $pubOrg);

		my $tempDir = $CONFDATA_SERVER->path_temp();
		my $Constraints = [
		{ Name => "Start/End Report Date ", Value => $reportBeginDate."  ".$reportEndDate},
		{ Name => "Start/End Service Date ", Value => $serviceBeginDate."  ".$serviceEndDate},
		{ Name=> "Insurance Org ", Value => ($insuranceOrg) ? 'Yes' : 'No' },
		{ Name=> "Print Report ", Value => ($hardCopy) ? 'Yes' : 'No' },
		{ Name=> "Printer ", Value => $printerDevice},
		];
		my $FormFeed = appendFormFeed($tempDir.$textOutputFilename);
		my $fileConstraint = appendLines($page, $tempDir.$textOutputFilename, $Constraints);

		if ($hardCopy == 1 and $printerAvailable) {
			my $reportOpened = 1;
			open (ASCIIREPORT, $tempDir.$textOutputFilename) or $reportOpened = 0;
			if ($reportOpened) {
				while (my $reportLine = <ASCIIREPORT>) {
					print $printHandle $reportLine;
				}
			}
			close ASCIIREPORT;
		}


	}
	else
	{
		my @rowData = (	"<B>Total</B>", undef, "<B>$totalPatients</B>",	"<B>$patientTotalPercent</B>", undef);
		my @rowDataText = (	'', 'Total', "$totalPatients", "$patientTotalPercent", undef);
		push(@data, \@rowData);
		push(@dataText, \@rowDataText);
		$html = createHtmlFromData($page, 0, \@data, $pub);
#		$html = $STMTMGR_REPORT_REFERRING_DOCTOR->createHtml($page, 0, 'patientCount', [$page->field('report_begin_date'), $page->field('report_end_date'), $page->field('service_begin_date'), $page->field('service_end_date')]);
		$textOutputFilename = createTextRowsFromData($page, 0, \@dataText, $pub);

		my $tempDir = $CONFDATA_SERVER->path_temp();
		my $Constraints = [

		{ Name => "Start/End Report Date ", Value => $reportBeginDate."  ".$reportEndDate},
		{ Name => "Start/End Service Date ", Value => $serviceBeginDate."  ".$serviceEndDate},
		{ Name=> "Insurance Org ", Value => ($insuranceOrg) ? 'Yes' : 'No' },
		{ Name=> "Print Report ", Value => ($hardCopy) ? 'Yes' : 'No' },
		{ Name=> "Printer ", Value => $printerDevice},
		];
		my $FormFeed = appendFormFeed($tempDir.$textOutputFilename);
		my $fileConstraint = appendConstraints($page, $tempDir.$textOutputFilename, $Constraints);

		if ($hardCopy == 1 and $printerAvailable) {
			my $reportOpened = 1;
			open (ASCIIREPORT, $tempDir.$textOutputFilename) or $reportOpened = 0;
			if ($reportOpened) {
				while (my $reportLine = <ASCIIREPORT>) {
					print $printHandle $reportLine;
				}
			}
			close ASCIIREPORT;
		}
	}
	return ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version</a> <br>} : "" ) . $html;
	#return $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;