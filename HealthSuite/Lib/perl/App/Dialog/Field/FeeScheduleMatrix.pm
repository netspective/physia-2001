##############################################################################
package App::Dialog::Field::FeeScheduleMatrix;
##############################################################################

use strict;
use Carp;
use CGI::Validator;
use CGI::Validator::Field;
use CGI::Dialog;
use DBI::StatementManager;

use App::Statements::Person;
use App::Statements::Catalog;
use App::Universal;

use Date::Manip;
use Date::Calc qw(:all);

use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	$params{name} = 'feescheduleentries' unless exists $params{name};
	
	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	return 1;
}


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	my $errorMsgsHtml = '';
	my $bgColorAttr = '';
	my $spacerHtml = '&nbsp;';
	my $linesHtml = '';
	my $headingsHtml = '';
	my $textFontAttrs = 'SIZE=1 FACE="Tahoma,Arial,Helvetica" STYLE="font-family:tahoma; font-size:8pt"';
	my $textFontAttrsForTotalBalRow = 'SIZE=2 FACE="Tahoma,Arial,Helvetica" STYLE="font-family:tahoma; font-size:10pt"';

	my $cpts = $page->param('_f_cpts');
	my $feeschedules = $page->param('_f_fs');

	if(my @messages = $page->validationMessages($self->{name}))
	{
		$spacerHtml = '<img src="/resources/icons/arrow_right_red.gif" border=0>';
		$bgColorAttr = "bgcolor='$dialog->{errorBgColor}'";
		$errorMsgsHtml = "<br><font $dialog->{bodyFontErrorAttrs}>" . join("<br>", @messages) . "</font>";
	}

	my ($dialogName) = ($dialog->formName());
	
#	$page->addDebugStmt("cpts are $cpts, feeschedules are $feeschedules");
	
	my @allcpts = split(/\s*,\s*/, $cpts);
	my @allfeeschedules = split(/\s*,\s*/, $feeschedules);
	
#	$page->addDebugStmt("allcpts are @allcpts, $allcpts[0]");
	my $totalFeeSchedules = @allfeeschedules;
	my $totalCpts = @allcpts;
#	$page->addDebugStmt("feeschedules are $totalFeeSchedules, $totalCpts, @allfeeschedules");

        for(my $headingline = 0; $headingline < $totalFeeSchedules; $headingline++)
        {
                $headingsHtml .= qq{
                                    <TD ALIGN=CENTER><FONT $textFontAttrs>$allfeeschedules[$headingline]</FONT></TD>
                                   };

	}

	for(my $line = 0; $line < $totalCpts; $line++)
	{
		if($allcpts[$line] =~ '-')
		{
			my @cptRange = split(/-/, $allcpts[$line]);
			for(my $rangeincrement = $cptRange[0]; $rangeincrement <= $cptRange[1]; $rangeincrement++)
				{
				my $cptRangeData = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $rangeincrement);
				$linesHtml .= qq{
						<TR VALIGN=TOP>
						<TD ALIGN=RIGHT><FONT $textFontAttrs COLOR="#333333"/><B>$rangeincrement ($cptRangeData->{name})</B></FONT></TD>
						};
				for(my $rangecol = 0; $rangecol < $totalFeeSchedules; $rangecol++)
					{
						$linesHtml .= qq{						
								<TD><INPUT CLASS='fsinput' NAME='_f_amount_$rangeincrement\_$rangecol\_payment' TYPE='text' SIZE=10 VALUE='@{[ $page->param("_f_amount_$rangeincrement\_$rangecol\_payment") ]}' ONBLUR="validateChange_Float(event)"></TD>
								};
					}

				}
			$linesHtml .= qq{
				</TR>
				};
				
		}                                   
                else
                {
			my $cptData = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $allcpts[$line]);
			$linesHtml .= qq{
					<TR VALIGN=TOP>
					<TD ALIGN=RIGHT><FONT $textFontAttrs COLOR="#333333"/><B>$allcpts[$line] ($cptData->{name})</B></FONT></TD>
					};
			for(my $col = 0; $col < $totalFeeSchedules; $col++)
			{
				$linesHtml .= qq{
						<TD><INPUT CLASS='fsinput' NAME='_f_amount_$line\_$col\_payment' TYPE='text' SIZE=10 VALUE='@{[ $page->param("_f_amount_$line\_$col\_payment") ]}' ONBLUR="validateChange_Float(event)"></TD>
						};
			}
			$linesHtml .= qq{
				</TR>
				};
		}
	
	}
	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD>
				<TABLE CELLSPACING=0 CELLPADDING=2>
                                        <INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$totalCpts"/>
                                        <INPUT TYPE="HIDDEN" NAME="_f_col_count" VALUE="$totalFeeSchedules"/>
                                        <INPUT TYPE="HIDDEN" NAME="_f_cpts" VALUE="$cpts"/>
                                        <INPUT TYPE="HIDDEN" NAME="_f_feeschedules" VALUE="$feeschedules"/>
                                        
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
                                                <TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						$headingsHtml
					</TR>
					$linesHtml
				</TABLE>
			</TD>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

1;
