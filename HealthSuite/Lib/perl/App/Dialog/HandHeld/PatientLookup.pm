##############################################################################
package App::Dialog::HandHeld::PatientLookup;
##############################################################################

use strict;
use SDE::CVS ('$Id: PatientLookup.pm,v 1.2 2000-12-28 23:29:53 thai_nguyen Exp $', '$Name:  $');

use base qw(CGI::Dialog);
use CGI::Validator::Field;
use App::Statements::Search::Person;

use vars qw($INSTANCE);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'patientLookup');

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Criteria',
			name => 'criteria',
			type => 'select',
			selOptions => qq{
				Person ID : id;
				Last Name : lastname;
				First or Last Name : anyname;
				Social Security : ssn;
				Date of Birth : dob;
				Phone Number : phone;
				Account Number : account;
				Chart Number : chart;
			},
			options => FLDFLAG_PREPENDBLANK | FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(caption => 'Value',
			name => 'search_value',
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $type = $page->field('criteria');
	my $expression = $page->field('search_value');
	my $category = '_patient';
	
	my $appendStmtName = $expression =~ s/\*/%/g ? '_like' : '';
	my $bindParams = $type eq 'anyname' ? 
		[$page->session('org_internal_id'), uc($expression), uc($expression)] : 
		[$page->session('org_internal_id'), uc($expression)];

	my $statement = "sel_$type$appendStmtName$category";
	my $results = $STMTMGR_PERSON_SEARCH->getRowsAsHashList($page, 0, $statement, @{$bindParams});
	my $html;

	return 'No patient found meeting criteria.' unless (@{$results});
	
	for (@{$results})
	{
		$html .= qq{
			<b>$_->{name}</b> <a href='Manage_Patient?pid=@{[ $_->{person_id} ]}'>$_->{person_id}</a><br>
			DOB: $_->{dob}<br>
			SSN: $_->{ssn}<br>
			Home Phone: $_->{home_phone}<br>
		};
	}

	return $html;
}

$INSTANCE = new __PACKAGE__;
$INSTANCE->heading("Patient Lookup");

1;
