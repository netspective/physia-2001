##############################################################################
package App::Page::Search::Catalog;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Catalog;
use Data::Publish;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/catalog' => {},
	);

sub getForm
{
	my ($self, $flags) = @_;

	my $view = $self->param('search_type') eq 'detail' || $self->param('search_type') eq 'detailname' ? 'offering_catalog_entry ' : 'offering_catalog';
	my $catalogId = $view eq 'offering_catalog_entry' ? $self->param('search_expression') : undef;

	my $dialogARL = $catalogId eq '' ? '/org/#session.org_id#/dlg-add-catalog' : '/org/#session.org_id#/dlg-add-catalog-item' . $catalogId;
	my $heading = $catalogId eq '' ?  'Lookup a fee schedule' : "Lookup a fee schedule item for '$catalogId'";	
	return ($heading, qq{
		<CENTER>
		<NOBR>
		<select name="search_type" style="color: darkred">
			<option value="id">ID</option>
			<option value="name">Name</option>
			<option value="description">Description</option>
			<option value="nameordescr" selected>Name or Description</option>
		</select>
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		@{[ $flags & SEARCHFLAG_LOOKUPWINDOW ? '' : " | <a href=$dialogARL>Add New Fee Schedule</a>" ]}
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_type, '@{[ $self->param('search_type') || 0 ]}');
		</script>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	# oracle likes '%' instead of wildcard '*'
	my $appendStmtName = $expression =~ s/\*/%/g ? '_like' : '';
	my $bindParams = [$self->session('org_internal_id') || $self->session('org_internal_id'), uc($expression)];
	push(@$bindParams, uc($expression)) if $type eq 'nameordescr';
	$self->addContent(
		'<CENTER>',
			#$STMTMGR_CATALOG_SEARCH->createHierHtml($self, STMTMGRFLAG_NONE,
			#	["sel_catalog_$type$appendStmtName", 5, 4], $bindParams,),
			$STMTMGR_CATALOG_SEARCH->createHtml($self, STMTMGRFLAG_NONE,
				"sel_catalog_$type$appendStmtName", $bindParams),
		'</CENTER>'
	);

	return 1;
}




sub execute_detail
{
	my ($self, $expression) = @_;

	$self->addContent(
		'<CENTER>',
			#$STMTMGR_CATALOG_SEARCH->createHierHtml($self, STMTMGRFLAG_NONE,
			#	['sel_catalog_detail', 0, 8],	[uc($expression)],
			$STMTMGR_CATALOG_SEARCH->createHtml($self, STMTMGRFLAG_NONE,
				'sel_catalog_detail',	[uc($expression)],
		),
		'</CENTER>'
	);

	return 1;
}

#This one will bring back the name instead of the numeric for fee schedules
sub execute_detailname
{
	my ($self, $expression) = @_;

	$self->addContent(
		'<CENTER>',
			#$STMTMGR_CATALOG_SEARCH->createHierHtml($self, STMTMGRFLAG_NONE,
			#	['sel_catalog_detail', 0, 8],	[uc($expression)],
			$STMTMGR_CATALOG_SEARCH->createHtml($self, STMTMGRFLAG_NONE,
				'sel_catalog_detail_name',[$self->session('org_internal_id'),uc($expression)],
		),
		'</CENTER>'
	);

	return 1;
}


1;
