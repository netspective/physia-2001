#!/usr/bin/perl -I.

# PerSe's REPORT field indicates "T0XS" where: 
#	T = Report Type
#		H = PerSe Generated Report
#		P = Payer Generated Report
#	X = Stage
#		For PerSe "H" Reports:
#			2 = Submission
#			3 = ReSubmission
#		For Payer "P" Reports:
#			1 = ?
#			2 = ?
#			3 = ?
#			4 = ?
#	S = Status
#		For PerSe "H" Reports:
#			0 = Error/Warning
#			1 = Acknowledgement
#		For Payer Reports:
#			0 = ?
#			0 = ?

use strict;
use Date::Manip;
use Schema::API;
use App::Data::MDL::Module;
use FindBin qw($Bin);
use App::Universal;
use App::Configuration;
use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::External;


my @fields = (
	'DATE', 'REPORT', 'TAXID', 'PROV_NM', 'OMS_IDNO', 
	'PAY_NAME', 'CLMPRCDATE', 'CLAIMID', 'CLAIMSEQID',
	'EMCTYPE', 'PAT_ACTNO', 'PAT_LNM', 'PTA_FNM',
	'PAT_DOB', 'PAT_PHONE', 'INS_IDNO', 'INS_GRPNO',
	'INS_LNM', 'INS_FNM', 'ICD1_CODE', 'CPT1_FDT',
	'CPT1_TDT', 'CPT1_POS', 'CPT1_CODE', 'CPT1_MOD1',
	'CPT1_UNIT', 'CPT1_CHG', 'CPT1_DRID', 'PHY_NM',
	'PROV_IDNO', 'TOTAL_CHG', 'TOT_CLMS', 'ACC_CLMS',
	'ACC_CHGS', 'RCVCTRLNO', 'PAYER_PD', 'PAID_DT', 
	'STATUSDESC', 'STATUSMSG', 'CRSPCONTCT', 'CRSPPHONE',
	'CRSPNAME', 'CRSPADDR1', 'CRSPCITY', 'CRSPSTATE',
	'CRSPZIP', 'SRCCTRLNO', 'TRANSSEQ', 'FORMTYPE',
	'ERRORCODE', 'ERRORFLAG', 'PAYNO'
);

# Set up fields hash for a Pseudo-Hash
my $i = 1;
my %fields = map { $_, $i++ } @fields;

# Array of Per-Se/Payer reports (each as a Psuedo-Hash)
my @reports = ();

# Connect to the database
my $page = new App::Data::MDL::Module();
$page->{schema} = undef;
$page->{schemaFlags} = SCHEMAAPIFLAG_LOGSQL | SCHEMAAPIFLAG_EXECSQL;
if($CONFDATA_SERVER->db_ConnectKey() && $CONFDATA_SERVER->file_SchemaDefn())
{
	my $schemaFile = $CONFDATA_SERVER->file_SchemaDefn();
	print STDOUT "Loading schema from $schemaFile\n";
	$page->{schema} = new Schema::API(xmlFile => $schemaFile);
	
	my $connectKey = $CONFDATA_SERVER->db_ConnectKey();
	print STDOUT "Connecting to $connectKey\n";
	$page->{schema}->connectDB($connectKey);
	$page->{db} = $page->{schema}->{dbh};
}
else
{
	die "DB Schema File and Connect Key are required!";
}

# Read the reports from the file specified on the command line
&parseFile($ARGV[0], \@reports, \%fields);

