##############################################################################
package App::Page::Search::EnvoyPayer;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::EnvoyPayer;
use Devel::ChangeLog;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/envoypayer' => {},
	);

sub getForm
{
	my ($self, $flags) = @_;	
	my $view = $self->param('search_type') eq 'detail' ? 'ref_envoy_payer ' : '' ;
	my $payerId = $view eq 'ref_envoy_payer' ? $self->param('search_expression') : undef;
	my $heading = $payerId eq '' ?  'Lookup an Envoy Payer ID' : "Lookup a Envoy Payer ID'";

	return ($heading, qq{
		<CENTER>
		<NOBR>
		<select name="search_type" style="color: darkred">
			<option value="id">ID</option>
			<option value="name">Name</option>			
		</select>
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>		
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 0 ]}');
		</script>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	# oracle likes '%' instead of wildcard '*'
	my $appendStmtName = $expression =~ s/\*/%/g ? '_like' : '';

	$self->addContent(
		'<CENTER>',
		$STMTMGR_ENVOYPAYER_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_$type$appendStmtName",
			[uc($expression)],
			#[
			#	['ID', '<A HREF=\'javascript:chooseEntry("%0")\' STYLE="text-decoration:none">%0</A>'],
			#	['Name'],
			#]
			),
		'</CENTER>'
		);

	return 1;
}

1;
