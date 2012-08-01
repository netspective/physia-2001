##############################################################################
package App::Data::MDL::Organization;
##############################################################################

use strict;
use App::Data::MDL::Module;
use App::Universal;
use App::Data::MDL::Invoice;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;

use Date::Manip;
use vars qw(@ISA);

@ISA = qw(App::Data::MDL::Module App::Data::MDL::Invoice);

use vars qw(%SERVICE_PLACE_TYPE_MAP %PERMISSION_ROLE_TYPE);

%SERVICE_PLACE_TYPE_MAP = (
	'Office' => App::Universal::SERVICE_PLACE_OFFICE,
	'Inpatient Hospital' => App::Universal::SERVICE_PLACE_INPATIENTHOSPITAL,
	'Outpatient Hospital' => App::Universal::SERVICE_PLACE_OUTPATIENTHOSPITAL,
	'Emergency Room Hospital' => App::Universal::SERVICE_PLACE_EMERGENCYROOM,

);

%PERMISSION_ROLE_TYPE = (
	'Grant' => App::Universal::ROLE_GRANT,
	'Revoke' => App::Universal::ROLE_REVOKE,
);

sub new
{
	my $type = shift;
	my $self = new App::Data::MDL::Module(@_, parentTblPrefix => 'Org');
	return bless $self, $type;
}
#	<!ELEMENT resources (resource)+>
#		<!ELEMENT resource (resource_type, status, duration, portable, parent_resource?, provider_id?, facility_id?, remarks?)>
#			<!ATTLIST resource
#				id CDATA #REQUIRED
##				caption CDATA #REQUIRED
#			>
#			<!ELEMENT resource_type %DATATYPE.ENUM;>
#			<!ELEMENT status %DATATYPE.TEXT;>
#			<!ELEMENT duration %DATATYPE.TEXT;>
#			<!ELEMENT portable %DATATYPE.TEXT;>
#			<!ELEMENT parent_resource %DATATYPE.TEXT;>
#			<!ELEMENT provider_id %DATATYPE.TEXT;>
#			<!ELEMENT facility_id %DATATYPE.TEXT;>
#			<!ELEMENT remarks %DATATYPE.TEXT;>

#SQL> describe resource_item
# Name                                                  Null?    Type
# ----------------------------------------------------- -------- --------------
# RESOURCE_ID                                           NOT NULL NUMBER(16)
# CR_SESSION_ID                                                  VARCHAR2(16)
# CR_STAMP                                              NOT NULL DATE
# CR_USER_ID                                            NOT NULL VARCHAR2(32)
# VERSION_ID                                            NOT NULL NUMBER(16)
# PARENT_ID                                                      NUMBER(16)
# OWNER_ID                                              NOT NULL VARCHAR2(16)
# RESOURCE_TYPE                                         NOT NULL NUMBER(8)
# STATUS                                                NOT NULL NUMBER(1)
# CAPTION                                               NOT NULL VARCHAR2(128)
# PROVIDER_ID                                                    VARCHAR2(16)
# FACILITY_ID                                                    VARCHAR2(16)
# DURATION                                              NOT NULL NUMBER(8)
# PORTABLE                                              NOT NULL NUMBER(1)
# REMARKS                                                        VARCHAR2(2048)


sub importHealthMaintenance
{
	my ($self, $flags, $healthRule, $org) = @_;
	if (my $list = $healthRule->{rule})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			$self->schemaAction($flags, 'Hlth_Maint_Rule', 'add',
						org_id => $org,
						rule_id => $item->{'rule-id'},
						gender => $self->translateEnum($flags, "Gender", $item->{gender}),
						start_age => $item->{'start-age'},
						end_age => $item->{'end-age'},
						age_metric => $self->translateEnum($flags, "Time_Metric", $item->{'age-metric'}),
						measure => $item->{measure},
						periodicity => $item->{periodicity},
						periodicity_metric => $self->translateEnum($flags, "Time_Metric", $item->{'periodicity-metric'}),
						diagnoses => $item->{'icd-code'},
						directions =>$item->{directions},
						source => $item->{source},
						src_begin_date => $item->{'source-startdate'},
						src_end_date => $item->{'source-enddate'}
					);
		}
	}
}

