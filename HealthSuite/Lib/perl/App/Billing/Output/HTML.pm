#########################################################################
package App::Billing::Output::HTML;
#########################################################################
use strict;
use App::Billing::Output::Driver;
use App::Billing::Claims;
use App::Billing::Output::Html::Template;
use Text::Template;
use vars qw(@ISA);
use constant EDIT => 1;
use constant VIEW => 2;

# this object is inherited from App::Billing::Output::Driver
@ISA = qw(App::Billing::Output::Driver);
use Devel::ChangeLog;

use vars qw(@CHANGELOG);

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

sub generateHTMLpre
{
	my ($self, $claim, $tempPath) = @_;
	my $htmlTemplate = new App::Billing::Output::Html::Template();
	$htmlTemplate->populateTemplate($claim);
	$tempPath = $tempPath eq "" ? 'C:\\hsc-live\\View1500.dat' : $tempPath;
	my $template = new Text::Template(SOURCE => $tempPath);
	my $html = $template->fill_in(HASH => $htmlTemplate->{data});
	return $html;
}

sub generateHTML
{
	my ($self, $claim, $tempPath) = @_;
	my $procesedProc = [];
	my $htmlTemplate = new App::Billing::Output::Html::Template();
	my @html;
	$tempPath = $tempPath eq "" ? 'C:\\hsc-live\\View1500.dat' : $tempPath;
	my $once = 0;
	my $template = new Text::Template(SOURCE => $tempPath);
	my $pp = $self->setPrimaryProcedure($claim);
	while ($self->allProcTraverse($procesedProc, $claim) eq "0" || ($once < 1))
	{
		$htmlTemplate->populateTemplate($claim, $procesedProc);
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
	return $sum >= $#$procs ? 1 : 0;
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
		$claim->{procedures}->[$primaryProcedure] = $claim->{procedures}->[0]
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

@CHANGELOG =
(
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/16/1999', 'SSI','Billing Interface/Output HTML','Box 14 - 23. added'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/17/1999', 'SSI','Billing Interface/Output HTML','method box1 is added to generate the html for box 1'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/21/2000', 'SSI','Billing Interface/Output HTML','New HTML code is implemented'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/21/2000', 'SSI','Billing Interface/Output HTML','Big brakets fixed, spelling mistakes fixied, All six procedures will be implemented soon.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/24/2000', 'SSI','Billing Interface/Output HTML','New HTML code is implemented'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/31/2000', 'SSI','Billing Interface/Output HTML','EDIT => 1, VIEW => 2 constant are added to specify the type of file genereted.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/31/2000', 'SSI','Billing Interface/Output HTML','TEMPLATE_PATH parama field  added to specify the path of the template file.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '03/01/2000', 'SSI','Billing Interface/Output HTML','More than six procedure implemented.'],
);

1;