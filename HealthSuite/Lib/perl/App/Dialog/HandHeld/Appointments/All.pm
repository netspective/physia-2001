##############################################################################
package App::Dialog::HandHeld::Appointments::All;
##############################################################################

use strict;
use Carp;

use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::HandHeld;
use App::Statements::HandHeld;
use App::Universal;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::HandHeld);

sub new
{
	my $class = shift;
	my $self = App::Dialog::HandHeld::new($class, id => 'all', heading => 'All', @_);
	$self->{sqlStmtId} = 'sel_scheduledAppts';
	return $self;
}

sub getHtml
{
	my $self = shift;
	my $page = shift;
	
	my $html = '';
	if(my $sth = $STMTMGR_HANDHELD->execute($page, 0, $self->{sqlStmtId}, 
					$page->session('GMT_DAYOFFSET'), 
					$page->session('active_date'),
					$page->session('user_id'),
					$page->session('org_internal_id')))
	{
		while(my $row = $sth->fetch())
		{
			$html .= qq{$row->[0] <a href="../Manage_Patient?pid=$row->[1]">$row->[2]</a><br>&nbsp;&nbsp;&nbsp;$row->[3] ($row->[4])<br>};
		}
	}
	return $html;
}

$INSTANCE = new __PACKAGE__;

1;