# Enter The Dragon
foreach my $report (@reports)
{
	my $message = '';
	my $status = '';
	
	# Perl CASE Statement (really) :-)
	for ($report->{REPORT})
	{
		/H020/		and do {
						$message = "Per-Se Claim Transmission";
						if ($report->{ERRORFLAG} eq 'E')
						{
							$message .= " Error $report->{ERRORCODE}";
							$status = App::Universal::INVOICESTATUS_INTNLREJECT;
						}
						else
						{
							$message .= " Warning $report->{ERRORCODE}";
						}
						last;
					};
		/H021/		and do {
						$message = "Per-Se Transmitted Claim To Payer Successfully";
						if ($report->{EMCTYPE} eq 'PAP')
						{
							$status = App::Universal::INVOICESTATUS_MTRANSFERRED;
						}
						else
						{
							$status = App::Universal::INVOICESTATUS_ETRANSFERRED;
						}
						last;
					};
		/H030/		and do {
						$message = "Per-Se Claim ReTransmission";
						if ($report->{ERRORFLAG} eq 'E')
						{
							$message .= " Error $report->{ERRORCODE}";
							$status = App::Universal::INVOICESTATUS_INTNLREJECT;
						}
						else
						{
							$message .= " Warning $report->{ERRORCODE}";
						}
						last;
					};
		/H031/		and do {
						$message = "Per-Se ReTransmitted Claim To Payer Successfully";
						if ($report->{EMCTYPE} eq 'PAP')
						{
							$status = App::Universal::INVOICESTATUS_MTRANSFERRED;
						}
						else
						{
							$status = App::Universal::INVOICESTATUS_ETRANSFERRED;
						}
						last;
					};
		/P020/		and do {
						$message = "Payer Accepted Claim";
						$status = App::Universal::INVOICESTATUS_AWAITPAYMENT;
						last;
					};
		/P030/		and do {
						$message = "Payer Rejected Claim";
						$status = App::Universal::INVOICESTATUS_EXTNLREJECT;
						last;
					};
		/P031/		and do {
						$message = "Payer Returned Warning";
						$status = App::Universal::INVOICESTATUS_AWAITPAYMENT;
						last;
					};
		/P040/		and do {
						$message = "Payer Returned Zero Payment";
						$status = App::Universal::INVOICESTATUS_EXTNLREJECT;
						last;
					};
		/P041/		and do {
						$message = "Payer Returned Claim Status";
						last;
					};
		/P042/		and do {
						$message = "Payer Requested Additional Information";
						$status = App::Universal::INVOICESTATUS_EXTNLREJECT;
						last;
					};
	}
	
	# Build an appropriate Invoice History Message
	my $msgDetail = '';
	$msgDetail .= $report->{STATUSDESC} if $report->{STATUSDESC};
	$msgDetail .= " " if $report->{STATUSDESC} && $report->{STATUSMSG};
	$msgDetail .= "'$report->{STATUSMSG}'" if $report->{STATUSMSG};
	$msgDetail = " ($msgDetail)" if $msgDetail;
	$msgDetail .= " Paid: \$$report->{PAYER_PD}" if $report->{PAYER_PD} ne '0.00';
	$message = "$message$msgDetail";
	print "Invoice $report->{PAT_ACTNO}: '$message' STATUS($status)\n";
	
	my $addedHistory = &addInvoiceHistory($page, $report->{DATE}, $report->{PAT_ACTNO}, 
		$message, $report->{PAYER_PD});
	if ($report->{PAT_ACTNO} && $status && $addedHistory)
	{
		&changeInvoiceStatus($page, $report->{PAT_ACTNO}, $status);
	}
	else
	{
		print "NO UPDATE STATUS ($report->{PAT_ACTNO}, $status)\n\n";
	}
}


# Read a PerSe status file into an array of psuedo-hashes
sub parseFile
{
	my $fileName = shift;
	my $array = shift;
	my $fields = shift;
	
	die "\nUsage: $0 reportfile\n" unless defined $fileName;
	open INFILE, "<$fileName" or die "Cannot open $fileName";
	while (<INFILE>)
	{
		# Remove trailing [CR]LF
		chomp;
		# Remove quotes and embedded commas
		s["([^"]*)"] [my $i = $1; $i =~ tr/,//d; $i]ge; #"
		# Split it up into fields
		my @pHash = split ',', $_;
		# Make the array into a Psuedo-Hash
		unshift @pHash, $fields;
		# Push it on to the master array
		push(@$array, \@pHash);
	}
	close INFILE;
}

sub addInvoiceHistory
{
	my ($page, $date, $invoice, $message, $amtPaid) = @_;
	
	return 0 unless $invoice;
	
	$date = UnixDate($date, '%m/%d/%Y');
	my $invAttribute = $STMTMGR_EXTERNAL->getRowsAsHashList($page, STMTMGRFLAG_CACHE,
		'sel_InvoiceAttribute', $invoice, 'Invoice/History/Item', $message, $date);
		
	if (@{$invAttribute})
	{
		for (@{$invAttribute})
		{
			print "EXISTING: $_->{item_id} - $_->{cr_stamp}: $_->{value_text} - $_->{value_date} \n";
		}
		return 0;
	}

	return $page->schemaAction(0, 'Invoice_Attribute', 'add',
		parent_id => $invoice,
		cr_user_id => 'EDI_PERSE',
		item_name => 'Invoice/History/Item',
		value_type => App::Universal::ATTRTYPE_HISTORY,
		value_text => $message,
		value_date => $date,
		value_float => $amtPaid || undef,
	);
}

sub changeInvoiceStatus
{
	my ($page, $invoice, $status) = @_;

	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoice);
	
	return if $invoiceInfo->{invoice_status} == App::Universal::INVOICESTATUS_VOID
			|| $invoiceInfo->{invoice_status} == App::Universal::INVOICESTATUS_CLOSED;
	
	return $page->schemaAction(0, 'Invoice', 'update', 
		invoice_id => $invoice,
		invoice_status => $status,
		flags => App::Universal::INVOICESTATUS_INTNLREJECT || App::Universal::INVOICESTATUS_EXTNLREJECT 
				|| App::Universal::INVOICESTATUS_AWAITPAYMENT ? 0 : $invoiceInfo->{flags},
	);
}