sub importResources
{
	my ($self, $flags, $resources, $parentStruct) = @_;
	unless($resources)
	{
	$self->logMsg($flags, "In importResources, but no resources tag in data file.");
		$self->itemMissingMsg($flags, 'No resources records found.');
		return;
	}
	$self->logMsg($flags, "In importResources ....\n");
	#my $dv = new Dumpvalue;
	#$dv->dumpValue($insurance);

	if(my $list = $resources->{resource})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			$self->schemaAction($flags, 'Resource_Item', 'add',
				owner_id => $parentStruct,
				caption => $item->{caption},
				resource_type => $self->translateEnum($flags, "Resource_Type", $item->{resource_type}),
				status => $item->{status},
				duration => $item->{duration},
				portable => $item->{portable},
				parent_id => exists $item->{parent_resource} ? $item->{parent_resource} : undef,
				provider_id => exists $item->{provider_id} ? $item->{provider_id} : undef,
				facility_id => exists $item->{facility_id} ? $item->{provider_id} : undef,
				remarks => exists $item->{remarks} ? $item->{remarks} : undef);
		}
	}
	$self->logMsg($flags, "Exit from importResources ....\n");
}

sub importGeneralInfo
{
	my ($self,  $flags, $generalinfo,$org) = @_;
	if(my $list = $generalinfo->{property})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $dv = new Dumpvalue;
			$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $org,
				item_name =>"$item->{name}",
				value_type =>  App::Universal::ATTRTYPE_ORGGENERAL,
				value_text => $item->{value});
		}
	}
}

sub importCredentials
{
	my ($self,  $flags, $credentials,$org) = @_;
	if(my $list = $credentials->{credential})
	{

		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
		#my $dv = new Dumpvalue;
		#$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $org,
				item_name => "$item->{_text}",
				value_type => App::Universal::ATTRTYPE_CREDENTIALS,
				value_dateEnd =>  $item->{expires},
				value_text => $item->{number},
				value_textB => $item->{_text});
		}
	}
}

sub importAssociatedOrg
{
	my ($self,  $flags, $assocorg,$org) = @_;
	if(my $list = $assocorg->{'assoc-org'})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $org,
				item_name => 'Org',
				value_type => App::Universal::ATTRTYPE_RESOURCEORG,
				value_text => $item->{id});
		}
	}
}

sub importAssociatedEmp
{
	my ($self,  $flags, $assocemp,$org) = @_;
	if(my $list = $assocemp->{emp})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $org,
				item_name => 'Staff',
				value_type => App::Universal::ATTRTYPE_RESOURCEOTHER,
				value_text => $item->{id});
		}
	}
}

sub importContactInfo
{
	my ($self,  $flags, $contactinfo,$org) = @_;
	if(my $list = $contactinfo)
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $org,
				item_name => 'Contact Information',
				value_type => App::Universal::ATTRTYPE_BILLING_PHONE,
				value_textB => $item->{_text},
				value_text => $item->{phone});
		}
	}
}

sub importAppointments
{
	my ($self, $flags, $event, $org) = @_;
	my $owner = $org;
	my $parentId = $org;
	if(my $parent = $event)
	{
		$parent = [$parent] if ref $parent eq 'HASH';
		foreach my $parent (@$parent)
		{
			$self->importEvent($flags, $parent, $owner);
		}

	}
}

