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

		<input type=submit name="execute" value="Go">
		</NOBR>
		
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 'name' ]}');
		</script>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;
	
	my $statement = 'sel_' . $self->param('search_type');
	
	$expression =~ s/\*/%/g;

	$self->addContent(
		'<CENTER>', 
			$STMTMGR_EPAYER_SEARCH->createHtml($self, STMTMGRFLAG_NONE,	$statement, 
				[$expression]
			),
		'</CENTER>'
	);

	return 1;
}

1;
