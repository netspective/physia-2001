##############################################################################
package App::Data::MDL::Person;
##############################################################################

use strict;
use App::Data::MDL::Module;
use App::Data::MDL::Invoice;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Catalog;
use App::Statements::Person;
use Date::Manip;
use vars qw(@ISA);
use Dumpvalue;

@ISA = qw(App::Data::MDL::Module App::Data::MDL::Invoice);

use vars qw(%CLINICAL_ALLERGY_TYPE_MAP %CLINICAL_DIRECTIVE_TYPE_MAP %ALERT_TYPE_MAP %PERIODICITY_TYPE_MAP %BENEFITS_TYPE_MAP %ROLES_TYPE_MAP);

%CLINICAL_ALLERGY_TYPE_MAP = (
	'Medication' => App::Universal::MEDICATION_ALLERGY,
	'Environmental' => App::Universal::ENVIRONMENTAL_ALLERGY,
	'MedicationIntolerance' => App::Universal::MEDICATION_INTOLERANCE,
);

%CLINICAL_DIRECTIVE_TYPE_MAP = (
	'Patient' => App::Universal::DIRECTIVE_PATIENT,
	'Physician' => App::Universal::DIRECTIVE_PHYSICIAN,
);

%ALERT_TYPE_MAP = (
	'organization' => App::Universal::TRANSTYPE_ALERTORG,
	'facility' => App::Universal::TRANSTYPE_ALERTORGFACILITY,
	'patient' => App::Universal::TRANSTYPE_ALERTPATIENT,
	'insurance' => App::Universal::TRANSTYPE_ALERTINSURANCE,
	'medication' => App::Universal::TRANSTYPE_ALERTMEDICATION,
	'action' => App::Universal::TRANSTYPE_ALERTACTION,
);

%PERIODICITY_TYPE_MAP = (
	'Seconds' => App::Universal::PERIODICITY_SECOND,
	'Minutes' => App::Universal::PERIODICITY_MINUTE,
	'Hours' => App::Universal::PERIODICITY_HOUR,
	'Days' => App::Universal::PERIODICITY_DAY,
	'Weeks' => App::Universal::PERIODICITY_WEEK,
	'Months' => App::Universal::PERIODICITY_MONTH,
	'Years' => App::Universal::PERIODICITY_YEAR,
);

%BENEFITS_TYPE_MAP = (
	'insurance' => App::Universal::BENEFIT_INSURANCE,
	'retirement' => App::Universal::BENEFIT_RETIREMENT,
	'other' => App::Universal::BENEFIT_OTHER,
);

%ROLES_TYPE_MAP = (
	'Active' => App::Universal::ROLESTATUS_ACTIVE,
	'Suspended' => App::Universal::ROLESTATUS_INACTIVE,
	'Inactive' => App::Universal::ROLESTATUS_SUSPENDED,
);

sub new
{
	my $type = shift;
	my $self = new App::Data::MDL::Module(@_, parentTblPrefix => 'Person');
	return bless $self, $type;
}

sub importHospitalizations
{
	my ($self, $flags, $hospitalizations, $person) = @_;
	my $parentId = $person->{id};
	if(my $list = $hospitalizations->{hospitalization})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Transaction", 'add',
				trans_owner_id => $parentId,
				trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
				trans_status => App::Universal::TRANSSTATUS_ACTIVE,
				trans_type => App::Universal::TRANSTYPE_ADMISSION,
				trans_begin_stamp => $item->{admitdate},
				related_data =>  $item->{hospitalname},
				caption => $item->{roomnum},
				provider_id => $item->{provider_id},
				trans_status_reason => $item->{reasontoadmit},
				detail => $item->{orders},
				data_text_a => $item->{'in-out'},
				data_text_b => $item->{'stay-duration'},
				data_text_c => $item->{'hosp-procedures'},
				cosult_id => $item->{consultphysician},
				trans_substatus_reason => $item->{finding});
		}
	}
}

sub importTestsandmeasurements
{
	my ($self, $flags, $testsmeasurements, $person) = @_;

	my $parentId = $person->{id};
	if(my $list = $testsmeasurements->{test})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			$self->schemaAction($flags, "Transaction", 'add',
				trans_owner_id => $parentId,
				trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
				trans_type => App::Universal::TRANSTYPE_TESTSMEASUREMENTS,
				trans_begin_stamp => $item->{'test-date'},
				data_text_b => $item->{'test-name'},
				data_text_a => $item->{'test-value'});

		}
	}
}

