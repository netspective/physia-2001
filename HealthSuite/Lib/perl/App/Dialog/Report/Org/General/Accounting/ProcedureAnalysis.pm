##############################################################################
package App::Dialog::Report::Org::General::Accounting::ProcAnalysis;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

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

	my $personId = $page->field('person_id');
#	my $batchDate = $page->field('batch_date');
	my $batch_from = $page->field('batch_begin_date');
	my $batch_to = $page->field('batch_end_date');	
	#my $orgId = $page->field('org_id');
	my $cptFrom = $page->field('cpt_from');
	my $cptTo = $page->field('cpt_to');
	my $orgIntId=$page->field('org_id');		
	my $allPub =
	{
		columnDefn =>
			[
			{ colIdx => 0, head => 'Physician Name', groupBy => '#0#', dAlign => 'LEFT' },			
			{ colIdx => 1, head => 'Visit Type' ,groupBy => '#1#'},
			{ colIdx => 2, head => 'Code' },
			{ colIdx => 3, head => 'Name'  },
			{ colIdx => 4, head => 'Batch Date' },	
			{ colIdx => 5, head => 'Batch Units' ,summarize => 'sum',  },						
			{ colIdx => 6, head => 'Batch Cost' ,summarize => 'sum', dformat => 'currency' },
			{ colIdx => 7, head => 'Mth Units', hHints=>'Month To Date Units'  },
			{ colIdx => 8, head => 'Mth Unit Cost', hHints=>'Month To Date Unit Cost',dformat => 'currency' },
			{ colIdx => 9, head => 'Yr Units', hHints=>'Year To Date Units'},
			{ colIdx => 10, head => 'Yr Unit Cost', hHints=>'Year To Date Unit Cost' ,dformat => 'currency'},
		],
	};	

	
	#$STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId) if $orgId;
	my $rcpt = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'procAnalysis', $personId,$batch_from,$batch_to,	
		$orgIntId,$cptFrom,$cptTo,$page->session('org_internal_id'));
	my @data = ();
	my $month_cost=0;
	my $year_cost=0;
	my $month_units=0;
	my $year_units=0;	
	my $track_doc=undef;	
	my $track_type=undef;
	my $track_code=undef;
	my $track_proc=undef;
	my $track_year=undef;
	my $track_month=undef;	
	foreach (@$rcpt)
	{
		#Track informatiom so we can sum it up for month and year info
		if(! defined $track_doc)
		{
			$track_doc=$_->{short_sortable_name};
			$track_type=$_->{visit_type};
			$track_code=$_->{code};
			$track_proc=$_->{proc};
			$track_year=$_->{year_date};
			$track_month=$_->{month_date};
			$month_units = $_->{units};
			$year_units = $_->{units};			
			$month_cost = $_->{unit_cost};
			$year_cost = $_->{unit_cost};			
			
		}		
		elsif ($track_doc ne $_->{short_sortable_name} || $track_type ne $_->{visit_type} )
		{
			
			$track_doc=$_->{short_sortable_name};
			$track_type=$_->{visit_type};
			$track_code=$_->{code};
			$track_proc=$_->{proc};
			$track_year=$_->{year_date};
			$track_month=$_->{month_date};
			$month_units = $_->{units};
			$year_units = $_->{units};			
			$month_cost = $_->{unit_cost};
			$year_cost = $_->{unit_cost};				
		}
		elsif ($track_year ne $_->{year_date} )
		{
			$track_doc=$_->{short_sortable_name};
			$track_type=$_->{visit_type};
			$track_code=$_->{code};
			$track_proc=$_->{proc};
			$track_year=$_->{year_date};
			$track_month=$_->{month_date};
			$month_units = $_->{units};
			$year_units = $_->{units};			
			$month_cost = $_->{unit_cost};
			$year_cost = $_->{unit_cost};			
		}
		elsif ($track_month ne $_->{month_date})
		{
			$track_month=$_->{month_date};
			$month_units = $_->{units};
			$month_cost = $_->{unit_cost};			
			$year_units += $_->{units};			
			$year_cost += $_->{unit_cost};	
		}
		else
		{
			$month_units += $_->{units};
			$month_cost += $_->{unit_cost};			
			$year_units += $_->{units};				
			$year_cost += $_->{unit_cost};	
		};		
			
		my @rowData =
		(
			$_->{short_sortable_name},
			$_->{visit_type},
			$_->{code},
			$_->{proc},
			$_->{invoice_date},
			$_->{units},			
			$_->{unit_cost},			
			$month_units,
			$month_cost,
			$year_units,
			$year_cost
		);
		push(@data, \@rowData);		
	}
	return createHtmlFromData($page, 0, \@data,$allPub);		
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
