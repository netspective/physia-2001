##############################################################################
package App::Page::Query;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Dialog::Query;
use File::Spec;
use base qw(App::Page);
use vars qw($LIMIT $QUERYDIR %RESOURCE_MAP);

$LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;
$QUERYDIR = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL');
%RESOURCE_MAP = (
	'query' => {
		_idSynonym => ['find'],
		_title => '#param._page_title#',
		_iconSmall => 'images/page-icons/query',
		_iconMedium => 'images/page-icons/query',
		_iconLarge => 'images/page-icons/query',
		_views => [],
		},
	);


sub prepare
{
	my $self = shift;


	if ($self->property('QDL'))
	{
		unless ($self->param('_query_view'))
		{
			my $queryType = $self->param('_query_type');
			$self->redirect("/query/$queryType/all");
			return;
		}
		my $heading = $self->{flags} & PAGEFLAG_ISPOPUP ? $self->param('_query_title') . " Query (" . $self->param('_query_view_title') . ")": '';
		my $dialog = new App::Dialog::Query(page => $self, schema => $self->{schema}, heading => $heading);
		$self->{queryDialog} = $dialog;

		push @{$self->{page_content}}, $dialog->getHtml($self, 'add');
		if ($self->field('dlg_execmode') eq 'V')
		{
			push @{$self->{page_content}}, $dialog->getHtml($self, 'add');
		}

	}
	else
	{
		# Give them a menu of Query Types
		#my $children = $self->getChildResources();
		#my $html = qq{<br>\n<br>\n<p>\n<table align="center" cellpadding="10" cellspacing="5" border="0">};
		#foreach (sort keys %$children)
		#{
		#	my $icon = $IMAGETAGS{$children->{$_}->{_iconMedium}};
		#	my $title = $children->{$_}->{_title};
		#	my $description = defined $children->{$_}->{_description} ? $children->{$_}->{_description} : '';
		#	next unless $icon && $title;
		#	$title = qq{<font face="Arial,Helvetica" size="4" color="darkred"><b>$title</b></font>};
		#	$description = qq{<br><font face="Arial,Helvetica" size="2" color="black">$description</font>} if $description;
		#	$title = qq{<a href="/worklist/$_">$title</a>};
		#	$html .= "<tr><td>\n$icon<br>\n</td><td>\n$title$description<br>\n</td></tr>";
		#}
		#$html .= '</table><p>';
		#$self->addContent($html);




		my $html = '';
		$html .= '<br><br><b>Available Queries:</b><br><ul>';
		foreach (@{$RESOURCE_MAP{query}->{_views}})
		{
			$html .= qq{<li><a href="/query/$_->{name}/all">$_->{caption}</a></li>};
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
	$self->addLocatorLinks([$self->param('_query_view_title'), '/query/#param._query_type#/#param._query_view#'],) if $self->param('_query_view');

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

	my $queryType = '';
	my $queryTitle = '';
	my $view = '';
	if ($queryType = $pathItems->[0])
	{
		$queryTitle = "\u$queryType";
		$self->property('ACL', "page/query/$queryType");
		my ($fileName) = map {$_->{name}} grep {$_->{name} eq $queryType} @{$RESOURCE_MAP{query}{_views}};
		$fileName = File::Spec->catfile($QUERYDIR, $fileName . '.qdl');
		#$self->addDebugStmt("fileName: $fileName");
		if (-f $fileName)
		{
			$self->property('QDL', $fileName);
		}
		$view = $pathItems->[1] || '';
	}
	else
	{
		$self->property('ACL', 'page/query');
	}

	my $pageTitle = "Query";
	$pageTitle = $queryTitle . ' ' . $pageTitle if $queryTitle;
	#$pageTitle .= " (\u$view)" if $view;
	$pageTitle =~ s/_/ /g;

	$self->param('_page_title', $pageTitle);
	$self->param('_query_type', $queryType);
	$self->param('_query_title', $queryTitle);
	$self->param('_query_view', $view);
	$self->param('_query_view_title', "\u$view");
	$self->param('_pm_view', $queryType);

	$self->printContents();
	return 0;
}


# Add views to the %RESOURCE_MAP with all available query types

opendir QUERYDIR, $QUERYDIR;
my @queries = grep {$_ =~ /\.qdl/ && -f "$QUERYDIR/$_"} readdir QUERYDIR;
closedir QUERYDIR;
foreach (sort @queries)
{
	my $sqlGen = new SQL::GenerateQuery(file => "$QUERYDIR/$_");
	my $id = $sqlGen->id();
	next unless defined $sqlGen->{params}->{caption};
	my $caption = $sqlGen->{params}->{caption};
	my $icon = defined $sqlGen->{params}->{icon} ? $sqlGen->{params}->{icon} : 'images/page-icons/default';
	push @{$RESOURCE_MAP{query}->{_views}}, {caption => $caption, name => $id, icon => $icon, };
}


1;