sub importActiveMedication
{
	my ($self, $flags, $activemedication, $person) = @_;

	my $parentId = $person->{id};

	if(my $list = $activemedication->{'current-medication'})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Transaction", 'add',
				trans_owner_id => $parentId,
				trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
				trans_status => App::Universal::TRANSSTATUS_ACTIVE,
				trans_type => $item->{type} eq 'OTC' ? App::Universal::TRANSTYPE_CURRENTMEDICATION_OTC : App::Universal::TRANSTYPE_CURRENTMEDICATION_HOMEO,
				trans_begin_stamp => $item->{'start-date'},
				caption => $item->{'medication-name'},
				data_text_a => $item->{dosage},
				detail => $item->{instructions},
				data_text_b => $item->{notes});

		}
	}
	if(my $list = $activemedication->{'prescribe-medication'})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Transaction", 'add',
				trans_owner_id => $parentId,
				trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
				trans_status => App::Universal::TRANSSTATUS_ACTIVE,
				trans_type => App::Universal::TRANSTYPE_PRESCRIBEMEDICATION,
				trans_begin_stamp => $item->{'prescription-date'},
				provider_id => $item->{'physician-id'},
				caption => $item->{'medication-name'},
				data_text_a => $item->{dosage},
				quantity => $item->{quantity},
				data_num_a => $item->{'num-of-refills'},
				detail => $item->{instructions});
		}
	}
}



sub importAllergies
{
	my ($self, $flags, $allergies, $person) = @_;
	return unless $allergies;
	my $parentId = $person->{id};
	if(my $list = $allergies->{allergy})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => "$item->{type}/$item->{substance}",
				value_type =>  $CLINICAL_ALLERGY_TYPE_MAP{exists $item->{type} ? $item->{type} : 'Medication'},
				value_text => $item->{reaction});
		}
	}
}

sub importPreventivecare
{
	my ($self,$flags, $preventivecare, $person) = @_;

	my $parentId = $person->{id};
	if(my $list = $preventivecare->{measure})
	{

		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $cptCode = $item->{cpt};
			my $cptData = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $cptCode);
			my $cptCodeName = $cptData->{'name'} ne '' ? $cptData->{'name'} : '';

			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => "$item->{_text}",
				value_type => App::Universal::PREVENTIVE_CARE,
				value_text => $item->{cpt},
				value_textB => $cptCodeName,
				value_date =>  $item->{lastperformed},
				value_dateEnd => $item->{nextdue});
		}
	}
}

sub importDirectives
{
	my ($self,  $flags, $directives,$person,$parentType) = @_;

	my $parentId = $person->{id};
	if(my $list = $directives->{directive})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => "$item->{type}/$item->{_text}",
				value_type => $CLINICAL_DIRECTIVE_TYPE_MAP{ $item->{type} ? $item->{type} : 'Physician'},
				value_date =>  $item->{date});

		}
	}
}

sub importAlerts
{
	my ($self,  $flags, $alerts,$person) = @_;

	my $parentId = $person->{id};
	if(my $list = $alerts->{alert})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Transaction", 'add',
				trans_owner_id => $parentId,
				trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
				trans_status => App::Universal::TRANSSTATUS_ACTIVE,
				trans_type => $ALERT_TYPE_MAP{exists $item->{type} ? $item->{type} : 'organization'},
				trans_subtype => $item->{priority},
				caption => $item->{caption},
				detail => $item->{details},
				initiator_id => $item->{'staff-member'},
				trans_begin_stamp => $item->{begindate},
				trans_end_stamp => $item->{enddate});
		}


	}
}

