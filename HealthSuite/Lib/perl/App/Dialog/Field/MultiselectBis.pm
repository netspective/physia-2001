##############################################################################
package App::Dialog::Field::MultiselectBis;
##############################################################################

use strict;
use Carp;
use CGI::Validator;
use CGI::Validator::Field;
use CGI::Dialog;
use DBI::StatementManager;

use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Catalog;
use App::Statements::Insurance;
use App::Universal;

use Date::Manip;
use Date::Calc qw(:all);

use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	# Validate parameters
	if (exists $params{fKeyStmtMgr})
	{
		die 'If using the fKeyStmtMgr parameter, the fKeyStmt parameter is also required.' unless $params{fKeyStmt};
		die 'If using the fKeyStmtMgr parameter, the fKeyStmtSelected parameter is also required.' unless $params{fKeyStmtSelected};
		if (exists $params{fKeyStmtParams} || exists $params{fKeyStmtParamsSelect})
		{
			die 'The fKeyStmtColNameValue parameter is required.' unless $params{fKeyStmtColNameValue};
			die 'The fKeyStmtColNameCaption parameter is required.' unless $params{fKeyStmtColNameCaption};
		}
	}

	# Set defaults
	$params{style} = 'multidual' unless exists $params{name};
	$params{caption} = '' unless exists $params{caption};
	$params{selectSize} = 8 unless exists $params{selectSize};
	$params{selectWidth} = 150 unless exists $params{selectWidth};
	$params{selectCaptionLeft} = '' unless exists $params{selectCaptionLeft};
	$params{selectCaptionRight} = '' unless exists $params{selectCaptionRight};
	$params{multiselectSortOnMove} = 'true' unless exists $params{multiselectSortOnMove};

	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	return 1;
}

sub isValid
{
	return 1;
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	
	my $list;
	my $selectOptions = '';
	my $listSelected;
	my $selectOptionsSelected = '';

	if (exists $self->{fKeyStmt}) 
	{
		if (exists $self->{fKeyStmtParams}) 
		{
			$list = $self->{fKeyStmtMgr}->getRowsAsHashList($page, STMTMGRFLAG_NONE, $self->{fKeyStmt}, @{$self->{fKeyStmtParams}} );
			if (exists $self->{fKeyStmtSelected})
			{
				$listSelected = $self->{fKeyStmtMgr}->getRowsAsHashList($page, STMTMGRFLAG_NONE, $self->{fKeyStmtSelected}, @{$self->{fKeyStmtParamsSelect}} );
			}
		}
		else 
		{
			$list = $self->{fKeyStmtMgr}->getRowsAsHashList($page, STMTMGRFLAG_NONE, $self->{fKeyStmt});
			if (exists $self->{fKeyStmtSelected})
			{
				$listSelected = $self->{fKeyStmtMgr}->getRowsAsHashList($page, STMTMGRFLAG_NONE, $self->{fKeyStmtSelected});
			}
		}

		for (@$list) 
		{
			$selectOptions .= "<OPTION VALUE=\"$_->{$self->{fKeyStmtColNameValue}}\">$_->{$self->{fKeyStmtColNameCaption}}</OPTION>";
		}
		#if ($listSelected) 
		#{
			for (@$listSelected) 
			{
				$selectOptionsSelected .= "<OPTION VALUE=\"$_->{$self->{fKeyStmtColNameValue}}\">$_->{$self->{fKeyStmtColNameCaption}}</OPTION>";
			}
		#}
	}

	return qq {
		<TR valign=top>
		<TD ALIGN=left COLSPAN=4>
			<TABLE CELLSPACING=0 CELLPADDING=1 ALIGN=left BORDER=0>
			<TR>
			<TD ALIGN=left colspan=3><FONT SIZE=2>$self->{caption}</FONT></TD>
			</TR>
			<TR>
			<TD ALIGN=left><FONT SIZE=2>$self->{selectCaptionLeft}</FONT></TD><TD></TD>
			<TD ALIGN=left><FONT SIZE=2>$self->{selectCaptionRight}</FONT></TD>
			</TR>
			<TR>
			<TD ALIGN=left VALIGN=top>
				<SELECT ondblclick="MoveSelectItems('Dialog', '$self->{name}_From', '_f_$self->{name}', $self->{multiselectSortOnMove})" NAME=$self->{name}_From SIZE=$self->{selectSize} MULTIPLE STYLE="width: $self->{selectWidth}pt">
				$selectOptions
				</SELECT>
			</TD>
			<TD ALIGN=center VALIGN=middle>
				&nbsp;<INPUT TYPE=button NAME="$self->{name}_addBtn" onClick="MoveSelectItems('Dialog', '$self->{name}_From', '_f_$self->{name}', $self->{multiselectSortOnMove})" VALUE=" > ">&nbsp;<BR CLEAR=both>
				&nbsp;<INPUT TYPE=button NAME="$self->{name}_removeBtn" onClick="MoveSelectItems('Dialog', '_f_$self->{name}', '$self->{name}_From', $self->{multiselectSortOnMove})" VALUE=" < ">&nbsp;
			</TD>
			<TD ALIGN=left VALIGN=top>
				<SELECT ondblclick="MoveSelectItems('Dialog', '_f_$self->{name}', '$self->{name}_From', $self->{multiselectSortOnMove})" NAME=_f_$self->{name} SIZE=$self->{selectSize} MULTIPLE STYLE="width: $self->{selectWidth}pt">
				$selectOptionsSelected
				</SELECT>
			</TD>
			</TR>
			</TABLE>
		</TD>
		</TR>
	};
}

1;
