##############################################################################
package App::Dialog::Query;
##############################################################################

use strict;
use App::Universal;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::DataGrid;
use SQL::GenerateQuery;
use base qw(CGI::Dialog);
use SDE::CVS ('$Id: Query.pm,v 1.1 2000-09-12 15:24:30 robert_jenks Exp $','$Name:  $');
use vars qw(%RESOURCE_MAP);

%RESOURCE_MAP=();

use constant MAXPARAMS => 5;
use constant SHOWROWS => 10;


sub new
{
	my $self = CGI::Dialog::new(@_, id => 'query', width => '100%');
	
	my $page = $self->{page};
	my $sqlGen = new SQL::GenerateQuery(file => $page->property('QDL'));
	$self->{sqlGen} = $sqlGen;
	my $styleName = $page->param('_style') || 'default';
	my $style = $sqlGen->style($page->param('_style'));
	$self->{style} = $style;
	
	my $fieldSelections = join ';', map {$sqlGen->field($_)->{caption} . ":" . $sqlGen->field($_)->{id}} $sqlGen->field();
	my $comparisonOps = join ';', map {$sqlGen->comparison($_)->{caption} . ":" . $sqlGen->comparison($_)->{id}} grep {$sqlGen->comparison($_)->{placeholder} !~ /\@/} $sqlGen->comparison();
	my $joinOps = 'AND;OR';
	
	my $gridName = 'params';
	my $maxParams = MAXPARAMS;
	
	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'start_row'),
		new CGI::Dialog::DataGrid(
			caption => '',
			name => $gridName,
			rows => $maxParams,
			rowFields => [
				{
					_class => 'CGI::Dialog::Field',
					name => 'field',
					caption => 'Field',
					selOptions => $fieldSelections,
					options => FLDFLAG_PREPENDBLANK,
					type => 'select',
					onChangeJS => qq{onChangeField(event);},
				},
				{
					_class => 'CGI::Dialog::Field',
					name => 'comparison',
					caption => 'Comparison',
					selOptions => $comparisonOps,
					type => 'select',
					onChangeJS => qq{onChangeComparison(event);},
				},
				{
					_class => 'CGI::Dialog::Field',
					name => 'criteria',
					findPopup => '/lookup',
					caption => 'Criteria',
					onChangeJS => qq{resetStartRow();},
				},
				{
					_class => 'CGI::Dialog::Field',
					_skipOnRows => [$maxParams],
					name => 'join',
					caption => 'Join',
					selOptions => $joinOps,
					options => FLDFLAG_PREPENDBLANK,
					type => 'select',
					onChangeJS => qq{resetStartRow();showHideRows('$gridName', 'join', $maxParams);},
				},
				{
					_class => 'CGI::Dialog::Field',
					_skipOnRows => [2..$maxParams],
					name => 'submit',
					caption => '',
					value => 'Go',
					type => 'submit',
				},
#				{
#					_class => 'CGI::Dialog::Field',
#					_skipOnRows => [2..$maxParams],
#					name => 'more',
#					caption => '',
#					value => 'More>>',
#					type => 'button',
#				},
			],
		),
	);
	
	
	# Setup data scructures necessary for JavaScript
	my $fieldLookups = join ", ", map {$sqlGen->field($_)->{id} . " : '" . $sqlGen->field($_)->{'lookup-url'} . "'"} grep {exists $sqlGen->field($_)->{'lookup-url'}} $sqlGen->field();
	my $noCriteria = join ", ", map {$sqlGen->comparison($_)->{id} . " : 1"} grep {$sqlGen->comparison($_)->{value} eq ''} $sqlGen->comparison();
	
	my $showRows = SHOWROWS;
	
	$self->addPostHtml(qq{
		<script language="JavaScript1.2">
		<!--
		
		var fieldLookups = {$fieldLookups};
		
		function onChangeField(event)
		{
			var myValue = event.srcElement.value;
			var lookup = '';
			var visibility = "hidden";
			var result = event.srcElement.name.match(/field_(\\d+)/);
			if (result != null)
			{
				var criteriaObj = "document.all._f_criteria_" + result[1];
				if (myValue && (lookup = eval("fieldLookups." + myValue)))
				{
					lookup = "javascript:doFindLookup(document.dialog, " + criteriaObj + ", '" + lookup + "', '', false, null, null);";
					visibility = "visible";
				}
				var lookupObj = eval("document.all._find_link_criteria_" + result[1]);
				lookupObj.href = lookup;
				lookupObj.style.visibility = visibility;
			}
			else
			{
				alert("field number not found");
			}
			resetStartRow();
		}
		
		var noCriteria = {$noCriteria};
		
		function onChangeComparison(event)
		{
			var myValue = event.srcElement.value;
			var disabled = false;
			var bgColor = "#FFFFFF";
			var result = event.srcElement.name.match(/comparison_(\\d+)/);
			if (result != null)
			{
				if (myValue && eval("noCriteria." + myValue))
				{
					disabled = true;
					bgColor = "#CCCCCC";
				}
				var criteriaObj = eval("document.all._f_criteria_" + result[1]);
				criteriaObj.disabled = disabled;
				criteriaObj.style.backgroundColor = bgColor;
			}
			else
			{
				alert("field number not found");
			}
			resetStartRow();
		}

		function changePage(offset)
		{
			var rowOffset = offset * $showRows;
			var fieldObj = "document.all._f_start_row";
			if(startRow = eval(fieldObj))
			{
				var newStart = Number(startRow.value) + rowOffset;
				if (newStart < 0)
					newStart = 0;
				startRow.value = newStart;
			}
			document.all.dialog.submit();
		}
		
		function resetStartRow()
		{
			var fieldObj = "document.all._f_start_row";
			//alert('Resetting Start Row to 0');
			if(startRow = eval(fieldObj))
				startRow.value = 0;
		}
		
		showHideRows('params', 'join', $maxParams);
		
		//if (destObj = eval('document.all._f_out_destination'))
		//{
		//	if (destObj.options[destObj.selectedIndex].text == 'Browser')
		//	{
		//		setIdStyle('_id_out_printer', 'display', 'none');
		//		setIdStyle('_id_out_email', 'display', 'none');
		//	}
		//	else if (destObj.options[destObj.selectedIndex].text == 'Browser')
		//	{
		//		setIdStyle('_id_out_format', 'display', 'none');
		//		setIdStyle('_id_out_email', 'display', 'none');
		//	}
		//	else if (destObj.options[destObj.selectedIndex].text == 'E-Mail')
		//	{
		//		setIdStyle('_id_out_format', 'display', 'none');
		//		setIdStyle('_id_out_printer', 'display', 'none');
		//	}
		//}
		
		// -->
		</script>
	});
	
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $sqlGen = $self->{sqlGen};
	my $style = $self->{style};
	my @outColumns = map {$_->{id}} @{$style->{columns}};
	my @orderBy = map {$_->{id}} @{$style->{'order-by'}};
	my $distinct = defined $style->{distinct} ? $style->{distinct} : 0;
	my $condition;
	
	my $startRow = $page->field('start_row');
	$startRow = 0 unless $startRow;
	my $endRow = $startRow + SHOWROWS;
		
	$page->property(CGI::Dialog::PAGEPROPNAME_INEXEC . '_' . $self->id(), 1);
	
	# Build user condition
	my @andConditions = ();
	my @orConditions = ();
	foreach my $i (1..MAXPARAMS)
	{
		my $field = $page->field("field_$i");
		my $comparison = $page->field("comparison_$i");
		my $criteria = $page->field("criteria_$i");
		my $join = $page->field("join_$i");
			
		#$page->addDebugStmt("got here $field $comparison $criteria");
		if ($field)
		{
			#$page->addDebugStmt("adding condition '$field $comparison $criteria'");
			push @andConditions, $sqlGen->WHERE("upper({$field})", $comparison, uc($criteria));
		}
		
		if ($join ne 'AND')
		{
			push @orConditions, $sqlGen->AND(@andConditions) if @andConditions;
			@andConditions = ();
		}
		last unless $join;
	}
	
	if (@orConditions)
	{
		$condition = $#orConditions ? $sqlGen->OR(@orConditions) : $orConditions[0];
	}
	
	
	# If the style has a condition, combine it with the user's
	if (exists $style->{condition} && defined $style->{condition})
	{
		$condition = $condition ? $sqlGen->AND($style->{condition}, $condition) : $style->{condition};
	}
	
	# Generate the SQL & Bind Params
	($self->{SQL}, $self->{bindParams}) = $condition->genSQL(
		outColumns => \@outColumns,
		orderBy => \@orderBy,
		distinct => $distinct);
		
	# Wrap the SQL with an outer SQL to limit results
	my $cols = join ",\n", map {"\t$_"} @outColumns;
	$self->{SQL} = "SELECT * FROM (\n\nSELECT\n\trownum AS row_num,\n$cols\nFROM (\n\n" . $self->{SQL} . "\n\n)\n\n)\n\nWHERE row_num <= ? AND row_num > ?";
	push @{$self->{bindParams}}, $endRow, $startRow;
	
	$self->{pageControlHtml} = qq{
		<br>
		<center>
			<a href="javascript:changePage(-1)">Prev Page</a>\&nbsp;\&nbsp;
			<a href="javascript:changePage(1)">Next Page</a>
		</center>
		};
	
	return '';
}

1;
