#!/usr/bin/perl -I.

use strict;
use Getopt::Long;
use App::Configuration;
use App::External;
use DBI::StatementManager;
use App::Statements::External;
use App::Universal;

########
# main
########

my ($db);
GetOptions ('db=s', \$db);
$CONFDATA_SERVER = $App::Configuration::AVAIL_CONFIGS{$db};

my ($page, $sqlPlusKey) = App::External::connectDB();

my $sqlStmt = qq{
	select rpad(org_id, 16, ' ') as org_id, to_char(submit_date, 'mm/dd/yyyy') as submit_date,
	to_char(trunc(sysdate-submit_date), '9999') as days, to_char(count(*), '9999') as count
	from org, invoice
	where invoice_status = :1
		and org_internal_id = owner_id
	group by org_id, submit_date, trunc(sysdate-submit_date)
};

my $message = "\n";

# Transferred
# -----------
$message .= "\nORG\t\t\t SUBMIT DATE \t  DAYS\t # TRANSFERRED";
$message .= "\n---\t\t\t ----------- \t  ----\t -------------\n";

my $transferred = $STMTMGR_EXTERNAL->getRowsAsHashList($page, STMTMGRFLAG_DYNAMICSQL, 
	$sqlStmt, App::Universal::INVOICESTATUS_TRANSFERRED);
for (@{$transferred})
{
	$message .= "$_->{org_id}\t $_->{submit_date} \t $_->{days}\t\t $_->{count}\n";
}
$message .= "\n\n";

# Rejected Internal
# -----------------
$message .= "\nORG\t\t\t SUBMIT DATE \t  DAYS\t # REJECTED INTERNAL";
$message .= "\n---\t\t\t ----------- \t  ----\t -------------------\n";

my $transferred = $STMTMGR_EXTERNAL->getRowsAsHashList($page, STMTMGRFLAG_DYNAMICSQL, 
	$sqlStmt, App::Universal::INVOICESTATUS_INTNLREJECT);
for (@{$transferred})
{
	$message .= "$_->{org_id}\t $_->{submit_date} \t $_->{days}\t\t $_->{count}\n";
}
$message .= "\n\n";

# Rejected External
# -----------------
$message .= "\nORG\t\t\t SUBMIT DATE \t  DAYS\t # REJECTED EXTERNAL";
$message .= "\n---\t\t\t ----------- \t  ----\t -------------------\n";

my $transferred = $STMTMGR_EXTERNAL->getRowsAsHashList($page, STMTMGRFLAG_DYNAMICSQL, 
	$sqlStmt, App::Universal::INVOICESTATUS_EXTNLREJECT);
for (@{$transferred})
{
	$message .= "$_->{org_id}\t $_->{submit_date} \t $_->{days}\t\t $_->{count}\n";
}
$message .= "\n\n";

use Mail::Sendmail;

my $sendMailTo = $ENV{TESTMODE} ? 'thai_nguyen@physia.com' : 'help@physia.com';
my $user = getpwuid($>) || '';

my %mail =
(	To => $sendMailTo,
	From => $user . '@physia.com',
	Cc => 'thai_nguyen@physia.com',
	Subject => "Production Claims in Limbo -- " . `date`,
	Message => $message,
	Smtp => 'smtp.physia.com',
);

sendmail(%mail) or die $Mail::Sendmail::error;
