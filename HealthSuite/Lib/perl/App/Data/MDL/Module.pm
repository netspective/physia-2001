##############################################################################
package App::Data::MDL::Module;
##############################################################################

use strict;
use App::Universal;
use Dumpvalue;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Catalog;
use vars qw(@ISA);

use vars qw(@ISA @EXPORT %PHONE_TYPE_MAP %ASSOC_EMPLOYMENT_TYPE_MAP %BILL_SEQUENCE_TYPE_MAP %DEDUCTIBLE_TYPE_MAP %INSURANCE_TYPE_MAP %BILLINGPARTY_TYPE_MAP);
use enum qw(BITMASK:MDLFLAG_ LOGSQL SHOWSTATUS SHOWMISSINGITEMS LOGACTIVITY DEBUG);
use constant MDLFLAGS_VERBOSE => MDLFLAG_SHOWSTATUS | MDLFLAG_SHOWMISSINGITEMS | MDLFLAG_LOGACTIVITY;
use constant MDLFLAGS_DEFAULT => 0;

@ISA = qw(Exporter);
@EXPORT = qw(MDLFLAG_SHOWSTATUS MDLFLAG_SHOWMISSINGITEMS MDLFLAG_DEBUG MDLFLAGS_DEFAULT MDLFLAG_LOGACTIVITY);

%PHONE_TYPE_MAP = (
	'voice' => 'Telephone',
	'fax' => 'Fax',
);

%ASSOC_EMPLOYMENT_TYPE_MAP = (
	'self-employed' => App::Universal::ATTRTYPE_SELFEMPLOYED,
	'employed-fulltime' => App::Universal::ATTRTYPE_EMPLOYEDFULL,
	'employed-parttime' => App::Universal::ATTRTYPE_EMPLOYEDPART,
	'retired' => App::Universal::ATTRTYPE_RETIRED,
	'student-fulltime' => App::Universal::ATTRTYPE_STUDENTFULL,
	'student-parttime' => App::Universal::ATTRTYPE_STUDENTPART,
);


%BILL_SEQUENCE_TYPE_MAP = (
	'primary' => App::Universal::INSURANCE_PRIMARY,
	'secondary' => App::Universal::INSURANCE_SECONDARY,
	'tertiary' => App::Universal::INSURANCE_TERTIARY,
	'inactive' => App::Universal::INSURANCE_INACTIVE,
	'workerscomp' => App::Universal::INSURANCE_WORKERSCOMP,
);

%DEDUCTIBLE_TYPE_MAP = (
	'none' => App::Universal::DEDUCTTYPE_NONE,
	'individual' => App::Universal::DEDUCTTYPE_INDIVIDUAL,
	'family' => App::Universal::DEDUCTTYPE_FAMILY,
	'both' => App::Universal::DEDUCTTYPE_BOTH
);

%INSURANCE_TYPE_MAP = (
	'Insurance' => App::Universal::CLAIMTYPE_INSURANCE,
	'Self-Pay' => App::Universal::CLAIMTYPE_SELFPAY,
	'HMO' => App::Universal::CLAIMTYPE_HMO,
	'PPO' => App::Universal::CLAIMTYPE_PPO,
	'Medicare' => App::Universal::CLAIMTYPE_MEDICARE,
	'Medicaid' => App::Universal::CLAIMTYPE_MEDICAID,
	'Champus' => App::Universal::CLAIMTYPE_CHAMPUS,
	'ChampVA' => App::Universal::CLAIMTYPE_CHAMPVA,
	'WorkersComp' => App::Universal::CLAIMTYPE_WORKERSCOMP,
	'HMO(non)' => App::Universal::CLAIMTYPE_HMO_NON_CAP,
	'ThirdParty' => App::Universal::CLAIMTYPE_CLIENT
);

%BILLINGPARTY_TYPE_MAP = (
	'client' => App::Universal::INVOICEBILLTYPE_CLIENT,
	'person' => App::Universal::INVOICEBILLTYPE_THIRDPARTYPERSON,
	'org' => App::Universal::INVOICEBILLTYPE_THIRDPARTYORG,
	'insurance' => App::Universal::INVOICEBILLTYPE_THIRDPARTYINS
);


