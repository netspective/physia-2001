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
use App::Dialog::Field::FeeScheduleMatrix;

use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Catalog;

use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'feescheduledataentry', heading => 'Fee Schedule Entries');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	

	$self->addContent(
                        new CGI::Dialog::Field(caption => 'Fee Schedules', size => 70, name => 'feeschedules',types => ['FeeScheduleEntry'],hints => 'Please provide a comma separated list of fee schedules.'),
                        new CGI::Dialog::Field(caption => 'CPTs', name => 'listofcpts', size => 70, hints => 'Please provide a comma separated list of cpts or cpt ranges, example:xxxxx,xxxxx-xxxxx,xxxxx,xxxxx-xxxxx.', findPopup => '/lookup/cpt'),

	);
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub customValidate
{
	my ($self, $page) = @_;

	my %cptsSeen = ();

	my $feeschedules = $page->field('feeschedules');
	my $feeScheduleField = $self->getField('feeschedules');
	$feeschedules =~ s/\s//g;
	
	my $cpts = $page->field('listofcpts');
	my $cptField = $self->getField('listofcpts');
        $cpts =~ s/\s//g;

	
        my @feeSchedules = split(/\s*,\s*/, $feeschedules);
        my @cptCodes = split(/\s*,\s*/, $cpts);

	#$page->addDebugStmt("feeschedules are $feeschedules, @feeSchedules");

	foreach my $feeSchedule (@feeSchedules)
	{
		if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selCatalogById', $feeSchedule)))
		{
			$feeScheduleField->invalidate($page, "The fee schedule $feeSchedule is not valid. Please verify");
		}
	}

        foreach (@cptCodes)
        {
                $cptsSeen{$_} = 1;
        }
        
        my $totalCodesEntered = @cptCodes;
        my $listTotal = keys %cptsSeen;

        if($totalCodesEntered != $listTotal)
        {
                $cptField->invalidate($page, 'Cannot enter the same CPT code more than once.');
        }
        
        foreach my $cptCode (@cptCodes)
        {
		if($cptCode !~ '-' && not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericCPTCode', $cptCode)))
		{
			$cptField->invalidate($page, "The CPT code $cptCode is not valid. Please verify");
		}
        
        	if($cptCode =~ '-')
        	{
        		my @cptRange = split(/-/, $cptCode);  		
        		if($cptRange[0] > $cptRange[1] )
        		{
                 		$cptField->invalidate($page, "The CPT Range $cptCode is not corect. Please verify");       			
        		}
        		else
        		{
				for(my $rangeincrement = $cptRange[0]; $rangeincrement <= $cptRange[1]; $rangeincrement++)
					{
						if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericCPTCode', $rangeincrement)))
						{
							$cptField->invalidate($page, "The CPT range $cptCode is not valid. Please verify");
						}
					}
        		}
        	}
        }

}

sub execute
{
	my ($self, $page, $command, $flags, $member) = @_;

	my $orgId = $page->session('org_id');
        my $feeschedules = $page->field('feeschedules');
        $feeschedules =~ s/\s//g;

        my $cpts = $page->field('listofcpts');
        $cpts =~ s/\s//g;

	$self->handlePostExecute($page, $command, $flags, "/org/$orgId/dlg-add-feescheduleentry?_f_fs=$feeschedules&_f_cpts=$cpts");

}

1;
