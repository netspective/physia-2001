#!/usr/bin/perl -I.

use strict;
use DBI;

my $batchSize = 100;

my $cs = shift;
die "Usage Example:  $0 sde_prime/sde\@sdedbs02 file.nsf" unless $cs;
my $nsfFileName = shift;

open (NSF, "$nsfFileName") || die "Unable to open '$nsfFileName': $!\n";

$cs =~ /(.*?)\/(.*?)\@(.*)/;
my ($userName, $password, $twoTask) =  ($1, $2, $3);

my $dbh = DBI->connect('dbi:Oracle:' . $twoTask, $userName, $password,
	{ RaiseError => 1, AutoCommit => 0 }) || die "Unable To Connect to Database: $!";

my @transmittedClaims = ();
while(<NSF>)
{
	chomp;
	next unless /^FA001(.*?)\s/;

	my $claimNo = $1;
	push(@transmittedClaims, $claimNo);
}

my @sortedClaims = sort @transmittedClaims;
print "@sortedClaims\n";

my @inStrings = ();
for(my $i=0; $i< scalar @sortedClaims; $i += $batchSize)
{
	my $string = qq{@{[ join(',', @sortedClaims[$i..$i+$batchSize-1]) ]}};
	$string =~ s/,+$//;
	push(@inStrings, "($string)");
}

my @sqlStmts = ();
for (@inStrings)
{
	push(@sqlStmts, "update Invoice set invoice_status = 5 where invoice_id in " . $_);
}

for my $sqlStmt (@sqlStmts)
{
	my $sth = $dbh->prepare($sqlStmt);
	my $result = $sth->execute();

	print "$sqlStmt\n";
	print "$result\n";

	$sth->finish();
}

$dbh->disconnect();

use Mail::Sendmail;

my $sendMailTo = 'help@physia.com';
my $user = getpwuid($>) || '';

my %mail =
(	To => $sendMailTo,
	From => $user . '@physia.com',
	Cc => 'thai_nguyen@physia.com',
	Subject => "Claims Submission to Per-Se - " . `date`,
	Message => "The following claims were submitted to Per-Se today:\n\n"
		. "@{[ join(', ', @sortedClaims) ]}." ,
	Smtp => 'smtp.physia.com',
);

sendmail(%mail) or die $Mail::Sendmail::error;
