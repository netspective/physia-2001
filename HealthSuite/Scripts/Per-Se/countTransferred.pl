#!/usr/bin/perl -I.

use strict;
use Getopt::Long;
use App::Configuration;
use App::External;
use DBI::StatementManager;
use App::Statements::External;

########
# main
########

my ($db);
GetOptions ('db=s', \$db);
$CONFDATA_SERVER = $App::Configuration::AVAIL_CONFIGS{$db};

my ($page, $sqlPlusKey) = App::External::connectDB();

my $sqlStmt = qq{
	select rpad(org_id, 16, ' ') as org_id, to_char(submit_date, 'mm/dd/yyyy') as submit_date,
	trunc(sysdate-submit_date) as days, count(*) as count
	from org, invoice
	where invoice_status = 5
		and org_internal_id = owner_id
	group by org_id, submit_date, trunc(sysdate-submit_date)
};

my $results = $STMTMGR_EXTERNAL->getRowsAsHashList($page, STMTMGRFLAG_DYNAMICSQL, $sqlStmt);

my $message = "\nORG\t\t\t SUBMIT DATE \t DAYS\t COUNT \n\n";
for (@{$results})
{
	$message .= "$_->{org_id}\t $_->{submit_date} \t $_->{days}  \t $_->{count}\n";
}

use Mail::Sendmail;

my $sendMailTo = $ENV{TESTMODE} ? 'thai_nguyen@physia.com' : 'help@physia.com';
my $user = getpwuid($>) || '';

my %mail =
(	To => $sendMailTo,
	From => $user . '@physia.com',
	Cc => 'thai_nguyen@physia.com',
	Subject => "Production Claims in Transferred Status -- " . `date`,
	Message => "COUNT is the number of claims in Transferred Status:\n" . $message,
	Smtp => 'smtp.physia.com',
);

sendmail(%mail) or die $Mail::Sendmail::error;
