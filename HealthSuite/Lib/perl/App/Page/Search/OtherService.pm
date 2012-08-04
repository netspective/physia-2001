##############################################################################
package App::Page::Search::OtherService;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::OtherService;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/other_service' => {},
	);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->setFlag(App::Page::PAGEFLAG_ISPOPUP) if $rsrc eq 'lookup';
	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
	
}

sub getForm
{
	my ($self, $flags) = @_;
	my $search_type = $self->param('search_type');
	my $search_compare = $self->param('search_compare');
	

	return ('Lookup Other Ancillary Service', qq{
		<CENTER>
		<NOBR>
		<select name="search_compare">
			<option value="code">Code</option>
			<option value="name">Name</option>
		</select>
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_compare, '$search_compare');
		</script>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	return 1 unless $expression;
	#return $self->execute_detail($expression) if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	# oracle likes '%' instead of wildcard '*'
	my $appendStmtName = '';
	if($expression =~ s/\*/%/g)
	{
		$appendStmtName = '_like';
	}

	$type = $self->param('search_compare');
	my $bindParams = [$self->param('search_type') ||undef, uc($expression)];

	$self->addContent(
		'<CENTER>',
		$STMTMGR_OTHERSERVICE_SEARCH->createHtml
			($self, STMTMGRFLAG_NONE, "sel_other_service_$type$appendStmtName", $bindParams,),
		'</CENTER>'
	);			
	return 1;
}

1;
