##############################################################################
package App::Page::Search::CPT;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Code;
use Devel::ChangeLog;

use vars qw(@ISA  @CHANGELOG);
@ISA = qw(App::Page::Search);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->setFlag(App::Page::PAGEFLAG_ISPOPUP) if $rsrc eq 'lookup';
	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
}

sub getForm
{
	my ($self, $flags) = @_;
	my $search_type = $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP) ? "code" : $self->param('search_type') || "nameordescr";
	#my $search_compare = $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP) ? "is" : $self->param('search_compare');
	my $search_compare = $self->param('search_compare');

	return ('Lookup CPT-4 code/description', qq{
		<CENTER>
		<NOBR>
		<select name="search_type">
			<option value="code">Code</option>
			<option value="name">Name</option>
			<option value="description">Description</option>
			<option value="nameordescr">Name or Description</option>
		</select>
		<select name="search_compare">
			<option value="contains">contains</option>
			<option value="is">is</option>
		</select>
		<input name="search_expression" value="@{[$self->param('search_expression')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		</CENTER>
		<script>
			setSelectedValue(document.search_form.search_type, '$search_type');
			setSelectedValue(document.search_form.search_compare, '$search_compare');
		</script>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	return 1 unless $expression;
	#return $self->execute_detail($expression) if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	# oracle likes '%' instead of wildcard '*'
	my $appendStmtName = '';
	if($expression =~ s/\*/%/g)
	{
		$appendStmtName = '_like';
	}
	elsif($self->param('search_compare') eq 'contains')
	{
		$expression = "\%$expression\%";
		$appendStmtName = '_like';
	}

	my $bindParams = [uc($expression)];
	push(@$bindParams, uc($expression)) if $type eq 'nameordescr';


	$self->addContent(
		'<CENTER>',
		$STMTMGR_CPT_CODE_SEARCH->createHtml
			($self, STMTMGRFLAG_NONE, "sel_cpt_$type$appendStmtName", $bindParams,),
		'</CENTER>'
	);

	return 1;
}

sub execute_detail
{
	my ($self, $expression) = @_;
	my $cptHash = $STMTMGR_CPT_CODE_SEARCH->getRowAsHash($self, STMTMGRFLAG_NONE, "sel_detail_cpt", $expression);

	unless ($cptHash)
	{
		$self->addContent('<CENTER> No records found. </CENTER>');
		return 1;
	}

	my $compoundsHtml;
	my @compounds = split(/,/, $cptHash->{comprehensive_compound_cpts});
	for (@compounds)
	{
		$compoundsHtml .= qq{
			<a HREF="javascript:chooseItem2('/lookup/cpt/detail/$_', $_, true)"> $_ </a>
		};
	}

	my $mutualsHtml;
	my @mutuals = split(/,/, $cptHash->{mutual_exclusive_cpts});
	for (@mutuals)
	{
		$mutualsHtml .= qq{
			<a HREF="javascript:chooseItem2('/lookup/cpt/detail/$_', $_, true)"> $_ </a>
		};
	}

	my $details = qq{
		<style>
			a { text-decoration: none; }
			a { color: blue; }
			a:hover { color: red; }
			td { font-size: 8pt; font-family: Verdana }
			td.bold { font-size: 8pt; font-family: Tahoma; font-weight: bold; color: darkblue}
		</style>

		<table>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Code</td>
				<td>$cptHash->{cpt}</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Name</td>
				<td>$cptHash->{name}</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Description</td>
				<td>$cptHash->{description}</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Comprehensive/Compound CPTs</td>
				<td>$compoundsHtml</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Mutually Exclusive CPTs</td>
				<td>$mutualsHtml</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Sex</td>
				<td>$cptHash->{sex}</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Unlisted</td>
				<td>$cptHash->{unlisted}</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Questionable</td>
				<td>$cptHash->{questionable}</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Non-Rep</td>
				<td>$cptHash->{non_rep}</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>ASC</td>
				<td>$cptHash->{asc_}</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Non-Rep</td>
				<td>$cptHash->{non_rep}</td>
			</tr>
			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Non-Covered</td>
				<td>$cptHash->{non_cov}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
		</table>
	};

	$self->addContent(
		'<CENTER>',
		$details,
		'</CENTER>'
	);

	return 1;
}

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/05/2000', 'TVN',
			'Search/CPT',
		'Completed Detailed CPT Search.'],
);


1;
