##############################################################################
package App::Dialog::Field::Association;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use DBI::StatementManager;
use App::Statements::Person;
use Schema::Utilities;
use vars qw(@ISA);
@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;

	$params{name} = 'relation' unless $params{name};
	$params{hints} = "Select an existing relationship type or select 'Other' and fill in the 'Other' field" unless $params{hints};
	$params{fields} =
	[
		new CGI::Dialog::Field(caption => 'Relationship',
					name => 'rel_type',
					fKeyStmtMgr => $STMTMGR_PERSON,
					fKeyStmt => 'selRelationship',
					fKeyDisplayCol => 0,
					fKeyValueCol => 0,
					options => $params{options}
				),

		new CGI::Dialog::Field(caption => 'Other', name => 'other_rel_type', onValidate => \&validateOther),
	];

	return CGI::Dialog::Field::new($type, %params);
}

sub validateOther
{
	my ($dialogItem, $page, $dialog, $value, $extraData) = @_;

	if($page->field('rel_type') eq 'Other' && ! $page->field('other_rel_type'))
	{
		return ("Please provide 'Other' relationship name.");
	}

	if($page->field('rel_type') ne 'Other' && $page->field('other_rel_type'))
	{
		return ("If you supply a value in the 'Other' field, you must select 'Other' from the 'Relationship' pull-down");
	}

	return ();
}

1;