#!/usr/bin/perl -I.

use strict;

use constant NSFDEST_ARRAY => 0;
use constant NSFDEST_FILE => 1;
use constant NSF_HALLEY => '0';
use constant NSF_ENVOY => '1';
use constant DEFAULT_VFLAGS => 0;

use App::Billing::Claims;
use App::Billing::Input::DBI;
use App::Billing::Output::NSF;
use App::Billing::Validators;
use App::Billing::Output::PDF;
use DBI;

use constant INVOICESTATUS_SUBMITTED => 4;
use constant INVOICESTATUS_TRANSMITTED => 5;

use Date::Manip;

sub main
{
	my @ARGV = @_;

	my $today = UnixDate('today', '%m%d%Y_%H%M');

	my $cs = shift;
	die "Usage Example:  $0 sde_prime/sde\@sdedbs02" unless $cs;

	$cs =~ /(.*?)\/(.*?)\@(.*)/;
	my ($userName, $password, $twoTask) =  ($1, $2, $3);

	my $NSF_FILE_NAME = 'phy169_' . $today . '.nsf';

	my $claimList = new App::Billing::Claims;
	my $valMgr = new App::Billing::Validators;
	my $input = new App::Billing::Input::DBI;

	$input->registerValidators($valMgr);

	if($input->populateClaims($claimList, valMgr => $valMgr,
		UID => $userName, PWD => $password, connectStr => 'dbi:Oracle:' . $twoTask,
		invoiceIds => ''))
	{
		if($valMgr->haveErrors() == 0)
		{
			my $output = new App::Billing::Output::NSF();
			$output->registerValidators($valMgr);

			my $claims = $claimList->getClaim();

			# $valMgr->validateClaim('Output', DEFAULT_VFLAGS, $claimList);

			foreach my $claim (@$claims)
			{
				# $valMgr->validateClaim('Claim_Payer', DEFAULT_VFLAGS, $claim);
			}

			if($valMgr->haveErrors() == 0)
			{
				my $st = $claimList->getStatistics;

				my @outArray = ();
				if ($valMgr->haveErrors() == 0)
				{
					my $outResult = $output->processClaims(
						destination => NSFDEST_FILE,
						outArray => \@outArray,
						outFile => $NSF_FILE_NAME,
						claimList => $claimList,
						validationMgr => $valMgr,
						nsfType => NSF_HALLEY,
						FLAG_STRIPDASH => '1',
					);

					print " Total Claims Processed = $st->{count} \n ";

				}
				else
				{
					printErrors($valMgr,"NSF ERRORS");
				}
			}
			else
			{
				printErrors($valMgr,"CLAIM VALIDATORS");
			}
		}
		else
		{
			printErrors($valMgr,"DBI ERRORS");
		}
	}
	else
	{
		printErrors($valMgr,"CLAIM POPULATION");
	}
}

main(@ARGV);


sub printErrors
{
	my ($valMgr, $header) = @_;
	my $errors = $valMgr->getErrors();

	open(CLAIMFILE,">./claimerror.txt");
	print CLAIMFILE "$header","\n\n\n";
	foreach my $error (@$errors)
	{
		print CLAIMFILE @$error,"\n";

	}
	close(CLAIMFILE);
}

