#########################################################################
package App::Billing::Output::TWCC;
#########################################################################
use strict;
use App::Billing::Output::Driver;
use App::Billing::Claims;

use App::Billing::Output::TWCC::TWCC61;
use App::Billing::Output::TWCC::TWCC64;
use App::Billing::Output::TWCC::TWCC69;
use App::Billing::Output::TWCC::TWCC73;

use pdflib 2.01;

use constant FONT_NAME => 'Helvetica';
use vars qw(@ISA); 
# this object is inherited from App::Billing::Output::Driver
@ISA = qw(App::Billing::Output::Driver);

sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Output::Driver(@_);
	return bless $self, $type;
}

sub processClaims
{	
	my ($self, $claimList, %params) = @_;


	my $claims = $claimList->getClaim();
	my $p = pdflib::PDF_new();
	die "PDF file name is required" unless exists $params{outFile};
	die "Couldn't open PDF file"  if (pdflib::PDF_open_file($p, $params{outFile}) == -1);
	pdflib::PDF_set_info($p, "Creator", "PHYSIA");
	pdflib::PDF_set_info($p, "Author", "PHYSIA");
	pdflib::PDF_set_info($p, "Title", "TWCC Report");
	
	my %reports;
	$reports{'TWCC61'}= new App::Billing::Output::TWCC::TWCC61;
	$reports{'TWCC64'}= new App::Billing::Output::TWCC::TWCC64;
	$reports{'TWCC69'}= new App::Billing::Output::TWCC::TWCC69;
	$reports{'TWCC73'}= new App::Billing::Output::TWCC::TWCC73;

	foreach my $claim(@$claims)
	{
		if ($claim->haveErrors() == 1)
		{
			$self->newPage($p);
			$self->drawErrors($p,$claim);
			$self->endPage($p);
		}
		else
		{
			my $rpt = $reports{$params{reportId}};
			$rpt->printReport($p, $claim) if ($rpt ne "");
		}
	}

	pdflib::PDF_close($p);
	pdflib::PDF_delete($p);

}	


sub drawErrors
{
	
	my ($self, $p, $claim) = @_;
	my $font = pdflib::PDF_findfont($p, FONT_NAME , "default", 0);
	die "Couldn't set font"  if ($font == -1);
	pdflib::PDF_setfont($p, $font, 8.0);
	my $y = 747.0;
	pdflib::PDF_show_xy($p , 'The claim with id' . $claim->getId(). " have following errors", 50,$y );
	my $errors = $claim->getErrors();
	my $error;
	$y-=10;
	foreach $error (@$errors)
	{
		pdflib::PDF_show_xy($p , $error->[1] . $error->[2], 60, $y-=10);
	}
}
