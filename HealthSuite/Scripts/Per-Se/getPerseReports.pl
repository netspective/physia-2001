#!/usr/bin/perl -I.

use strict;
use Date::Manip;
use Dumpvalue;

use CommonUtils;
use OrgList;

# Config Params
# ----------------------------------------------------------
my $EDIHOST = 'depot.medaphis.com';
my $OUTGOINGDIR = '../outgoing';
my $STAGINGDIR = '$HOME/per-se';
my $LOGFILE = $STAGINGDIR . '/get_perse_report.log';

my $PERSEDIR = '$HOME/per-se';
my $INCOMINGDIR = $PERSEDIR . '/incoming';

my $ARCHIVEDIR = $INCOMINGDIR . '/archive';
my $REPORTDIR = $INCOMINGDIR . '/reports';
my $REPORTDELIMDIR = $INCOMINGDIR . '/reports-delim';
my $SCRIPTDIR = '$HOME/projects/HealthSuite/Scripts/Per-Se';
# ----------------------------------------------------------

my %billId = (
	2 => 'phy169',
);

my $now = UnixDate('today', '%Y-%m-%d_%H-%M');

my ($page, $sqlPlusKey) = CommonUtils::connectDB();
OrgList::buildOrgList($page);

sub archiveFiles
{
  for my $orgInternalId (keys %billId)
  {
    my $pgpFile = $billId{$orgInternalId} . 'ms.zip.pgp';
    my $zipFile = $billId{$orgInternalId} . 'ms.zip';

    system(qq{
      cd $STAGINGDIR
      if [ -f $pgpFile ]; then
        mkdir -p $ARCHIVEDIR/$orgInternalId
        mkdir -p $ARCHIVEDIR/$orgInternalId/pgp

        pgp $pgpFile
        unzip $zipFile

        mv $pgpFile $ARCHIVEDIR/$orgInternalId/pgp/$now.pgp
        mv $zipFile $ARCHIVEDIR/$orgInternalId/$now.zip

      fi
    });

    for my $orgKey (keys %orgList)
    {
      my $billingId = lc($orgList{$orgKey}->{billingId});
      my $msgFile = $billingId . '.msg';
      my $dlmFile = $billingId . '.dlm';

      my ($textFile, $csvFile);

      my $orgInternalId = $orgKey;
      if ($orgInternalId =~ s/\..*//g)
      {
        $textFile = "$REPORTDIR/$orgInternalId/${now}_$billingId.txt";
        $csvFile  = "$REPORTDELIMDIR/$orgInternalId/${now}_$billingId.csv";
      }
      else
      {
        $textFile = "$REPORTDIR/$orgInternalId/$now.txt";
        $csvFile  = "$REPORTDELIMDIR/$orgInternalId/$now.csv";
      }

      system(qq{
        cd $STAGINGDIR
        if [ -f $msgFile ]; then
          mkdir -p $REPORTDIR/$orgInternalId
          mv $msgFile $textFile
        fi
        if [ -f $dlmFile ]; then
          mkdir -p $REPORTDELIMDIR/$orgInternalId
          mv $dlmFile $csvFile
          $SCRIPTDIR/ParseReports.pl $csvFile
        fi
      });
    }
  }
}

sub ftpGetFiles
{
	my $ftpCommands = qq{
		ftp $EDIHOST << !!!
		cd $OUTGOINGDIR
	};

	for my $orgInternalId (keys %billId)
	{
		my $pgpFile = $billId{$orgInternalId} . 'ms.zip.pgp';
		$ftpCommands .= qq{get $pgpFile\n};
	}

	$ftpCommands .= qq{bye
	!!!
	};

	system(qq{
		echo
		echo "-------------------------------"
		date
		echo "-------------------------------"
		
		cd $STAGINGDIR
		$ftpCommands
	});
}

sub ftpDeleteFiles
{
	my $ftpCommands = qq{
		ftp $EDIHOST << !!!
		cd $OUTGOINGDIR
	};

	for my $orgInternalId (keys %billId)
	{
		my $pgpFile = $billId{$orgInternalId} . 'ms.zip.pgp';
		$ftpCommands .= qq{delete $pgpFile\n};
	}

	$ftpCommands .= qq{bye
	!!!
	};

	system(qq{$ftpCommands});
}

########
# main
########

ftpGetFiles;
archiveFiles;
ftpDeleteFiles;
