##############################################################################
package App::Page::Eligibility;
##############################################################################

use strict;

use App::Page::Invoice;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Insurance;
use Data::Publish;

use Date::Manip;
use Date::Calc qw( Date_to_Days );
use constant FORMATTER => new Number::Format(INT_CURR_SYMBOL => '$');

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page);
%RESOURCE_MAP = (
	'eligibility' => {},
	);

sub prepare
{
	my ($self) = @_;
	my $sysdate = UnixDate('today', '%m/%d/%Y');

	my $person = $self->property('activePerson');
	my $insurance = $self->property('activeInsurance');
	
	my $eligDate = $self->param('elig_date');
	my $isEligible = $self->checkEligibility($insurance, $eligDate);

	my $patientHtml = $self->getPatientHtml($person);
	#my $pcphysician = $self->
	my $employerHtml = $self->getEmployerHtml($person);
	my $carrierHtml = $self->getCarrierHtml($insurance);

	my $pageContent = qq{
		<SPAN style="font-family:Verdana; font-size:10pt">
			<CENTER>	
				<TABLE width=80% border=0>
					<TR>
						<TD valign=top>$patientHtml</TD>						
						<TD valign=top>$employerHtml</TD>
					</TR>					
					<TR>
						<TD colspan=2>&nbsp;</TD>
					</TR>
					<TR>
						<TD align=left valign=top>$carrierHtml</TD>
						<TD align=right valign=top><b>$isEligible</b></TD>
					</TR>
				
					<TR>
						<TD colspan=2>&nbsp;</TD>
					</TR>

					<TR>
						<TD colspan=2>PCP: Dr. Munir A. Faridi</TD>
					</TR>
					<TR>
						<TD>Plan: $insurance->{plan_name} ($insurance->{ins_type})</TD>
						<TD align=right>Coverage Dates: $insurance->{coverage_begin_date_html} - $insurance->{coverage_end_date_html}</TD>
					</TR>
					
					<TR>
						<TD colspan=2>&nbsp;</TD>
					</TR>

					<TR>
						<TD align=center colspan=2><b>Copays</b></TD>
					</TR>
					<TR>
						<TD align=left>
							<TABLE border=0 width=100%>
								<TR>
									<TD>Office Visit:</TD>
									<TD align=right>\$10</TD>
								</TR>
								<TR>
									<TD>Ancillary Only:</TD>
									<TD align=right>\$10</TD>
								</TR>
								<TR>
									<TD>Well Baby to age 2:</TD>
									<TD align=right>\$10</TD>
								</TR>
								<TR>
									<TD>Physical - 1 annual:</TD>
									<TD align=right>\$10</TD>
								</TR>
								<TR>
									<TD>Well woman - 1 annual:</TD>
									<TD align=right>\$10</TD>
								</TR>
								<TR>
									<TD>Immunizations:</TD>
									<TD align=right>\$0</TD>
								</TR>
								<TR>
									<TD>Prenatal Care (1st visit):</TD>
									<TD align=right>\$20</TD>
								</TR>
							</TABLE>
						</TD>

						<TD align=right>
							<TABLE>
								<TR>
									<TD>Hosp Admit:</TD>
									<TD align=right>\$175</TD>
								</TR>
								<TR>
									<TD>Hosp Outpatient:</TD>
									<TD align=right>\$50</TD>
								</TR>
								<TR>
									<TD>Emg Room:</TD>
									<TD align=right>\$25</TD>
								</TR>
								<TR>
									<TD>&nbsp;</TD>
									<TD align=right>&nbsp;</TD>
								</TR>
								<TR>
									<TD>RX - Generic</TD>
									<TD align=right>\$10</TD>
								</TR>
								<TR>
									<TD>RX - Brand:</TD>
									<TD align=right>\$20</TD>
								</TR>
								<TR>
									<TD>BTL/Vasectomy:</TD>
									<TD align=right>\$0</TD>
								</TR>
							</TABLE>
						</TD>
					</TR>
					
					<TR>
						<TD colspan=2>&nbsp;</TD>
					</TR>
					
					<TR>
						<TD>Mental Health:</TD>
						<TD align=right>Cap to Mental Health Associates</TD>
					</TR>
					<TR>
						<TD>
							<TABLE border=0 width=100%>
								<TR>
									<TD>&nbsp;</TD>
									<TD>Visit</TD>
									<TD>1-20</TD>
									<TD align=right>\$0</TD>
								</TR>
								<TR>
									<TD>&nbsp;</TD>
									<TD>&nbsp;</TD>
									<TD>21-40</TD>
									<TD align=right>\$50</TD>
								</TR>
								<TR>
									<TD>&nbsp;</TD>
									<TD>&nbsp;</TD>
									<TD>41+</TD>
									<TD align=right>Not covered</TD>
								</TR>
							</TABLE>
						</TD>
						<TD align=right valign=top>Inpatient 20 days/yr @ \$50/day</TD>
					</TR>

					<TR>
						<TD colspan=2>&nbsp;</TD>
					</TR>

					<TR>
						<TD align=left>
							<TABLE border=0 width=100%>
								<TR>
									<TD>Allergy Testing/Injections</TD>
									<TD align=right>50%</TD>
								</TR>
							</TABLE>
						</TD>
						<TD align=right>
							<TABLE border=0>
								<TR>
									<TD>Allergy Serum</TD>
									<TD align=right>50%</TD>
								</TR>
							</TABLE>
						</TD>
					</TR>

					<TR>
						<TD colspan=2>&nbsp;</TD>
					</TR>

					<TR>
						<TD>
							<TABLE border=0 width=100%>
								<TR>
									<TD>IUD</TD>
									<TD align=right>50% device cost plus \$200</TD>
								</TR>
								<TR>
									<TD>IVF</TD>
									<TD align=right>Not covered</TD>
								</TR>
								<TR>
									<TD>DME</TD>
									<TD align=right>50% copay</TD>
								</TR>
							</TABLE>
						</TD>
						<TD>&nbsp;</TD>						
					</TR>

					<TR>
						<TD colspan=2>&nbsp;</TD>
					</TR>

					<TR>
						<TD colspan=2>Rider:</TD>
					</TR>
					<TR>
						<TD>
							<TABLE border=0 width=100%>
								<TR>
									<TD>&nbsp;</TD>
									<TD>Eyeglasses</TD>
									<TD>Lens</TD>
									<TD align=right>renew 1/yr</TD>
								</TR>
								<TR>
									<TD>&nbsp;</TD>
									<TD>&nbsp;</TD>
									<TD>Frames</TD>
									<TD align=right>1/2yr</TD>
								</TR>
							</TABLE>
						</TD>
						<TD align=right valign=top>Cap EyeGlasses Associates</TD>
					</TR>
					<TR>
						<TD colspan=2>Rider:</TD>
					</TR>
					<TR>
						<TD>
							<TABLE border=0 width=100%>
								<TR>
									<TD>&nbsp;</TD>
									<TD>Dental</TD>
									<TD>&nbsp;</TD>
									<TD>&nbsp;</TD>
								</TR>
							</TABLE>
						</TD>
						<TD align=right valign=top>Cap Dental Associates</TD>
					</TR>

				</TABLE>
		
			</CENTER>
		</SPAN>
	};
	
	
	$self->addContent(qq{
		<center>
		<table bgcolor='#DDDDDD' cellspacing=1 width=100%>
			<tr><td>
				<table width=100% bgcolor=white>
					<tr>
						<td>$pageContent</td>
					</tr>
				</table>
			</td></tr>
		</table>
		
		</center>
	});

	return 1;
}

