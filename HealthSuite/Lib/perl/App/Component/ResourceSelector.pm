##############################################################################
package App::Component::ResourceSelector;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Component::Scheduling;
use Data::Publish;

use vars qw(@ISA);
@ISA   = qw(CGI::Component);

sub initialize
{
	my ($self, $page) = @_;
	my $layoutDefn = $self->{layoutDefn};
	my $arlPrefix = '/worklist';

	$layoutDefn->{frame}->{heading} = "Resource Selector";
	$layoutDefn->{style} = 'panel';
}

sub getHtml
{
	my ($self, $page) = @_;

	$self->initialize($page);
	createLayout_html($page, $self->{flags}, $self->{layoutDefn}, $self->getComponentHtml($page));
}

sub getComponentHtml
{
	my ($self, $page) = @_;

	my $dialog = new CGI::Dialog(schema => $page->getSchema());

	my $field = 	new CGI::Dialog::Field(caption => 'Physician',
		name => 'physList',
		style => 'multicheck',
		hints => 'Choose one or more Physicians to monitor.',
		fKeyStmtMgr => $STMTMGR_PERSON,
		fKeyStmt => 'selResourceAssociations',
		fKeyDisplayCol => 1,
		fKeyValueCol => 0,
	);

	$dialog->addContent($field);

	my $sessOrgId = $page->session('org_id');
	$dialog->getField('physList')->{fKeyStmtBindPageParams} = $sessOrgId;

	my $physicansList = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, 
		STMTMGRFLAG_NONE, 'sel_worklist_resources', $page->session('user_id'));

	my @physicians = ();
	for (@$physicansList)
	{
		push(@physicians, $_->{resource_id});
	}
	
	$page->field('physList', @physicians);

	my $fieldHtml = $field->getHtml($page, $dialog);

	return qq{
		<FORM method=POST name=resourceListForm>
			<INPUT TYPE=HIDDEN NAME="_f_action_change_resources" VALUE="1">
			$fieldHtml
			<tr><td>&nbsp;</td><td>&nbsp;</td><td align=right>
				<input type=submit value=" Apply ">
			</td></tr>
		</FORM>
	};
}

# auto-register instance
new App::Component::ResourceSelector(id => 'resourceselector');

1;
