##############################################################################
package App::Page::Directory;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Component::Navigate::FileSys;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page);
%RESOURCE_MAP = (
	'directory' => {},
	);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	my $rootFS = File::Spec->catfile($CONFDATA_SERVER->path_OrgDirectory(), 'General');
	my @activePath = $self->param('arl_pathItems');
	if(my $module = App::Component::Navigate::FileSys::getModuleNameForFile($rootFS, \@activePath))
	{
		no strict 'refs';
		$self->property('activeModule', $module);
		$self->property('activeInstance', ${"$module\::INSTANCE"});
	}

	my @activePathInfo = App::Component::Navigate::FileSys::getActivePathInfo(0, $rootFS, '/directory', \@activePath, 'locator');
	$self->addLocatorLinks(
			['Directory', '/directory'],
			@activePathInfo,
		);
}

sub prepare_page_content_header
{
	my $self = shift;

	if($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP))
	{
		if(my $instance = $self->property('activeInstance'))
		{
			push(@{$self->{page_content_header}}, '<H1>', $instance->heading(), '</H1>');
		}
		return 1;
	}

	$self->SUPER::prepare_page_content_header(@_);
	my $heading = "Directories";
	my $insideDirectory = 0;
	if(my $instance = $self->property('activeInstance'))
	{
		$heading = $instance->heading();
		$insideDirectory = 1;
	}
	push(@{$self->{page_content_header}}, qq{
		<STYLE>
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</STYLE>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE BORDER=0 CELLPADDING=0 CELLSPACING=1>
		<TR><TD BGCOLOR=BEIGE>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TR>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					<B>$heading</B>
				</FONT>
			</TD>
			@{[
			$insideDirectory ? qq{
			<TD ALIGN=RIGHT>
				<FONT FACE="Arial,Helvetica" SIZE=2>
					<A HREF="#hrefSelfNoDlg#">Edit</A> | <A HREF=".">Directory Menu</A>
				</FONT>
			</TD>
			</TR>
			} : ''
			]}
		</TABLE>
		</TD></TR>
		</TABLE>
		<FONT SIZE=1>&nbsp;<BR></FONT>
		});

	return 1;
}

sub handleDrillDown
{
	my ($self, $instance) = @_;

	# if the directory page doesn't know how to handle drill downs, fail
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
					<TD ALIGN=RIGHT>#component.navigate-directory-panel#</TD>
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
	else
	{
		$self->addContent(qq{
			<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
				<TR VALIGN=TOP>
				<TD>#component.navigate-directory-transparent#</TD>
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

	#$self->addContent('#anchorSelf.Test Self# | #anchorSelfPopup.Test Self Popup# ');
	$self->printContents();

	return 0;
}

1;
