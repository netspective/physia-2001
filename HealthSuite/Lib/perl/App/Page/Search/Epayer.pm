##############################################################################
package App::Page::Search::Epayer;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Epayer;
use App::Statements::Catalog;
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
	my $sqlStmt = qq{SELECT id,caption as name FROM Electronic_Payer_Source where id != 0};
	my $payers = $STMTMGR_CATALOG->getRowsAsHashList($self,STMTMGRFLAG_DYNAMICSQL,$sqlStmt);
	my $payer_select = qq{<select name="search_payer" style="color: darkblue">};
	
	#Build list of payer names
	foreach (@$payers)
	{
		#default to PerSe
		if( (!defined $self->param('search_payer') && $_->{id} == 2) || $self->param('search_payer')== $_->{id})
		{
			$payer_select .= qq{<option value="$_->{id}" selected>$_->{name}</optipn>};
		}
		else
		{
			$payer_select .= qq{<option value="$_->{id}">$_->{name}</optipn>};
		}
	}
	$payer_select .=qq{</select>};
	return ($heading, qq{
		<CENTER>
		<NOBR>		
		$payer_select
		<select name="search_type" style="color: darkblue">
			<option value="name">Name</option>
			<option value="id">ID</option>
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
	
	my $payer_id = $self->param('search_payer');
	
	$expression =~ s/\*/%/g;

	$self->addContent(
		'<CENTER>', 
			$STMTMGR_EPAYER_SEARCH->createHtml($self, STMTMGRFLAG_NONE,	$statement, 
				[$expression, $payer_id]
			),
		'</CENTER>'
	);

	return 1;
}

1;