sub importActiveProblems
{
	my ($self, $flags, $activeproblems, $person) = @_;

	my $parentId = $person->{id};
	my $todaysDate = UnixDate('today', '%m/%d/%Y %I:%M %p');
	if(my $list = $activeproblems->{'problem-notes'})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Transaction", 'add',
				trans_owner_id => $parentId,
				trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
				trans_status => App::Universal::TRANSSTATUS_ACTIVE,
				trans_type =>  App::Universal::TRANSTYPEDIAG_NOTES,
				curr_onset_date => $item->{date},
				data_text_a => $item->{'notes-memo'},
				provider_id => $item->{'physician-id'},
				trans_begin_stamp => $todaysDate);
		}
	}
	if(my $list = $activeproblems->{'permanent-diag'})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Transaction", 'add',
				trans_owner_id => $parentId,
				trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
				trans_status => App::Universal::TRANSSTATUS_ACTIVE,
				trans_type => App::Universal::TRANSTYPEDIAG_PERMANENT,
				curr_onset_date => $item->{date},
				provider_id => $item->{'physician-id'},
				code => $item->{'icd-code'},
				data_text_a => $item->{diagnosis},
				trans_begin_stamp => $todaysDate);
		}
	}
	if(my $list = $activeproblems->{'transient-diag'})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Transaction", 'add',
				trans_owner_id => $parentId,
				trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
				trans_status => App::Universal::TRANSSTATUS_ACTIVE,
				trans_type => App::Universal::TRANSTYPEDIAG_TRANSIENT,
				curr_onset_date => $item->{date},
				provider_id => $item->{'physician-id'},
				code => $item->{'icd-code'},
				data_text_a => $item->{diagnosis},
				trans_begin_stamp => $todaysDate);
		}
	}
	if(my $list = $activeproblems->{'icd'})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Transaction", 'add',
				trans_owner_id => $parentId,
				trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
				trans_status => App::Universal::TRANSSTATUS_ACTIVE,
				trans_type => App::Universal::TRANSTYPEDIAG_ICD,
				curr_onset_date => $item->{date},
				provider_id => $item->{'physician-id'},
				code => $item->{'icd-code'},
				trans_begin_stamp => $todaysDate);
		}
	}
}

sub importCategories
{
	my ($self,  $flags, $categories,$person,$parentType) = @_;

	my $parentId = $person->{id};
	if(my $list = $categories->{category})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $orgId = $item->{'org-id'};
			my $ownerOrg = exists $item->{'owner-org'} ? $item->{'owner-org'} : $orgId;
			my $ownerOrgIdExist = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $ownerOrg);
			my $internalOrgId = exists $item->{'owner-org'} ? $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrg', $ownerOrgIdExist, $orgId) : $ownerOrgIdExist;

			$self->schemaAction($flags, "Person_Org_Category", 'add',
				person_id => $parentId,
				org_internal_id => $internalOrgId,
				category => $item->{_text});

			$self->schemaAction($flags, "Person_Attribute", 'add',
					parent_id => $parentId,
					item_name => $item->{_text},
					value_type => App::Universal::ATTRTYPE_RESOURCEORG || undef,
					value_text => $item->{'org-id'},
					value_int  => $internalOrgId,
					parent_org_id => $internalOrgId) if $item->{_text} ne 'Patient';
		}


	}

}

sub importAffiliations
{
	my ($self,  $flags, $affiliations,$person,$parentType) = @_;
	my $parentId = $person->{id};
	if(my $list = $affiliations->{affiliation})
	{

			# in case there is only one, force it to be "multiple" to simplify coding
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
				$self->schemaAction($flags, "Person_Attribute", 'add',
					parent_id => $parentId,
					item_name => "$item->{'affil-name'}",
					value_type => App::Universal::ATTRTYPE_AFFILIATION,
					value_dateEnd =>  $item->{date},
					value_text => $item->{other_affiliation});
			}
	}
}

sub importCertification
{
	my ($self,  $flags, $certification,$person,$parentType) = @_;
	my $parentId = $person->{id};
	if(my $list = $certification->{license})
	{

			# in case there is only one, force it to be "multiple" to simplify coding
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
				$self->schemaAction($flags, "Person_Attribute", 'add',
					parent_id => $parentId,
					item_name => "$item->{'license-name'}",
					value_type => App::Universal::ATTRTYPE_LICENSE,
					value_dateEnd =>  $item->{expirationdate},
					value_text => $item->{number},
					value_textB => $item->{'license-name'});
			}
	}
	if(my $list = $certification->{'state-license'})
	{

			# in case there is only one, force it to be "multiple" to simplify coding
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
				$self->schemaAction($flags, "Person_Attribute", 'add',
					parent_id => $parentId,
					item_name => "$item->{state}",
					value_type => App::Universal::ATTRTYPE_STATE,
					value_dateEnd =>  $item->{expirationdate},
					value_text => $item->{number},
					value_textB => $item->{state});
			}
	}
	if(my $list = $certification->{accreditation})
	{

			# in case there is only one, force it to be "multiple" to simplify coding
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
				$self->schemaAction($flags, "Person_Attribute", 'add',
					parent_id => $parentId,
					item_name => "$item->{name}",
					value_type => App::Universal::ATTRTYPE_ACCREDITATION,
					value_text => $item->{name},
					value_dateEnd =>  $item->{expirationdate},
					value_textB => $item->{number});
			}
	}

}

