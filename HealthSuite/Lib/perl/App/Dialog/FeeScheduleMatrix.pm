##############################################################################
package App::Dialog::FeeScheduleMatrix;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
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

use App::Universal;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'feescheduleentry' => {
			heading => '$Command Fee Schedule Entry', 
			_arl => ['feeschedules'], 
			_arl_modify => ['feeschedules'], 
			_idSynonym => 'FeeScheduleEntry'
		},	
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'feescheduleentry', heading => 'Add Fee Schedule Entry Costs');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	
	$self->addContent(
		new App::Dialog::Field::FeeScheduleMatrix(name =>'feescheduleentries'),
	);
        $self->addFooter(new CGI::Dialog::Buttons());

	return $self;
}


sub addFeeScheduleEntryItems
{
        my ($self, $page, $command, $flags) = @_;

        my $cpts = $page->param('_f_cpts');
        my $feeschedules = $page->param('_f_fs');

        my @allcpts = split(/\s*,\s*/, $cpts);
        my @allfeeschedules = split(/\s*,\s*/, $feeschedules);

        my $lineCount = $page->param('_f_line_count');
        my $colCount = $page->param('_f_col_count');


	for(my $line = 0; $line < $lineCount; $line++)
	{
		if($allcpts[$line] =~ '-')
		{
			my @cptRange = split(/-/, $allcpts[$line]);
			for(my $rangeincrement = $cptRange[0]; $rangeincrement <= $cptRange[1]; $rangeincrement++)
				{
				for(my $rangecol = 0; $rangecol < $colCount; $rangecol++)
					{
					       $page->schemaAction('Offering_Catalog_Entry', 'add',
								code => $rangeincrement || undef,
								unit_cost => $page->param("_f_amount_$rangeincrement\_$rangecol\_payment") || undef,
								catalog_id => $allfeeschedules[$rangecol] || undef,
								entry_type => App::Universal::CATALOGENTRYTYPE_CPT || undef,
								_debug => 0,
								);
					}

				}
		}                                   
                else
                {
			for(my $col = 0; $col < $colCount; $col++)
			{
			       $page->schemaAction('Offering_Catalog_Entry', 'add',
						code => $allcpts[$line] || undef,
						unit_cost => $page->param("_f_amount_$line\_$col\_payment") || undef,
						catalog_id => $allfeeschedules[$col] || undef,
						entry_type => App::Universal::CATALOGENTRYTYPE_CPT || undef,
						_debug => 0,
						);
			}
		}
	
	}


}


sub execute
{
        my ($self, $page, $command, $flags, $member) = @_;

        my $orgId = $page->session('org_id');

	addFeeScheduleEntryItems($self, $page, $command, $flags);
	$self->handlePostExecute($page, $command, $flags, "/org/$orgId/catalog");
}

1;