sub importRolePermissions
{
	my ($self,  $flags, $permissions,$org) = @_;
	if(my $list = $permissions->{permission})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $permissionRole = $item->{'role'};
			my $roleNameId = '';
			my $existRoleId = '';
			my $roleNameExists = $STMTMGR_PERSON->recordExists($self,STMTMGRFLAG_NONE, 'selRoleNameExists', $permissionRole);
			if ($roleNameExists !=1)
			{
				$roleNameId = $self->schemaAction($flags, "Role_Name", 'add',
									role_name => $permissionRole
								);
			}
			else
			{
				my $existRoleData =  $STMTMGR_PERSON->getRowAsHash($self,STMTMGRFLAG_NONE, 'selRoleNameExists', $permissionRole);
				$existRoleId = $existRoleData->{'role_name_id'};
			}
			my $roleId = $roleNameId ne '' ? $roleNameId : $existRoleId;
			$self->schemaAction($flags, "Role_Permission", 'add',
						org_internal_id  => $org,
						role_name_id => $roleId,
						permission_name  => $item->{name},
						role_activity_id => $PERMISSION_ROLE_TYPE{exists $item->{activity} ? $item->{activity} :'Active'}
					);

		}
	}
}


sub importOrgRegistry
{
	my ($self, $flags, $registry, $org) = @_;
	my $orgId = $org->{id};
	if (my $registry = $org->{org_registry})
	{
		my $registryNames = $registry->{org_names};
		my $parentOrg = exists $registry->{parent_org} ? $registry->{parent_org} : '';
		my $ownerOrg = $registry->{'owner-org'};
		my $ownerOrgIdExist = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $ownerOrg);
		my $ownerOrgId = exists $registry->{parent_org} ? $ownerOrgIdExist : 0;
		my $parentOrgId =  $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $parentOrg) if $registry->{parent_org} ne '';
		my $orgPrimary = $self->schemaAction($flags, 'Org', 'add',
						org_id => $orgId || undef,
						owner_org_id => $ownerOrgId || undef,
						name_primary => exists $registryNames->{primary} ? $registryNames->{primary} : undef,
						name_trade => exists $registryNames->{trade} ? $registryNames->{trade} : undef,
						tax_id => exists $registry->{taxid} ? $registry->{taxid} : undef,
						category => exists $registry->{type} ? $registry->{type} : undef,
						parent_org_id => $parentOrgId || undef
					);

		$STMTMGR_ORG->execute($self, STMTMGRFLAG_NONE, 'selUpdateOwnerOrgId', $orgPrimary, $orgPrimary) if $parentOrgId eq '';

		if (my $sevice = $registry->{'service-place'})
		{
			$self->schemaAction($flags, 'Org_Attribute', 'add',
							parent_id => $orgPrimary || undef,
							item_name => 'HCFA Service Place',
							value_type => App::Universal::ATTRTYPE_INTEGER,
							value_text => $SERVICE_PLACE_TYPE_MAP{$sevice ? $sevice : 'Office'},
							value_textB => $sevice
						);
		}

		$self->importContactMethods($flags, $org->{'contact-methods'}, $orgId, $orgPrimary);
		$self->importRolePermissions($flags, $org->{'role-permissions'}, $orgPrimary);
		$self->importAssociations($flags, $org->{associations}, $orgPrimary);
		$self->importInsurance($flags, $org->{'insurance-plans'}, $orgPrimary);
		$self->importGeneralInfo($flags, $org->{generalinfo}, $orgPrimary);
		$self->importCredentials($flags, $org->{credentials}, $orgPrimary);
		$self->importAssociatedOrg($flags, $org->{'assoc-orgs'}, $orgPrimary);
		$self->importAssociatedEmp($flags, $org->{'assoc-emp'}, $orgPrimary);
		$self->importContactInfo($flags, $org->{'contact-info'}, $orgPrimary);
		$self->importAppointments($flags, $org->{'events'}, $orgPrimary);
		$self->importHealthMaintenance($flags, $org->{'health-maintenance'}, $orgPrimary);
	}

}

sub importStruct
{
	my ($self, $flags, $org) = @_;
	$self->{mainStruct} = $org;
	$self->importOrgRegistry($flags, $org->{org_registry}, $org);
	#$self->importResources($flags|MDLFLAG_LOGACTIVITY|MDLFLAG_SHOWMISSINGITEMS, $org->{resources}, $org);
}

1;