sub importBenefits
{
	my ($self,  $flags, $benefits,$person,$parentType) = @_;
	my $parentId = $person->{id};
	if(my $list = $benefits->{insurance})
	{

			# in case there is only one, force it to be "multiple" to simplify coding
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
				$self->schemaAction($flags, "Person_Attribute", 'add',
					parent_id => $parentId,
					item_name => "$item->{caption}",
					value_type => App::Universal::BENEFIT_INSURANCE,
					value_text => $item->{value});
			}
	}

	if(my $list = $benefits->{retirement})
	{

			# in case there is only one, force it to be "multiple" to simplify coding
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
				$self->schemaAction($flags, "Person_Attribute", 'add',
					parent_id => $parentId,
					item_name => "$item->{caption}",
					value_type => App::Universal::BENEFIT_RETIREMENT,
					value_text => $item->{value});
			}
	}

	if(my $list = $benefits->{other})
	{

			# in case there is only one, force it to be "multiple" to simplify coding
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
				$self->schemaAction($flags, "Person_Attribute", 'add',
					parent_id => $parentId,
					item_name => "$item->{caption}",
					value_type => App::Universal::BENEFIT_OTHER,
					value_text => $item->{value});
			}
	}
}

sub importAttendance
{
	my ($self,  $flags, $attendance,$person,$parentType) = @_;
	my $parentId = $person->{id};
	if(my $list = $person->{attendance}->{record})
		{
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				value_type => App::Universal::ATTRTYPE_EMPLOYEEATTENDANCE,
				item_name => "$item->{name}",
				value_textB => $item->{name},
				value_text => $item->{value});
			}
		}
}

sub importAssocSessionPhysicians
{
	my ($self,  $flags, $sessionphysicians,$person,$parentType) = @_;
	my $parentId = $person->{id};
	my @phys =();
	if (my $physicians = $person->{'assoc-session-physicians'})
	{
		$physicians = [$physicians] unless ref $physicians eq 'ARRAY';
		foreach my $physician (@$physicians)
		{
			push(@phys, $physician);
		}


		$self->schemaAction($flags, "Person_Attribute", 'add',
			parent_id => $parentId,
			item_name => 'SessionPhysicians',
			value_type => App::Universal::ATTRTYPE_RESOURCEPERSON,
			value_text => join(',' , @phys) || undef,
			value_int => 1);
	}
}

sub importAssociatedNurse
{
	my ($self,  $flags, $assocnurse,$person,$parentType) = @_;
	my $parentId = $person->{id};
	if(my $list = $assocnurse->{physician})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $orgId = $item->{id};
			my $ownerOrg = $item->{'owner-org'};
			my $ownerInternalId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $ownerOrg);
			my $orgInternalId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrg', $ownerInternalId, $orgId);

			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => 'Physician',
				value_type => App::Universal::ATTRTYPE_RESOURCEPERSON,
				value_text => $item->{id});
			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => 'WorkList',
				value_type => App::Universal::ATTRTYPE_RESOURCEPERSON,
				value_text => $item->{id} || undef,
				value_int => 1);
		}
	}
}

sub importAuthorization
{
	my ($self,  $flags, $authorization,$person,$parentType) = @_;
	my $parentId = $person->{id};
	if(my $list = $authorization->{'patient_sign'})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => 'Signature Source',
				value_type => App::Universal::ATTRTYPE_AUTHPATIENTSIGN,
				value_textB => $item->{sign});
		}
	}

	if(my $list = $authorization->{'provider_asign'})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => 'Provider Assignment',
				value_type => App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN,
				value_textB => $item->{asign});
		}
	}

	if(my $list = $authorization->{'inforelease'})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => 'Information Release',
				value_type => App::Universal::ATTRTYPE_AUTHINFORELEASE,
				value_int => $item->{authozized} eq 'yes' ? 1 : 0);
		}
	}
}

