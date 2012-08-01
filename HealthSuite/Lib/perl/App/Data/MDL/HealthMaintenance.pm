##############################################################################
package App::Data::MDL::HealthMaintenance;
##############################################################################

use strict;
use App::Universal;
use App::Data::MDL::Module;
use DBI::StatementManager;
use App::Statements::Org;
use vars qw(@ISA);
use Dumpvalue;

@ISA = qw(App::Data::MDL::Module);

use vars qw(%PERIODICITY_TYPE_MAP);

%PERIODICITY_TYPE_MAP = (
	'Seconds' => App::Universal::PERIODICITY_SECOND,
	'Minutes' => App::Universal::PERIODICITY_MINUTE,
	'Hours' => App::Universal::PERIODICITY_HOUR,
	'Days' => App::Universal::PERIODICITY_DAY,
	'Weeks' => App::Universal::PERIODICITY_WEEK,
	'Months' => App::Universal::PERIODICITY_MONTH,
	'Years' => App::Universal::PERIODICITY_YEAR,
);


sub new
{
	my $type = shift;
	my $self = new App::Data::MDL::Module(@_, parentTblPrefix => 'Hlth_Maint_Rule');
	return bless $self, $type;
}


sub importStruct
{
	my ($self, $flags, $healthmaintenance) = @_;
	$self->{mainStruct} = $healthmaintenance;
	if(my $list = $healthmaintenance->{rule})
	{
		# in case there is only one, force it to be "multiple" to simplify coding
		$list = [$list] if ref $list eq 'HASH';
		foreach my $item (@$list)
		{
			my $orgId = $item->{'org-id'};
			my $ownerOrg = exists $item->{'owner-org'} ? $item->{'owner-org'} : $orgId;
			my $ownerOrgIdExist = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOwnerOrgId', $ownerOrg);
			my $internalOrgId = exists $item->{'owner-org'} ? $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrg', $ownerOrgIdExist, $orgId) : $ownerOrgIdExist;


			$self->schemaAction($flags, "Hlth_Maint_Rule", 'add',
				rule_id => $item->{'rule_id'},
				org_internal_id => $internalOrgId,
				gender => $self->translateEnum($flags, "Gender", $item->{gender}),
				start_age => $item->{'start_age'} || undef,
				end_age => $item->{'end_age'} || undef,
				age_metric => $PERIODICITY_TYPE_MAP{exists $item->{'age_metric'} ? $item->{'age_metric'} : 'Seconds'},
				measure => $item->{measure},
				periodicity => $item->{periodicity},
				periodicity_metric => $PERIODICITY_TYPE_MAP{exists $item->{'periodicity_metric'} ? $item->{'periodicity_metric'} : 'Seconds'},
				diagnoses => $item->{'icd-code'},
				directions => $item->{directions},
				source => $item->{source},
				src_begin_date => $item->{'source_startdate'},
				src_end_date => $item->{'source_enddate'});
		}
	}
}

1;