##############################################################################
package XAP::Component::Theme;
##############################################################################

use strict;
use Exporter;
use XAP::Component;
use base qw(XAP::Component Exporter);
use fields qw(
	colBgndPage
	colBkgndChannel
	colBkgndChanneledit
	colBkgndTools
	colBkgndBanner
	colBkgndLocator
	colBkgndHeading
	colFrameChannel
	colFrameChanneledit
	colFrameTools
	fontPlainOpen fontPlainClose
	fontChannelFrameOpen fontChannelFrameClose
	fontChannelBodyOpen fontChannelBodyClose
	fontChannelBodySmOpen fontChannelBodySmClose
	fontChannelHighlOpen fontChannelHighlClose
	fontToolsFrameOpen fontToolsFrameClose
	fontToolsBodyOpen fontToolsBodyClose
	fontToolsHighlOpen fontToolsHighlClose
	fontLocatorOpen fontLocatorClose
	fontLocatorSelectedOpen fontLocatorSelectedClose
	fontDatetimeOpen fontDatetimeClose
	fontHighlightedOpen fontHighlightedClose
	fontLinkOpen fontLinkClose
	fontVisitedOpen fontVisitedClose
	);

sub init
{
	my XAP::Component::Theme $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{colBgndPage} = '#FFFFFF';            # page
	$self->{colBkgndChannel} = 'LIGHTYELLOW';    # channel (normal pane)
	$self->{colBkgndChanneledit} = 'RED';        # channel ("add" portion of edit channel)
	$self->{colBkgndTools} = 'BEIGE';            # tools (tools pane)
	$self->{colBkgndBanner} = 'YELLOW';          # banner (banner underneath frame of a pane)
	$self->{colBkgndLocator} = 'LIGHTSTEELBLUE'; # locator
	$self->{colBkgndHeading} = 'YELLOW';         # heading
	$self->{colFrameChannel} = 'NAVY';           # channel frame
	$self->{colFrameChanneledit} = 'DARKRED';    # channel frame when editing
	$self->{colFrameTools} = 'BLACK';            # tools frame

	$self->{fontPlainOpen} = '<FONT FACE="Arial,Helvetica" SIZE="2">';
	$self->{fontPlainClose} = '</FONT>';
	$self->{fontChannelFrameOpen} = '<FONT FACE="Arial,Helvetica" SIZE="2"><B>';
	$self->{fontChannelFrameClose} = '</B></FONT>';
	$self->{fontChannelBodyOpen} = '<FONT FACE="Arial,Helvetica" SIZE="2">';
	$self->{fontChannelBodyClose} = '</FONT>';
	$self->{fontChannelBodySmOpen} = '<FONT FACE="Arial,Helvetica" SIZE="1">';
	$self->{fontChannelBodySmClose} = '</FONT>';
	$self->{fontChannelHighlOpen} = '<FONT FACE="Arial,Helvetica" SIZE="2" COLOR="RED">';
	$self->{fontChannelHighlClose} = '</FONT>';
	$self->{fontToolsFrameOpen} = '<FONT FACE="Arial,Helvetica" SIZE="2"><B>';
	$self->{fontToolsFrameClose} = '</B></FONT>';
	$self->{fontToolsBodyOpen} = '<FONT FACE="Arial,Helvetica" SIZE="2">';
	$self->{fontToolsBodyClose} = '</FONT>';
	$self->{fontToolsHighlOpen} = '<FONT FACE="Arial,Helvetica" SIZE="2" COLOR="RED">';
	$self->{fontToolsHighlClose} = '</FONT>';
	$self->{fontLocatorOpen} = '<FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">';
	$self->{fontLocatorClose} = '</FONT>';
	$self->{fontLocatorSelectedOpen} = '<B>';
	$self->{fontLocatorSelectedClose} = '</B>';
	$self->{fontDatetimeOpen} = '<FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt" COLOR=GREEN>';
	$self->{fontDatetimeClose} = '</FONT>';

	$self;
}

1;