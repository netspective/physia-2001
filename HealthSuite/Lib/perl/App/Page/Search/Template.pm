##############################################################################
package App::Page::Search::Template;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Scheduling;
use Data::Publish;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/template' => {},
	);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->param('_pm_view', $pathItems->[0]);

	unless ($self->param('searchAgain')) {
		my $r_ids = $pathItems->[2];
		my $facility_id = $pathItems->[3];
		my $template_type = $pathItems->[4];

		$self->param('r_ids', $r_ids);
		$self->param('facility_id', $facility_id);
		$self->param('searchAgain', 1);
	}

	$self->param('execute', 'Go') if $pathItems->[1];  # Auto-execute
	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
}

sub getForm
{
	my ($self, $flags) = @_;

	my $createFns = '';
	unless($flags & SEARCHFLAG_LOOKUPWINDOW)
	{
		$createFns = qq{
			|
			<font size=2 face='Tahoma'>&nbsp &nbsp
			<a href="/schedule/dlg-add-template?_dialogreturnurl=/search/template">Add Template</a>
			</font>
		};
	}

	my ($selected0, $selected1, $selected2);
	my $selected;

	my @available = split (/,/, $self->param('template_type'));

	return ('Lookup a scheduling template', qq{
		<CENTER>
		<NOBR>
		<font size=2 face='Tahoma'>	Search for </font>
		<select name="template_type" style="color: darkred">
			<option value="0,1" $selected0>All Templates</option>
			<option value="1,1" $selected1>Positive Templates</option>
			<option value="0,0" $selected2>Negative Templates</option>
		</select>
		<select name="template_active" style="color: navy">
			<option value="1">Active</option>
			<option value="0">Inactive</option>
		</select>
		<script>
			setSelectedValue(document.search_form.template_type, '@{[$self->param('template_type')]}');
			setSelectedValue(document.search_form.template_active, '@{[$self->param('template_active')]}');
		</script>

		<input name='r_ids' size=17 maxlength=32 value="@{[$self->param('r_ids')]}"
			title='Resource ID'>
			<a href="javascript:doFindLookup(this.form, search_form.r_ids, '/lookup/person/id');">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Resource ID"></a>

		<input name='facility_id' size=17 maxlength=32 value="@{[$self->param('facility_id')]}" title='Facility ID'>
			<a href="javascript:doFindLookup(this.form, search_form.facility_id, '/lookup/org/id');">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Facility ID"></a>

		<input type=hidden name='searchAgain' value="@{[$self->param('searchAgain')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		$createFns
		</CENTER>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	my @available = split (/,/, $self->param('template_type'));
	@available = (0,1) unless @available;
	
	my $template_active;
	my $statement;
	
	if (defined $self->param('template_active') && $self->param('template_active') == 1)
	{ 
		$template_active = $self->param('template_active');
		$statement = 'selEffectiveTemplate';
	} 
	else
	{
		$template_active = 0;
		$statement = 'selInEffectiveTemplate';
	}
	
	my @bindCols = ($self->session('org_internal_id'), $self->param('r_ids').'%', 
		$self->param('facility_id').'%', @available, $template_active);

	$self->param('_dialogreturnurl', '/search/template');

	# Need to move this to GLOBAL area
	# --------------------------------
	my $patientTypes = $STMTMGR_SCHEDULING->getRowsAsHashList($self, STMTMGRFLAG_NONE, 'selPatientTypes');
	my %PATIENT_TYPE;
	for (@$patientTypes)
	{
		$PATIENT_TYPE{$_->{id}} = $_->{caption};
		$PATIENT_TYPE{$_->{id}} =~ s/\spatient//gi;
	}

	my $visitTypes = $STMTMGR_SCHEDULING->getRowsAsHashList($self, STMTMGRFLAG_NONE, 'selVisitTypes');
	my %VISIT_TYPE;
	for (@$visitTypes)
	{
		$VISIT_TYPE{$_->{id}} = $_->{caption};
	}
	
	my %WEEKDAYS = (1=>'Sun', 2=>'Mon', 3=>'Tue', 4=>'Wed', 5=>'Thu', 6=>'Fri', 7=>'Sat');
	# --------------------------------
	
	my $templates = $STMTMGR_SCHEDULING->getRowsAsHashList($self, STMTMGRFLAG_NONE,
		$statement, @bindCols);
		
	my @data = ();
	my $patientTypesString;
	my $visitTypesString;
	
	foreach (@{$templates})
	{
		if ($_->{patient_types})
		{
			my @pTypes = split(/\s*,\s*/, $_->{patient_types});
			my @decodePTypes = ();
			for (@pTypes)
			{
				push(@decodePTypes, $PATIENT_TYPE{$_});
			}
			$patientTypesString = join(', ', @decodePTypes);
		}
		else
		{
			$patientTypesString = 'All';
		}

		if ($_->{visit_types})
		{
			my @vTypes = split(/\s*,\s*/, $_->{visit_types});
			my @decodeVTypes = ();
			for (@vTypes)
			{
				push(@decodeVTypes, $VISIT_TYPE{$_});
			}
			$visitTypesString = join(', ', @decodeVTypes);
		}
		else
		{
			$visitTypesString = 'All';
		}
		
		my $daysOfWeek = 'All';
		if ($_->{days_of_week})
		{
			my @dow = split(/\s*,\s*/, $_->{days_of_week});
			my @decodedDOW = ();
			for (@dow)
			{
				push(@decodedDOW, $WEEKDAYS{$_});
			}
			$daysOfWeek = join(', ', @decodedDOW);
		}
		
		$_->{months} ||= 'All';
		$_->{days_of_month} ||= 'All';
		
		
		my @rowData = (
			$_->{template_id},
			$_->{resources},
			$_->{caption},
			$_->{org_id},
			$patientTypesString,
			$visitTypesString,
			$_->{start_time},
			$_->{end_time},
			$_->{begin_date},
			$_->{end_date},
			$_->{months},
			$_->{days_of_month},
			$daysOfWeek,
			$_->{available},
		);
			
		push(@data, \@rowData);
	}
	
	my $STMTRPTDEFN_TEMPLATEINFO =
	{
		columnDefn =>
			[
				{ head => 'ID', url => q{javascript:location.href='/schedule/dlg-update-template/#&{?}#?_dialogreturnurl=/search/template'}, hint => 'Edit Template #&{?}#'},
				{ head => 'Resource(s)', url => q{javascript:location.href='/search/template/1/#&{?}#'}, hint => 'View #&{?}# Templates'},
				{ head => 'Caption'},
				{ head => 'Facility', url => q{javascript:location.href='/search/template/1//#&{?}#'}, hint => 'View #&{?}# Templates'},
				{ head => 'Details', dataFmt => qq{
					<nobr>Time: <b>#6# - #7# </b></nobr><br>
					<nobr>Patient Types: #4#</nobr><br>
					Visit Types: #5#<br>
					<nobr>Months: #10#</nobr><br>
					<nobr>Days of Month: #11#</nobr><br>
					<nobr>Weekdays: #12# </nobr><br>
					},
				},
				{ head => 'Available', colIdx => 13,},
				{ head => 'Effective', dataFmt => '#8#-<br>#9#', },	
			],
	};

	
	my $html = createHtmlFromData($self, 0, \@data, $STMTRPTDEFN_TEMPLATEINFO);
	
	$self->addContent(
	'<CENTER>',
		$html,
	'</CENTER>'
	);





	return 1;
}

1;
