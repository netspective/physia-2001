##############################################################################
package App::Component::FacilitySelector;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Component::Scheduling;
use Data::Publish;

use vars qw(@ISA);
@ISA   = qw(CGI::Component);

sub initialize
{
	my ($self, $page) = @_;
	my $layoutDefn = $self->{layoutDefn};
	my $arlPrefix = '/worklist';

	$layoutDefn->{frame}->{heading} = "Facility Selector";
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

	my $field = 	new CGI::Dialog::Field(caption => 'Facility',
		name => 'facility_list',
		style => 'multicheck',
		hints => 'Choose one or more Facilities to monitor.',
		fKeyStmtMgr => $STMTMGR_SCHEDULING,
		fKeyStmt => 'selFacilityList',
		fKeyDisplayCol => 1,
		fKeyValueCol => 0,
	);

	$dialog->addContent($field);
	
	# populate	
	# --------
		my $facilityList = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, 
			STMTMGRFLAG_NONE, 'sel_worklist_facilities', $page->session('user_id'));
	
		my @facilities = ();
		for (@$facilityList)
		{
			push(@facilities, $_->{facility_id});
		}
		
		$page->field('facility_list', @facilities);

	# return
	# ------
	my $fieldHtml = $field->getHtml($page, $dialog);

	return qq{
		<FORM method=POST name=resourceListForm>
			<INPUT TYPE=HIDDEN NAME="_f_action_change_facilities" VALUE="1">
			$fieldHtml
			<tr><td>&nbsp;</td><td>&nbsp;</td><td align=right>
				<input type=submit value=" Apply ">
			</td></tr>
		</FORM>
	};
}

# auto-register instance
new App::Component::FacilitySelector(id => 'facilityselector');

1;
