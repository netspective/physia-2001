##############################################################################
package App::Page::Search::FeeProcedure;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::FeeProcedure;
use App::Statements::Catalog;
use Data::Publish;
use Date::Manip;
use vars qw(%RESOURCE_MAP);
use base 'App::Page::Search';
%RESOURCE_MAP = (
	'search/feeprocedure' => {},
	);

sub getForm
{
	my ($self, $flags) = @_;
	
	
	
	#Build heading for search screen
	my $heading = 'Lookup Fee Schedule Procedure Code';
	my @listFee = split "," , $self->param('fee_list');
	my $fee_schedules=q{<select name="fee_schedule" style="color: darkblue">};
	
	#Get Default Fee Schedule Id if one exists and append to list of searchable fee schedules
	my $ffs = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_NONE,'sel_catalog_by_id_orgId', 'FFS', $self->session('org_internal_id'));
	push @listFee,$ffs->{internal_catalog_id} if $ffs;
	
	#Sort the list fee so we can remove dups
	my @sortFee = sort @listFee; 
	my $prev_value=undef;
	
	#Build drop down with all searchable fee schedules
	foreach my $ele (@sortFee)	
	{
		
		#Get the text name for the fee schedule and display that
		my $ele_name = $STMTMGR_CATALOG->getRowAsHash($self,STMTMGRFLAG_NONE,'selCatalogById',$ele);	
		$fee_schedules.=qq{<option value=$ele>$ele_name->{catalog_id}</option>} if $ele_name->{catalog_id} && $prev_value ne $ele;
		$prev_value = $ele;
	}
	
	$fee_schedules.=qq{</select>};	
	return ($heading, qq{
		<CENTER>
		<NOBR>		
		<select name="search_type">
			<option value="code">Code</option>
			<option value="name">Name</option>
			<option value="description">Description</option>
		</select>
		<select name="search_compare">
			<option value="contains">contains</option>
			<option value="is">is</option>
		</select>
		
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		$fee_schedules
		
		<input type=submit name="execute" value="Go">
		</NOBR>
		
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || "code" ]}');
			setSelectedValue(document.search_form.fee_schedule, '@{[ $self->param('fee_schedule') || "FFS" ]}');
			setSelectedValue(document.search_form.search_compare, '@{[ $self->param('search_compare') || "contains" ]}');			
		</script>
	});
}


sub execute
{
	my ($self, $type, $expression) = @_;
	
	return 1 unless $expression;
	
	# oracle likes '%' instead of wildcard '*'
	my $appendStmtName = '';
	my $selFee = $self->param('fee_schedule');
	if($expression =~ s/\*/%/g)
	{
		$appendStmtName = '_like';
	}
	elsif($self->param('search_compare') eq 'contains')
	{
		$expression = "\%$expression\%";
		$appendStmtName = '_like';
	}
	$type = $type eq '' ? 'code' : $type;			
	
	#do not allow fee schedule ids with text to be passed to the sql statement it will die
	$self->addContent(
			'<CENTER>',		
			$STMTMGR_FEE_PROCEDURE_CODE_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_fee_procedure_$type$appendStmtName", [$selFee,uc($expression)]),
			'</CENTER>'
			) if $selFee =~ m/^[\d]/;
	

	return 1;
}



sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems, $handleExec) = @_;
	#do NOT auto run search
	$handleExec = 0;
	
	#Get the fee_list which will appears in the search_type position 
	$self->param('fee_list', $pathItems->[1]);
	$self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
	return 0;
}


1;
