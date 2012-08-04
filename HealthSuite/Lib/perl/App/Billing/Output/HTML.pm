#########################################################################
package App::Billing::Output::HTML;
#########################################################################
use strict;
use App::Billing::Output::Driver;
use App::Billing::Claims;
use App::Billing::Output::Html::Template;
use App::Billing::Output::Html::Worker;
use App::Billing::Output::Html::FloridaMedicaid;

use Text::Template;
use vars qw(@ISA);
use constant EDIT => 1;
use constant VIEW => 2;

# this object is inherited from App::Billing::Output::Driver
@ISA = qw(App::Billing::Output::Driver);

sub processClaims
{
	my ($self, %params) = @_;
	my $claim;
	my $claimsList = $params{claimList};
	my $claims = $params{claimList}->getClaim();
    foreach $claim(@$claims)
	{
		if ($claim ne "")
		{
			if(my $file = $params{outFile})
			{
				$self->createHTML($file, $claim, $params{TEMPLATE_PATH});
			}
			else
			{
				push(@{$params{outArray}}, $self->generateHTML($claim, $params{TEMPLATE_PATH} ));
			}
		}
	}
}

sub createHTML
{
	my ($self, $file, $claim, $tempPath) = @_;

	my $htmlText =  $self->generateHTML($claim, $tempPath);
	open(CLAIMFILE,">$file");
	print CLAIMFILE $htmlText;
	close CLAIMFILE;
}

sub generateHTML
{
	my ($self, $claim, $tempPath) = @_;
	
	my $htmlTemplate;
	my $insured = $claim->getInsured(0);
	my $insuranceProductOrPlan = $insured->getInsurancePlanOrProgramName();

	if ($claim->getInvoiceSubtype() eq 6)
	{
		$htmlTemplate = new App::Billing::Output::Html::Worker();
	}
	elsif ($claim->getInvoiceSubtype() eq 5 && ($insuranceProductOrPlan eq "FLORIDA MEDICAID"))
	{
		$htmlTemplate = new App::Billing::Output::Html::FloridaMedicaid();
	}
	else
	{
		$htmlTemplate = new App::Billing::Output::Html::Template();
	}

	my @html;
	my $procesedProc = [];
	$tempPath = $tempPath eq "" ? 'C:\\hsc-live\\View1500.dat' : $tempPath;
	my $once = 0;
	my $template = new Text::Template(SOURCE => $tempPath);
	my $pp = $self->setPrimaryProcedure($claim);
	while ($self->allProcTraverse($procesedProc, $claim) eq "0")
	{
		$htmlTemplate->populateTemplate($claim, $procesedProc);
		if ($self->allProcTraverse($procesedProc, $claim) eq "1")
		{
			$htmlTemplate->populateFinalCharges($claim);
		}
		push @html, $template->fill_in(HASH => $htmlTemplate->{data});
		$htmlTemplate->doInit;
		$once++;
	}
	
	$self->reversePrimaryProcedure($claim, $pp);
	return join('', @html);
}

sub allProcTraverse
{
	my ($self, $procesedProc, $claim) = @_;
	my $procs = $claim->{procedures};
	my $sum = 0;

	for my $i (0..$#$procs)
	{
		$sum = ($procesedProc->[$i] eq "1") ? ++$sum : $sum;
	}
	return $sum >= ($#$procs + 1)? 1 : 0;
}

sub setPrimaryProcedure
{
	my ($self, $claim) = @_;

	my $procedures = $claim->{procedures};
	my $dg = $claim->{'diagnosis'}->[0]->getDiagnosis()	if defined ($claim->{'diagnosis'}->[0]);
	my $procedure;
	my $primaryProcedure = -1;
	foreach my $i (0..$#$procedures)
	{
		$procedure = $procedures->[$i];
		if ($procedure ne "")
		{
			 $primaryProcedure = $procedure->getDiagnosis() =~ /$dg/ ? $i : -1;

		}
	}
	if ($primaryProcedure != -1)
	{
		my $temp = $claim->{procedures}->[0];
		$claim->{procedures}->[0] = $claim->{procedures}->[$primaryProcedure];
		$claim->{procedures}->[$primaryProcedure] = $temp;
	}
	return  $primaryProcedure;
}

sub reversePrimaryProcedure
{
	my ($self, $claim, $primaryProcedure) = @_;
	if ($primaryProcedure != -1)
	{
		my $procedure = $claim->{procedures}->[$primaryProcedure];
		$claim->{procedures}->[$primaryProcedure] = $claim->{procedures}->[0];
		$claim->{procedures}->[0] = $procedure;
	}
}


1;