##############################################################################
package App::Page::BrowseFS::HandHeld;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Page;
use App::Component::Navigate::FileSys;
use App::Page::BrowseFS;
use DBI::StatementManager;
use App::Statements::HandHeld;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::BrowseFS);
%RESOURCE_MAP = (
	'mobile' => {},
	);

sub initialize
{
	my $self = shift;
	$self->setFlag(PAGEFLAG_ISHANDHELD);
	$self->SUPER::initialize(@_);

	$self->setBrowseInfo(
		rootFS => File::Spec->catfile($CONFDATA_SERVER->path_HandheldPages()), 
		rootURL => '/mobile',
		rootURLCaption => 'Mobile',
		rootHeading => 'Mobile',
		);

	if (my $patientId = $self->param('pid'))
	{
		if($patientId ne $self->session('active_person_id'))
		{
			$self->session('active_person_id', $patientId);
			$self->session('active_person_name', $STMTMGR_HANDHELD->getSingleValue($self, 
				STMTMGRFLAG_DYNAMICSQL, 'select initcap(simple_name) from person where person_id = :1',
				$patientId));
		}
	}
	
	$self->param('person_id', $self->session('active_person_id'));
}

sub prepare_page_content_header
{
	my ($self) = @_;
	
	my $browseInfo = $self->property('browseInfo');
	my $heading = $browseInfo->{rootHeading} || 'No rootHeading provided';
	my $insideItem = 0;
	my $instance = undef;
	
	if($instance = $self->property('activeInstance'))
	{
		$heading = $instance->heading();
		$insideItem = 1;
	}
	elsif(my $caption = $self->param('ecaption'))
	{
		$heading = $caption;
		$insideItem = 1;
	}

	my $locLinks = $self->{page_locator_links};
	my $contentHeader = $self->{page_content_header};
	my $inHome = 0;
	if($insideItem || scalar(@$locLinks) > 2)
	{
		my $location = qq{
			<a href="/mobile" border=0><img src="/resources/images/icons/home-sm.gif"></a> 
			<a href="/logout" border=0><img src="/resources/widgets/action-close.gif"></a>
		};
		
		my $lastLoc = $#$locLinks;
		for(my $loc = 2; $loc <= $lastLoc; $loc++)
		{
			$location .= ' <img src="/resources/images/icons/arrow-right-orange.gif"> ';
			$location .= "<a href='@{[$locLinks->[$loc]->[App::Page::MENUITEM_HREF]]}' border=0>
				@{[$locLinks->[$loc]->[App::Page::MENUITEM_CAPTION]]}</a>";
		}
		unshift(@$contentHeader, $location);
	}
	else
	{
		unshift(@$contentHeader, '<img src="/resources/images/design/mobile-home-graphic.gif">');
		$inHome = 1;
	}
	push(@$contentHeader, "<br>User: @{[ $self->session('user_id') ]}\@@{[ $self->session('org_id') ]}");
	push(@$contentHeader, "<br>Date: @{[ $self->session('active_date') ]}");
	
	push(@$contentHeader, "<br>Patient: @{[ $self->session('active_person_name') ]}" .
		" (@{[ $self->session('active_person_id') ]})")
		#if $instance && $instance->can('showActivePatient') && $instance->showActivePatient();
		if ($self->session('active_person_id'));

	push(@$contentHeader, '<hr size=1>');

	unshift(@{$self->{page_head}}, "<title>$heading</title>");
	$self->SUPER::prepare_page_content_header(@_);

	return 1;
}

sub prepare
{
	my $self = shift;
	if(my $instance = $self->property('activeInstance'))
	{
		return 1 if $self->handleDrillDown($instance);

		my $html = $instance->getHtml($self);
		my $dlgFlags = $self->property(CGI::Dialog::PAGEPROPNAME_FLAGS . '_' . $instance->id());
		$self->addContent($html);
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
		$self->addContent($self->getNavigatorHtml(0));
	}
}

1;
