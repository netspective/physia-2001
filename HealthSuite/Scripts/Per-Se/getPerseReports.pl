#!/usr/bin/perl -I.

use strict;
use Date::Manip;

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
	2   => 'phy169',
);
my $now = UnixDate('today', '%Y-%m-%d_%H-%M');

sub archiveFiles
{
	for my $orgInternalId (keys %billId)
	{
		my $pgpFile = $billId{$orgInternalId} . 'ms.zip.pgp';
		my $zipFile = $billId{$orgInternalId} . 'ms.zip';
		my $msgFile = $billId{$orgInternalId} . '.msg';
		my $dlmFile = $billId{$orgInternalId} . '.dlm';
		
		system(qq{
			cd $STAGINGDIR
			if [ -f $pgpFile ]; then
				pgp $pgpFile
				unzip $zipFile

				mkdir -p $ARCHIVEDIR/$orgInternalId
				mkdir -p $ARCHIVEDIR/$orgInternalId/pgp
				mkdir -p $REPORTDIR/$orgInternalId
				mkdir -p $REPORTDELIMDIR/$orgInternalId

				mv $msgFile $REPORTDIR/$orgInternalId/$now.txt
				mv $dlmFile $REPORTDELIMDIR/$orgInternalId/$now.csv
				mv $pgpFile $ARCHIVEDIR/$orgInternalId/pgp/$now.pgp
				mv $zipFile $ARCHIVEDIR/$orgInternalId/$now.zip

				$SCRIPTDIR/ParseReports.pl $REPORTDELIMDIR/$orgInternalId/$now.csv
			fi
		});
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