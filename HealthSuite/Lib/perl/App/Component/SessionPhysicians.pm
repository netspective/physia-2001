##############################################################################
package App::Component::SessionPhysicians;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use vars qw(%RESOURCE_MAP);
use base qw(CGI::Component);

use DBI::StatementManager;
use App::Statements::Component::Person;

%RESOURCE_MAP = (
	'sessionPhysicians' => {
		_class => new App::Component::SessionPhysicians(),
	},
);

sub init
{
	my $self = shift;
	my $layoutDefn = $self->{layoutDefn};

	$layoutDefn->{frame}->{heading} = 'Session Set of Physicians';
	#$layoutDefn->{frame}->{borderWidth} = 0;
	$layoutDefn->{frame}->{editUrl} = qq{
		<A HREF='/person/#param.person_id#/dlg-update-resource-session-physicians?home=#homeArl#'>
		<IMG SRC='/resources/icons/action-edit.gif' BORDER=0></A>};
}

sub getHtml
{
	my ($self, $page) = @_;
	
	my $physicians = $STMTMGR_COMPONENT_PERSON->getSingleValueList($page, STMTMGRFLAG_CACHE,
		'person.associatedSessionPhysicians', $page->session('user_id'), $page->session('org_internal_id'));
	
	my @physHref = ();
	for (@$physicians)
	{
		push(@physHref, qq{<a href="/person/$_/summary" title="View $_ Summary">$_</a>});
	}
	createLayout_html($page, $self->{flags}, $self->{layoutDefn}, join(', ', @physHref));
}


1;