sub new
{
	my ($class, %params) = @_;
	$params{errors} = [];
	$params{parentTblPrefix} = 'NONE' unless $params{parentTblPrefix};
	$params{parentTblPrefix_attrs} = "$params{parentTblPrefix}_Attribute";
	$params{parentIdKey_attrs} = 'id';

	#
	# $params{rootStruct} will be the root MDL structure
	# $params{mainStruct} will be the person, organization, etc
	#

	my $self = bless \%params, $class;
	$self;
}

sub connect
{
	my ($self, $flags, $connectStr) = @_;
}

sub param
{
	return undef;
}

sub getSchema {	$_[0]->{schema}; }

sub schemaAction
{
	my $self = shift;
	my ($flags, $table, $command, %params) = @_;

	return $self->{schema}->schemaAction($self, $table, $command, %params);
}

sub getSqlLog
{
	return $_[0]->{sqlLog};
}

sub clearSqlLog
{
	my $self = shift;
	$self->{sqlLog} = [];
	return $self->{sqlLog};
}

sub translateEnum
{
	my ($self, $flags, $tableName, $value) = @_;

	if(my $schema = $self->{schema})
	{
		if(my $table = $schema->getTable($tableName))
		{
			if(my $data = $table->{data})
			{
				$value = uc($value);
				my $rowIdx = 0;
				foreach my $row (@{$data->{rows}})
				{
					next unless ref $row eq 'HASH';
					if(uc($row->{caption}) eq $value)
					{
						my $id = exists $row->{id} && defined $row->{id} ? $row->{id} : $rowIdx;
						return $id if defined $id;
					}
					$rowIdx++;
				}
			}
			$self->addError("translateEnum could not find '$value' in table $tableName");
			return -9999;
		}
		else
		{
			$self->addError("table $tableName not found in translateEnum");
			return -9999;
		}
	}

	return "TRANSLATE-$tableName.$value";
}

sub addDebugStmt # put this in because $self is sent into $schema->dbCommand and we want $self to look like a $page
{
	my ($self, @messages) = @_;
	push(@{$self->{errors}}, @messages);
}

sub addError
{
	my ($self, @messages) = @_;
	push(@{$self->{errors}}, @messages);
}

sub printErrors
{
	my ($self) = @_;
	print join("\n", @{$self->{errors}});
}

sub logMsg
{
	my ($self, $flags, $message) = @_;
	print STDOUT "$message\n" if $flags & (MDLFLAG_SHOWSTATUS | MDLFLAG_LOGACTIVITY);
}

sub statusMsg
{
	my ($self, $flags, $message) = @_;
	print STDOUT "\r$message" if $flags & (MDLFLAG_SHOWSTATUS);
}

sub itemMissingMsg
{
	my ($self, $flags, $message) = @_;
	print STDOUT "\r$message\n" if $flags & (MDLFLAG_SHOWMISSINGITEMS);
}

sub importStruct
{
	my ($self, $flags, $struct) = @_;
	$self->abstract();
}

