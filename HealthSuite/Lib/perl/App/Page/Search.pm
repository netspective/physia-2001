##############################################################################
package App::Page::Search;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Exporter;
use CGI::ImageManager;

use enum qw(BITMASK:SEARCHFLAG_ LOOKUPWINDOW SEARCHBAR);

use vars qw(@ISA @EXPORT %RESOURCE_MAP);
@ISA = qw(Exporter App::Page);
@EXPORT = qw(SEARCHFLAG_LOOKUPWINDOW SEARCHFLAG_SEARCHBAR);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

%RESOURCE_MAP = (
	'search' => {
		_idSynonym => ['lookup', 'menu'],
		_title => 'Lookup',
		_iconSmall => 'icons/search',
		_iconMedium => 'icons/search',
		_iconLarge => 'icons/search',
		},
	);

sub prepare_page_content_header
{
	my $self = shift;
	my $flags = 0;
	my ($heading, $searchForm) = $self->getForm($flags);
	$self->{page_heading} = $heading;
	$self->property('_title', $heading) unless $self->property('_title');
	$self->property('_iconMedium', 'icons/search') unless $self->property('_iconMedium');
	
	unshift(@{$self->{page_content_header}}, q{
		<style>
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</style>
		});
		
	$heading = $self->flagIsSet(PAGEFLAG_ISPOPUP) ? qq{<center><b><font face="arial,helvetica" size="2" color="navy">$heading</font></b></center>} : '';
	
	my $formHtml = $searchForm ? qq{
		<table bgcolor="#EEEEEE" border="0" cellspacing="0" cellpadding="5" width="100%"><tr><td>
			<form name="search_form" method="post">
				$heading \&nbsp;
				<input type="hidden" name="arl" value="@{[$self->param('arl')]}">
				<font face='arial,helvetica' size="2">$searchForm</font>
			</form>
		</td></tr></table>
		} : '';	
	push(@{$self->{page_content_header}}, $formHtml);
	return 1 if $self->flagIsSet(PAGEFLAG_ISPOPUP);

	$self->SUPER::prepare_page_content_header(@_);
	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;
	
	if($self->param('execute'))
	{	
		push(@{$self->{page_content_footer}}, qq{
			<br>
			<center><font color="GRAY">(Search results are limited to $LIMIT records)</font></center>
		});
	}
	$self->SUPER::prepare_page_content_footer(@_);
}

sub getForm
{
	my ($self, $flags) = @_;
	$self->abstract();
}

sub execute
{
	my ($self, $type, $expression) = @_;
	$self->abstract();
}

sub prepare
{
	my $self = shift;
	if($self->param('execute'))
	{
		#my $subType = $self->param('search_subtype');
		if($self->param('search_type') eq 'detail')
		{
			$self->execute_detail($self->param('search_expression'));
		}
		else
		{
			$self->execute($self->param('search_type') || 'code', $self->param('search_expression') || '*');
		}
	}
	else
	{
		$self->addContent('Please enter a search value.');
	}

	return 1;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
	$self->addLocatorLinks(
			['Main Menu', '/menu'],
		);
		
	# Check user's permission to page
	my $activeView = $self->param('_pm_view');
	if ($activeView) 
	{
		unless($self->hasPermission("page/search/$activeView"))
		{
			$self->disable(
					qq{
						<br>
						You do not have permission to view this information. 
						Permission page/search/$activeView is required.

						Click <a href='javascript:history.back()'>here</a> to go back.
					});
		}
	}	

		
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems, $handleExec) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	$handleExec = 1 unless defined $handleExec;

	$self->setFlag(PAGEFLAG_ISPOPUP) if $arl =~ /^lookup/;
	$self->param('_islookup', 1) if $arl =~ /^lookup/;
	$self->param('_pm_view', $pathItems->[0]);
	$self->param('search_type', $pathItems->[1]) unless $self->param('search_type');
	$self->param('search_expression', $pathItems->[2]) unless $self->param('search_expression');
	$self->param('search_compare', 'contains') unless $self->param('search_compare');
	$self->param('execute', 'Go') if $handleExec && $pathItems->[2];  # if an expression is given, do the find immediately

	$self->printContents();

	return 0;
}

# STATIC FUNCTION

sub getSearchBar
{
	my ($page, $dirARLSuffix) = @_;
	my @pathItems = split(/\//, $dirARLSuffix);

	my $pagePrefix = &App::ResourceDirectory::PAGE_RESOURCE_PREFIX;
	my $class = $App::ResourceDirectory::RESOURCES{$pagePrefix . 'search'}{$pathItems[0]}{_class};
	my $flags = SEARCHFLAG_SEARCHBAR;
	my ($heading, $searchForm) = &{\&{"$class\::getForm"}}($page, $flags);
	return qq{
		<STYLE>
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</STYLE>
		<TABLE BGCOLOR=BBBBBB BORDER=0 CELLSPACING=1 CELLPADDING=2 WIDTH=100%>
			<TR>
			<FORM NAME="search_form" METHOD=POST ACTION="/search/$dirARLSuffix">
			<TD BGCOLOR=EEEEEE>
			<CENTER><B><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=999999>$heading</FONT></B></CENTER>
			<FONT FACE='Verdana,Arial,Helvetica' SIZE=2>
			$searchForm
			</FONT>
			</TD>
			</FORM>
			</TR>
		</TABLE>
	};
}

1;
