##############################################################################
package App::Page::Search::ServicePlace;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Code;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/serviceplace' => {},
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
	my $search_type = $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP) ? "code" : $self->param('search_type') || "name";
	my $search_compare = $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP) ? "is" : $self->param('search_compare');

	return ('Lookup Service Place code/name', qq{
		<CENTER>
		<NOBR>
		<select name="search_type">
			<option value="code">Code</option>
			<option value="name">Name</option>
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
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 0 ]}');
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

	my $bindParams = [$expression];

	$self->addContent(
		'<CENTER>',
		$STMTMGR_SERVICEPLACE_CODE_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_place_$type$appendStmtName", $bindParams,
#			[
#				['Code', '<A HREF=\'javascript:chooseEntry("%0")\' STYLE="text-decoration:none">%0</A>'],
#				['Name'],
#			]
		),
		'</CENTER>'
		);

	return 1;
}

1;