sub _importPersonaldata
{
	my ($self,  $flags, $personal,$person,$parentType) = @_;
	my $parentId = $person->{id};
	if(my $list = $personal->{identification}->{driverslicense})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name =>"General/Person/Drivers License",
				value_type =>  App::Universal::ATTRTYPE_PERSONALGENERAL,
				value_text => $item);
		}
	}

	if(my $list = $personal->{'birth-place'})
	{
		$list = [$list] unless ref $list eq 'ARRAY';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);

			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => "General/Person/Birthplace",
				value_type =>  App::Universal::ATTRTYPE_PERSONALGENERAL,
				value_text => $item);
		}
	}

	if(my $list = $personal->{citizenship})
	{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($list);
			$self->schemaAction($flags, "Person_Attribute", 'add',
				parent_id => $parentId,
				item_name => "General/Person/Citizenship",
				value_type =>  App::Universal::ATTRTYPE_PERSONALGENERAL,
				value_text => $list);

	}

	#if(my $list = $personal->{race})
	#{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($list);
			#$self->schemaAction($flags, "Person_Attribute", 'add',
				#parent_id => $parentId,
				#item_name => "Personal/Demographic/Race",
				#value_text => $list);

	#}

	if(my $list = $personal->{nationality})
	{
		#my $dv = new Dumpvalue;
		#$dv->dumpValue($list);
		$self->schemaAction($flags, "Person_Attribute", 'add',
			parent_id => $parentId,
			item_name => "General/Person/Nationality",
			value_type =>  App::Universal::ATTRTYPE_PERSONALGENERAL,
			value_text => $list);

	}

	if(my $list = $personal->{religion})
	{
		#my $dv = new Dumpvalue;
		#$dv->dumpValue($list);
		$self->schemaAction($flags, "Person_Attribute", 'add',
			parent_id => $parentId,
			item_name => "General/Person/Religion",
			value_type =>  App::Universal::ATTRTYPE_PERSONALGENERAL,
			value_text => $list);

	}

}

sub importLogins
{
	my ($self,  $flags, $logins, $person) = @_;
	my $parentId = $person->{id};
	if(my $list = $logins->{login})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $OrgId = $item->{'org-id'};
			my $internalOrgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $OrgId);
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, "Person_Login", 'add',
				person_id => $parentId,
				org_internal_id => $internalOrgId,
				password => $item->{password},
				quantity =>  $item->{limit} ne '' ? $item->{limit} : '1' );
		}
	}
}

sub importRoles
{
	my ($self,  $flags, $roles,$person) = @_;
	my $personId = $person->{id};
	if(my $list = $roles->{role})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $roleName = $item->{'name'};
			my $roleNameId = '';
			my $existRoleId = '';
			my $roleNameExists = $STMTMGR_PERSON->recordExists($self,STMTMGRFLAG_NONE, 'selRoleNameExists', $roleName);
			if ($roleNameExists !=1)
			{
				$roleNameId = $self->schemaAction($flags, "Role_Name", 'add',
						role_name => $roleName) ;
			}

			else
			{
				my $existRoleData =  $STMTMGR_PERSON->getRowAsHash($self,STMTMGRFLAG_NONE, 'selRoleNameExists', $roleName);
				$existRoleId = $existRoleData->{'role_name_id'};
			}

			my $orgId = $item->{'org-id'};
			my $ownerOrg = $item->{'owner-org'};
			my $ownerOrgIdExist = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $ownerOrg);

			my $internalOrgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrg', $ownerOrgIdExist, $orgId);

			my $personRoleId = $roleNameId ne '' ? $roleNameId : $existRoleId;
			$self->schemaAction($flags, "Person_Org_Role", 'add',
						org_internal_id    => $internalOrgId,
						role_name_id => $personRoleId,
						person_id => $personId,
						priority  => $item->{priority},
						role_status_id => $ROLES_TYPE_MAP{exists $item->{status} ? $item->{status} :'Active'});

		}
	}
}

