##############################################################################
package App::Dialog::HandHeld::Chart;
##############################################################################

use strict;
use Carp;
use SDE::CVS();

use App::Dialog::HandHeld;
use App::Statements::HandHeld;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::HandHeld);

sub new
{
	my $class = shift;
	my $self = App::Dialog::HandHeld::new($class, id => 'chart', heading => 'Chart', @_);

	return $self;
}

sub getHtml
{
	my ($self, $page) = @_;
	
	my $html;
	
	my $activeMeds = $STMTMGR_HANDHELD->getRowsAsHashList($page, 0, 'sel_patientActiveMeds', 
		$page->session('active_person_id'));

	$html .= 'ACTIVE MEDICATIONS<br>';
	$html .= 'None<br>' unless(@{$activeMeds});
	for(@{$activeMeds})
	{
		$html .= qq{
			<b>$_->{med_name}</b><br>
			$_->{start_date} - $_->{end_date}<br>
			$_->{dose} $_->{dose_units} $_->{frequency} $_->{route}<br>
			Approved by: $_->{approved_by}<br>
		};
	}

	my $allergies = $STMTMGR_HANDHELD->getRowsAsHashList($page, 0, 'sel_patientAllergies',
		$page->session('active_person_id'));
	
	$html .= '<br>ALLERGIES<br>';
	$html .= 'None<br>' unless(@{$allergies});
	for (@{$allergies})
	{
		$html .= qq{
			<b>$_->{item_name}</b><br>
			$_->{value_text}<br>
		};
	}
	
	$html .= '<br>BLOOD TYPE<br>';
	$html .= $STMTMGR_HANDHELD->getSingleValue($page, 0, 'sel_patientBloodType',
		$page->session('active_person_id')) || 'N/A';

	my $activeProblems = $STMTMGR_HANDHELD->getRowsAsHashList($page, 0, 'sel_patientActiveProblems',
		$page->session('active_person_id'));
	
	$html .= '<br><br>ACTIVE PROBLEMS<br>';
	$html .= 'None<br>' unless(@{$activeProblems});
	for (@{$activeProblems})
	{
		$html .= qq{
			<b>$_->{code}</b> - $_->{curr_onset_date}<br>
			$_->{name}<br>
		};
	}

	return $html;
}

$INSTANCE = new __PACKAGE__;

1;