##############################################################################
package App::Page::Query;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Dialog::Query;
use DBI::StatementManager;
use App::Statements::Org;
use File::Spec;
use base qw(App::Page);
use vars qw($LIMIT $QUERYDIR %RESOURCE_MAP);

$LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;
$QUERYDIR = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL');
%RESOURCE_MAP = (
	'query' => {
		_idSynonym => ['find'],
		_title => '#param._query_title# Query',
		_iconSmall => 'icons/search',
		_iconMedium => 'icons/search',
		_iconLarge => 'icons/search',
		_views => [],
		},
	);


sub prepare
{
	my $self = shift;
	
	if ($self->property('QDL'))
	{
		my $heading = $self->{flags} & PAGEFLAG_ISPOPUP ? $self->param('_query_title') . " Query" : '';
		my $dialog = new App::Dialog::Query(page => $self, schema => $self->{schema}, heading => $heading);
		$self->{queryDialog} = $dialog;
		push @{$self->{page_content_header}}, $dialog->getHtml($self, 'add');
		if ($dialog->{SQL})
		{
			my $SQL = $dialog->{SQL};
			my $bindParams = $dialog->{bindParams};
			#my $debugBind = join '', map {"\t${_}\n"} @$bindParams;
			#$self->addDebugStmt("<pre><b>SQL STATEMENT:</b>\n$SQL\n\n<b>BIND PARAMS:</b>\n$debugBind</pre>\n");
			$self->replaceVars(\$SQL);
			push @{$self->{page_content_header}},
				$dialog->getHtml($self, 'add'),
				'<br><br><center>',
				$STMTMGR_ORG->createHtml($self, STMTMGRFLAG_DYNAMICSQL | STMTMGRFLAG_REPLACEVARS, $SQL, $bindParams),
				'</center>',
				$dialog->{pageControlHtml};
		}
	}
	else
	{
		my $html = '';
		$html .= '<br><br><b>Available Queries:</b><br><ul>';
		foreach (@{$RESOURCE_MAP{query}->{_views}})
		{
			$html .= qq{<li><a href="/query/$_->{name}">$_->{caption}</a></li>};
		}
		$html .= '</ul>';
		$self->addContent($html);
	}
	return 1;
}


sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
	$self->addLocatorLinks(['Query', '/query'],);
	$self->addLocatorLinks([$self->param('_query_title'), '/query/#param._query_type#'],) if $self->param('_query_type');
		
	# Check user's permission to page
	my $activeQuery = $self->param('_query_type');
	unless($self->hasPermission($self->property('ACL')))
	{
		$self->disable(
				qq{
					<br>
					You do not have permission to view this information. 
					Permission @{[ $self->property('ACL') ]} is required.

					Click <a href='javascript:history.back()'>here</a> to go back.
				});
	}
}


sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems, $handleExec) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	$handleExec = 1 unless defined $handleExec;

	if (my $queryType = $pathItems->[0])
	{
		$self->param('_query_type', $queryType);
		
		my $queryTitle = "\u$queryType";
		$queryTitle =~ s/_/ /g;
		$self->param('_query_title', $queryTitle);
		
		$self->property('ACL', "page/query/$pathItems->[0]");
	
		my ($fileName) = map {$_->{caption}} grep {$_->{name} eq $queryType} @{$RESOURCE_MAP{query}{_views}};
		$fileName = File::Spec->catfile($QUERYDIR, $fileName . '.qdl');
		if (-f $fileName)
		{
			$self->property('QDL', $fileName);
		}
		my $style = $pathItems->[1] || 'default';
		$self->param('_style', $style);
	}
	else
	{
		$self->property('ACL', 'page/query');
	}
	
	$self->printContents();
	return 0;
}


# Add views to the %RESOURCE_MAP with all available query types

opendir QUERYDIR, $QUERYDIR;
my @queries = map {$_ =~ s/\.qdl//;$_} grep {$_ =~ /\.qdl/ && -f "$QUERYDIR/$_"} readdir QUERYDIR;
closedir QUERYDIR;
foreach (@queries)
{
	push @{$RESOURCE_MAP{query}->{_views}}, {caption => $_, name => lc($_)};
}


1;
