##############################################################################
package App::Dialog::Report::Org::General::Accounting::CloseDate;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use Data::Publish;
use App::Statements::Report::CloseDate;
use App::Statements::Person;

use Date::Manip;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub publishDefn
{
	my ($heading) = @_;
	
	return {
		columnDefn => [
			{ colIdx => 0, head => $heading, hAlign => 'left',
				dAlign => 'left',
			},
			{ colIdx => 1, head => '#param._f_close_date#', hAlign => 'right',
				dAlign => 'right', dformat => 'currency',
			},
			{ colIdx => 2, head => 'This Month', hAlign => 'right',
				dAlign => 'right', dformat => 'currency',
			},
			{ colIdx => 3, head => 'This Year', hAlign => 'right',
				dAlign => 'right', dformat => 'currency',
			},
		],
	};
}

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-close-date',	heading => 'Close Date Report');

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Close Date',
			name => 'close_date',
			type=> 'date',
			defaultValue => '',
			options => FLDFLAG_REQUIRED,
			futureOnly => 0
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);
	$self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('close_date', $page->param('close_date'));
}

sub customValidate
{
	my ($self, $page) = @_;
}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $dateFormat = $page->{defaultUnixDateFormat};
	
	my $orgInternalId = $page->session('org_internal_id');
	my $closeDate = $page->field('close_date');
	my $closeMonth = UnixDate($closeDate, '%m/%Y');
		
	my $today = UnixDate('today', $dateFormat);
	my $fiscalMonth = '01';
	my ($cMonth, $cDay, $cYear) = split('/', $today);
	my $fiscalYear = $cMonth >= $fiscalMonth ? $cYear : $cYear -1;
	my $fiscalYearBeginDate = "$fiscalMonth/01/$fiscalYear";

	my $orgDay = $STMTMGR_REPORT_CLOSEDATE->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_orgTotalsForDate', $orgInternalId, $closeDate);

	my $orgMonth = $STMTMGR_REPORT_CLOSEDATE->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_orgTotalsForMonth', $orgInternalId, $closeMonth, $closeDate);

	my $orgYear = $STMTMGR_REPORT_CLOSEDATE->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_orgTotalsForYear', $orgInternalId, $fiscalYearBeginDate, $closeDate);

	my $dayStartAR = $STMTMGR_REPORT_CLOSEDATE->getSingleValue($page, STMTMGRFLAG_NONE,
		'sel_orgDayStartingAR', $orgInternalId, $closeDate);

	my $monthStartAR = $STMTMGR_REPORT_CLOSEDATE->getSingleValue($page, STMTMGRFLAG_NONE,
		'sel_orgMonthStartingAR', $orgInternalId, $closeMonth);
		
	my $yearStartAR = $STMTMGR_REPORT_CLOSEDATE->getSingleValue($page, STMTMGRFLAG_NONE,
		'sel_orgYearStartingAR', $orgInternalId, $fiscalYearBeginDate);

	my @data = (
		['<b>STARTING A.R</b>', $dayStartAR || 0, $monthStartAR || 0, $yearStartAR || 0],
		[undef, undef, undef, undef],

		['<b>CHARGES</b>', $orgDay->{total_charges} || 0, $orgMonth->{total_charges} || 0, $orgYear->{total_charges} || 0],
		[undef, undef, undef, undef],

		['<b>RECEIPTS</b>', undef, undef, undef],
		['Personal', - $orgDay->{person_pay} || 0, - $orgMonth->{person_pay} || 0, - $orgYear->{person_pay} || 0],
		['Insurance', - $orgDay->{insurance_pay} || 0, - $orgMonth->{insurance_pay} || 0, - $orgYear->{insurance_pay} || 0],
		['<b>Total</b>', - ($orgDay->{person_pay}+$orgDay->{insurance_pay}), - ($orgMonth->{person_pay}+$orgMonth->{insurance_pay}), - ($orgYear->{person_pay}+$orgYear->{insurance_pay})],
		
		[undef, undef, undef, undef],
		['<b>ADJUSTMENTS</b>', undef, undef, undef],
		['Courtesy Adjustments', - $orgDay->{courtesy_adj} || 0, - $orgMonth->{courtesy_adj} || 0, - $orgYear->{courtesy_adj} || 0],
		['Contractual (Insurance Write-offs)', - $orgDay->{contractual_adj} || 0, - $orgMonth->{contractual_adj} || 0, - $orgYear->{contractual_adj} || 0],
		['Miscellaneous Charges', $orgDay->{misc_charges} || 0, $orgMonth->{misc_charges} || 0, $orgYear->{misc_charges} || 0],
		['Receipt (Refunds/Returned Checks)', $orgDay->{refund} || 0, $orgMonth->{refund} || 0, $orgYear->{refund} || 0],
		
		[undef, undef, undef, undef],
		['<b>CURRENT A.R</b>', 
			($dayStartAR + $orgDay->{total_charges} - ($orgDay->{person_pay}+$orgDay->{insurance_pay}) - $orgDay->{courtesy_adj} - $orgDay->{contractual_adj} + $orgDay->{misc_charges} - $orgDay->{refund}),
			($monthStartAR + $orgMonth->{total_charges} - ($orgMonth->{person_pay}+$orgMonth->{insurance_pay}) - $orgMonth->{courtesy_adj} - $orgMonth->{contractual_adj} + $orgMonth->{misc_charges} - $orgMonth->{refund}),
			($yearStartAR + $orgYear->{total_charges} - ($orgYear->{person_pay}+$orgYear->{insurance_pay}) - $orgYear->{courtesy_adj} - $orgYear->{contractual_adj} + $orgYear->{misc_charges} - $orgYear->{refund})
		],
	);

	my $html = createHtmlFromData($page, 0, \@data, publishDefn('PRACTICE TOTALS'));
	
	my $providers = $STMTMGR_REPORT_CLOSEDATE->getSingleValueList($page, STMTMGRFLAG_NONE,
		'sel_providerList', $orgInternalId, $fiscalYearBeginDate);
	
	for my $doc (@{$providers})
	{
		my $docName = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 
			'selPersonSimpleNameById', $doc);
			
		my $docDay = $STMTMGR_REPORT_CLOSEDATE->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_docTotalsForDate', $orgInternalId, $closeDate, $doc);

		my $docMonth = $STMTMGR_REPORT_CLOSEDATE->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_docTotalsForMonth', $orgInternalId, $closeMonth, $closeDate, $doc);

		my $docYear = $STMTMGR_REPORT_CLOSEDATE->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_docTotalsForYear', $orgInternalId, $fiscalYearBeginDate, $closeDate, $doc);

		my $dayStartAR = $STMTMGR_REPORT_CLOSEDATE->getSingleValue($page, STMTMGRFLAG_NONE,
			'sel_docDayStartingAR', $orgInternalId, $closeDate, $doc);

		my $monthStartAR = $STMTMGR_REPORT_CLOSEDATE->getSingleValue($page, STMTMGRFLAG_NONE,
			'sel_docMonthStartingAR', $orgInternalId, $closeMonth, $doc);

		my $yearStartAR = $STMTMGR_REPORT_CLOSEDATE->getSingleValue($page, STMTMGRFLAG_NONE,
			'sel_docYearStartingAR', $orgInternalId, $fiscalYearBeginDate, $doc);

		my @data = (
			['<b>STARTING A.R</b>', $dayStartAR || 0, $monthStartAR || 0, $yearStartAR || 0],
			[undef, undef, undef, undef],

			['<b>CHARGES</b>', $docDay->{total_charges} || 0, $docMonth->{total_charges} || 0, $docYear->{total_charges} || 0],
			[undef, undef, undef, undef],

			['<b>RECEIPTS</b>', undef, undef, undef],
			['Personal', - $docDay->{person_pay} || 0, - $docMonth->{person_pay} || 0, - $docYear->{person_pay} || 0],
			['Insurance', - $docDay->{insurance_pay} || 0, - $docMonth->{insurance_pay} || 0, - $docYear->{insurance_pay} || 0],
			['<b>Total</b>', - ($docDay->{person_pay}+$docDay->{insurance_pay}), - ($docMonth->{person_pay}+$docMonth->{insurance_pay}), - ($docYear->{person_pay}+$docYear->{insurance_pay})],

			[undef, undef, undef, undef],
			['<b>ADJUSTMENTS</b>', undef, undef, undef],
			['Courtesy Adjustments', - $docDay->{courtesy_adj} || 0, - $docMonth->{courtesy_adj} || 0, - $docYear->{courtesy_adj} || 0],
			['Contractual (Insurance Write-offs)', - $docDay->{contractual_adj} || 0, - $docMonth->{contractual_adj} || 0, - $docYear->{contractual_adj} || 0],
			['Miscellaneous Charges', $docDay->{misc_charges} || 0, $docMonth->{misc_charges} || 0, $docYear->{misc_charges} || 0],
			['Receipt (Refunds/Returned Checks)',  $docDay->{refund} || 0, $docMonth->{refund} || 0, $docYear->{refund} || 0],

			[undef, undef, undef, undef],
			['<b>CURRENT A.R</b>', 
				($dayStartAR + $docDay->{total_charges} - ($docDay->{person_pay}+$docDay->{insurance_pay}) - $docDay->{courtesy_adj} - $docDay->{contractual_adj} + $docDay->{misc_charges} - $docDay->{refund}),
				($monthStartAR + $docMonth->{total_charges} - ($docMonth->{person_pay}+$docMonth->{insurance_pay}) - $docMonth->{courtesy_adj} - $docMonth->{contractual_adj} + $docMonth->{misc_charges} - $docMonth->{refund}),
				($yearStartAR + $docYear->{total_charges} - ($docYear->{person_pay}+$docYear->{insurance_pay}) - $docYear->{courtesy_adj} - $docYear->{contractual_adj} + $docYear->{misc_charges} - $docYear->{refund})
			],
		);
			
		$html .= '<br><br>' . createHtmlFromData($page, 0, \@data, publishDefn($docName));
	}
	
	return $html;
}

# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
