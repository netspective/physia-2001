##############################################################################
package App::Page::Error;
##############################################################################

use strict;
use App::Page;
use App::Universal;

use vars qw(@ISA %MESSAGE_INFO %RESOURCE_MAP);
@ISA = qw(App::Page);

%RESOURCE_MAP = (
	'error' => {},
	);

use enum qw(BITMASK:ERRMSGFLAG_ SHOWARLINFO SHOWCGIPARAMS);
use constant DEFAULT_ERRORMSGFLAGS => ERRMSGFLAG_SHOWARLINFO;

%MESSAGE_INFO = (
	'UIE-000100' => [DEFAULT_ERRORMSGFLAGS, 'Invalid ARL'],
	'UIE-001010' => [DEFAULT_ERRORMSGFLAGS, 'Parameter person_id Expected'],
);

sub prepare
{
	my $self = shift;
	$self->addLocatorLinks(
			['Home', '/home'],
			['Error', '', undef, App::Page::MENUITEMFLAG_FORCESELECTED],
		);

	if(my $info = $MESSAGE_INFO{$self->param('errorcode')})
	{
		$self->addContent(qq{
			<table bgcolor=BBBBBB cellspacing=1 cellpadding=2 border=0>
				<tr bgcolor=BEIGE>
					<td>$info->[1]</td>
				</tr>
				<tr bgcolor=EEEEEE>
				<td>
					<table>
						<tr><td>ARL</td><td><code>@{[ $self->param('arl') ]}</code></td></tr>
						<tr><td>Resource</td><td><code>@{[ $self->param('arl_resource') ]}</code></td></tr>
						<tr><td>Path Items</td><td><code>@{[ join('/', $self->param('arl_pathItems')) ]}</code></td></tr>
					</table>
				</td>
				</tr>
			<table>
		});
	}
	else
	{
		$self->addContent("Error ", $self->param('errorcode'), " -- no message information available.");
	}
	return 1;
}

1;
