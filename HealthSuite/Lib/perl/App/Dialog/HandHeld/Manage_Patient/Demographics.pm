##############################################################################
package App::Dialog::HandHeld::Demographics;
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
	my $self = App::Dialog::HandHeld::new($class, id => 'demographics', heading => 'Demographics', @_);
	$self->{sqlStmtId} = 'sel_patientDemographics';
	
	return $self;
}

sub getHtml
{
	my $self = shift;
	my $page = shift;

	return "No patient selected.  Please select a patient." unless $page->session('active_person_id');
	
	my $html = '';
	if(my $sth = $STMTMGR_HANDHELD->execute($page, 0, $self->{sqlStmtId}, 
		$page->session('active_person_id')))
	{
		while(my $row = $sth->fetch())
		{
			$html .= qq{
				<b>$row->[0]</b><br>
				$row->[5], $row->[6], DOB: $row->[4]<br>
				Address:<br>
				$row->[1]<br>
				(H) $row->[2]<br>
				(W) $row->[3]<br>
			};
		}
	}
	
	if(my $sth = $STMTMGR_HANDHELD->execute($page, 0, 'sel_patientInsurance', 
		$page->session('active_person_id')))
	{
		$html .= '<br>INSURANCE<br>';
		while(my $row = $sth->fetch())
		{
			$html .= qq{
				@{[ $row->[2] ? $row->[2] . ': ' . $row->[5] : $row->[4] . ' ' . $row->[3] ]}<br>
				@{[ $row->[2] ? $row->[4] : '' ]}<br>
			};
		}
	}
	
	return $html;
}

sub showActivePatient
{
	return 1;
}

$INSTANCE = new __PACKAGE__;

1;