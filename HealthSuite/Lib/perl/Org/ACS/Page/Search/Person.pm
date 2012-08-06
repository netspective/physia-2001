##############################################################################
package Org::ACS::Page::Search::Person;
##############################################################################

use strict;
use App::Page;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Person;

use vars qw(@ISA);
@ISA = qw(App::Page::Search::Person);

sub execute
{
	my ($self, $type, $expression) = @_;
	# oracle likes '%' instead of wildcard '*'
	my $appendStmtName = $expression =~ s/\*/%/g ? '_like' : '';
	my $bindParams = $type eq 'anyname' ? [$self->session('org_internal_id'), uc($expression) , uc($expression)] : [$self->session('org_internal_id'), uc($expression)];
	my $category = "";
	for ($self->param('_pm_view'))
	{
		/person/ and do {last};
		$category = "_$_";
	}
	
	my $idUrl = $self->flagIsSet(PAGEFLAG_ISPOPUP) ? 'javascript:chooseEntry(\'#0#\')' : '/person/#0#/stpe-person.referralAndIntake/dlg-add-referral?_f_person_id=#0#&home=/person/#0#/profile';
	my $actionURL = $self->flagIsSet(PAGEFLAG_ISPOPUP) ? '/person/#0#/stpe-person.referralAndIntake/dlg-add-referral?_f_person_id=#0#&home=/person/#0#/profile' : 'javascript:chooseEntry(\'#0#\')';
	
	$self->addContent(
		'<CENTER>',
		$STMTMGR_PERSON_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_$type$appendStmtName$category", $bindParams, undef, undef,
			{
				columnDefn =>
						[
							{ head => 'ID', url => $idUrl, },
							{ head => 'Last Name' },
							{ head => 'First Name' },
							{ head => 'SSN'},
							{ head => 'Date of Birth'},
							{ head => 'Home Phone'},
							{ head => 'Action', dataFmt => "<a href=\"$actionURL\" style=\"text-decoration:none\"><img src=\"/resources/images/icons/hand-pointing-to-folder-sm.gif\" border=0></a>" },
						],
			}
			),
		'</CENTER>'
		);

	return 1;
}

1;
