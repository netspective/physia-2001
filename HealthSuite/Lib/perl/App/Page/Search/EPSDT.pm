##############################################################################
package App::Page::Search::EPSDT;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Code;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/epsdt' => {},
	'search/220' => {},
	);

sub getForm
{
	my ($self, $flags) = @_;

	return ('Lookup EPSDT code/description', qq{
		<CENTER>
		<NOBR>
		<select name="search_type">
			<option value="code">Code</option>
			<option value="description">Description</option>
		</select>
		<select name="search_compare">
			<option value="contains">contains</option>
			<option value="is">is</option>
		</select>
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || "nameordescr" ]}');
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
		$STMTMGR_EPSDT_CODE_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_epsdt_$type$appendStmtName", $bindParams,
#			[
#				['Code', '<A HREF=\'javascript:chooseEntry("%0")\' STYLE="text-decoration:none">%0</A>'],
#				['Name'],
#				['Description'],
#			]
		),
		'</CENTER>'
		);

	return 1;
}

sub execute_detail
{
	my ($self, $expression) = @_;

	$self->addContent($expression);

	return 1;
}

1;
