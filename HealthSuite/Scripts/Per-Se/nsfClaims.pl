#!/usr/bin/perl -I.

use strict;
use Date::Manip;

use App::Universal;
use App::Configuration;

use DBI::StatementManager;
use App::Statements::Invoice;

use App::Billing::Claims;
use App::Billing::Input::DBI;
use App::Billing::Output::NSF;

use constant NSFDEST_ARRAY => 0;
use constant NSFDEST_FILE  => 1;
use constant NSF_HALLEY    => '0';
use constant NSF_ENVOY     => '1';
use constant NSF_THIN      => '2';

# Config Params
# ----------------------------------------------------------
my $EDIHOST = $ENV{TESTMODE} ? 'gamma' : 'depot.medaphis.com';
my $STAGINGDIR = '$HOME/per-se';

my $PERSEDIR = '$HOME/per-se';
my $OUTGOINGDIR = $PERSEDIR . '/outgoing';

my $PGPDIR = $OUTGOINGDIR . '/pgp';
my $ARCHIVEDIR = $OUTGOINGDIR . '/archive';

my $SCRIPTDIR = '$HOME/projects/HealthSuite/Scripts/Per-Se';
# ----------------------------------------------------------

use CommonUtils;
use OrgList;

my $now = UnixDate('today', '%m%d%Y_%H%M');

sub createNSFfiles
{
	my ($page) = @_;

	for my $orgInternalId (keys %billId)
	{
		my $claims = findSubmittedClaims($page, $orgInternalId);
		createNSFfile($page, $orgInternalId, $claims) if defined $claims;
	}
}

sub createNSFfile
{
	my ($page, $orgInternalId, $claims) = @_;

	my $claimList = new App::Billing::Claims;
	my $input = new App::Billing::Input::DBI;

	my $nsfFile = $billId{$orgInternalId} . '_' . $now . '.nsf';

	$input->populateClaims($claimList,
		dbiHdl => $page->getSchema()->{dbh},
		invoiceIds => $claims,
	) || die ("Unable to call populateClaims routine: $!");

	my @outArray = ();
	my $output = new App::Billing::Output::NSF();
	my $outResult = $output->processClaims(
		destination => NSFDEST_FILE,
		outArray => \@outArray,
		outFile => $nsfFile,
		claimList => $claimList,
		nsfType => NSF_HALLEY,
		FLAG_STRIPDASH => '1',
	);

	my $st = $claimList->getStatistics;
	print "\nFile Created: $nsfFile\n";
	print "Total Claims Processed = $st->{count} \n";
}

sub transmitNSFfiles
{
	my ($connectString) = @_;

	my $ftpCommands = qq{
		ftp $EDIHOST << !!!
	};

	my @nsfFiles = ();
	
	opendir(DIR, ".") || die "Can't opendir .: $!\n";
  for my $file (readdir(DIR))
  {
		next unless $file =~ /\.nsf$/;
		push(@nsfFiles, $file);
		my $pgpFile = $file . '.pgp';
		$ftpCommands .= qq{put $pgpFile $file\n};
	}

	unless (@nsfFiles)
	{
		print "No '.nsf' file found to transmit -- " . `date`;
		return;
	}
	
	$ftpCommands .= qq{bye
	!!!
	};

	system(qq{
		cd $STAGINGDIR
		for f in *nsf; do
			\$HOME/bin/encrypt \$f
			$SCRIPTDIR/update_transmitted.pl $connectString \$f
		done
		$ftpCommands
	});
}

sub archiveNSFfiles
{
	for my $orgInternalId (keys %billId)
	{
		my $stem = $billId{$orgInternalId};

		system(qq{
			cd $STAGINGDIR
			mkdir -p $ARCHIVEDIR/$orgInternalId
			mkdir -p $PGPDIR/$orgInternalId
			for f in $stem*nsf; do
				if [ -f \$f ]; then
					mv \$f $ARCHIVEDIR/$orgInternalId
				fi
			done
			for f in $stem*pgp; do
				if [ -f \$f ]; then
					mv \$f $PGPDIR/$orgInternalId
				fi
			done
		});
	}
}

########
# main
########

my $forceConfig = shift || die "\nUsage: $0 <db-connect-key>\n";
$CONFDATA_SERVER = $App::Configuration::AVAIL_CONFIGS{$forceConfig};
my ($page, $sqlPlusKey) = connectDB();

my @whatToDo = @ARGV ? @ARGV : ('create');

print "\n-------------------------------\n";
print `date`;
print "-------------------------------\n";

createNSFfiles($page) if grep (/create/, @whatToDo);
transmitNSFfiles($sqlPlusKey) if grep(/transmit/, @whatToDo);
archiveNSFfiles() if grep(/archive/, @whatToDo);