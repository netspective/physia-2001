##############################################################################
package App::Dialog::Query;
##############################################################################

use strict;
use App::Universal;
use App::Configuration;
use File::Temp qw(tempfile);
use App::Page;
use CGI::Dialog;
use CGI::Validator::Field;
use CGI::ImageManager;
use SQL::GenerateQuery;
use DBI::StatementManager;
use App::Statements::Org;
use Data::Dumper;

# Output modules
use Data::Publish;
use Text::CSV;

use base qw(CGI::Dialog);
use SDE::CVS ('$Id: Query.pm,v 1.6 2000-10-08 21:53:37 robert_jenks Exp $','$Name:  $');
use vars qw(%RESOURCE_MAP);


%RESOURCE_MAP=();

use constant MAXPARAMS => 5;
use constant SHOWROWS => 10;


sub new
{
	my $self = CGI::Dialog::new(@_, id => 'query', headColor => '#FFFFFF', bgColor => '#CCCCCC');

	my $page = $self->{page};
	my $sqlGen = new SQL::GenerateQuery(file => $page->property('QDL'));
	$self->{sqlGen} = $sqlGen;
	my $viewName = $page->param('_query_view') || 'all';
	my $view = $sqlGen->views($page->param('_query_view'));
	$self->{view} = $view;
	my $queryViewTitle = $view->{caption};
	my $queryType = $page->param('_query_type');

	# Create custom HTML for Filter Tabs
	my $filterTabs = '';
	if (!($page->{flags} & App::Page::PAGEFLAG_ISPOPUP))
	{
		my $viewMenu = [];
		foreach my $viewName ($sqlGen->views())
		{
			push @$viewMenu, [ $sqlGen->views($viewName)->{caption} || "\u$viewName", "/query/$queryType/$viewName", $viewName ];
		}
		my $viewMenuHtml = $page->getMenu_Tabs(App::Page::MENUFLAGS_DEFAULT, '_query_view', $viewMenu, {
			selColor => '#CCCCCC', selTextColor => 'black', unselColor => '#E5E5E5', unselTextColor => '#555555', highColor => 'navy',
			leftImage => 'images/design/tab-top-left-corner-white', rightImage => 'images/design/tab-top-right-corner-white'} );
		$self->{topHtml} = [qq{<br><table align="center" border="0" cellspacing="0" cellpadding="0" bgcolor="white"><tr><td>&nbsp;<font face="tahoma,helvetica" size="2" color="Navy"><b>Filters:</b></font>&nbsp;</td>$viewMenuHtml</tr></table>}];
	}

	my $fieldSelections =
		join ';',
			map {$sqlGen->fields($_)->{caption} . ":" . $sqlGen->fields($_)->{id}}
				grep {defined $sqlGen->fields($_)->{caption}}
					$sqlGen->fields();
	my $comparisonOps =
		join ';',
			map {$sqlGen->comparisons($_)->{caption} . ":" . $sqlGen->comparisons($_)->{id}}
				grep {$sqlGen->comparisons($_)->{placeholder} !~ /\@/}
					$sqlGen->comparisons();
	my $joinOps = 'AND;OR';

	my $gridName = 'params';
	my $maxParams = MAXPARAMS;

	push @{$page->{page_content}}, '<style> table.button {font-size: 8pt; border: 2; border-style: outset;}</style>';

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'start_row'),
		new CGI::Dialog::Subhead(
			heading => 'Query Definition',
		),
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
#				{
#					_class => 'CGI::Dialog::Field',
#					_skipOnRows => [2..$maxParams],
#					name => 'submit',
#					caption => '',
#					value => 'Go',
#					type => 'submit',
#				},
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
		new CGI::Dialog::Subhead(
			heading => 'Result Options',
		),
		new CGI::Dialog::Field(
			name => 'out_columns',
			caption => 'Columns',
			selOptions => $fieldSelections,
			multiDualCaptionLeft => 'Available Columns',
			multiDualCaptionRight => 'Output Columns',
			width => 175,
			size => 5,
			style => 'multidual',
			type => 'select',
#			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(
			name => 'out_sort',
			caption => 'Sorting',
			selOptions => $fieldSelections,
			multiDualCaptionLeft => 'Available Columns',
			multiDualCaptionRight => 'Sort Results By',
			width => 175,
			size => 3,
			style => 'multidual',
			type => 'select',
		),
