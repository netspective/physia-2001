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
	my $dictionaryFile = $self->param ('dictionary');
	my $html;
	
	if ($templateFile) {
		$html = qq{
			<script src="/lib/dynamic-page.js" language="JavaScript1.2"></script>
			<link rel="stylesheet" type="text/css" href="/lib/dynamic-page.css">
	
			<script>
				if(loadSource('/resources/data/$dictionaryFile', '/resources/data/$templateFile'))
				{
					var html = createTemplateHtml(activeTemplate);
					document.write(html);
					var srcWin = window.open("", "source", "location,status,scrollbars,width=800,height=600");
					var srcHtml = html.replace (/</g, '&lt;');
					srcHtml = srcHtml.replace (/>/g, '&gt;');
					srcHtml = srcHtml.replace (/&lt;/g, '<font color="blue">&lt;</font>');
					srcHtml = srcHtml.replace (/&gt;/g, '<font color="blue">&gt;</font>');
					srcWin.document.write('<pre>' + srcHtml + '</pre>');				
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
	my $personId = $self->param ('person_id');
	my $html = qq{Please choose from the follow xml templates:<br>};
	
	my $dirOpened = opendir DIRHANDLE, $CONFDATA_SERVER->path_XMLData();
	
	if ($dirOpened) {
		my @xmlDatafiles = grep /\.data.xml$/i, readdir DIRHANDLE;
		rewinddir DIRHANDLE;
		my @xmlTemplatefiles = grep /\.template.xml$/i, readdir DIRHANDLE;
		
		my $dataSelectHtml = q{<select name="dictionary" size="1">\n};
		my $templateSelectHtml = q{<select name="template" size="!">\n};

		foreach my $xmlFile (sort @xmlDatafiles) {
			my $xmlFilename = $xmlFile;
			
			if ($xmlFile =~ /(.+).data.xml$/) {
				$xmlFilename = $1;
			}
			
			$dataSelectHtml .= qq{\t<option value="$xmlFile">$xmlFilename</option>\n};
		}
		
		foreach my $xmlFile (sort @xmlTemplatefiles) {
			my $xmlFilename = $xmlFile;
			
			if ($xmlFile =~ /(.+).template.xml$/) {
				$xmlFilename = $1;
			}
			
			$templateSelectHtml .= qq{\t<option value="$xmlFile">$xmlFilename</option>\n};
		}
		
		$dataSelectHtml .= q{</select>};
		$templateSelectHtml .= q{</select>};
		
		$html .= qq{
			<form action="/person/$personId/cnote" method="post">
				<table>
					<tr>
						<td align="right" valign="top">Data Dictionary:</td>
						<td align="left" valign="top">$dataSelectHtml</td>
					</tr>
	
					<tr>
						<td align="right" valign="top">Template:</td>
						<td align="left" valign="top">$templateSelectHtml</td>
					</tr>
					
					<tr colspan="0" align="center">
						<td align="center" valign="top"><input type="submit" value="submit"><input type="reset" value="reset"></td>
					</tr>
				</table>
			</form>
		};
	} else {
		$html .= '<b>Couldnt open directory /export/home/sjaveed/projects/HealthSuite/WebSite/resources/data<br>';
	}
	
	return $html;
}

1;
