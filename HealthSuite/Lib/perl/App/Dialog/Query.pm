##############################################################################
package App::Dialog::Query;
##############################################################################

use strict;
use App::Universal;
use CGI::Dialog;
use CGI::Validator::Field;
use CGI::ImageManager;
use SQL::GenerateQuery;
use DBI::StatementManager;
use App::Statements::Org;
use Data::Publish;
use base qw(CGI::Dialog);
use SDE::CVS ('$Id: Query.pm,v 1.3 2000-09-13 16:04:02 robert_jenks Exp $','$Name:  $');
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
	
	my $fieldSelections = 
		join ';',
			map {$sqlGen->field($_)->{caption} . ":" . $sqlGen->field($_)->{id}}
				grep {defined $sqlGen->field($_)->{caption}}
					$sqlGen->field();
	my $comparisonOps =
		join ';',
			map {$sqlGen->comparison($_)->{caption} . ":" . $sqlGen->comparison($_)->{id}}
				grep {$sqlGen->comparison($_)->{placeholder} !~ /\@/}
					$sqlGen->comparison();
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
					onBlurJS => qq{onBlurCriteria(event);},
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
	my $fieldLookups = 
		join ", ", 
			map {$sqlGen->field($_)->{id} . " : '" . $sqlGen->field($_)->{'lookup-url'} . "'"} 
				grep {exists $sqlGen->field($_)->{'lookup-url'}} 
					$sqlGen->field();
	my $fieldTypes = 
		join ", ", 
			map {$sqlGen->field($_)->{id} . " : '" . $sqlGen->field($_)->{'ui-datatype'} . "'"} 
				grep {exists $sqlGen->field($_)->{'ui-datatype'}}
					$sqlGen->field();
	my $noCriteria = 
		join ", ",
			map {$sqlGen->comparison($_)->{id} . " : 1"}
				grep {defined $sqlGen->comparison($_)->{value} && $sqlGen->comparison($_)->{value} eq ''}
					$sqlGen->comparison();
	
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
		
		var fieldTypes = {$fieldTypes};
		
		function onBlurCriteria(event)
		{
			var myValue = event.srcElement.value;
			var result = event.srcElement.name.match(/criteria_(\\d+)/);
			if (result != null)
			{
				var fieldSelObj = eval("document.all._f_field_" + result[1]);
				var curField = fieldSelObj.options[fieldSelObj.selectedIndex].value;
				if (myValue && (type = eval("fieldTypes." + curField)))
				{
					if (type = 'date') validateChange_Date(event);
				}
			}
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
		
		function onMouseOverRow(event)
		{
			event.srcElement.parentElement.parentElement.parentElement.style.backgroundColor = '#CCCCCC';
		}
		
		function onMouseOutRow(event)
		{
			event.srcElement.parentElement.parentElement.parentElement.style.backgroundColor = '#FFFFFF';
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
			my $whereField = "UPPER({$field})";
			if ($sqlGen->field($field) && defined $sqlGen->field($field)->{'ui-datatype'})
			{
				my $dataType = $sqlGen->field($field)->{'ui-datatype'};
				if ($dataType eq 'date')
				{
					$whereField = "TO_CHAR({$field}, 'MM/DD/YYYY')";
				}
				
			}

			push @andConditions, $sqlGen->WHERE($whereField, $comparison, uc($criteria));
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
	my ($SQL, $bindParams) = $condition->genSQL(
		outColumns => \@outColumns,
		orderBy => \@orderBy,
		distinct => $distinct);
		
	# Wrap the SQL with an outer SQL to limit results
	my $cols = join ",\n", map {"\t$_"} @outColumns;
	$SQL = "SELECT * FROM (\n\nSELECT\n\trownum AS row#,\n$cols\nFROM (\n\n" . $SQL . "\n\n) WHERE rownum <= ?\n\n) WHERE row# > ?";
	push @{$bindParams}, ($endRow+1), $startRow;
	
	# Do any variable replacements in the SQL itself
	$page->replaceVars(\$SQL);

	my $stmgrFlags = STMTMGRFLAG_DYNAMICSQL | STMTMGRFLAG_REPLACEVARS;
	my $publDefn = {};
	my $stmtHdl = $STMTMGR_ORG->execute($page, $stmgrFlags, $SQL, @$bindParams);
	prepareStatementColumns($page, $stmgrFlags, $stmtHdl, $publDefn);
	my $resultHtml = createHtmlFromStatement($page, $stmgrFlags, $stmtHdl, $publDefn, {stmtId => $SQL, maxRows => SHOWROWS});
	my $nextPageExists = $stmtHdl->fetch();
	$stmtHdl->finish();
	
	# Add the results table to the page	
	$page->addContent('<br><div align="center">' . $resultHtml . '</div>');
	
	# Add page controls below the results
	my $pageControlHtml = '<br><center>';
	$pageControlHtml .= qq{<a href="javascript:changePage(-1)">Prev Page</a>} unless $startRow == 0;
	if (defined $nextPageExists)
	{
		$pageControlHtml .= '&nbsp;&nbsp' if $startRow > 0;
		$pageControlHtml .= qq{<a href="javascript:changePage(1)">Next Page</a>};
	}
	$pageControlHtml .= '</center>';
	$page->addContent($pageControlHtml);
	
	return '';
}

1;
