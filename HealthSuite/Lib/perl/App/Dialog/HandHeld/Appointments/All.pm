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
	$self->{sqlStmtId} = 'sel_allAppts';
	
	return $self;
}

sub getHtml
{
	my $self = shift;
	my $page = shift;
	
	my $html = '';
	if(my $sth = $STMTMGR_HANDHELD->execute($page, 0, $self->{sqlStmtId}, 
			$page->session('GMT_DAYOFFSET'), 
			$page->session('handheld_select_date'),
			$page->session('user_id'),
			$page->session('org_internal_id')))
	{
		if (my $row = $sth->fetch())
		{
			$html = getRowHtml($row);

			while($row = $sth->fetch())
			{
				$html .= getRowHtml($row);
			}
		}
		else
		{
			$html = "No Appointment Found.";
		}
	}
	return $html;
}

sub getRowHtml
{
	my ($row) = @_;	
	
	return qq{$row->[0] $row->[2] (<a href="../Manage_Patient?pid=$row->[1]">$row->[1]</a>)
		<br>&nbsp;&nbsp;&nbsp;$row->[3] ($row->[4])<br>
	};
}

$INSTANCE = new __PACKAGE__;

1;