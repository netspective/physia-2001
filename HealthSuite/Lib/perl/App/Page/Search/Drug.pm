##############################################################################
package App::Page::Search::Drug;
##############################################################################

use strict;
use App::Page::Search;
use LWP::Simple;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/drug' => {},
	);

sub getForm
{
	my ($self, $flags) = @_;

	return ('Lookup a drug', qq{
		<CENTER>
		<NOBR>
		Find:
		<select name="search_type" style="color: darkred">
			<option value="name" selected>Name</option>
			<option value="keyword">Keywords</option>
		</select>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 0 ]}');
		</script>
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		</CENTER>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	my $paramName = $type eq 'name' ? 'drug' : 'keywords';
	$self->addContent(get("http://www.rxlist.com/cgi/rxlist.cgi?$paramName=$expression"));

	return 1;
}

1;