sub _importContactMethods
{
	my ($self, $flags, $contacts, $parentStruct, $parentTblPrefix, $parentId) = @_;
	unless($contacts)
	{
		$self->itemMissingMsg($flags, 'No contactmethods found.');
		return;
	}
	my $parentNewId = $parentId;
	my $attrTable = "$parentTblPrefix\_Attribute";
	my $addrTable = "$parentTblPrefix\_Address";
	unless($parentId)
	{
		$self->addError("Parent ID in key '$self->{parentIdKey_attrs}' not found.");
		return;
	}
	if(my $list = $contacts->{phone})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $type = $PHONE_TYPE_MAP{$item->{type} || 'voice'};

			$self->schemaAction($flags, $attrTable, 'add',
				parent_id => $parentNewId,
				item_name => $parentTblPrefix ne "Insurance" ? "$item->{name}" : "Contact Method/$type/$item->{name}",
				value_type => $type eq 'Telephone' ? App::Universal::ATTRTYPE_PHONE : App::Universal::ATTRTYPE_FAX,
				value_textB => $item->{name},
				value_text => $item->{_text});
		}
	}
	if(my $list = $contacts->{email})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, $attrTable, 'add',
				parent_id => $parentNewId,
				item_name => $parentTblPrefix ne "Insurance" ? "$item->{name}" : "Contact Method/Email/$item->{name}",
				value_type => App::Universal::ATTRTYPE_EMAIL,
				value_textB => $item->{name},
				value_text => $item->{_text});
		}
	}
	if(my $list = $contacts->{internet})
		{
			# in case there is only one, force it to be "multiple" to simplify coding
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
				#my $dv = new Dumpvalue;
				#$dv->dumpValue($item);
				$self->schemaAction($flags, $attrTable, 'add',
					parent_id => $parentNewId,
					item_name => $parentTblPrefix ne "Insurance" ? "$item->{name}" : "Contact Method/Internet/$item->{name}",
					value_type => App::Universal::ATTRTYPE_URL,
					value_textB => $item->{name},
					value_text => $item->{_text});
			}
	}
	if(my $list = $contacts->{address})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			#my $dv = new Dumpvalue;
			#$dv->dumpValue($item);
			$self->schemaAction($flags, $addrTable, 'add',
				address_name => $item->{name},
				parent_id => $parentNewId,
				line1 => $item->{street},
				line2 => exists $item->{street2} ? $item->{street2} : undef,
				city => $item->{city},
				county => $item->{county},
				state => $item->{state},
				zip => $item->{zipcode});
		}
	}
}

sub importContactMethods
{
	my ($self, $flags, $contacts, $parentStruct, $internalOrgId) = @_;
	my $preFix = $self->{parentTblPrefix};
	if ($preFix ne 'Org')
	{
		$self->_importContactMethods($flags, $contacts, $parentStruct, $self->{parentTblPrefix}, $parentStruct->{$self->{parentIdKey_attrs}});
	}
	else
	{
		$self->_importContactMethods($flags, $contacts, $parentStruct,$self->{parentTblPrefix}, $internalOrgId);
	}
}


sub importAssociations
{
	my ($self, $flags, $assocs, $parentStruct) = @_;
	$self->itemMissingMsg($flags, 'No associations found.') unless $assocs;
	return unless $assocs;

	my $parentId =  $self->{parentTblPrefix} ne 'Org' ? $parentStruct->{$self->{parentIdKey_attrs}} : $parentStruct;
	my $attrTable = $self->{parentTblPrefix_attrs};
	if(my $list = $assocs->{employment})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $orgId = $item->{_text};
			my $ownerOrg = $item->{'owner-org'};
			my $ownerInternalId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $ownerOrg);
			my $orgInternalId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrg', $ownerInternalId, $orgId);
			$self->schemaAction($flags, $attrTable, 'add',
				parent_id => $parentId,
				item_name => "$item->{occupation}",
				value_type => $ASSOC_EMPLOYMENT_TYPE_MAP{exists $item->{status} ? $item->{status} : 'employed-fulltime'},
				value_text => $item->{_text},
				value_int  => $orgInternalId);
		}
	}

	if(my $list = $assocs->{'emergency-contact'})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			$self->schemaAction($flags, $attrTable, 'add',
				parent_id => $parentId,
				item_name => "$item->{relationship}",
				value_type => App::Universal::ATTRTYPE_EMERGENCY,
				value_text => $item->{name},
				value_int => $item->{'exist-person'},
				value_textB =>$item->{phone}->{_text});
		}
	}

	if(my $list = $assocs->{provider})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $medSpecCode = $item->{specialty};
			my $medSpecCaption = $STMTMGR_PERSON->getSingleValue($self, STMTMGRFLAG_CACHE, 'selMedicalSpecialtyCaption', $medSpecCode);
			$self->schemaAction($flags, $attrTable, 'add',
				parent_id => $parentId,
				item_name => $medSpecCaption,
				value_type => App::Universal::ATTRTYPE_PROVIDER,
				value_text => $item->{id},
				value_textB => $medSpecCode);
		}
	}

	if(my $list = $assocs->{family})
		{
			$list = [$list] if ref $list eq 'HASH';
			foreach my $item (@$list)
			{
				#my $dv = new Dumpvalue;
				#$dv->dumpValue($item);
				$self->schemaAction($flags, $attrTable, 'add',
					parent_id => $parentId,
					item_name => "$item->{relationship}",
					value_type => App::Universal::ATTRTYPE_FAMILY,
					value_text => $item->{name},
					value_int => $item->{'exist-person'},
					value_textB =>$item->{phone}->{_text});
			}
	}
}

