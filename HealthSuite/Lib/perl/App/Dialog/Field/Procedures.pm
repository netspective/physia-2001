##############################################################################
package App::Dialog::Field::Procedures;
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
use App::Universal;

use Date::Manip;
use Date::Calc qw(:all);

use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	$params{name} = 'procedures_list' unless exists $params{name};
	$params{type} = 'procedures';
	$params{lineCount} = 4 unless exists $params{count};
	$params{allowComments} = 1 unless exists $params{allowComments};

	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	return 1;
}

sub isValid
{
	my ($self, $page, $validator, $valFlags) = @_;

	my $sessUser = $page->session('user_id');
	my $sessOrg = $page->session('org_id');

	my $personId = $page->field('attendee_id');
	my $personInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $personId);
	my $gender = '';
	$gender = 'M' if $personInfo->{gender_caption} eq 'Male';
	$gender = 'F' if $personInfo->{gender_caption} eq 'Female';
	my $dateOfBirth = $personInfo->{date_of_birth};

	my $servicedatebegin = '';
	my $servicedateend = '';
	#my $serviceplace = '';
	my $servicetype = '';
	my $procedure = '';
	my $modifier = '';
	my $diags = '';
	my $units = '';
	my $charges = '';
	my $emergency = '';
	my %diagsSeen = ();
	my @feeSchedules = $page->param('_f_proc_default_catalog');

	my @diagCodes = split(/\s*,\s*/, $page->field('proc_diags'));

	#munir's old icd validation for checking if the same icd code is entered in twice
	foreach (@diagCodes)
	{
		$diagsSeen{$_} = 1;
	}

	my $totalCodesEntered = @diagCodes;
	my $listTotal = keys %diagsSeen;

	if($totalCodesEntered != $listTotal)
	{
		$self->invalidate($page, 'Cannot enter the same ICD code more than once.');
	}

	my @procs = ();
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		$servicedatebegin = $page->param("_f_proc_$line\_dos_begin");
		$servicedateend = $page->param("_f_proc_$line\_dos_end");
		#$serviceplace = $page->param("_f_proc_$line\_service_place");
		$servicetype = $page->param("_f_proc_$line\_service_type");
		$procedure = $page->param("_f_proc_$line\_procedure");
		$modifier = $page->param("_f_proc_$line\_modifier");
		$diags = $page->param("_f_proc_$line\_diags");
		$units = $page->param("_f_proc_$line\_units");
		$charges = $page->param("_f_proc_$line\_charges");
		$emergency = $page->param("_f_proc_$line\_emg");

		#$page->addDebugStmt("Detail dates: $servicedatebegin, $servicedateend, $servicetype, $procedure, emg is $emergency, charges are $charges");

		next if $servicedatebegin eq 'From' && $servicedateend eq 'To';
		next if $servicedatebegin eq '' && $servicedateend eq '';

		if($servicedatebegin !~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/)
		{
			$self->invalidate($page, "[<B>P$line</B>] Invalid Service Begin Date: $servicedatebegin");
		}
		if($servicedateend !~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/)
		{
			$self->invalidate($page, "[<B>P$line</B>] Invalid Service End Date: $servicedateend ");
		}
		#comparing the begin and end date to see if the begin date is less than the end date
		if ($servicedatebegin =~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/ && $servicedateend =~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/)
		{
			my $serviceBeginDate = ParseDate($servicedatebegin);
			my $serviceEndDate = ParseDate($servicedateend);
			my $flag = Date_Cmp($serviceBeginDate,$serviceEndDate);

			if($flag > 0)
			{
				# date2 is earlier
				$self->invalidate($page, "[<B>P$line</B>] Service begin date $servicedatebegin should be earlier than the end date $servicedateend");
			}
		}
		#if($serviceplace =~ m/^(\d+)$/)
		#{
		#	# $1 is the check to see if it is an integer
		#	if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericServicePlaceId', $1)))
		#	{
		#		$self->invalidate($page, "[<B>P$line</B>] The service place code $serviceplace is not valid. Please verify");
		#	}
		#}
		#elsif($serviceplace !~ m/^(\d+)$/)
		#{
		#	$self->invalidate($page, "[<B>P$line</B>] The service place code $serviceplace should be an integer. Please verify");
		#}
		if($servicetype =~ m/^(\d+)$/)
		{
			# $1 is the check to see if it is an integer
			if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericServiceTypeId', $1)))
			{
				$self->invalidate($page, "[<B>P$line</B>] The service type code $servicetype is not valid. Please verify");
			}
		}
		elsif($servicetype !~ m/^(\d+)$/)
		{
			$self->invalidate($page, "[<B>P$line</B>] The service type code $servicetype should be an integer. Please verify");
		}
		if($procedure =~ m/^(\d+)$/)
		{
			# $1 is the check to see if it is an integer
			if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericCPTCode', $1)))
			{
				#$self->invalidate($page, "[<B>P$line</B>] The CPT code $procedure is not valid. Please verify");
			}
		}
		elsif($procedure !~ m/^(\d+)$/)
		{
			$self->invalidate($page, "[<B>P$line</B>] The CPT code was not found.");
		}
		if($modifier ne '')
		{
			if($modifier =~ m/^(\d+)$/)
		 	{
				# $1 is the check to see if it is an integer
				$self->invalidate($page, "[<B>P$line</B>] The modifier code $modifier is not valid. Please verify") unless $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericModifierCodeId', $1);
			}
		 	else
		 	{
				$self->invalidate($page, "[<B>P$line</B>] The modifier code $modifier should be an integer. Please verify");
		 	}
		}

		my @actualDiagCodes = ();
		if($diags ne '')
		{
			my @diagNumbers = split(/\s*,\s*/, $diags);
			foreach my $diagNumber (@diagNumbers)
			{
				if($diagNumber !~ /^(\d+)$/)
				{
					$self->invalidate($page, "[<B>P$line</B>] The diagnosis $diagNumber should be integer. Please verify");
				}
				elsif(($diagNumber > $totalCodesEntered) || ($diagNumber == 0))
				{
					$self->invalidate($page, "[<B>P$line</B>] The diagnosis $diagNumber is not valid. Please verify");
				}

				push(@actualDiagCodes, $diagCodes[$diagNumber-1]);
			}

			@actualDiagCodes = join(', ', @actualDiagCodes);
			$page->param("_f_proc_$line\_actual_diags", @actualDiagCodes);
		}
		elsif($diags eq '')
		{
			$self->invalidate($page, "[<B>P$line</B>] The diagnosis relationships are not valid. Please verify");
		}

		if($units !~ /^(\d+\.?\d*|\.\d+)$/)
		{
			$self->invalidate($page, "[<B>P$line</B>] The dollar amount $units is not valid. Please verify");
		}
		if($charges ne '' && $charges !~ /^(\d+\.?\d*|\.\d+)$/)
		{
			$self->invalidate($page, "[<B>P$line</B>] The dollar amount $charges is not valid. Please verify");
		}

		#for intellicode
		push(@procs, [$procedure, $modifier || undef, @actualDiagCodes]);
		my @cptCodes = ($procedure);

		#App::IntelliCode::getItemCost($page, $procedure, \@feeSchedules);
		#App::IntelliCode::incrementUsage($page, 'Cpt', \@cptCodes, $sessUser, $sessOrg);
		#App::IntelliCode::incrementUsage($page, 'Icd', \@diagCodes, $sessUser, $sessOrg);
	}

	my @errors = App::IntelliCode::validateCodes
		(
	#		$page, 0,
	#		sex => $gender,
	#		dateOfBirth => $dateOfBirth,
	#		diags => \@diagCodes,
	#		procs => \@procs,
		);

	#foreach (@errors)
	#{
	#	$self->invalidate($page, $_);
	#}

	return @errors || $page->haveValidationErrors() ? 0 : 1;
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	my $errorMsgsHtml = '';
	my $bgColorAttr = '';
	my $spacerHtml = '&nbsp;';
	my $textFontAttrs = 'SIZE=1 FACE="Tahoma,Arial,Helvetica" STYLE="font-family:tahoma; font-size:8pt"';

	#get service place code from service facility org
	my $svcFacility = $page->field('service_facility_id') || $page->session('org_id');
	my $svcPlaceCode = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $svcFacility, 'HCFA Service Place');

	if(my @messages = $page->validationMessages($self->{name}))
	{
		$spacerHtml = '<img src="/resources/icons/arrow_right_red.gif" border=0>';
		$bgColorAttr = "bgcolor='$dialog->{errorBgColor}'";
		$errorMsgsHtml = "<br><font $dialog->{bodyFontErrorAttrs}>" . join("<br>", @messages) . "</font>";
	}

	my ($dialogName, $lineCount, $allowComments, $allowRemove) = ($dialog->formName(), $self->{lineCount}, $self->{allowComments}, $dlgFlags & CGI::Dialog::DLGFLAG_UPDATE);
	my ($linesHtml, $numCellRowSpan, $removeChkbox) = ('', $allowComments ? 'ROWSPAN=2' : '', '');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		$removeChkbox = $allowRemove ? qq{<TD ALIGN=CENTER $numCellRowSpan><INPUT TYPE="CHECKBOX" NAME='_f_proc_$line\_remove'></TD>} : '';
		$linesHtml .= qq{
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_item_id" VALUE='@{[ $page->param("_f_proc_$line\_item_id")]}'/>
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_actual_diags" VALUE='@{[ $page->param("_f_proc_$line\_actual_diags")]}'/>
			<TR VALIGN=TOP>
				<SCRIPT>
					function onChange_dosBegin_$line(event, flags)
					{
						if(event.srcElement.value == 'From')
							event.srcElement.value = '0';
						event.srcElement.value = validateDate(event.srcElement.name, event.srcElement.value);
						if(document.$dialogName._f_proc_$line\_dos_end.value == '' || document.$dialogName._f_proc_$line\_dos_end.value == 'To')
							document.$dialogName._f_proc_$line\_dos_end.value = event.srcElement.value;
						if(event.srcElement.value != '')
						{
							if(document.$dialogName._f_proc_$line\_service_type.value == '')
								document.$dialogName._f_proc_$line\_service_type.value = '01';
							if(document.$dialogName._f_proc_$line\_units.value == '')
								document.$dialogName._f_proc_$line\_units.value = 1;
						}
					}
					function onChange_procedure_$line(event, flags)
					{
						if(document.$dialogName._f_proc_$line\_modifier.value == 'Modf')
							document.$dialogName._f_proc_$line\_modifier.value = '';
					}
				</SCRIPT>
				<TD ALIGN=RIGHT $numCellRowSpan><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				$removeChkbox
				<TD><INPUT CLASS='procinput' NAME='_f_proc_$line\_dos_begin' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_dos_begin") || ($line == 1 ? 'From' : '')]}' ONBLUR="onChange_dosBegin_$line(event)"><BR>
					<INPUT CLASS='procinput' NAME='_f_proc_$line\_dos_end' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_dos_end") || ($line == 1 ? 'To' : '') ]}' ONBLUR="validateChange_Date(event)"></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><NOBR><INPUT CLASS='procinput' NAME='_f_proc_$line\_service_type' TYPE='text' VALUE='@{[ $page->param("_f_proc_$line\_service_type") ]}' size=2><A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_$line\_service_type, '/lookup/servicetype', '');"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><NOBR><INPUT CLASS='procinput' NAME='_f_proc_$line\_procedure' TYPE='text' size=8 VALUE='@{[ $page->param("_f_proc_$line\_procedure") || ($line == 1 ? 'Procedure' : '') ]}' ONBLUR="onChange_procedure_$line(event)"><A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_$line\_cpt, '/lookup/cpt', '');"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR><BR>
					<INPUT CLASS='procinput' NAME='_f_proc_$line\_modifier' TYPE='text' size=4 VALUE='@{[ $page->param("_f_proc_$line\_modifier") || ($line == 1 && $command eq 'add' ? '' : '') ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT CLASS='procinput' NAME='_f_proc_$line\_diags' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_diags")]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT CLASS='procinput' NAME='_f_proc_$line\_units' TYPE='text' size=3 VALUE='@{[ $page->param("_f_proc_$line\_units") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT CLASS='procinput' NAME='_f_proc_$line\_charges' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_charges") ]}'></TD>
				<TD><nobr><INPUT CLASS='procinput' NAME='_f_proc_$line\_emg' TYPE='CHECKBOX' @{[ ($page->param("_f_proc_$line\_emg") eq 'on' ? 'checked' : '' ) ]}> <FONT $textFontAttrs/>Emergency</FONT></nobr>
				</TD>
			</TR>
		};
		$linesHtml .= qq{
			<TR>
				<TD COLSPAN=4 ALIGN=RIGHT><FONT $textFontAttrs><I>Comments:</I></FONT></TD>
				<TD COLSPAN=8><INPUT CLASS='procinput' NAME='_f_proc_$line\_comments' TYPE='text' size=50 VALUE='@{[ $page->param("_f_proc_$line\_comments") ]}'></TD>
			</TR>
		} if $allowComments;
	}

	my $removeHd = $allowRemove ? qq{<TD ALIGN=CENTER><FONT $textFontAttrs><IMG SRC="/resources/icons/action-edit-remove-x.gif"></FONT></TD>} : '';
	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD COLSPAN=2>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD><FONT $textFontAttrs>Diagnoses (ICD-9s)</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><FONT $textFontAttrs>Service Place</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><FONT $textFontAttrs>Default Fee Schedule(s)</FONT></TD>
					</TR>
					<TR VALIGN=TOP>
						<TD><NOBR><INPUT TYPE="TEXT" SIZE=20 NAME="_f_proc_diags"  VALUE='@{[ $page->param("_f_proc_diags") ]}'> <A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_diags, '/lookup/icd', ',');"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><NOBR><INPUT TYPE="TEXT" SIZE=20 NAME="_f_proc_service_place"  VALUE='@{[ $page->param("_f_proc_service_place") || $svcPlaceCode->{value_text} ]}'> <A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_service_place, '/lookup/serviceplace', ',');"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><INPUT TYPE="TEXT" SIZE=20 NAME="_f_proc_default_catalog"></TD>
					</TR>
				</TABLE>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$lineCount"/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						$removeHd
						<TD ALIGN=CENTER><FONT $textFontAttrs>Dates</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Svc Type</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>CPT/Modf</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Diagnoses</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Units</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Charge</FONT></TD>
					</TR>
					$linesHtml
				</TABLE>
			</TD>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

1;
