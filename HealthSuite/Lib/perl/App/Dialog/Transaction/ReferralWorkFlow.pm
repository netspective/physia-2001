##############################################################################
package App::Dialog::Transaction::ReferralWorkFlow;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;


use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = ( 'referralworkflow' => {});

sub initialize
{
	#my $self = CGI::Dialog::new(@_, id => 'referral', heading => 'Add Referral');
	my $self = shift;

	$self->{activityLog} =
	{
			level => 1,
			scope =>'transaction',
			key => "#param.person_id#",
			data => "Referral'to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};


	return $self;
}

1;