sub importInsurance
{
	my ($self, $flags, $insurance, $parentStruct) = @_;
	$self->itemMissingMsg($flags, 'No insurance records found.') unless $insurance;
	return unless $insurance;

	if(my $list = $insurance->{coverage})
	{
		my $ownerId = $parentStruct->{id};
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $insOrgId = $item->{'insurance-org'};
			my $primaryOrg = $item->{'ins-org-owner'};
			my $primaryOwnerOrgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $primaryOrg);
			my $primaryInsOrgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrgId', $primaryOwnerOrgId, $insOrgId);


			my $productName = $item->{'ins-id'};
			my $planName = $item->{'policy-name'};
			my $guarantor = $item->{guarantor};
			my $ownerOrg = $item->{'owner-org'};
			my $ownerOrgInternalId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $ownerOrg);

			my $guarantorInternalId = $ownerOrg ne '' ? $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrgInternalId, $guarantor) : $guarantor;
			my $guarantorType = $item->{'guarantor-type'};
			my $recordType = App::Universal::RECORDTYPE_INSURANCEPLAN;
			my $planData = $STMTMGR_INSURANCE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInsPlan', $productName, $planName, $primaryInsOrgId);
			my $insInternalId = $planData->{'ins_internal_id'};
			my $feeschedule =  $STMTMGR_INSURANCE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insInternalId, 'Fee Schedule');
			my $insType = $item->{'ins-type'} ne '' ? $item->{'ins-type'} : $planData->{'ins_type'};
			my $insIntId = $self->schemaAction($flags, "Insurance", 'add',
								ins_org_id 		=> $primaryInsOrgId || undef,
								record_type 	=> App::Universal::RECORDTYPE_PERSONALCOVERAGE || undef,
								owner_person_id => $ownerId || undef,
								owner_org_id    =>  $primaryOwnerOrgId || undef,
								guarantor_type  => $guarantorType || undef,
								parent_ins_id 	=> $planData->{'ins_internal_id'} || undef,
								product_name  	=> $item->{'ins-id'} || undef,
								plan_name 	=> $item->{'policy-name'} || undef,
								bill_sequence 	=> $BILL_SEQUENCE_TYPE_MAP{exists $item->{'bill-sequence'} ? $item->{'bill-sequence'} :''} || undef,
								member_number 	=> $item->{'member-number'} || undef,
								policy_number   => $item->{'member-number'} || undef,
								group_name   => $item->{'group-name'} || undef,
								group_number   => $item->{'group-number'} || undef,
								insured_id    => $item->{insured} || undef,
								indiv_deductible_amt => $planData->{'indiv-deduct-amt'} || undef,
								family_deductible_amt => $planData->{'family-deduct-amt'} || undef,
								indiv_deduct_remain => $item->{'indiv-deduct-remain'} || undef,
								family_deduct_remain => $item->{'family-deduct-remain'} || undef,
								ins_type 		=> $insType || undef,
								guarantor_id            => $guarantorInternalId || undef,
								coverage_begin_date => $item->{begindate} || undef,
								coverage_end_date => $item->{enddate} || undef,
								percentage_pay => $planData->{percentage_pay} || undef,
								copay_amt => $planData->{copay_amt} || undef,
								remit_type => $planData->{'remit_type'} || undef,
								remit_payer_id => $planData->{'remit_payer_id'} || undef,
								remit_payer_name => $planData->{'remit_payer_name'} || undef,
								threshold => $planData->{threshold} || undef
							);

				$self->schemaAction($flags,"Insurance_Attribute", 'add',
						parent_id => $insIntId,
						item_name => 'HMO-PPO/Indicator',
						value_type => 0,
						value_text => $item->{'hmo-ppo'});

				$self->schemaAction($flags,"Insurance_Attribute", 'add',
						parent_id => $insIntId,
						item_name => 'BCBS Plan Code',
						value_type => 0);

				#$self->schemaAction($flags,"Insurance_Attribute", 'add',
				#		parent_id => $insIntId || undef,
				#		item_name => 'Fee Schedule',
				#		value_type => 0,
				#		value_text => $feeschedule->{'value_text'});
				if ($insType  == App::Universal::CLAIMTYPE_CLIENT)
				{

					my $mailingAddress = $STMTMGR_ORG->getRowAsHash($self, STMTMGRFLAG_NONE, 'selOrgAddressByAddrName', $guarantor, 'Mailing');
					$self->schemaAction($flags,"Insurance_Address", 'add',
								parent_id    => $insIntId || undef,
								address_name => $mailingAddress->{address_name} || undef,
								line1        => $mailingAddress->{line1} || undef,
								line2        => $mailingAddress->{line2} || undef,
								city         => $mailingAddress->{city} || undef,
								country      => $mailingAddress->{country} || undef,
								state        => $mailingAddress->{state} || undef,
								zip          => $mailingAddress->{zip} || undef
							);

					my $billingContact = $STMTMGR_ORG->getRowAsHash($self, STMTMGRFLAG_NONE, 'selAttribute', $guarantor, 'Primary');
					$self->schemaAction($flags,"Insurance_Attribute", 'add',
								parent_id => $insIntId || undef,
								item_name => 'Contact Method/Telephone/Primary' || undef,
								value_type => App::Universal::ATTRTYPE_PHONE || undef,
								value_text =>  $billingContact->{value_text} || undef,
								value_textB => 'Primary' || undef
							);
				}


			#$self->_importContactMethods($flags, $item->{'contact-methods'}, $item, 'Insurance', $insIntId);
		}
	}

