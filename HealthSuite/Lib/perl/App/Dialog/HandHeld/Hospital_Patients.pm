##############################################################################
package App::Dialog::HandHeld::HospitalPatients;
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
	return App::Dialog::HandHeld::new(@_, id => 'hosppatients', heading => 'Hospital Patients');
}

sub getHtml
{
	my $self = shift;
	my $page = shift;
	
	my $html = '';
	if(my $sth = $STMTMGR_HANDHELD->execute($page, 0, 'sel_inPatients', 
					$page->session('user_id'),
					$page->session('org_internal_id')))
	{
		while(my $row = $sth->fetch())
		{
			$html .= qq{<b>$row->[0]</b><br><a href="Manage_Patient?pid=$row->[4]">$row->[2]</a> ($row->[3])<br>$row->[5]<br>Room: @{[$row->[1] || 'N/A']}<p>};
		}
	}
	return $html;
}

$INSTANCE = new __PACKAGE__;

1;