sub importRegistry
{
	my ($self, $flags, $registry, $person) = @_;
	my $personId = $person->{id};
	if(my $registry = $person->{registry})
	{
			my $personal = $person->{personal};
			#my @ethnicity = $personal->{race};
			my @lang =();
			my $languages = $personal->{languages};
			$languages = [$languages] unless ref $languages eq 'ARRAY';
			foreach my $language (@$languages)
			{
				push(@lang, $language);
			}

			#my @cat = ();
			#my $categories = $person->{categories};
			#$categories = [$categories] unless ref $categories eq 'ARRAY';
			#foreach my $category (@$categories)
			#{
			#	push(@cat, $category);
			#}

			my $registryNames = $registry->{names};

			$self->schemaAction($flags, 'Person', 'add',
						person_id => $personId,
						name_prefix => exists $registryNames->{prefix} ? $registryNames->{prefix} : undef,
						name_last => $registryNames->{last},
						name_middle => $registryNames->{middle},
						name_first => $registryNames->{first},
						name_suffix => exists $registryNames->{suffix} ? $registryNames->{suffix} : undef,
						gender => exists $registry->{gender} ? $self->translateEnum($flags, "Gender", $registry->{gender}) : undef,
						marital_status => exists $registry->{'marital-status'} ? $self->translateEnum($flags, "Marital_Status", $registry->{'marital-status'}) : undef,
						date_of_birth => exists $registry->{'birth-date'} ? $registry->{'birth-date'} : undef,
						ssn => exists $registry->{ssn} ? $registry->{ssn} : undef,
						age => exists $registry->{age} ? $registry->{age} : undef,
						#category => join(',', @cat) || undef,
						language => join(',', @lang) || undef,
						ethnicity => $registry->{ethnicity}
					);

			$self->schemaAction($flags, 'Person_Attribute', 'add',
						parent_id => $personId,
						item_name => 'Person/Name/LastFirst',
						value_type => 0,
						value_int => 1
					);
			$self->schemaAction($flags, 'Person_Attribute', 'add',
						parent_id => $personId || undef,
						item_name => 'Guarantor' || undef,
						value_type => App::Universal::ATTRTYPE_EMERGENCY || undef,
						value_text => $registry->{'responsible-person'} || undef,
						value_int => 1
					) if $registry->{'responsible-person'} ne '';

			$self->schemaAction($flags, 'Person_Attribute', 'add',
						parent_id => $personId || undef,
						item_name => 'BloodType' || undef,
						value_type => 0,
						value_text => 0
					);
	}

}

sub importStruct
{
	my ($self, $flags, $person) = @_;

	#unless($person)
	#{
	#	$self->addError('$person parameter is required');
	#	return 0;
	#}

	$self->{mainStruct} = $person;



	$self->importRegistry($flags, $person->{registry}, $person);
	$self->importLogins($flags, $person->{logins}, $person);
	$self->importCategories($flags, $person->{categories}, $person);
	$self->importRoles($flags, $person->{roles}, $person);
	#$self->importPersonaldata($flags,$person->{personal},$person);
	$self->importContactMethods($flags, $person->{'contact-methods'}, $person);
	$self->importAssociations($flags, $person->{associations}, $person);
	$self->importInsurance($flags, $person->{insurance}, $person);
	$self->importHospitalizations($flags, $person->{hospitalizations}, $person);
	$self->importAllergies($flags, $person->{allergies}, $person);
	$self->importPreventivecare($flags, $person->{'preventive-care'}, $person);
	$self->importDirectives($flags, $person->{directives}, $person);
	$self->importTestsandmeasurements($flags, $person->{'tests-measurements'}, $person);
	$self->importActiveMedication($flags, $person->{'active-medication'}, $person);
	$self->importAlerts($flags, $person->{alerts}, $person);
	$self->importAffiliations($flags, $person->{affiliations}, $person);
	$self->importAttendance($flags, $person->{attendance}, $person);
	$self->importCertification($flags, $person->{certification}, $person);
	$self->importActiveProblems($flags, $person->{'active-problems'}, $person);
	$self->importBenefits($flags, $person->{benefits}, $person);
	$self->importAssocSessionPhysicians($flags, $person->{'assoc-session-physicians'}, $person);
	$self->importAssociatedNurse($flags, $person->{'assoc-nurse'}, $person);
	$self->importEvent($flags, $person->{event}, $person);
	#$self->importAuthorization($flags, $person->{authorization}, $person);
	#$self->importHealthMaintenance($flags, $person->{healthmaintenance}, $person);


}

1;