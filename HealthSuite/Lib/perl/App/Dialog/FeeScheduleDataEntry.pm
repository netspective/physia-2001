##############################################################################
package App::Dialog::FeeScheduleDataEntry;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use App::Dialog::Field::Organization;

use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Catalog;
use App::Statements::Search::Code;
use App::Statements::IntelliCode;

use App::Universal;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'feescheduledataentry' => {
			heading => '$Command Fee Schedule Entry', 
			_arl => ['internal_catalog_id'], 
		},
);

my $CPT_CODE=App::Universal::CATALOGENTRYTYPE_CPT;
my $CPT_HCPCS=App::Universal::CATALOGENTRYTYPE_HCPCS;
my $FS_CATALOG_TYPE = 0;
sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'feescheduledataentry', heading => 'Fee Schedule Entries');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	

	$self->addContent(
                        new App::Dialog::Field::Catalog::ID(caption => 'Fee Schedule ID',
						name => 'catalog_id',
						#type => 'integer',
						options => FLDFLAG_REQUIRED,
						#findPopup => '/lookup/catalog',
						#hints => 'Numeric Fee Schedule ID'
						),
                        new CGI::Dialog::Field(	caption => 'CPTs', 
                        			name => 'listofcpts', 
                        			size => 70, 
                        			hints => 'Please provide a comma separated list of cpts or cpt ranges, example:xxxxx,xxxxx-xxxxx,xxxxx,xxxxx-xxxxx.', 
                        			findPopup => '/lookup/cpt',
                        			findPopupAppendValue =>',',
						),
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}


sub populateData
{
	my ($self, $page, $command) = @_;
	return unless $page->param('internal_catalog_id');	
	my $internalId = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,'selInternalCatalogIdById',$page->session('org_internal_id'),$page->param('internal_catalog_id'));
	$page->field('catalog_id',$internalId->{catalog_id}) if $internalId->{internal_catalog_id};
	
}


sub _sortCptValues
{
	my ($page,$a,$b)= @_;
	my @cpta = split(/-/, $a);  
	my @cptb = split(/-/, $b);  
	return (return $cpta[0] <=> $cptb[0]);
	
}
sub customValidate
{
	my ($self, $page) = @_;
	
	my $cpts = $page->field('listofcpts');
	my $fs;
	my $fsField = $self->getField('catalog_id');
	my $cptField = $self->getField('listofcpts');
        $cpts =~ s/\s//g;         
        my @cptCodes = split(/\s*,\s*/, $cpts);        
        my $mincpt;
        my $maxcpt;
        my $first=0;
        my @sortCpt = sort {_sortCptValues($page,$a,$b)} @cptCodes; 
        my $orgName = $page->session('org_id');
        
        #check if Org has the GPIC Local info set
        my $gpciItemName = 'Medicare GPCI Location';		
	my $org = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute',$page->session('org_internal_id'), $gpciItemName);
	$fsField->invalidate($page, "Medicare GPCI Location is not set for $orgName")	unless $org->{value_text};

	my $catalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE,'selInternalCatalogIdByIdType', 
			$page->session('org_internal_id'),$page->field('catalog_id'),$FS_CATALOG_TYPE);     
	$fs = $catalog->{internal_catalog_id};
	$page->param('internal_catalog_id',$fs);
        #Make sure Fee schedule has a multipler specificed
        my $fsHash = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selCatalogById', $fs);
        if(!defined $fsHash->{catalog_id})
        {
                $fsField->invalidate($page, "Fee Schedule $fs does not exist");
        }
        else
        {
        	$fsField->invalidate($page, "Fee Schedule '$fsHash->{catalog_id}' does not have a RVRBS multiplier.") unless defined $fsHash->{rvrbs_multiplier};
        }
        
        foreach my $check (@sortCpt)
        {        	
        	unless ($check=~/^\w+$|(\w+)-(\w+)$/)
        	{
        		$cptField->invalidate($page, "Invalid range $check");
        	}
		my @cptRange = split(/-/, $check);   			
		$cptRange[1] = length($cptRange[1]) ? $cptRange[1] : $cptRange[0];		
		
		#If not first time thru loop then check for overlapping values
		if($first!=0)
		{
			
			if  (	($mincpt<=$cptRange[0]&&$maxcpt>=$cptRange[0]) ||
			 	($mincpt<=$cptRange[1]&&$maxcpt>=$cptRange[1])
			    )
			{
				$cptField->invalidate($page, "Overlapping Ranges $check, [$mincpt-$maxcpt]");
			}
			
					
		}
		
		#Query database for already existing CPT codes
		$cptField->invalidate($page, "CPT code in range $check, already exists in Fee Schedule $fs") if $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selCatalogItemByRange', $cptRange[0], $cptRange[1],$fs);
		
		$first++;		
		#Only change maxcpt range if new value is greater then the old value
		if ($cptRange[1]>$maxcpt)
		{
			$mincpt = $cptRange[0];
			$maxcpt = $cptRange[1];
		}
        };
}


