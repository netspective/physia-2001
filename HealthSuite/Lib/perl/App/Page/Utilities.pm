##############################################################################
package App::Page::Utilities;
##############################################################################

use strict;
use base qw(App::Page);

use Date::Manip;
use DBI::StatementManager;
use App::Statements::Invoice;
use App::Universal;
use App::Configuration;
use App::Utilities::Invoice;

use App::Billing::Claims;
use App::Billing::Input::DBI;
use App::Billing::Output::PDF;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'utilities' => {
		_title => 'Utilities',
		_iconSmall => 'icons/sde',
		_iconMedium => 'icons/sde',
		_iconLarge => 'icons/sde',
		_views => [],
	},
);

sub findPaperClaims
{
	my ($self, $orgInternalId) = @_;
	
	return $STMTMGR_INVOICE->getSingleValueList($self, STMTMGRFLAG_NONE, 
		'selPaperClaims', $orgInternalId
	);
}

sub prepare_view_createBatchPaperClaims
{
	my ($self, $drawBackground) = @_;
	my $orgInternalId = $self->param('org_internal_id');
	
	unless ($orgInternalId)
	{
		$self->addContent(qq{
			<h3><u>Create Batch Paper Claims</u></h3>
			<font face=Verdana size=3>
			This function will create a printable <b>pdf</b> file containing the batch of all 
			currently submitted paper claims.
			<br>
			Click here to <a href="/utilities/createBatchPaperClaims/@{[ $self->session('org_internal_id')]}" 
				title='Create batch paper claims'>create</a>.
			</font>
		});
		return 1;
	}

	my $claims = $self->findPaperClaims($orgInternalId);

	unless (defined $claims)
	{
		$self->addContent(qq{
			<h3><u>Create Batch Paper Claims</u></h3>
			<font face=Verdana size=3>
			No Paper Claims found at this time.
			Return to <a href='/menu'>Main Menu</a>.
			</font>
		});
		return 1;
	}

	my ($listName, $listFile) = $self->createBatchPaperClaims($claims, $orgInternalId, $drawBackground);	
	$self->updatePaperClaimsPrinted($claims);
	
	$self->redirect("/paperclaims/$listName?enter=$listFile");
}

sub createBatchPaperClaims
{
	my ($self, $claims, $orgInternalId, $drawBackground) = @_;
	
	my $claimList = new App::Billing::Claims;
	my $input = new App::Billing::Input::DBI;
	
	$input->populateClaims($claimList, 
		dbiHdl => $self->getSchema()->{dbh},
		invoiceIds => $claims, 
	) || $self->addError("Unable to call populateClaims routine: $!");
	
	my $now = UnixDate('today', '%Y-%m-%d_%H-%M');
	my $pdfName = $orgInternalId . '_' . $now . '.pdf';

	my $listFile = File::Spec->catfile($CONFDATA_SERVER->path_PaperClaims,
		$orgInternalId . '_' . $now . '.claims');
	my $listName = $orgInternalId . '_' . $now . '.claims';

	my @claimsHtml = ();
	for (@{$claims})
	{
		push(@claimsHtml, qq{
			<a href="/invoice/$_/summary" title="View Claim $_ Summary">$_</a>
		});
	}
	open (LISTFILE, ">$listFile") || die "Unable to open list file $listFile: $!\n";
	print LISTFILE qq{
		<font face=Verdana size=3>
		<b>Paper Claims Included in this batch:</b><br>
		@{[ join(', ', @claimsHtml) ]}
		<br><br>Click here to <a href="/paperclaims/pdf/$pdfName" title="Print Batch Paper Claims"><b>Print</b></a>
		</font>
	};

	my $output = new App::Billing::Output::PDF;
	$output->processClaims(
		outFile => File::Spec->catfile($CONFDATA_SERVER->path_PaperClaims, 'pdf', $pdfName),
		claimList => $claimList, 
		drawBackgroundForm => $drawBackground,
	);

	close(LISTFILE);
	return ($listName, $listFile);
}

sub updatePaperClaimsPrinted
{
	my ($self, $claims) = @_;
	
	my $claimListString = join(',', @{$claims});

	foreach (@$claims)
	{
		handleDataStorage($self, $_, App::Universal::SUBMIT_PAYER, 1);
	}
}

sub prepare_view_printerSpec
{
	my $self = shift;
	
	$self->addContent(qq{
		<b>Printer Specification.</b><br>
		This function is under construction awaiting completion of Device Management.<br>
		Please try again later.
		<br><br>		
		Click <a href='javascript:history.back()'>here</a> to go back.
	});
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->addLocatorLinks(
		[ 'Utilities', '/utilities' ],
	);
}

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=createBatchPaperClaims$');
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	return 1 if ref($self) ne __PACKAGE__;

	unless ($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[0]) if $pathItems->[0];
		$self->param('org_internal_id', $pathItems->[1]) if $pathItems->[1];
	}

	$self->printContents();
	return 0;
}

1;
