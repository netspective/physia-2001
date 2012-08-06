##############################################################################
package App::Dialog::Report::Org::General::Accounting::ZipCodes;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;

use App::Statements::Person;
use App::Statements::Report::ClaimStatus;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-zipcodes', heading => 'Zip Code Report');

	$self->addContent(
			new CGI::Dialog::MultiField(caption =>'Start/End Zip Codes', name => 'zipcodes',
				fields => [
					new CGI::Dialog::Field(
						caption => 'Start Zip Code',
						name => 'start_zip_code',
						size => 10,
						),
					new CGI::Dialog::Field(
						caption => 'End Zip Code',
						name => 'end_zip_code',
						size => 10,
						),
				]
			),
			new CGI::Dialog::Field(
				caption => 'Physician ID',
				name => 'provider_id',
				fKeyStmtMgr => $STMTMGR_PERSON,
				fKeyStmt => 'selPersonBySessionOrgAndCategory',
				fKeyDisplayCol => 0,
				fKeyValueCol => 0,
				options => FLDFLAG_PREPENDBLANK),


			new CGI::Dialog::MultiField(caption =>'Insurance Product', name => 'product',
				fields => [
					new CGI::Dialog::Field(
						caption => 'Insurance Product',
						name => 'product_select',
						type => 'bool',
						style => 'check',
						defaultValue => 0
						),
					new CGI::Dialog::Field(
						name => 'primary_product',
						caption => 'Primary only',
						type => 'bool',
						style => 'check',
						defaultValue => 0
						),
				]
			),

			new CGI::Dialog::Field(
				name => 'insurance_select',
				caption => 'Insurance Org',
				type => 'bool',
				style => 'check',
				defaultValue => 0
				),

			new CGI::Dialog::Field(
				name => 'assocprovorg_select',
				caption => 'Associate Provider Org',
				type => 'bool',
				style => 'check',
				defaultValue => 0
				),

			new CGI::Dialog::Field(
				name => 'printReport',
				type => 'bool',
				style => 'check',
				caption => 'Print report',
				defaultValue => 0
			),

			new CGI::Dialog::Field(
				caption =>'Printer',
				name => 'printerQueue',
				options => FLDFLAG_PREPENDBLANK,
				fKeyStmtMgr => $STMTMGR_DEVICE,
				fKeyStmt => 'sel_org_devices',
				fKeyDisplayCol => 0
			),

			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $sessOrg = $page->session('org_internal_id');
	$self->getField('provider_id')->{fKeyStmtBindPageParams} = [$sessOrg, 'Physician'];
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $pub = {
		reportTitle => "Zip Code Report",
		columnDefn => [
			{ colIdx => 0, head => 'Zip Code', hAlign => 'center',dAlign => 'left',dataFmt => '#0#'},
		],
	};

	my $hardCopy = $page->field('printReport');
	my $html;
	my $textOutputFilename;

	# Get a printer device handle...
	my $printerAvailable = 1;
	my $printerDevice;
	$printerDevice = ($page->field('printerQueue') ne '') ? $page->field('printerQueue') : App::Device::getPrinter ($page, 0);
	my $printHandle = App::Device::openPrintHandle ($printerDevice, "-o cpi=17 -o lpi=6");

	$printerAvailable = 0 if (ref $printHandle eq 'SCALAR');


	my $qryStmt = qq{
						select count(distinct person_id) total_patients
						from person_org_category
						where org_internal_id = @{[ $page->session('org_internal_id') ]}
						and category = 'Patient'
					};

	my $totalPatients = $STMTMGR_RPT_CLAIM_STATUS->getSingleValue($page,STMTMGRFLAG_DYNAMICSQL,$qryStmt);

	my $startZipCode =  $page->field('start_zip_code');
	my $endZipCode =  $page->field('end_zip_code');
	my $physician_id = $page->field('provider_id');
	my $assocprovorg = $page->field('assocprovorg_select');
	my $insuranceOrg = $page->field('insurance_select');
	my $primaryProduct = $page->field('primary_product');
	my $insuranceProduct = $page->field('product_select');

	my $zipCodeClause = qq{ and pad.zip between \'$startZipCode\' and \'$endZipCode\' }if($startZipCode ne '' && $endZipCode ne '');
	$zipCodeClause =qq{ and  pad.zip = \'$endZipCode\'} if($startZipCode eq '' && $endZipCode ne '');
	$zipCodeClause =qq{ and  pad.zip = \'$startZipCode\' } if($startZipCode ne '' && $endZipCode eq '');

	my $columns = "distinct substr(pad.zip, 1, 5) zipcode, count(p.person_id) patients";
	my $tables = " person p, person_address pad, person_org_category poc" ;
	my $where = " p.person_id = poc.person_id";
	$where = $where . " and poc.org_internal_id = " . $page->session('org_internal_id');
	$where = $where . " and poc.category = \'Patient\'";
	$where = $where . " and pad.address_name = \'Home\'";
	$where = $where . " and p.person_id = pad.parent_id" . $zipCodeClause;
	my $group = "substr(pad.zip, 1, 5)";

	my $columnNo = 1;

	if ($page->field('provider_id') ne '')
	{
		$columns = $columns . ", pph.simple_name doctor";
		$tables = $tables . ", person pph , person_attribute pat1 " ;
		$group = $group . ", pph.simple_name ";

		$where = $where . " and p.person_id = pat1.parent_id (+)";
		$where = $where . " and pat1.value_text = pph.person_id" ;
		$where = $where . " and pat1.value_type = 210" ;
		$where = $where . " and pat1.value_text = \'" . $page->field('provider_id') . "\'";
		$where = $where . " and pat1.value_int = 1" if ($page->field('primary_provider') ne '');

		my $pubCol = { colIdx => $columnNo, head => 'Doctor', dAlign => 'left', dataFmt => '#' . $columnNo . '#' };
		push(@{$pub->{columnDefn}}, $pubCol);
		$columnNo++;
	}

	if ($page->field('assocprovorg_select') ne '')
	{
		$columns = $columns . ", pat2.value_text org";
		$tables = $tables . ", person_attribute pat2";
		$where = $where . " and p.person_id = pat2.parent_id (+)";
		$where = $where . "	and pat2.item_name = 'Office Location' ";
		$group = $group . ", pat2.value_text ";
		my $pubCol = { colIdx => $columnNo, head => 'Assoc Org', dAlign => 'left', dataFmt => '#' . $columnNo . '#' };
		push(@{$pub->{columnDefn}}, $pubCol);
		$columnNo++;
	}

	if ($page->field('insurance_select') ne '' || $page->field('product_select') ne '')
	{
		$tables = $tables . ", org o, insurance i";
		$where = $where . "	and p.person_id = i.owner_person_id (+) and i.ins_org_id = o.org_internal_id";
		$where = $where . "	and i.bill_sequence = 1 " if ($page->field('primary_product') ne '');
		if ($page->field('insurance_select') ne '')
		{
			$columns = $columns . ", o.org_id ins_org ";
			$group = $group . ", o.org_id";
			my $pubCol = { colIdx => $columnNo, head => 'Insuance Org', dAlign => 'left', dataFmt => '#' . $columnNo . '#' };
			push(@{$pub->{columnDefn}}, $pubCol);
			$columnNo++;
		}

		if ($page->field('product_select') ne '')
		{
			$columns = $columns . ", i.product_name product";
			$group = $group . ", i.product_name";
			my $pubCol = { colIdx => $columnNo, head => 'Product', dAlign => 'left', dataFmt => '#' . $columnNo . '#' };
			push(@{$pub->{columnDefn}}, $pubCol);
			$columnNo++;
		}
	}

	my $pubCol = { colIdx => $columnNo, head => '# of Patients', dAlign => 'right', dataFmt => '#' . $columnNo . '#' };
	push(@{$pub->{columnDefn}}, $pubCol);
	$columnNo++;

	my $pubCol = { colIdx => $columnNo, head => '% of Patients', dAlign => 'right' };
	push(@{$pub->{columnDefn}}, $pubCol);
	$columnNo++;

	my $sqlStmt = qq 	{
							select
								$columns
							from
								$tables
							where
								$where
							group by
								$group
							order by
								$group
						};

	my $rows = $STMTMGR_RPT_CLAIM_STATUS->getRowsAsHashList($page,STMTMGRFLAG_DYNAMICSQL,$sqlStmt);
	my @data = ();
	my $fieldsExist;
	my $currentTotal = 0;
	my $currentPercent = 0;
	foreach (@$rows)
	{
		my @rowData = ($_->{zipcode});
		push (@rowData, $_->{doctor}) if exists $_->{doctor};
		push (@rowData, $_->{org}) if exists $_->{org};
		push (@rowData, $_->{ins_org}) if exists $_->{ins_org};
		push (@rowData, $_->{product}) if exists $_->{product};
		push (@rowData, $_->{patients});
		push (@rowData, sprintf "%3.2f%", ($_->{patients}/$totalPatients) * 100);

		$fieldsExist = $_;
		$currentTotal += $_->{patients};
		$currentPercent += (($_->{patients}/$totalPatients) * 100);

		push(@data, \@rowData);
	};

	if($fieldsExist ne '')
	{
		my @rowData = ("Selected Zips Subtotal");
		push (@rowData, ' ') if exists $fieldsExist->{doctor};
		push (@rowData, ' ') if exists $fieldsExist->{org};
		push (@rowData, ' ') if exists $fieldsExist->{ins_org};
		push (@rowData, ' ') if exists $fieldsExist->{product};
		push (@rowData, $currentTotal);
		push (@rowData, sprintf "%3.2f%", $currentPercent);
		push (@data, \@rowData);
	}

	if($fieldsExist ne '')
	{
		my @rowData = ("Unselected and Unknowns");
		push (@rowData, ' ') if exists $fieldsExist->{doctor};
		push (@rowData, ' ') if exists $fieldsExist->{org};
		push (@rowData, ' ') if exists $fieldsExist->{ins_org};
		push (@rowData, ' ') if exists $fieldsExist->{product};
		push (@rowData, $totalPatients - $currentTotal);
		push (@rowData, sprintf "%3.2f%", 100 - $currentPercent);
		push (@data, \@rowData);
	}

	if($fieldsExist ne '')
	{
		my @rowData = ("Grand Total");
		push (@rowData, ' ') if exists $fieldsExist->{doctor};
		push (@rowData, ' ') if exists $fieldsExist->{org};
		push (@rowData, ' ') if exists $fieldsExist->{ins_org};
		push (@rowData, ' ') if exists $fieldsExist->{product};
		push (@rowData, $totalPatients);
		push (@rowData, sprintf "%3.2f%", 100);
		push (@data, \@rowData);
	}

	 $html = createHtmlFromData($page, 0, \@data, $pub);
	$textOutputFilename = createTextRowsFromData($page, 0, \@data, $pub);

	my $tempDir = $CONFDATA_SERVER->path_temp();
	my $Constraints = [
	{ Name => "Start/End ZIP Code ", Value => $startZipCode."  ".$endZipCode},
	{ Name => "Physician ID ", Value => $physician_id},
	{ Name => "Insurance Product ", Value => ((($insuranceProduct) ? 'Yes ' : 'No ') . "Insurance Product ") . ((($primaryProduct) ? 'Yes ' : 'No ') . "Primary Only")},
	{ Name => "Insurance Org ", Value =>($insuranceOrg) ? 'Yes' : 'No'},
	{ Name => "Associate Provider Org ", Value => ($assocprovorg) ? 'Yes' : 'No'},
	{ Name=> "Print Report ", Value => ($hardCopy) ? 'Yes' : 'No' },
	{ Name=> "Printer ", Value => $printerDevice},
	];
	my $FormFeed = appendFormFeed($tempDir.$textOutputFilename);
	my $fileConstraint = appendConstraints($page, $tempDir.$textOutputFilename, $Constraints);

	if ($hardCopy == 1 and $printerAvailable) {
		my $reportOpened = 1;
		open (ASCIIREPORT, $tempDir.$textOutputFilename) or $reportOpened = 0;
		if ($reportOpened) {
			while (my $reportLine = <ASCIIREPORT>) {
				print $printHandle $reportLine;
			}
		}
		close ASCIIREPORT;
	}

	return ($textOutputFilename ? qq{<a href="/temp$textOutputFilename">Printable version</a> <br>} : "" ) . $html;

	#return $html;

}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;