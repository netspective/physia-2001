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

	$self->addContent(qq{
		<script src="/lib/dynamic-page.js" language="JavaScript1.2"></script>
		<link rel="stylesheet" type="text/css" href="/lib/dynamic-page.css">

		<script>
			if(loadSource('/resources/data/clinical-dictionary.xml'))
			{
				var html = createTemplateHtml(activeTemplate);
				document.write(html);
			}
			else
			{
				document.write("Unable to load source file.");
			}
		</script>
	});
}

1;
