##############################################################################
package App::Page::BrowseFS;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Component::Navigate::FileSys;

use vars qw(@EXPORT @ISA %RESOURCE_MAP);
@ISA = qw(App::Page);

sub setBrowseInfo
{
	my $self = shift;
	my %params = @_;
	#
	# required in %params: rootFS, rootURL, rootURLCaption
	#
	
	$self->property('browseInfo', \%params);
	my $rootFS = $params{rootFS} || die 'rootFS is required';
	
	my @activePath = $self->param('arl_pathItems');
	if(my $module = App::Component::Navigate::FileSys::getModuleNameForFile($rootFS, \@activePath))
	{
		no strict 'refs';
		$self->property('activeModule', $module);
		$self->property('activeInstance', ${"$module\::INSTANCE"});
	}

	my @activePathInfo = App::Component::Navigate::FileSys::getActivePathInfo(0, $rootFS, 
		$params{rootURL}, \@activePath, 'locator');
	$self->addLocatorLinks(
		[$params{rootURLCaption}, $params{rootURL}], @activePathInfo,
	);
}

sub prepare_page_content_header
{
	my ($self) = @_;
	
	my $browseInfo = $self->property('browseInfo');
	my $siblings = [
		['Menu', '.'],
	];

	if($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP))
	{
		if(my $instance = $self->property('activeInstance'))
		{
			push(@{$self->{page_content_header}}, '<H1>', $instance->heading(), '</H1>');
		}
		elsif(my $caption = $self->param('ecaption'))
		{
			push(@{$self->{page_content_header}}, '<H1>', $caption, '</H1>');
		}
		return 1;
	}

	my $heading = $browseInfo->{rootHeading} || 'No rootHeading provided';
	my $insideItem = 0;
	
	if(my $instance = $self->property('activeInstance'))
	{
		$heading = $instance->heading();
		unshift(@$siblings, ['Edit', '#hrefSelfNoDlg#']);
		$insideItem = 1;
	}
	elsif(my $caption = $self->param('ecaption'))
	{
		$heading = $caption;
		$insideItem = 1;
	}

	$self->{page_heading} = $heading;
	$self->{page_menu_sibling} = $siblings if $insideItem;
	$self->SUPER::prepare_page_content_header(@_);

	return 1;
}

sub handleDrillDown
{
	my ($self, $instance) = @_;

	# if the page doesn't know how to handle drill downs, fail
	return 0 unless $instance->can('getDrillDownHandlers');

	# now see if we find any drill down handlers
	my $handlersCount = 0;
	foreach ($instance->getDrillDownHandlers())
	{
		s/\$(\w+)\$/$self->param($1)/ge;
		if(my $method = $instance->can($_))
		{
			$handlersCount++;
			&$method($instance, $self);
		}
	}

	# if we find any handlers then TRUE will be returned
	return $handlersCount;
}

sub getNavigatorHtml
{
	my ($self, $enteredFile) = @_;
	my $navgParams = $self->property('browseInfo');
	
	new App::Component::Navigate::FileSys(
		heading => $navgParams->{rootHeading},
		rootFS => $navgParams->{rootFS},
		rootURL => $navgParams->{rootURL},
		rootCaption => $navgParams->{rootURLCaption},
		style => $enteredFile ? '' : 'panel.transparent',
		flags => $navgParams->{flags},
		)->getHtml($self),
}

sub prepare
{
	my $self = shift;
	if(my $instance = $self->property('activeInstance'))
	{
		return 1 if $self->handleDrillDown($instance);

		my $html = $instance->getHtml($self);
		my $dlgFlags = $self->property(CGI::Dialog::PAGEPROPNAME_FLAGS . '_' . $instance->id());

		unless($dlgFlags & CGI::Dialog::DLGFLAG_EXECUTE)
		{
			$self->addContent(qq{
				<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=100%>
					<TR VALIGN=TOP>
					<TD>@{[ $html ]}</TD>
					<TD WIDTH=10>&nbsp;</TD>
					<TD ALIGN=RIGHT>@{[ $self->getNavigatorHtml(1) ]}</TD>
					</TR>
				</TABLE>
				});
		}
		else
		{
			$self->addContent(qq{
				<TABLE BORDER=0 CELLSPACING=1 CELLPADDING=4 BGCOLOR=CCCCCC>
				<TR VALIGN=TOP><TD BGCOLOR=BEIGE>@{[ $instance->getStaticHtml($self) ]}</TD></TR>
				</TABLE>
				}, '<BR>', $html);
		}
	}
	elsif(my $enterFile = $self->param('enter'))
	{
		my $entryFlags = $self->param('eflags');
		if(open(ENTRYFILE, $enterFile))
		{	
			my @fileData = <ENTRYFILE>;
			if($entryFlags & NAVGFILEFLAG_RAWTEXT)
			{
				$self->addContent('<PRE>', @fileData, '</PRE>');
			}
			else
			{
				$self->addContent(@fileData);
			}
			close(ENTRYFILE);
		}
		else
		{
			$self->addContent("Unable to open file $enterFile: $!");
		}
	}
	else
	{
		$self->addContent(qq{
			<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
				<TR VALIGN=TOP>
				<TD>@{[$self->getNavigatorHtml(0)]}</TD>
				</TR>
			</TABLE>
			});
	}
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems, $handleExec) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	$handleExec = 1 unless defined $handleExec;

	$self->printContents();

	return 0;
}

1;
