##############################################################################
package App::Page::Search::Epayer;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Epayer;
use Data::Publish;

use vars qw(%RESOURCE_MAP);
use base 'App::Page::Search';
%RESOURCE_MAP = (
	'search/epayer' => {},
	);

sub getForm
{
	my ($self, $flags) = @_;

	my $heading = 'Lookup E-Remit Payers';

	return ($heading, qq{
		<CENTER>
		<NOBR>
		<select name="search_type" style="color: darkblue">
			<option value="name">Name</option>
			<option value="id">ID</option>
			<option value="id2">ID 2</option>
		</select>
		
		<input name="search_expression" value="@{[$self->param('search_expression')]}">

		<select name="payer_source" style="color: darkblue">
			<option value=2>Perse</option>
			<option value=1>Envoy</option>
		</select>
		
		<input type=submit name="execute" value="Go">
		</NOBR>
		
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 'name' ]}');
			setSelectedValue(document.search_form.payer_source, '@{[ $self->param('payer_source') || 2 ]}');
		</script>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;
	
	my $statement = 'sel_' . $self->param('search_type');
	my $payerSource = $self->param('payer_source') || '%';
	
	$expression =~ s/\*/%/g;

	$self->addContent(
		'<CENTER>', 
			$STMTMGR_EPAYER_SEARCH->createHtml($self, STMTMGRFLAG_NONE,	$statement, 
				[$expression, $payerSource]
			),
		'</CENTER>'
	);

	return 1;
}

1;