#		new CGI::Dialog::Field(
#			name => 'out_group',
#			caption => 'Grouping',
#			selOptions => $fieldSelections,
#			multiDualCaptionLeft => 'Available Columns',
#			multiDualCaptionRight => 'Group Results By',
#			width => 175,
#			size => 3,
#			style => 'multidual',
#			type => 'select',
#		),
		new CGI::Dialog::Subhead(
			heading => 'Output Options',
		),
		new CGI::Dialog::Field(
			name => 'out_destination',
			caption => 'Destination',
			selOptions => 'Browser;Printer;E-Mail',
			type => 'select',
			defaultValue => 'Browser',
#			options => FLDFLAG_REQUIRED,
			onChangeJS => q{onChangeDestination();},
		),
		new CGI::Dialog::Field(
			name => 'out_printer',
			caption => 'Printer',
			selOptions => 'Back Office Laser;Reception Desk;Medical Records 1;Medical Records 2;Lab',
			type => 'select',
#			options => FLDFLAG_PREPENDBLANK,
		),
		new CGI::Dialog::Field(
			name => 'out_format',
			caption => 'Format',
			selOptions => 'Web Page (HTML):html;Comma Separated Values (CSV):csv;eXtensible Markup Language (XML):xml',
			type => 'select',
			defaultValue => 'html',
		),
		new CGI::Dialog::Field(
			name => 'out_email',
			caption => 'E-Mail',
		),
		new CGI::Dialog::Subhead(
#			heading => qq{<table cellspacing="0" cellpadding="0" border="0"><tr><td>
#				<font face="arial,helvetica" size=2 color=navy>
#					<b>Saved Queries&nbsp;&nbsp;</b>
#				</font>
#			</td><td><table cellspacing="0" cellpadding="1" align="right" class="button"><tr><td></td><td>
#				$IMAGETAGS{'icons/arrow-down-blue'}<br>
#			</td><td>
#				Show
#			</td></tr></table></td></tr></table>},
			heading => 'Saved Queries',
		),
		new CGI::Dialog::ContentItem(
			caption => '',
			preHtml => qq{
				<div style="font-face: Tahoma, Ariel, Helvetica; font-size: 10pt">
				<ul>
					<li><i>You do not have any saved queries of this type ($queryType / $queryViewTitle).</i></li>
				</ul>
				</div>
			},
		),
		new CGI::Dialog::ContentItem(
			caption => '',
			preHtml => qq{
				<center>
					<style>input.oksubmit {width: 75; font-weight: bold; font-size: 8pt; font-family: Tahoma, Ariel, Helvetica;}</style>
					<input type="button" class="oksubmit" value="Ok" onClick="validateOnSubmit(document.forms.dialog);document.dialog.submit()">&nbsp;&nbsp;
					<input type="button" class="oksubmit" value="Save" onClick="alert('Save not implemented yet')">&nbsp;&nbsp;
					<input type="button" class="oksubmit" value="Cancel" onClick="history.back()">
				</center>
			},
		),
	);

	$self->addFooter(
	);


	# Setup data scructures necessary for JavaScript
	my $fieldLookups =
		join ", ",
			map {$sqlGen->fields($_)->{id} . " : '" . $sqlGen->fields($_)->{'lookup-url'} . "'"}
				grep {exists $sqlGen->fields($_)->{'lookup-url'}}
					$sqlGen->fields();
	my $fieldTypes =
		join ", ",
			map {$sqlGen->fields($_)->{id} . " : '" . $sqlGen->fields($_)->{'ui-datatype'} . "'"}
				grep {exists $sqlGen->fields($_)->{'ui-datatype'}}
					$sqlGen->fields();
	my $noCriteria =
		join ", ",
			map {$sqlGen->comparisons($_)->{id} . " : 1"}
				grep {defined $sqlGen->comparisons($_)->{value} && $sqlGen->comparisons($_)->{value} eq ''}
					$sqlGen->comparisons();

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

		function onChangeDestination()
		{
			if (destObj = eval('document.all._f_out_destination'))
			{
				if (destObj.options[destObj.selectedIndex].text == 'Browser')
				{
					setIdStyle('_id_out_printer', 'display', 'none');
					setIdStyle('_id_out_email', 'display', 'none');
					setIdStyle('_id_out_format', 'display', 'block');
				}
				else if (destObj.options[destObj.selectedIndex].text == 'Printer')
				{
					alert ("Printer output is not yet supported. Output will still be sent to the browser.");
					setIdStyle('_id_out_printer', 'display', 'block');
					setIdStyle('_id_out_format', 'display', 'none');
					setIdStyle('_id_out_email', 'display', 'none');
				}
				else if (destObj.options[destObj.selectedIndex].text == 'E-Mail')
				{
					alert ("E-Mail output is not yet supported. Output will still be sent to the browser.");
					setIdStyle('_id_out_printer', 'display', 'none');
					setIdStyle('_id_out_format', 'display', 'block');
					setIdStyle('_id_out_email', 'display', 'block');
				}
			}
		}

		// Call it at startup to initially hide fields
		onChangeDestination();

		// -->
		</script>
	});

	return $self;
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	my $sqlGen = $self->{sqlGen};
	my $view = $self->{view};

	my @viewOutCols = map {$sqlGen->fields($_->{id})->{id}} @{$view->{columns}};
	#$page->addDebugStmt("outCols '@viewOutCols'");
	$page->field('out_columns', @viewOutCols) unless $page->field('out_columns');

	my @viewSortCols = map {$sqlGen->fields($_->{id})->{id}} @{$view->{'order-by'}};
	#$page->addDebugStmt("sortCols '@viewSortCols'");
	$page->field('out_sort', @viewSortCols) unless $page->field('out_sort');
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $sqlGen = $self->{sqlGen};
	my $view = $self->{view};
	my @outColumns = $page->field('out_columns');
	my @orderBy = $page->field('out_sort');
	my @groupBy = map {$_->{id}} @{$view->{'group-by'}};
	my $distinct = defined $view->{distinct} ? $view->{distinct} : 0;
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
			my @criteria = split /,\s*/, uc($criteria);
			@criteria = ('') unless @criteria;

			my $whereField = "UPPER({$field})";
			if ($sqlGen->fields($field) && defined $sqlGen->fields($field)->{'ui-datatype'})
			{
				my $dataType = $sqlGen->fields($field)->{'ui-datatype'};
				if ($dataType eq 'date')
				{
					$whereField = "TO_CHAR({$field}, 'MM/DD/YYYY')";
				}

			}
			push @andConditions, $sqlGen->WHERE($whereField, $comparison, @criteria);
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
	if (exists $view->{condition} && defined $view->{condition})
	{
		$condition = $condition ? $sqlGen->AND($view->{condition}, $condition) : $view->{condition};
	}

	# Check for special formatting field
	for my $i (0..$#outColumns)
	{
		my $fieldData = $sqlGen->fields($outColumns[$i]);
		my $dataFormat = defined $fieldData->{'ui-datatype'} ? $fieldData->{'ui-datatype'} : 'text';
		for ($dataFormat)
		{
			$_ eq 'text' && do {last;};
			$_ eq 'date' && do {$outColumns[$i] = "TO_CHAR({$outColumns[$i]}, 'MM/DD/YYYY')"; last;};
		}
	}

	# Generate the SQL & Bind Params
	my ($SQL, $bindParams) = $condition->genSQL(
		outColumns => \@outColumns,
		orderBy => \@orderBy,
		groupBy => \@groupBy,
		distinct => $distinct);

	# Wrap the SQL with an outer SQL to limit results
	if ($page->field('out_format') eq 'html')
	{
		my $cols = join ",\n", map {"\t$_"} @outColumns;
		$SQL = "SELECT * FROM (\n\nSELECT\n\trownum AS row#,\n$cols\nFROM (\n\n" . $SQL . "\n\n) WHERE rownum <= ?\n\n) WHERE row# > ?";
		push @{$bindParams}, ($endRow+1), $startRow;
	}

	# Do any variable replacements in the SQL itself
	$page->replaceVars(\$SQL);

	my $stmgrFlags = STMTMGRFLAG_DYNAMICSQL | STMTMGRFLAG_REPLACEVARS;
	my $stmtHdl;
	eval {
		$stmtHdl = $STMTMGR_ORG->execute($page, $stmgrFlags, $SQL, @$bindParams);
	};
	if ($@)
	{
		$page->addDebugStmt("$@");
		$page->addDebugStmt("<pre>$SQL</pre>");
		undef $@;
		return;
	}

	# Create the appropriate output destination container
	my $outDest = $page->field('out_destination');
	my $outFormat = $page->field('out_format');
	my $destRef;
	my $fileName;
	if ($outDest eq 'Printer')
	{
		$destRef = $page->{page_content};
	}
	elsif ($outDest eq 'E-Mail')
	{
		$destRef = $page->{page_content};
	}
	else # Browser by default
	{
		if ($outFormat ne 'html')
		{
			($destRef, $fileName) = tempfile('query_XXXXXX', DIR => $App::Configuration::CONFDATA_SERVER->path_temp, SUFFIX => ".$outFormat");
		}
		else
		{
			$destRef = $page->{page_content};
		}
	}

	# Call the appropriate output formatting function
	if (my $exSub = $self->can('format_' . $outFormat))
	{
		&$exSub($self, $page, $stmtHdl, $stmgrFlags, $destRef);
	}
	else
	{
		$self->format_html($page, $stmtHdl, $stmgrFlags, $destRef);
	}

	close $destRef if ref($destRef) eq 'GLOB';

	# Handle the output
	if ($fileName)
	{
		$fileName =~ s{.*/}{};
		$page->redirect('/temp/' . $fileName);
	}
	return '';
}


