##############################################################################
package App::Page::Person::ClinicalNote;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use CGI::ImageManager;
use Date::Manip;
use App::Configuration;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/cnote' => {},
	);


sub prepare_view
{
	my ($self) = @_;

	my $personId = $self->param ('person_id');
	my $templateFile = $self->param ('template');
	my $html;
	
	if ($templateFile) {
		$html = qq{
			<script src="/lib/dynamic-page.js" language="JavaScript1.2"></script>
			<link rel="stylesheet" type="text/css" href="/lib/dynamic-page.css">
	
			<script>
				if(loadSource('/resources/data/$templateFile'))
				{
					var html = createTemplateHtml(activeTemplate);
					document.write(html);
				}
				else
				{
					document.write("Unable to load source file.");
				}
			</script>
		};
	} else {
		$html = $self->findResources (qq{/person/$personId/cnote?template=});
	}

	$self->addContent(qq{
		$html
	});

}

sub findResources {
	my ($self) = shift;
	my ($url) = shift;
	my $html = qq{Please choose from the follow xml templates:<br>};
	
	my $dirOpened = opendir DIRHANDLE, '/export/home/sjaveed/projects/HealthSuite/WebSite/resources/data';
	
	if ($dirOpened) {
		my @xmlDatafiles = grep /\.xml$/i, readdir DIRHANDLE;
		
		foreach my $xmlFile (@xmlDatafiles) {
			$html .= qq{<a href="$url$xmlFile">$xmlFile</a><br>};
		}
	} else {
		$html .= '<b>Couldnt open directory /export/home/sjaveed/projects/HealthSuite/WebSite/resources/data<br>';
	}
	
	return $html;
}

1;
