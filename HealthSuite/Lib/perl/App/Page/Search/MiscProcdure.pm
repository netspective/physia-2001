##############################################################################
package App::Page::Search::MiscProcedure;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::MiscProcedure;
use App::Statements::Transaction;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/miscprocedure' => {},
	'search/230' => {},
	);



sub getForm
{
	my ($self, $flags) = @_;		
	my $heading;
	my $procCode;
	my $lookupValue;
	if($self->param('search_type') eq 'detail')
	{		
		$procCode =  $STMTMGR_TRANSACTION->getSingleValue($self,STMTMGRFLAG_NONE,'selMiscProcedureByTransId',
		$self->param('search_expression')) if $self->param('search_expression');
		#This is not the best fix but it will set the lookup value on a detail search to the parent code
		#value
		$heading = $procCode ? "Lookup Misc Procedure item ($procCode)" : 'Lookup Misc Procedure item';		
		$self->param('code_value',$procCode);
		$lookupValue =qq{<input name="search_expression" value="$procCode">};
	}
	else
	{
		$heading =  "Lookup Misc Procedure code";
		$lookupValue=qq{<input name="search_expression" value="@{[$self->param('search_expression')]}">}
	}	
	
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
		$lookupValue
		<input type=submit name="execute" value="Go">
		</NOBR>
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || "code" ]}');
			setSelectedValue(document.search_form.search_compare, '@{[ $self->param('search_compare') || 0 ]}');
		</script>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	return 1 unless $expression;

	# oracle likes '%' instead of wildcard '*'
	my $appendStmtName = '';
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

	my $bindParams = [uc($expression)];
	push(@$bindParams, uc($expression)) if $type eq 'nameordescr';

	$self->addContent(
		'<CENTER>',		
		$STMTMGR_MISC_PROCEDURE_CODE_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_misc_procedure_$type$appendStmtName", $bindParams,),
		'</CENTER>'
		);

	return 1;
}


sub execute_detail
{
	my ($self, $expression) = @_;	

	$self->addContent(
		'<CENTER>',		
			
			$STMTMGR_MISC_PROCEDURE_CODE_SEARCH->createHtml($self, STMTMGRFLAG_NONE,
				'sel_misc_procedure_detail',	[uc($expression)],
		),
		'</CENTER>'
	);

	return 1;
}

1;
