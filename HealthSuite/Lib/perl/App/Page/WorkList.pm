##############################################################################
package App::Page::WorkList;
##############################################################################

use strict;
use Date::Manip;
use Date::Calc qw(:all);

use App::Page;
use CGI::ImageManager;
use Devel::ChangeLog;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Page;
use App::Statements::Search::Appointment;

use vars qw(@ISA @CHANGELOG %RESOURCE_MAP);
@ISA = qw(App::Page);
%RESOURCE_MAP = (
	'worklist' => {
		_title => 'Work List Menu',
		_iconSmall => 'icons/signpost',
		_iconMedium => 'icons/signpost',
		_iconLarge => 'icons/signpost',
		},
	);


sub prepare_view_default
{
	my $self = shift;
	my $children = $self->getChildResources();
	my $html = qq{<br>\n<br>\n<p>\n<table align="center" cellpadding="10" cellspacing="5" border="0">};
	foreach (keys %$children)
	{
		my $icon = $IMAGETAGS{$children->{$_}->{_iconMedium}};
		my $title = $children->{$_}->{_title};
		my $description = defined $children->{$_}->{_description} ? $children->{$_}->{_description} : '';
		next unless $icon && $title;
		$title = qq{<font face="Arial,Helvetica" size="4" color="darkred"><b>$title</b></font>};
		$description = qq{<br><font face="Arial,Helvetica" size="2" color="black">$description</font>} if $description;
		$title = qq{<a href="/worklist/$_">$title</a>};
		$html .= "<tr><td>\n$icon<br>\n</td><td>\n$title$description<br>\n</td></tr>";
	}
	$html .= '</table><p>';
	$self->addContent($html);
	return 1;
}


sub getChildResources
{
	my $self = shift;
	my $children = {};
	my $resourceMap = $self->property('resourceMap');
	return $children unless ref($resourceMap) eq 'HASH';
	foreach (keys %$resourceMap)
	{
		next unless ref($resourceMap->{$_}) eq 'HASH';
		if (exists $resourceMap->{$_}->{_class})
		{
			$children->{$_} = $resourceMap->{$_};
		}
	}
	return $children;
}


sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->addLocatorLinks(
		[ 'Work List Menu', '/worklist' ],
	);
}

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=default$');
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	return 1 if ref($self) ne __PACKAGE__;

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless ($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1]) if $pathItems->[1];
	}

	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

1;
