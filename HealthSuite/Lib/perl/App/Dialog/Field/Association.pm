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
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;

	$params{fields} =
	[
		#new CGI::Dialog::Field(caption => 'Relationship',
		#						type => 'foreignKey',
		#						name => 'rel_type',
		#						fKeyTable => 'Relationship',
		#						fKeySelCols => "caption",
		#						fKeyDisplayCol => 0,
		#						fKeyValueCol => 0),
		new CGI::Dialog::Field(caption => 'Relationship',								
								name => 'rel_type',
								fKeyStmtMgr => $STMTMGR_PERSON,
								fKeyStmt => 'selRelationship',								
								fKeyDisplayCol => 0,
								fKeyValueCol => 0),

		new CGI::Dialog::Field(caption => 'Other Relationship', name => 'other_rel_type', onValidate => \&validateOther),
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
		return ("When supplying a relationship name, select 'Other'.");
	}

	return ();
}

use constant FAMILY_DIALOG => 'Dialog/Family';

@CHANGELOG =(
	
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/16/2000', 'RK',
		FAMILY_DIALOG,
		'Replaced fkeyxxx select in the dialog with Sql statement from Statement Manager.'],
);

1;