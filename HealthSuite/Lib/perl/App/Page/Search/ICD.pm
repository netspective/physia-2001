##############################################################################
package App::Page::Search::ICD;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Code;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/icd' => {},
	'search/80' => {},
	);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->setFlag(App::Page::PAGEFLAG_ISPOPUP) if $rsrc eq 'lookup';
	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
}

sub getForm
{
	my ($self, $flags) = @_;
	
	my $search_type = $self->param('search_type') || "description";
	#my $search_type = $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP) ? "code" : $self->param('search_type') || "description";
	#my $search_compare = $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP) ? "is" : $self->param('search_compare');
	my $search_compare = $self->param('search_compare');

	return ('Lookup an ICD-9 code/description', qq{
		<CENTER>
		<NOBR>
		<select name="search_type">
			<option value="code">Code</option>
			<option value="description">Description</option>
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

	$self->addContent(
		'<CENTER>',
		$STMTMGR_CATALOG_CODE_SEARCH->createHtml($self, STMTMGRFLAG_NONE, "sel_icd_$type$appendStmtName", $bindParams,),
		'</CENTER>'
	);

	return 1;
}

sub execute_detail
{
	my ($self, $expression) = @_;
	my $icdHash = $STMTMGR_CATALOG_CODE_SEARCH->getRowAsHash($self, STMTMGRFLAG_NONE, "sel_detail_icd", $expression);

	unless ($icdHash)
	{
		$self->addContent('<CENTER> No records found. </CENTER>');
		return 1;
	}

	my $cptsHtml;
	my @cpts = split(/,/, $icdHash->{cpts_allowed});
	for (@cpts)
	{
		$cptsHtml .= qq{
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
				<td>$icdHash->{icd}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Description</td>
				<td>$icdHash->{descr}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Sex</td>
				<td>$icdHash->{sex}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Age</td>
				<td>$icdHash->{age}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>CPTs Allowed</td>
				<td>$cptsHtml</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Major Diagnosis Category</td>
				<td>$icdHash->{major_diag_category}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Comorbidity/Complication</td>
				<td>$icdHash->{comorbidity_complication}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Medicare Secondary Payer</td>
				<td>$icdHash->{medicare_secondary_payer}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Manifestation Code</td>
				<td>$icdHash->{manifestation_code}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Questionable Admission</td>
				<td>$icdHash->{questionable_admission}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Unacceptable Primary Diag Without</td>
				<td>$icdHash->{unacceptable_primary_wo}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Unacceptable Principal</td>
				<td>$icdHash->{unacceptable_principal}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Unacceptable Procedure</td>
				<td>$icdHash->{unacceptable_procedure}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Non-Specific Procedure</td>
				<td>$icdHash->{non_specific_procedure}</td>
			</tr>

			<TR><TD COLSPAN=2><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>
			<tr>
				<td class='bold' valign=top>Non-Covered Procedure</td>
				<td>$icdHash->{non_covered_procedure}</td>
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

1;