sub execute
{
	my ($self, $page, $command, $flags, $member) = @_;

	my $cpts = $page->field('listofcpts');
	my $fs = $page->param('internal_catalog_id');
	my $fsField = $self->getField('catalog_id');
	my $cptField = $self->getField('listofcpts');
        $cpts =~ s/\s//g;         
        my @cptCodes = split(/\s*,\s*/, $cpts);        
        my $sessionId = $page->session('_session_id');
	my $userId = $page->session('user_id');
	my $orgId = $page->session('org_internal_id');
	my @sortCpt = sort {_sortCptValues($page,$a,$b)} @cptCodes; 	
	
        foreach my $check (@sortCpt)
        {        	
		my @cptRange = split(/-/, $check);   			
		$cptRange[1] = length($cptRange[1]) ? $cptRange[1] : $cptRange[0];		
		$page->addError("$cptRange[0] <-> $cptRange[1]");
		#SQL COMMAND TO CREATE RANGE FEE SCHEDULE ENTRIES
		my $insertStmt = qq{
			INSERT INTO Offering_Catalog_Entry  (cr_session_id, cr_stamp, cr_user_id, cr_org_internal_id,
			catalog_id,  entry_type, flags, status, code,  name, cost_type, unit_cost, description ,data_text) 			
			(SELECT '$sessionId', sysdate, '$userId', '$orgId', $fs,  $CPT_CODE, ora.value_int, 1 ,
				rvu.code,
				ref_cpt.name, 
				1, 	
				( 
				(rvu.work_rvu * gpci.work) + 
				(decode(ora.value_int,0,trans_non_fac_pe_rvu,trans_fac_pe_rvu) * gpci.practice_expense) + 
				(rvu.mal_practice_rvu * gpci.mal_practice) 
				) * rvu.conversion_fact * oc.rvrbs_multiplier
				as unit_cost,
				ref_cpt.description,
				nvl((	SELECT	service_type 
					FROM REF_Code_Service_Type
				 	WHERE rvu.code BETWEEN code_min 
				 	AND	code_max
				),'01') as service_type
			FROM 	Offering_Catalog oc,  ofcatalog_attribute oa, org_attribute ora,
				REF_PFS_RVU  rvu, REF_GPCI gpci, ref_cpt
				
			WHERE	oc.internal_catalog_id = $fs
			AND	oa.parent_id (+) = oc.internal_catalog_id
			AND	oa.item_name (+)= 'Capitated Contract'
			AND 	ora.item_name  = 'Medicare GPCI Location'
			AND 	ora.parent_id (+) = $orgId
			AND	ora.value_text = gpci.gpci_id
			AND	UPPER(rvu.code) BETWEEN UPPER('$cptRange[0]')
			AND	UPPER('$cptRange[1]')
			AND	rvu.modifier is NULL
			AND	sysdate BETWEEN rvu.eff_begin_date
			AND	rvu.eff_end_date		
			AND	ref_cpt.cpt = rvu.code
			)
			UNION
			(SELECT '$sessionId', sysdate, '$userId', '$orgId', $fs,  $CPT_HCPCS, ora.value_int, 1 ,
				rvu.code,
				ref_hcpcs.name, 
				1, 	
				( 
				(rvu.work_rvu * gpci.work) + 
				(decode(ora.value_int,0,trans_non_fac_pe_rvu,trans_fac_pe_rvu) * gpci.practice_expense) + 
				(rvu.mal_practice_rvu * gpci.mal_practice) 
				) * rvu.conversion_fact * oc.rvrbs_multiplier
				as unit_cost,
				ref_hcpcs.description,
				nvl((	SELECT	service_type 
					FROM REF_Code_Service_Type
				 	WHERE rvu.code BETWEEN code_min 
				 	AND	code_max
				),'01') as service_type
			FROM 	Offering_Catalog oc,  ofcatalog_attribute oa, org_attribute ora,
				REF_PFS_RVU  rvu, REF_GPCI gpci, 
				ref_hcpcs
			WHERE	oc.internal_catalog_id = $fs
			AND	oa.parent_id (+) = oc.internal_catalog_id
			AND	oa.item_name (+)= 'Capitated Contract'
			AND 	ora.item_name  = 'Medicare GPCI Location'
			AND 	ora.parent_id (+) = $orgId
			AND	ora.value_text = gpci.gpci_id
			AND	UPPER(rvu.code) BETWEEN UPPER('$cptRange[0]')
			AND	UPPER('$cptRange[1]')
			AND	rvu.modifier is NULL
			AND	sysdate BETWEEN rvu.eff_begin_date
			AND	rvu.eff_end_date		
			AND	ref_hcpcs.hcpcs  = rvu.code
			)			
		};
	  	$STMTMGR_CATALOG->execute($page, STMTMGRFLAG_DYNAMICSQL, $insertStmt);
        };       	       	
        $page->param('_dialogreturnurl', "/org/@{[$page->param('org_id')]}/catalog");
	$self->handlePostExecute($page, $command, $flags);
}

1;