sub formatDate
{
	my ($date) = @_;
	return UnixDate(ParseDate($date), '%m/%d/%Y');
}

sub formatPhone
{
	my ($phone) = @_;
	
	my ($area, $ph3, $ph4);
	
	$area = substr($phone, 0, 3);
	$ph3  = substr($phone, 3, 3);
	$ph4  = substr($phone, 6, 4);
	
	return "($area) $ph3-$ph4" if $area && $ph3 && $ph4;
}

sub checkEligibility
{
	my ($self, $insurance, $date) = @_;
	
	my @beginDate = split(/,/, $insurance->{coverage_begin_date});
	my $lower = Date_to_Days(@beginDate);
	
	my @endDate = split(/,/, $insurance->{coverage_end_date});
	my $upper = Date_to_Days(@endDate);

	my ($month, $day, $year) = split(/\//, $date);
	my $middle = Date_to_Days($year,$month,$day);

	if (($middle >= $lower) && ($middle <= $upper))
	{
		return qq{<b>Eligible: $date</b>};
	}
	else
	{
		return qq{<b>Patient is not eligible: $date</b>};
	}
}

sub getPatientHtml
{
	my ($self, $person) = @_;

	my $personId = $person->{person_id};
	my $addr = $STMTMGR_PERSON->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selHomeAddress', $personId);

	return qq{
		<b>$person->{name_first} $person->{name_middle} $person->{name_last}</b> ($personId) <br>DOB: $person->{date_of_birth}, Sex: $person->{gender_caption}<br>
		$addr->{line1}<br>
		@{[ $addr->{line2} ? "$addr->{line2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zip}<br>
	};
}

sub getEmployerHtml
{
	my ($self, $person) = @_;

	my $personId = $person->{person_id};
	my $employerAssoc = $STMTMGR_PERSON->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selEmploymentAssociations', $personId);
	my $employerId = $employerAssoc->{value_text};
	my $employerName = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selOrgSimpleNameById', $employerId);
	my $employerAddr = $STMTMGR_ORG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $employerId, 'Mailing');

	return qq{&nbsp;} if $employerId eq '';

	return qq{
		<b>$employerName</b> ($employerId)<br>
		$employerAddr->{line1}<br>
		@{[ $employerAddr->{line2} ? "$employerAddr->{line2}<br>" : '']}
		$employerAddr->{city}, $employerAddr->{state} $employerAddr->{zip}<br>
	};
}

sub getCarrierHtml
{
	my ($self, $insurance) = @_;

	my $addr = $STMTMGR_INSURANCE->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selInsuranceAddrWithOutColNameChanges', $insurance->{parent_ins_id});
	my $phone = $STMTMGR_INSURANCE->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selInsurancePayerPhone', $insurance->{parent_ins_id});

	return qq{
		<b>$insurance->{plan_name}</b> ($insurance->{ins_org_id})<br>
		$addr->{line1}<br>
		@{[ $addr->{line2} ? "$addr->{line2}<br>" : '']}
		$addr->{city}, $addr->{state} $addr->{zip}<br>
		$phone->{phone}
	};
}

sub prepare_page_content_footer
{
	my $self = shift;
	return 1;
}

sub prepare_page_content_header
{
	my $self = shift;

	if($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP))
	{
		if(my $instance = $self->property('activeInstance'))
		{
			push(@{$self->{page_content_header}}, '<H1>', $instance->heading(), '</H1>');
		}
		return 1;
	}

	$self->SUPER::prepare_page_content_header(@_);
	my $heading = 'Eligibility';
	push(@{$self->{page_content_header}}, qq{
		<STYLE>
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</STYLE>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE BORDER=0 CELLPADDING=0 CELLSPACING=1>
		<TR><TD BGCOLOR=BEIGE>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TR>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					<B>$heading</B>
				</FONT>
			</TD>
		</TABLE>
		</TD></TR>
		</TABLE>
		<FONT SIZE=1>&nbsp;<BR></FONT>
		});

	return 1;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	my $orgId = $self->param('ins_org_id');
	my $eligDate = $self->param('elig_date');

	if(my $memberNum = $self->param('member_number'))
	{
		my $insurance = $STMTMGR_INSURANCE->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selInsuranceByInsOrgAndMemberNumberForElig', $orgId, $memberNum);
		$self->property('activeInsurance', $insurance);
		
		my $personId = $insurance->{owner_person_id};
		my $person = $STMTMGR_PERSON->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selRegistry', $personId);
		$self->property('activePerson', $person);

		#$self->property('heading', "Unknown Member Number: $memberNum") unless $person->{complete_name};
	}
	elsif(my $ssn = $self->param('ssn'))
	{
		my $person = $STMTMGR_PERSON->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selRegistryBySSN', $ssn);
		$self->property('activePerson', $person);
		#$self->property('complete_name', "Unknown SSN: $ssn") unless $self->property('complete_name');
		
		my $insurance = $STMTMGR_INSURANCE->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selInsuranceByOwnerAndProductNameForElig', $orgId, $person->{person_id});
		$self->property('activeInsurance', $insurance);
		#$self->property('complete_name', "No insurance information on file for $ssn") unless $self->property('complete_name');
	}
	else
	{
		my $firstName = $self->param('first_name');
		my $lastName = $self->param('last_name');
		my $dob = $self->param('dob');
		my $person = $STMTMGR_PERSON->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selRegistryByLastAndFirstNameAndDOB', $lastName, $firstName, $dob);
		$self->property('activePerson', $person);
		#$self->property('complete_name', "Unknown Person: $lastName, $firstName") unless $self->property('complete_name');

		my $insurance = $STMTMGR_INSURANCE->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selInsuranceByOwnerAndProductNameForElig', $orgId, $person->{person_id});
		$self->property('activeInsurance', $insurance);
		#$self->property('complete_name', "No insurance information on file for $lastName, $firstName") unless $self->property('complete_name');
	}

	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	
	$self->param('ins_org_id', $pathItems->[0]);

	my $eligDate = $pathItems->[1];
	$eligDate =~ s/\-/\//g;
	$self->param('elig_date', $eligDate);	

	if($pathItems->[2] == 0)
	{
		$self->param('member_number', $pathItems->[3]) if defined $pathItems->[3];
	}
	elsif($pathItems->[2] == 1)
	{
		$self->param('ssn', $pathItems->[3]) if defined $pathItems->[3];
	}
	elsif($pathItems->[2] == 2)
	{
		my $dob = $pathItems->[5];
		$dob =~ s/\-/\//g;
		$self->param('first_name', $pathItems->[3]) if defined $pathItems->[3];
		$self->param('last_name', $pathItems->[4]) if defined $pathItems->[4];
		$self->param('dob', $dob) if defined $pathItems->[5];
		#$self->addDebugStmt($pathItems->[3]);
		#$self->addDebugStmt($pathItems->[4]);
		#$self->addDebugStmt($dob);
	}
	else
	{
		return "test";
	}

	$self->printContents();
	return 0;
}

1;
