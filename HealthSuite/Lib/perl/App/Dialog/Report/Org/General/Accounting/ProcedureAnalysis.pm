##############################################################################
package App::Dialog::Report::Org::General::Accounting::ProcAnalysis;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;
use Date::Calc qw(:all);
use Date::Manip;
use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Org;
use Data::Publish;
use App::Statements::Component::Invoice;
use App::Statements::Report::Accounting;
use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-acct-proc-receipt-analysis', heading => 'Procedure Analysis');

	$self->addContent(
			#new CGI::Dialog::Field(
			#	name => 'batch_date',
			#	caption => 'Batch Report Date',
			#	type =>'date',
			#	options=>FLDFLAG_REQUIRED,
			#	),
			new CGI::Dialog::Field::Duration(
				name => 'batch',
				caption => 'Batch Report Date',
				begin_caption => 'Report Begin Date',
				end_caption => 'Report End Date',
				options=>FLDFLAG_REQUIRED,
				),			
			#new App::Dialog::Field::Organization::ID(caption =>'Site Organization ID', name => 'org_id'),
		new App::Dialog::Field::OrgType(
			caption => 'Site Organization ID',
			name => 'org_id',
			options => FLDFLAG_PREPENDBLANK,
			types => "'PRACTICE', 'CLINIC','FACILITY/SITE','DIAGNOSTIC SERVICES', 'DEPARTMENT', 'HOSPITAL', 'THERAPEUTIC SERVICES'",
			),			
			new App::Dialog::Field::Person::ID(caption =>'Physican ID', name => 'person_id', ),
			new CGI::Dialog::MultiField(caption => 'CPT From/To', name => 'cpt_field', 
						fields => [
			new CGI::Dialog::Field(caption => 'CPT From', name => 'cpt_from', size => 12),
			new CGI::Dialog::Field(caption => 'CPT To', name => 'cpt_to', size => 12),
				]),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');;
	my $batch_from = $page->field('batch_begin_date');
	my $batch_to = $page->field('batch_end_date');	
	my $cptFrom = $page->field('cpt_from');
	my $cptTo = $page->field('cpt_to');
	my $orgIntId=$page->field('org_id');	
	my $inc_date = 0;
	if($batch_from eq $batch_to)
	{
		$inc_date = 1;
	}	
	my $allPub;
	if (!$inc_date)
	{
	 $allPub =
		{
		columnDefn =>
			[
			{ colIdx => 0, ,hAlign=>'left',head => 'Physician Name', groupBy => '#0#', dAlign => 'LEFT' },			
			{ colIdx => 1,,hAlign=>'left', head => 'Visit Type' ,groupBy => '#1#'},
			{ colIdx => 2,,hAlign=>'left', head => 'Code' },
			{ colIdx => 3,,hAlign=>'left', head => 'Name'  },
			{ colIdx => 4, head => 'Mth Units', summarize => 'sum',hHints=>'Month To Date Units'  },
			{ colIdx => 5, head => 'Mth Unit Cost', summarize => 'sum',hHints=>'Month To Date Unit Cost',dformat => 'currency' },
			{ colIdx => 6, head => 'Yr Units', summarize => 'sum',hHints=>'Year To Date Units'},
			{ colIdx => 7, head => 'Yr Unit Cost',summarize => 'sum', hHints=>'Year To Date Unit Cost' ,dformat => 'currency'},
		],
		};	
	}
	else
	{
	 $allPub =
		{
		columnDefn =>
			[
			{ colIdx => 0, ,hAlign=>'left',head => 'Physician Name', groupBy => '#0#', dAlign => 'LEFT' },			
			{ colIdx => 1, ,hAlign=>'left',head => 'Visit Type' ,groupBy => '#1#'},
			{ colIdx => 2, ,hAlign=>'left',head => 'Code' },
			{ colIdx => 3, ,hAlign=>'left',head => 'Name'  },
			{ colIdx => 8, ,hAlign=>'left',head => 'Batch Date' },	
			{ colIdx => 9, ,hAlign=>'left',head => 'Batch Units' ,summarize => 'sum',  },						
			{ colIdx => 10, head => 'Batch Cost' ,summarize => 'sum', dformat => 'currency' },
			{ colIdx => 4, head => 'Mth Units',summarize => 'sum', hHints=>'Month To Date Units'  },
			{ colIdx => 5, head => 'Mth Unit Cost', summarize => 'sum',hHints=>'Month To Date Unit Cost',dformat => 'currency' },
			{ colIdx => 6, head => 'Yr Units', summarize => 'sum',hHints=>'Year To Date Units'},
			{ colIdx => 7, head => 'Yr Unit Cost',summarize => 'sum', hHints=>'Year To Date Unit Cost' ,dformat => 'currency'},
		],
		};	
	
	}


	my $orgInternalId = $page->field('org_id') || $page->session('org_internal_id');
	
	#Get Fiscal year for Main Org
	my $fiscal = $STMTMGR_ORG->getRowAsHash($page,STMTMGRFLAG_NONE,'selAttribute',$orgInternalId,'Fiscal Month');	
	
	#month is 1 less so add a 1
	my $month = $fiscal->{value_int}+1;	
	
	#Check if end date is less then fiscal month if so go back one year
	my @start_Date = Decode_Date_US($batch_from);
	if ($start_Date[1] < $month)
	{
		#Go back one year
		$start_Date[0]--;
	}
	#Use Fiscal month
	$start_Date[1] = $month;
	
	#First of fiscal month
	$start_Date[2] = 1;
	
	my $startDate = sprintf("%02d/%02d/%04d", $start_Date[1],$start_Date[2],$start_Date[0]);

	#Convert to first day of fiscal month
	$batch_from =$startDate;

	
	#$STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;
	my $rcpt = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'procAnalysis', $personId,$batch_from,$batch_to,	
		$orgIntId,$cptFrom,$cptTo,$page->session('org_internal_id'));
	my @data = ();
	foreach (@$rcpt)
	{
		my @rowData =
		(
			$_->{simple_name},
			$_->{visit_type},
			$_->{code},
			$_->{proc},
			$_->{month_units},
			$_->{month_cost},
			$_->{year_units},
			$_->{year_cost},
			$batch_to,
			$_->{batch_units},
			$_->{batch_cost},
			
		);
		push(@data, \@rowData);		
	}
	my $html = '<br> <b style="font-family:Helvetica; font-size:10pt">(Fiscal Range '. $batch_from .' - ' . $batch_to . ' ) </b><br>';
	$html .= createHtmlFromData($page, 0, \@data,$allPub);
	return $html;
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
