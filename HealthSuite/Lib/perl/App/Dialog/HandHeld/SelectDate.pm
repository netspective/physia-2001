##############################################################################
package App::Dialog::HandHeld::SelectDate;
##############################################################################

use strict;
use SDE::CVS ('$Id: SelectDate.pm,v 1.1 2001-01-31 19:07:46 thai_nguyen Exp $', '$Name:  $');

use base qw(CGI::Dialog);
use CGI::Validator::Field;
use Date::Manip;

use vars qw($INSTANCE);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'selectDate');

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Select Date',
			name => 'select_date',
			type => 'date',
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub hideEntry
{
	return 1;	
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	
	$page->field('select_date', $page->session('handheld_select_date') || UnixDate('today',
		'%m/%d/%Y'));
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	$page->session('handheld_select_date', $page->field('select_date'))
		if ( $page->field('select_date') =~ /\d\d\/\d\d\/\d\d\d\d/
			&& ParseDate($page->field('select_date'))
		)
	;
	
	$page->redirect('/mobile?acceptDup=1');
}

$INSTANCE = new __PACKAGE__;
$INSTANCE->heading("Select Date");

1;