# Note: In org, the data may have more than one <deductible> tag,  we need to prepare action for both cases.
# 	example:<deductible type="individual">1000</deductible>
# 		<deductible type="family">3000</deductible>
#	INDIV_DEDUCT_REMAIN = 1000
#	FAMILY_DEDUCT_REMAIN = 3000
#	DEDUCT_TYPE = 3
	if(my $list = $insurance->{product})
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $insOrgId = $item->{'insurance-org'};
			my $primaryOrg = $item->{'ins-org-owner'};
			my $primaryOwnerId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $primaryOrg);
			my $primaryInsOrgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrgId', $primaryOwnerId, $insOrgId);

			my $ownerOrg = $item->{'owner-org'};
			my $primaryOwnerOrgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $ownerOrg);
			my $insIntId =  $self->schemaAction($flags, "Insurance", 'add',
							product_name => $item->{'ins-id'} || undef,
							owner_org_id => $primaryOwnerId || undef,
							ins_type      => $INSURANCE_TYPE_MAP{exists $item->{'insurance-type'} ? $item->{'insurance-type'} :'Insurance'},
							ins_org_id    => $primaryInsOrgId || undef,
							#ins_type      => $self->translateEnum($flags, "Claim_Type", $item->{'insurance-type'}),
							record_type   => App::Universal::RECORDTYPE_INSURANCEPRODUCT || undef);

			$self->schemaAction($flags,"Insurance_Attribute", 'add',
						parent_id => $insIntId,
						item_name => 'HMO-PPO/Indicator',
						value_type => 0,
						value_text => $item->{'hmo-ppo'});


			my @fee = split(', ', $item->{feeschedule});

			foreach my $feeSch (@fee)
			{
				my $internalCatalogId = $STMTMGR_CATALOG->getSingleValue($self, STMTMGRFLAG_NONE, 'selInternalIdByCatalog', $feeSch);
				my $dv = new Dumpvalue;
				$dv->dumpValue("FEE SCHED: $feeSch, $internalCatalogId");

				$self->schemaAction($flags,"Insurance_Attribute", 'add',
						parent_id => $insIntId,
						item_name => 'Fee Schedule',
						value_type => 0,
						value_text => $internalCatalogId)if $internalCatalogId ne '';
			}

			#if($item->{'record-type'} eq App::Universal::RECORDTYPE_INSURANCEPLAN)
			#{
			#	$self->schemaAction($flags,"Insurance_Attribute", 'add',
			#			parent_id => $insIntId,
			#			item_name => 'Fee Schedules',
			#			value_type => 0,
			#			value_text => $item->{feeschedule} || undef);
			#}

			$self->schemaAction($flags,"Insurance_Attribute", 'add',
					parent_id => $insIntId,
					item_name => 'BCBS Plan Code',
					value_type => 0);

			#print "The insurance ID: $insIntId \n";

			$self->_importContactMethods($flags, $item->{'contact-methods'}, $item, 'Insurance', $insIntId);

			if (my $insPlan = $item->{plan})
			{
				my $rec = $item;
				$self->importinsPlan($flags, $insPlan, $rec, $insurance, $item->{'ins-id'}, $item->{'contact-methods'}, $insIntId, $primaryOrg);
			}

			#$deductflag = 0;
		}
	}
}

