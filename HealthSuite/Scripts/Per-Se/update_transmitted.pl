#!/usr/bin/perl -I.

use strict;
use DBI;
use App::Data::Manipulate;

sub getClaimDetails
{
	my ($dbh, $sortedClaims) = @_;

	my $sqlStmt = qq{
		select to_char(i.invoice_id, '9999999'), substr(rpad(initcap(p.complete_sortable_name), 30), 1, 30),
			substr(rpad(initcap(nvl(o.name_primary, 'N/A')), 25), 1, 25), 
			to_char(i.balance, '\$99999.99'), i.balance
		from org o, person p, invoice_billing ib, invoice i
		where i.invoice_id in (@{[ join(',', @{$sortedClaims}) ]})
			and ib.bill_id = i.billing_id
			and p.person_id = i.client_id
			and to_char(o.org_internal_id (+)) = ib.bill_to_id
	};

	my $sth = $dbh->prepare($sqlStmt);
	$sth->execute();
	
	my $claimDetails;
	my $numClaims = 0;
	my $total = 0;
	
	while(my $row = $sth->fetch())
	{
		$numClaims++;
		$total += $row->[4];
		$claimDetails .= "$row->[0]  $row->[1] $row->[2] $row->[3]\n";
	}
	
	return ($claimDetails, $numClaims, $total);
}


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
	next unless $claimNo;

	push(@transmittedClaims, $claimNo);
}

my @sortedClaims = sort {$a <=> $b} @transmittedClaims;

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
	print "$sqlStmt\n";
	my $result = $sth->execute();
	print "$result\n";

	$sth->finish();
}

my ($claimDetails, $numClaims, $total) = getClaimDetails($dbh, \@sortedClaims);

$dbh->disconnect();

use Mail::Sendmail;

my $sendMailTo = $ENV{TESTMODE} ? 'thai_nguyen@physia.com' : 'help@physia.com';
my $user = getpwuid($>) || '';

my %mail =
(	To => $sendMailTo,
	From => $user . '@physia.com',
	Cc => 'thai_nguyen@physia.com',
	Subject => "Claims Submission to Per-Se - " . `date`,
	Message => "The following claims were submitted to Per-Se in file $nsfFileName:\n\n"
		. "Number of Claims:  $numClaims\n"
		. qq{Total Dollars:  \$@{[ App::Data::Manipulate::trim(sprintf("%9.2f", $total)) ]}\n\n}
	 	. $claimDetails,
	Smtp => 'smtp.physia.com',
);

sendmail(%mail) or die $Mail::Sendmail::error;
