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
	my ($self, $page) = @_;
	my $html;
	
	my $inPatients = $STMTMGR_HANDHELD->getRowsAsHashList($page, 0, 'sel_inPatients',
		$page->session('user_id'), $page->session('org_internal_id') );
		
	if (@{$inPatients})
	{
		for (@{$inPatients})
		{
			$html .= qq{<br>
				<b>$_->{hospital_name}</b><br>
				Room: $_->{room}<br>
				$_->{patient_name} <a href='Manage_Patient?pid=$_->{patient_id}'>$_->{patient_id}</a><br>
				Admitted: $_->{begin_date}<br>
				ICDs: $_->{diags}<br>
				CPTs: $_->{procs}<br>
			};
		}
	}
	else
	{
		$html = 'No Hospital patients found.<br>';
	}
	
	return $html;
}

$INSTANCE = new __PACKAGE__;

1;