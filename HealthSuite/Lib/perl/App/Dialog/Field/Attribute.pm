##############################################################################
package App::Dialog::Field::Attribute::Name;
##############################################################################

use strict;
use DBI::StatementManager;
use CGI::Validator::Field;
use CGI::Dialog;
use Schema::Utilities;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	die 'attrNameFmt required' unless $params{attrNameFmt};
	die 'fKeyStmtMgr required' unless $params{fKeyStmtMgr};
	die 'selAttrNameStmtName required' unless $params{selAttrNameStmtName};

	$params{name} = 'item_name' unless $params{name};
	$params{options} = 0 unless exists $params{options};

	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;

	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $validator->id());

	return () if $command ne 'add';

	my $entityId;
	if ($page->param('person_id'))
	{
		$entityId = $page->param('person_id')
	}
	else
	{
		$entityId = $self->{fKeyStmtMgr}->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id'));
	}
	if($self->SUPER::isValid($page, $validator))
	{
		my $itemName = $page->replaceVars($self->{attrNameFmt});
		my $value = $page->field($self->{name});

		$self->invalidate($page, "$self->{caption} '$value' already exists.")
			if $self->{fKeyStmtMgr}->recordExists($page, STMTMGRFLAG_NONE, $self->{selAttrNameStmtName}, $entityId, $itemName, $self->{valueType});
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

sub getRealItemName
{
	my ($self, $page) = @_;

	return $page->replaceVars($self->{attrNameFmt});
}

1;
