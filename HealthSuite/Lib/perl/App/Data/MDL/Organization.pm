##############################################################################
package App::Data::MDL::Organization;
##############################################################################

use strict;
use App::Data::MDL::Module;
use App::Data::MDL::Invoice;
use vars qw(@ISA);

@ISA = qw(App::Data::MDL::Module App::Data::MDL::Invoice);

use vars qw(%SERVICE_PLACE_TYPE_MAP);

%SERVICE_PLACE_TYPE_MAP = (
	'Office' => App::Universal::SERVICE_PLACE_OFFICE,
	'Inpatient Hospital' => App::Universal::SERVICE_PLACE_INPATIENTHOSPITAL,
	'Outpatient Hospital' => App::Universal::SERVICE_PLACE_OUTPATIENTHOSPITAL,
	'Emergency Room Hospital' => App::Universal::SERVICE_PLACE_EMERGENCYROOM,

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
	my $orgId = $org->{id};
	if (my $list = $healthRule->{rule})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			$self->schemaAction($flags, 'Hlth_Maint_Rule', 'add',
						org_id => $orgId,
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

	my $ownerId = $parentStruct->{id};
	if(my $list = $resources->{resource})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			$self->schemaAction($flags, 'Resource_Item', 'add',
				owner_id => $item->{id},
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
	my $orgId = $org->{id};
	if(my $list = $org->{generalinfo}->{property})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $dv = new Dumpvalue;
			$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $orgId,
				item_name =>"$item->{name}",
				value_type =>  App::Universal::ATTRTYPE_ORGGENERAL,
				value_text => $item->{value});
		}
	}
}

sub importCredentials
{
	my ($self,  $flags, $credentials,$org) = @_;
	my $orgId = $org->{id};
	if(my $list = $credentials->{credential})
	{

		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
		#my $dv = new Dumpvalue;
		#$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $orgId,
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
	my $orgId = $org->{id};
	if(my $list = $assocorg->{'assoc-org'})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $dv = new Dumpvalue;
			$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $orgId,
				item_name => 'Org',
				value_type => App::Universal::ATTRTYPE_RESOURCEORG,
				value_text => $item->{id});
		}
	}
}

sub importAssociatedEmp
{
	my ($self,  $flags, $assocemp,$org) = @_;
	my $orgId = $org->{id};
	if(my $list = $org->{assocemp}->{emp})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $dv = new Dumpvalue;
			$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $orgId,
				item_name => 'Staff',
				value_type => App::Universal::ATTRTYPE_RESOURCEOTHER,
				value_text => $item->{id});
		}
	}
}

sub importContactInfo
{
	my ($self,  $flags, $contactinfo,$org) = @_;
	my $orgId = $org->{id};
	if(my $list = $contactinfo)
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $dv = new Dumpvalue;
			$dv->dumpValue($item);
			$self->schemaAction($flags, "Org_Attribute", 'add',
				parent_id => $orgId,
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
	my $parentId = $org->{id};
	if(my $parent = $org->{event})
	{
		$parent = [$parent] if ref $parent eq 'HASH';
		foreach my $parent (@$parent)
		{
			$self->importEvent($flags, $parent, $owner);
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
		$self->schemaAction($flags|MDLFLAG_LOGACTIVITY, 'Org', 'add',
				org_id => $orgId,
				name_primary => exists $registryNames->{primary} ? $registryNames->{primary} : undef,
				name_trade => exists $registryNames->{trade} ? $registryNames->{trade} : undef,
				tax_id => exists $registry->{taxid} ? $registry->{taxid} : undef,
				category => exists $registry->{type} ? $registry->{type} : undef,
				parent_org_id => exists $registry->{parent_org} ? $registry->{parent_org} : undef);

		if (my $sevice = $registry->{'service-place'})
		{
			$self->schemaAction($flags, 'Org_Attribute', 'add',
							parent_id => $orgId || undef,
							item_name => 'HCFA Service Place',
							value_type => App::Universal::ATTRTYPE_INTEGER,
							value_text => $SERVICE_PLACE_TYPE_MAP{$sevice ? $sevice : 'Office'},
							value_textB => $sevice
						);
		}
	}
}

sub importStruct
{
	my ($self, $flags, $org) = @_;

	#unless($org)
	#{
	#	$self->addError('$org parameter is required');
	#	return 0;
	#}
	$self->{mainStruct} = $org;

	$self->importOrgRegistry($flags, $org->{org_registry}, $org);
	$self->importContactMethods($flags, $org->{'contact-methods'}, $org);
	$self->importAssociations($flags, $org->{associations}, $org);
	$self->importInsurance($flags, $org->{'insurance-plans'}, $org);
	$self->importGeneralInfo($flags, $org->{generalinfo}, $org);
	$self->importCredentials($flags, $org->{credentials}, $org);
	$self->importAssociatedOrg($flags, $org->{'assoc-orgs'}, $org);
	$self->importAssociatedEmp($flags, $org->{'assoc-emp'}, $org);
	$self->importContactInfo($flags, $org->{'contact-info'}, $org);
	$self->importAppointments($flags, $org->{'events'}, $org);
	$self->importHealthMaintenance($flags, $org->{'health-maintenance'}, $org);
	#$self->importResources($flags|MDLFLAG_LOGACTIVITY|MDLFLAG_SHOWMISSINGITEMS, $org->{resources}, $org);
}

1;