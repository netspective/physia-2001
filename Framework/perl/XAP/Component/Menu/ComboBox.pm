##############################################################################
package XAP::Component::Menu::ComboBox;
##############################################################################

use strict;
use Exporter;

use Data::Publish;
use XAP::Component::Menu;

use base qw(XAP::Component::Menu Exporter);

XAP::Component->registerXMLTagClass('menu', ['type', { 'combobox' => __PACKAGE__ } ]);

sub getBodyHtml
{
	my XAP::Component::Menu::ComboBox $self = shift;
	my ($page, $flags) = (shift, shift);	
	my (@menuItems) = @_;
	my $activeURL = $page->getActiveURL();

	my $html = $self->{caption} ? "<option>$self->{caption}</option>" : '';
	my $items = @menuItems ? \@menuItems : $self->{items};
	
	if(ref $items->[0] eq 'ARRAY')
	{
		foreach(@$items)
		{
			my $url = $_->[1];
			$html .= "<option value='$url'>$_->[0]" . ($activeURL eq $url ? ' *' : '') . "</option>";
		}
	}
	else
	{
		foreach (@$items)
		{
			my $url = $_->getURL($page);
			$html .= "<option value='$url'>" . $_->getCaption() . ($activeURL eq $url ? ' *' : '') . "</option>";
		}
	}
	
	return qq{
		<select style="font-family: tahoma,arial,helvetica; font-size: 8pt" onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
			$html
		</select>		
	};
}

1;