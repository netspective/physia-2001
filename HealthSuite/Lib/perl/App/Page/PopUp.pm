##############################################################################
package App::Page::PopUp;
##############################################################################

use strict;
use base 'App::Page';

use DBI::StatementManager;
use App::Statements::Component::Scheduling;
use App::Statements::Person;

use App::Billing::Prescription::Prescription;
use App::Billing::Input::PrescriptionDBI;
use App::Billing::Output::PrescriptionPDF;
use App::Configuration;


use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'popup' => {},
);

sub prepare_view_alerts
{
	my ($self) = @_;
	my $patientId = $self->param('person_id');

	my $html = $STMTMGR_COMPONENT_SCHEDULING->createHtml($self, STMTMGRFLAG_NONE,
		'sel_detail_alerts',	[$self->session('GMT_DAYOFFSET'), $patientId],);

	my $patient = $STMTMGR_PERSON->getRowAsHash($self, STMTMGRFLAG_NONE, 'selPersonData',
		$patientId);

	$self->addContent(qq{
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0 width=100%>
			<TR>
				<TD>
					<b style="color:darkgreen">@{[$patient->{simple_name}]} - ($patientId)</b>
				</TD>
				<TD align=right>
					<a href='javascript:window.close()'><img src='/resources/icons/done.gif' border=0></a>
				</TD>
			</TR>
			<TR>
				<TD>
					$html
				</TD>
			</TR>
		</TABLE>
	});

	return 1;
}

sub prepare_view_prescription_pdf
{
	my ($self) = @_;
	my $permed_id = $self->param('permed_id');

	my $prescription = new App::Billing::Prescription::Prescription;
	my $input = new App::Billing::Input::PrescriptionDBI;
	my $output = new App::Billing::Output::PrescriptionPDF;

	$input->populatePrescription (
		$prescription,
		$self,
		$permed_id
	);

	my $pdfName = $self->session('org_internal_id') . '_' . $self->session('user_id') .
		'_' . $permed_id . '.pdf';
	my $pdfFile = File::Spec->catfile($CONFDATA_SERVER->path_PDFPrescriptionOutput, $pdfName);
	my $pdfHref = File::Spec->catfile($CONFDATA_SERVER->path_PDFPrescriptionOutputHREF, $pdfName);

	$output->printReport(
		$prescription,
		file => $pdfFile,
#		columns => 4,
#		rows => 51
	);

	$self->redirect($pdfHref);

	return 1;
}


sub getContentHandlers
{
	return ('prepare_view_$_pm_view=alerts$');
}

sub prepare_page_content_footer
{
	my $self = shift;
	return 1;
}

sub prepare_page_content_header
{
	my $self = shift;
	return 1;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->param('_pm_view', $pathItems->[0]);
	$self->param('person_id', $pathItems->[1]);

	$self->printContents();
	return 0;
}

1;
