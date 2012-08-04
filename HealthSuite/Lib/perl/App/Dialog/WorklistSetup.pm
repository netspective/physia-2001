##############################################################################
package App::Dialog::WorklistSetup;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Component::WorkList::PatientFlow;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Person;
use App::Statements::Component::Scheduling;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'worklist_setup' => {},	
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'worklistSetup', heading => 'Worklist Setup');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	my $resourcesField = 	new CGI::Dialog::Field(
		caption => 'Physician',
		name => 'physician_list',
		style => 'multidual',
		fKeyStmtMgr => $STMTMGR_PERSON,
		fKeyStmt => 'selResourceAssociations',
		fKeyDisplayCol => 1,
		fKeyValueCol => 0,
		size => 5,
		multiDualCaptionLeft => 'Available Physicians',
		multiDualCaptionRight => 'Selected Physicians',
	);
	
	my $facilitiesField = new App::Dialog::Field::OrgType(
		caption => 'Facility',
		name => 'facility_list',
		style => 'multidual',
		types => qq{'CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE'},
		size => 5,
		multiDualCaptionLeft => 'Available Facilities',
		multiDualCaptionRight => 'Selected Facilities',		
	);
	$facilitiesField->clearFlag(FLDFLAG_REQUIRED);

	my $patientSelOptions;
	for my $key (reverse sort(keys %PATIENT_URLS))
	{
		#$patientSelOptions .= "$key:$PATIENT_URLS{$key}->{arl},";
		$patientSelOptions .= "$key:$key,";
	}
	
	my $physSelOptions;
	for my $key (reverse sort(keys %PHYSICIAN_URLS))
	{
		#$physSelOptions .= "$key:$PHYSICIAN_URLS{$key}->{arl},";
		$physSelOptions .= "$key:$key,";
	}
	
	my $orgSelOptions;
	for my $key (reverse sort(keys %ORG_URLS))
	{
		#$orgSelOptions .= "$key:$ORG_URLS{$key}->{arl},";
		$orgSelOptions .= "$key:$key,";
	}
	
	my $apptSelOptions;
	for my $key (reverse sort(keys %APPT_URLS))
	{
		#$apptSelOptions .= "$key:$APPT_URLS{$key}->{arl},";
		$apptSelOptions .= "$key:$key,";
	}

	$self->addContent(
		new CGI::Dialog::Subhead(heading => 'Physicians'),
		$resourcesField,
		new CGI::Dialog::Subhead(heading => 'Facilities'),
		$facilitiesField,
		new CGI::Dialog::Subhead(heading => 'On-Select'),
		
		new CGI::Dialog::Field(
			name => 'patientOnSelect',
			caption => 'Patient',
			choiceDelim =>',',
			selOptions => $patientSelOptions,
			type => 'select',
		),

		new CGI::Dialog::Field(
			name => 'physicianOnSelect',
			caption => 'Physician',
			choiceDelim =>',',
			selOptions => $physSelOptions,
			type => 'select',
		),

		new CGI::Dialog::Field(
			name => 'orgOnSelect',
			caption => 'Organization',
			choiceDelim =>',',
			selOptions => $orgSelOptions,
			type => 'select',
		),

		new CGI::Dialog::Field(
			name => 'apptOnSelect',
			caption => 'Appointment',
			choiceDelim =>',',
			selOptions => $apptSelOptions,
			type => 'select',
		),
		
	);

	$self->addFooter(new CGI::Dialog::Buttons);
	
	return $self;
}

###############################
# makeStateChanges functions
###############################

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
}

###############################
# populateData functions
###############################

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	
	my $sessOrgId = $page->session('org_internal_id');
	$self->getField('physician_list')->{fKeyStmtBindPageParams} = $sessOrgId;

	my $physicansList = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, 
		STMTMGRFLAG_NONE, 'sel_worklist_resources', $page->session('user_id'), 'WorkList', $sessOrgId);

	my @physicians = ();
	for (@$physicansList)
	{
		push(@physicians, $_->{resource_id});
	}
	
	$page->field('physician_list', @physicians);
	
	my $facilityList = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, 
		STMTMGRFLAG_NONE, 'sel_worklist_facilities', $page->session('user_id'), $sessOrgId);

	my @facilities = ();
	for (@$facilityList)
	{
		push(@facilities, $_->{facility_id});
	}

	$page->field('facility_list', @facilities);
	
	for my $itemType (@ITEM_TYPES)
	{
		my $name = $itemType . 'OnSelect';

		if ($page->session($name))
		{
			$page->field($name, $page->session($name));
		}
		else
		{
			my $itemName = 'Worklist/' . "\u$itemType" . '/OnSelect';
			my $preference = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
				'selSchedulePreferences', $page->session('user_id'), $itemName);
			
			if (my $itemUrl = $preference->{resource_id})
			{
				$page->session($name, $itemUrl);
				$page->field($name, $itemUrl);
			}
		}
	}
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $userId =  $page->session('user_id');
	my $orgInternalId = $page->session('org_internal_id');
	
	$STMTMGR_COMPONENT_SCHEDULING->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_resources', $userId, 'WorkList', $orgInternalId);

	my @physicians = $page->field('physician_list');
	for (@physicians)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_internal_id') || undef,
			value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
			item_name => 'WorkList',
			value_text => $_,
			parent_org_id => $orgInternalId,
			_debug => 0
		);
	}
	
	$STMTMGR_COMPONENT_SCHEDULING->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_facilities', $userId, $orgInternalId);

	my @facilities = $page->field('facility_list');
	for (@facilities)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_internal_id') || undef,
			value_type => App::Universal::ATTRTYPE_RESOURCEORG || undef,
			item_name => 'WorkList',
			value_int => $_,
			parent_org_id => $orgInternalId,
			_debug => 0
		);
	}

	for my $itemType (@ITEM_TYPES)
	{
		my $itemName = 'Worklist/' . "\u$itemType" . '/OnSelect';

		my $preference = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
			'selSchedulePreferences', $userId, $itemName);
			
		my $itemID = $preference->{item_id};
		my $command = (defined $itemID) ? 'update' : 'add';

		my $name = $itemType . 'OnSelect';

		$page->schemaAction(
			'Person_Attribute', $command,
			item_id     => $command eq 'add' ? undef : $itemID,
			parent_id   => $userId,
			item_name   => $itemName,
			value_text   => $page->field($name),
		);
		
		$page->session($name, $page->field($name));
	}
	
	$self->handlePostExecute($page, $command, $flags);
}

1;
