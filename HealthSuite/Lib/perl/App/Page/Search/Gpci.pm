##############################################################################
package App::Page::Search::Gpci;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Gpci;
use Data::Publish;
use Date::Manip;

use base 'App::Page::Search';

sub getForm
{
	my ($self, $flags) = @_;

	my $heading = 'Lookup Medicare GPCI Location';

	return ($heading, qq{
		<CENTER>
		<NOBR>
		Effective Dates:
		<input name='eff_begin_date' size=10 maxlength=10 value="@{[$self->param('eff_begin_date')]}" title='Effective Begin Date'>
		<input name='eff_end_date' size=10 maxlength=10 value="@{[$self->param('eff_end_date')]}" title='Effective End Date'>
		
		<select name="search_type" style="color: darkblue">
			<option value="state">State</option>
			<option value="carrierNo">Carrier Number</option>
			<option value="locality">Locality</option>
			<option value="county">County</option>
			<option value="id">GPCI Id</option>
		</select>
		
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		
		<input type=submit name="execute" value="Go">
		</NOBR>
		
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 'state' ]}');
		</script>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;
	
	my $statement = 'sel_GPCI_' . $self->param('search_type');
	my $thisYear = UnixDate('today', '%Y');
	my $day1 = UnixDate('01/01/'. $thisYear, '%m/%d/%Y');
	my $day2 = UnixDate('12/31/'. $thisYear, '%m/%d/%Y');
	
	$self->param('eff_begin_date', UnixDate($day1, '%m/%d/%Y'))
		unless ParseDate($self->param('eff_begin_date'));

	$self->param('eff_end_date', UnixDate($day2, '%m/%d/%Y'))
		unless ParseDate($self->param('eff_end_date'));

	$expression =~ s/\*/%/g;

	$self->addContent(
		'<CENTER>', 
			$STMTMGR_GPCI_SEARCH->createHtml($self, STMTMGRFLAG_NONE,	$statement, [$expression]),
		'</CENTER>'
	);

	return 1;
}

1;