sub format_html
{
	my ($self, $page, $stmtHdl, $stmgrFlags, $destRef) = @_;
	my $sqlGen = $self->{sqlGen};
	my $view = $self->{view};
	my @outColumns = $page->field('out_columns');
	my $startRow = $page->field('start_row');
	$startRow = 0 unless $startRow;
	my $endRow = $startRow + SHOWROWS;

	# Create a Data::Publish format definition for the output results
	my $publDefn = {};
	prepareStatementColumns($page, $stmgrFlags, $stmtHdl, $publDefn);
	$publDefn->{bodyRowAttr} = {
		onMouseOver => q{this.style.cursor='hand';this.style.backgroundColor='#CCCCCC'},
		onMouseOut => q{this.style.cursor='default';this.style.backgroundColor='#FFFFFF'},
		onClick => q{alert('You selected #1#');},
	};
	if (defined $view->{href})
	{
		my $viewHref = $view->{href};
		$viewHref =~ s/\{(\w+)\}/join('',map {$1 eq $outColumns[$_] ? '#' . ($_+1) . '#' : ''} 0..$#outColumns)/eg;
		$publDefn->{bodyRowAttr}->{onClick} = qq{document.location = '$viewHref';};
	}
	$publDefn->{columnDefn} = [
		{
			head => '#',
			hint => "Query Result Number #0#",
			dataFmt => '<font color="NAVY">#&{?}#.</font>',
		},
	];
	foreach my $column (@outColumns)
	{
		my $colData = $sqlGen->fields($column);
		my $colFormat = {};

		my $head = $colData->{id};
		$head = $colData->{caption} if defined $colData->{caption};
		$colFormat->{head} = $head;

		if (defined $colData->{'ui-datatype'})
		{
			for ($colData->{'ui-datatype'})
			{
				$_ eq 'currency' && do {$colFormat->{dformat} = 'currency'; last;};
			}
		}

		push @{$publDefn->{columnDefn}}, $colFormat;
	}

	$page->addDebugStmt("<pre>" . Dumper($publDefn) . "</pre>") if $page->param('_debug_dpub') == 1;


	my $resultHtml = createHtmlFromStatement($page, $stmgrFlags, $stmtHdl, $publDefn, {maxRows => SHOWROWS}); #stmtId => $SQL,
	my $nextPageExists = $stmtHdl->fetch();
	$stmtHdl->finish();

	# Add the results table to the page
	$page->addContent('<br><div align="center">' . $resultHtml . '</div>');

	# Add page controls below the results
	my $pageControlHtml = '<style>input.pagecontrol { font-size: 8pt; width: 75; font-family: Tahoma, Ariel, Helvetica; }</style><br><center>';
	$pageControlHtml .= qq{<input type="button" class="pagecontrol" value="First Page" onClick="validateOnSubmit(document.forms.dialog);changePage(-999)">&nbsp;&nbsp;} if $startRow >= (2 * SHOWROWS);
	$pageControlHtml .= qq{<input type="button" class="pagecontrol" value="Prev Page" onClick="validateOnSubmit(document.forms.dialog);changePage(-1)">} unless $startRow == 0;
	if (defined $nextPageExists)
	{
		$pageControlHtml .= '&nbsp;&nbsp' if $startRow > 0;
		$pageControlHtml .= qq{<input type="button" class="pagecontrol" value="Next Page" onClick="validateOnSubmit(document.forms.dialog);changePage(1)">};
	}
	$pageControlHtml .= '</center><br><br>';
	$page->addContent($pageControlHtml);

	return '';
}


sub format_csv
{
	my ($self, $page, $stmtHdl, $stmgrFlags, $destRef) = @_;
	my $sqlGen = $self->{sqlGen};
	my $view = $self->{view};
	my $outColumns = [];

	foreach my $column (@{$view->{columns}})
	{
		my $fieldData = $sqlGen->fields($column->{id});
		my $id = $column->{id};
		$id = $fieldData->{caption} if defined $fieldData->{caption};
		$id = $column->{caption} if defined $column->{caption};
		push @$outColumns, $id;
	}

	my $didHeader = 0;
	my $csvObj = new Text::CSV;
	my $row;
	while(!$didHeader || ($row = $stmtHdl->fetch()))
	{
		unless ($didHeader)
		{
			$row = $outColumns;
			$didHeader = 1;
		}
		die "Failed to generate csv of @{$row}" unless $csvObj->combine(@{$row}[0..$#{$row}]);
		$self->addDataToDest($destRef, $csvObj->string() . "\n");
	}
}


sub format_xml
{
	my ($self, $page, $stmtHdl, $stmgrFlags, $destRef) = @_;
	my $sqlGen = $self->{sqlGen};
	my $view = $self->{view};
	my $outColumns = [ map {$sqlGen->fields($_->{id})->{id}} @{$view->{columns}} ];

	$self->addDataToDest($destRef, "<results>\n");
	my $row;
	my $rownum = 0;
	while($row = $stmtHdl->fetch())
	{
		$rownum++;
		my $xml = qq{\t<result rownum="$rownum">\n};
		foreach my $i (0..$#{$row})
		{
			next unless defined $row->[$i];
			$xml .= "\t\t<$outColumns->[$i]>$row->[$i]</$outColumns->[$i]>\n";
		}
		$xml .= "\t</result>\n";
		$self->addDataToDest($destRef, $xml);
	}
	$self->addDataToDest($destRef, "</results>\n");
}


sub addDataToDest
{
	my ($self, $destRef, $data) = @_;
	for (ref($destRef))
	{
		$_ eq 'GLOB' && do {print $destRef $data; last};
		$_ eq 'ARRAY' && do {push @{$destRef}, $data; last};
		$_ eq 'SCALAR' && do {$$destRef .= $data; last};
		die "I don't know how to deal with output to a $_";
	}
}

1;