sub importinsPlan
{
	my ($self, $flags, $insPlan, $rec, $insurance, $productName, $recordContactMethod, $parentInsId, $primaryOrg) = @_;

	#my $productName = $insurance;
	my $recordType = App::Universal::RECORDTYPE_INSURANCEPRODUCT;
	#my $recordContactMethod = $insurance->{product}->{'contact-methods'};
	my $recordData = $STMTMGR_INSURANCE->getRowAsHash($self, STMTMGRFLAG_NONE, 'selProductRecord', $primaryOrg, $productName);
	my $insInternalId = $recordData->{'ins_internal_id'};
	my $feeschedule =  $STMTMGR_INSURANCE->getRowsAsHashList($self, STMTMGRFLAG_NONE, 'selInsuranceAttr', $insInternalId, 'Fee Schedule');
	if(my $list = $insPlan)
	{
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{

			my $insIntId =  $self->schemaAction($flags, "Insurance", 'add',
							product_name => $productName || undef,
							owner_org_id => $recordData->{'owner_org_id'} || undef,
							ins_type      => $recordData->{'ins_type'} || undef,
							ins_org_id    => $recordData->{'ins_org_id'} || undef,
							parent_ins_id => $parentInsId || undef,
							#ins_type      => $self->translateEnum($flags, "Claim_Type", $item->{'insurance-type'}),
							record_type   => App::Universal::RECORDTYPE_INSURANCEPLAN || undef,
							plan_name 	  => $item->{'policy-name'} || undef,
							coverage_begin_date => $item->{begindate} || undef,
							coverage_end_date => $item->{enddate} ||undef,
							percentage_pay => $item->{'percentage-pay'} || undef,
							copay_amt => $item->{copay} || undef,
							indiv_deductible_amt => $item->{'indiv-deduct-amt'} || undef,
							family_deductible_amt => $item->{'family-deduct-amt'} || undef,
							remit_type => $recordData->{'remit_type'} || undef,
							remit_payer_id => $recordData->{'remit_payer_id'} || undef,
							remit_payer_name => $recordData->{'remit_payer_name'} || undef,
							threshold => $item->{threshold} || undef
						);
			foreach my $fee (@{$feeschedule})
			{

				$self->schemaAction($flags,"Insurance_Attribute", 'add',
					parent_id => $insIntId || undef,
					item_name => 'Fee Schedule',
					value_type => 0,
					value_text => $fee->{'value_text'} || undef);
			}

			if (! $item->{'contact-methods'})
			{
				$self->_importContactMethods($flags, $recordContactMethod, $rec, 'Insurance', $insIntId);
			}

			elsif (my $planContactMethod = $item->{'contact-methods'})
			{
				$self->_importContactMethods($flags, $planContactMethod, $item, 'Insurance', $insIntId);
			}

		}
	}
}

1;