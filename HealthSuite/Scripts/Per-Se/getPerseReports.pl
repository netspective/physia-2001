#!/usr/bin/perl -I.

use strict;
use Date::Manip;
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
	2   => 'phy169',
);
my $now = UnixDate('today', '%Y-%m-%d_%H-%M');

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
			my $orgInternalId = $orgKey;
			$orgInternalId =~ s/\..*//g;

			my $msgFile = $orgList{$orgKey}->{billingId} . '.msg';
			my $dlmFile = $orgList{$orgKey}->{billingId} . '.dlm';
			
			system(qq{
				cd $STAGINGDIR
				if [ -f $msgFile ]; then
					mkdir -p $REPORTDIR/$orgInternalId
					mv $msgFile $REPORTDIR/$orgInternalId/$now.txt
				fi
				if [ -f $dlmFile ]; then
					mkdir -p $REPORTDELIMDIR/$orgInternalId
					mv $dlmFile $REPORTDELIMDIR/$orgInternalId/$now.csv
					$SCRIPTDIR/ParseReports.pl $REPORTDELIMDIR/$orgInternalId/$now.csv
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