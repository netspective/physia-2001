#########################################################################
package App::Billing::Output::HTML;
#########################################################################
use strict;
use App::Billing::Output::Driver;
use App::Billing::Claims;
use vars qw(@ISA);

# this object is inherited from App::Billing::Output::Driver
@ISA = qw(App::Billing::Output::Driver);
sub processClaims
{
	my ($self, %params) = @_;

	my $claimsList = $params{claimList};
	my $claims = $params{claimList}->getClaim();

	my $file = $params{out};
	$file = (($file eq "") ?  'claim.htm' : $file);

	$self->createHTML($file);


}


sub createHTML
{
	my ($self, $file) = @_;

	my $htmlText =  $self->generateHTML();
	open(CLAIMFILE,">$file");
	print CLAIMFILE $htmlText;
	close CLAIMFILE;
}


sub generateHTML
{
	my $self = shift;

	my $html = $self->htmlHeader();
	$html = $html . $self->htmlBody();
	$html = $html . $self->htmlFooter();


	return $html;

}


sub htmlHeader
{
	my $self = shift;

	return '<html>
			<head>
			<title>Test</title>
			<meta name="GENERATOR" content="Microsoft FrontPage 3.0">
			<style>
			td.l { border-left: 1px solid rgb(0,0,128); margin-left: 1px }
			td.r { border-right: 1px solid rgb(0,0,128); margin-right: 1px }
			td.t { border-top: 1px solid rgb(0,0,128); margin-top: 1px }
			td.b { border-bottom: 1px solid rgb(0,0,128); margin-bottom: 1px }
			tr.box1font { text-align: centre; font-size: 7pt; font-size: helvetica }
			tr.box9Height { height: 50 }
			td.p5 { padding: 5px }
			td.f { padding: 0px }
			td.a { border-left: 1px solid rgb(0,0,128); margin-left: 1px }
			td.c { border-top: 1px solid rgb(0,0,128); margin-top: 1px }
			td.d { border-bottom: 1px solid rgb(0,0,128); margin-bottom: 1px }
			td.g { border-top: 1px solid rgb(255,255,255); margin-top: 1px }
			td.e { padding: 5px }
			</style>
			</head>';

}


sub htmlFooter
{
	my $self = shift;

	return '</html>';

}

sub htmlBody
{
	my $self = shift;

	return '<body bgcolor ="lightBlue">
<table border="0" cellspacing="0" bgcolor="BLACK" width ="770">
<table border="0" cellspacing="0" width ="770">
  <tr>
    <td Height = "2"  bgcolor="BLACK" colspan = "8"></td>
  </tr>
  <tr class = "box1font">
    <td class="l t p5" width = "70" valign ="Top">MEDICARE</td>
    <td class="t p5" width = "60" valign ="Top">MEDICAID</td>
    <td class="t p5" width = "60" valign ="Top">CHAMPUS</td>
    <td class="t p5" width = "60" valign ="Top">CHAMPVA</td>
    <td class="t p5" width = "80" valign ="Top">GROUP <BR> HEALTH PLAN</td>
    <td class="t p5" width = "80" valign ="Top">FECA <BR> BLK LUNG</td>
    <td class="r t p5" width = "43" valign ="Top">OTHER </td>
  	<td class="l r t b p5" width = "350" rowspan="2" valign ="top">INSURED\'S ID NUMBER </td>
  </tr>
  <tr>
    <td class="l b p5"><INPUT TYPE = "CHECKBOX" NAME = "chkMedicare"></td>
    <td class="b p5"><INPUT TYPE = "CHECKBOX" NAME = "chkMedicaid"> </td>
    <td class="b p5"><INPUT TYPE = "CHECKBOX" NAME = "chkChampus">  </td>
    <td class="b p5"><INPUT TYPE = "CHECKBOX" NAME = "chkChampva"> </td>
    <td class="b p5"><INPUT TYPE = "CHECKBOX" NAME = "chkFeca"> </td>
    <td class="b p5"><INPUT TYPE = "CHECKBOX" NAME = "chkBlk"> </td>
    <td class="b r p5"><INPUT TYPE = "CHECKBOX" NAME = "chkother"></td>
  </tr>
  <tr  class = "box1font">
    <td class="l r b p5"  valign ="top" COLSPAN = "4">2. PATIENT\'S NAME (Last Name,First Name, Middle Initial)</td>
    <td class="b p5" valign ="top" COLSPAN ="2">3. PATIENT\'S BIRTH DATE</td>
    <td class="b r p5" valign ="top" > &nbsp &nbsp &nbsp SEX <BR> M &nbsp &nbsp &nbsp &nbsp &nbsp F<BR><INPUT TYPE = "CHECKBOX" NAME = "chkM"> <INPUT TYPE = "CHECKBOX" NAME = "chkF"> </td>
    <td class="l b r p5" valign ="top">4. INSURED\'S NAME(Last Name,First Name,Middle Initial)</td>
  </tr>
  <tr  class = "box1font">
    <td class="l r b p5" valign ="top" COLSPAN = "4">5. PATIENT\'S ADDRESS (No., Street)</td>
    <td class="b r p5" valign ="top" COLSPAN ="3">6. PATIENT RELATIONSHIP TO INSURED <BR>
    											&nbsp Self <INPUT TYPE = "CHECKBOX" NAME = "chkRelationSelf">
    											&nbsp Spouse <INPUT TYPE = "CHECKBOX" NAME = "chkRelationSpouse">
    											&nbsp Child <INPUT TYPE = "CHECKBOX" NAME = "chkRelationChild">
    											&nbsp Other <INPUT TYPE = "CHECKBOX" NAME = "chkRelationOther"> </td>
    <td class="l b r p5"  valign ="top">4. INSURED\'S ADDRESS (No., Street)</td>
  </tr>
  <tr  class = "box1font">
    <td class="l b p5" valign ="top" COLSPAN = "3">City</td>
    <td class="l r b p5"  valign ="top">State</td>
    <td class="r p5"valign ="top" COLSPAN ="3">8. PATIENT STATUS <BR>
    											&nbsp &nbsp &nbsp &nbsp &nbsp Single <INPUT TYPE = "CHECKBOX" NAME = "chkRelationSelf">
    											&nbsp &nbsp &nbsp Married <INPUT TYPE = "CHECKBOX" NAME = "chkRelationSpouse">
    											&nbsp &nbsp &nbsp &nbsp Other <INPUT TYPE = "CHECKBOX" NAME = "chkRelationChild">
	</td>
	<td class="l b r f" valign ="top" >

    		<table border="0" width = "100%" cellpadding ="0" cellspaceing ="0">
      		<tr class = "box1font">
        		<td width = "250" valign ="top">  City</td>
        		<td class= "l" width = "80" valign ="top" height ="40"> &nbsp State</td>
      		</tr>
    		</table>

    </td>
  </tr>


  <tr class = "box1font">
    <td class="l b p5" valign ="top" >ZIP CODE</td>
    <td class="l r b p5"  valign ="top" COLSPAN = "3">TELEPHONE (Include Area Code)</td>
    <td class="b r p5"  valign ="top" COLSPAN ="3">
    							&nbsp Employed <INPUT TYPE = "CHECKBOX" NAME = "chkRelationOther">
    							&nbsp Full-Time <INPUT TYPE = "CHECKBOX" NAME = "chkRelationSpouse">
    							&nbsp Part-Time<INPUT TYPE = "CHECKBOX" NAME = "chkRelationChild">
    					  	<BR>
								&nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp Student
								&nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp   Student
	</td>
	<td class="l b r f"  valign ="top">
      		<table border="0" width = "100%">
        		<tr class = "box1font">
          		<td width = "100" valign ="top"> ZIP CODE</td>
          		<td class= "l" width = "280" valign ="top" height ="40"> &nbsp TELEPHONE (Include Area Code)</td>
        		</tr>
      		</table>
	</td>
  </tr>


  <tr class = "box1font box9height" >
    <td class="l b r p5" valign ="top" COLSPAN="4">9. OTHER\'S INSURED NAME (Last Name,First Name, Middle Initial) </td>
    <td class="r p5"  valign ="top" COLSPAN ="3">10. IS PATIENT CONDITION RELATED TO:</td>
	<td class="l b r p5"  valign ="top">11. INSURED\'S POLICY GROUP OR FECA NUMBER </td>
  </tr>
  <tr class = "box1font">
    <td class="l b r p5" valign ="top" COLSPAN ="4">a. OTHER INSURED\'S POLICY GROUP OR FECA NUMBER</td>
    <td class="r p5" valign ="top" COLSPAN ="3" > a.EMPLOYMENT (CURRENT OR PREVIOUS)<BR>   &nbsp &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkM">YES &nbsp  &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkF">NO </td>
    <td class="l b r p5"  valign ="top">11. INSURED\'S POLICY GROUP OR FECA NUMBER </td>
  </tr>
  <tr class = "box1font">
    <td class="l b p5" valign ="top" COLSPAN ="3">b. OTHER INSURED\'S DATE OF BIRTH</td>
    <td class="b r p5" valign ="top" COLSPAN ="1" > &nbsp &nbsp &nbsp SEX <BR> &nbsp &nbsp M &nbsp &nbsp  F <BR> <INPUT TYPE = "CHECKBOX" NAME = "chkM">  <INPUT TYPE = "CHECKBOX" NAME = "chkF"> </td>
    <td class="r p5"  valign ="top" COLSPAN ="3">AUTO ACCIDENT ? <BR> <BR>   &nbsp  &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkM">YES &nbsp  &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkF">NO  &nbsp  &nbsp PLACE(STATE)  </td>
	<td class="l b r p5"  valign ="top">b. EMPLOYER NAME OR SCHOOL NAME </td>
  </tr>
  <tr class = "box1font">
    <td class="l b r p5" valign ="top" COLSPAN ="4">c. EMPLOYER\'S NAME OR SCHOOL NAME</td>
    <td class="r b p5" valign ="top" COLSPAN ="3" > c. OTHER ACCIDENT?<BR>   &nbsp &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkM">YES &nbsp  &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkF">NO </td>
    <td class="l b r p5"  valign ="top">c INSURANCE PLAN NAME OR PROGRAM NAME </td>
  </tr>
  <tr class = "box1font">
    <td class="l b r p5" valign ="top" COLSPAN ="4">d. INSURANCE PLAN NAME OR PROGRAM NAME</td>
    <td class="r b p5" valign ="top" COLSPAN ="3" >10d. RESERVE FOR LOCAL USE </td>
    <td class="l b r p5"  valign ="top">d. IS THERE ANOTHER HEALTH BENEFIT PLAN <BR>   &nbsp &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkM">YES &nbsp  &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkF">NO </td>
  </tr>
  <tr class = "box1font">
    <td class="l b r p5" valign ="top" COLSPAN ="7"> &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp READ BACK OF FORM BEFORE COMPLETING & SIGNING THIS FORM <BR> 12. PATIENT\'S OR AUTHORIZED PERSON\'S SIGNATURE   &nbsp  &nbsp &nbsp I authorize the release of any medical or other information
				<BR>  &nbsp &nbsp &nbsp necessary to process this claim. I also request payment of goverment benefits either to myself or to the party who accepts
				<BR>  &nbsp &nbsp &nbsp assigment below
				<BR>
				<BR>  &nbsp &nbsp &nbsp SIGNED______________________________________________   &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp DATED __________________________
				</td>
    <td class="l b r p5"  valign ="top">13. INSURED\'S OR AUTHORIZED PERSON SIGNATURE\'S
				 &nbsp &nbsp I authorize payment of medical benefits to the undersigned
				<BR>   &nbsp  &nbsp &nbsp physician or supplier for service described below.
				<BR>
				<BR>   &nbsp  &nbsp &nbsp SIGNED_________________________________________
				 </td>
  </tr>

  <tr>
    <td Height = "2"  bgcolor="BLACK" colspan = "8"></td>
  </tr>
</table>


<table border="0" cellspacing="0" width ="770">
  <tr class = "box1font">
    <td class="l b f" width = "250" valign ="Top">
          		<table border="0" width = "100%">
        		<tr class = "box1font">
          		<td class = "p5"  valign ="top"> DATE OF CURRENT :</td>
          		<td class= " f" valign ="top" height ="40">  ILLNESS ( First symptom) OR <BR> INJURY (Accident) OR <BR> PREGNANCY(LMP) </td>
        		</tr>
		 		</table>
    </td>
    <td class="l r b p5" width = "261" valign ="Top">15. IF PATIENT HAS HAD SAME OR SIMILAR ILLNESS.
				 <BR> &nbsp  &nbsp &nbsp GIVE FIRST DATE
				 </td>
  	<td class="l r b p5" width = "260" valign ="top">16. DATES PATIENT UNABLE TO WORK IN CURRENT
  				<BR> &nbsp  &nbsp &nbsp OCCUPATION
  				<BR> &nbsp  &nbsp &nbsp FROM 28JAN1999 &nbsp  &nbsp &nbsp TO 28JAN1999
  				</td>
  </tr>

  <tr class = "box1font">
    <td class="l  P5" valign ="Top">17. NAME OF REFERRING PHYSICIAN OR OTHER <BR> &nbsp  &nbsp &nbsp SOURCE <BR> </td>
    <td class="l r  p5"  valign ="Top">17a. I.D NUMBER OF REFERRING PHYSICIAN.</td>
  	<td class="l r  p5"  valign ="top">18. HOSPITALIZATION DATES RELATED TO CURRENT <BR> &nbsp  &nbsp &nbsp  SERVICE  <BR> &nbsp  &nbsp &nbsp FROM 28JAN1999 &nbsp  &nbsp &nbsp TO 28JAN1999 </td>
  </tr>


  <tr class = "box1font">
    <td class="l t r P5" valign ="Top" colspan ="2" >19. RESERVED FOR LOCAL USE  </td>
    <td class="l t r  p5"  valign ="top">20. OUTSIDE LAB? &nbsp  &nbsp  &nbsp  &nbsp  &nbsp  &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp $CHARGES <BR>   &nbsp &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkM">YES &nbsp  &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkF">NO &nbsp &nbsp  &nbsp  &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp 345 </td>
  </tr>

  <tr class = "box1font">
    <td class="l t r P5" valign ="Top" colspan ="2" >21. DIAGNOSIS OR NATURE OF ILLNESS OR INGURY, (RELATE ITEMS 1,2,3 OR 4 TO ITEM 24E BY LINE)
    			<BR><BR> 1._____________________	&nbsp  &nbsp &nbsp &nbsp  &nbsp &nbsp &nbsp  &nbsp &nbsp &nbsp  &nbsp &nbsp 3._____________________	</td>
    <td class="l t r  p5"  valign ="top">20. OUTSIDE LAB? &nbsp  &nbsp  &nbsp  &nbsp  &nbsp  &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp $CHARGES <BR>   &nbsp &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkM">YES &nbsp  &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkF">NO &nbsp &nbsp  &nbsp  &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp 345 </td>
  </tr>

  <tr class = "box1font">
    <td class="l r P5" valign ="BOTTOM" colspan ="2" > 2._____________________	&nbsp  &nbsp &nbsp &nbsp  &nbsp &nbsp &nbsp  &nbsp &nbsp &nbsp  &nbsp &nbsp 4._____________________	</td>
    <td class="l t r  p5"  valign ="top">20. OUTSIDE LAB? &nbsp  &nbsp  &nbsp  &nbsp  &nbsp  &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp $CHARGES <BR>   &nbsp &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkM">YES &nbsp  &nbsp &nbsp <INPUT TYPE = "CHECKBOX" NAME = "chkF">NO &nbsp &nbsp  &nbsp  &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp &nbsp 345 </td>
  </tr>



</table>
<!--- afzal -->


<table border="0" cellspacing="0" cellpadding="0" width ="770">
  <tr>
    <td Height = "1"  bgcolor=rgb(0,0,128) colspan = "10"></td>
  </tr>
  <tr class="box1font" align="center">
    <td class="a d" align="left">24.   A</td>
    <td class="a d"  >B</td>
    <td class="a d e">C</td>
    <td class="a d e" colspan="2">D</td>
    <td class="a r d e">E</td>
    <td class="a d e">F</td>
    <td class="a d e">G</td>
    <td class="a d e">H</td>
    <td class="a d e">I</td>
    <td class="a c d e">J</td>
    <td class="a r c  d e">K</td>
  <tr  class="box1font">
    <td class="a d e" width="200" align="center">DATE(S) OF SERVICE
    	<br>From
    	&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
    	&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
    	&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
    	&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
    	&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
    	To
    	<br>
    	MM&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbspDD&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbspYY
    	&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
    	&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
    	MM&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbspDD&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbspYY
    	</td>
    <td class="a d e" align="center">Place of Service</td>
    <td class="a d e" align="center">Type of Service</td>
    <td class="a d e" width="600" align="center" colspan="2">PROCEDURES, SERVICES, OR SUPPLIES
    	<br>(Explain Unusual Circumstances)
    	<br>CPT/HCPCS &nbsp&nbsp&nbsp|
    	&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
    	&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
    		MODIFIER

    </td>
    <td class="a r d e" align="center">DIAGNOSIS CODE</td>
    <td class="a  d e" align="center">$CHARGES</td>
    <td class="a  d e" align="center">DAYS OR UNITS</td>
    <td class="a  d e" align="center">EPSDT Family Plan</td>
    <td class="a  d e" align="center">EMG</td>
    <td class="a  d e" align="center">COB</td>
    <td class="a  d e r" align="center">RESERVED FOR LOCAL USE</td>
  </tr>
  <tr class="box1font" >
	    <td class="a d f" align="center">
	    <div align="left">
	    <table border="0" cellspacing="0" cellpadding="0" width = "200" >
        <tr  class="box1font">
        	<td class=" ">
        	<table border="0" cellspacing="0" cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e  f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      	</table>
        	</td>
        	<td class="a e">
        	<table border="0" cellspacing="0"  cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
      		</td>
      	</tr>
      	</table>
 </td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a r d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e r">&nbsp</td>
  </tr>

<!--second-->
<tr class="box1font">
	    <td class="a d f" align="center">
	    <div align="left">
	    <table border="0" cellspacing="0" cellpadding="0" width = "200">
        <tr  class="box1font">
        	<td class=" ">
        	<table border="0" cellspacing="0" cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
        	</td>
        	<td class="a e">
        	<table border="0" cellspacing="0"  cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
      		</td>
      	</tr>
      	</table>
 </td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a r d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e r">&nbsp</td>
  </tr>


<!--third-->

<tr class="box1font">
	    <td class="a d f" align="center">
	    <div align="left">
	    <table border="0" cellspacing="0" cellpadding="0" width = "200">
        <tr  class="box1font">
        	<td class=" ">
        	<table border="0" cellspacing="0" cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
        	</td>
        	<td class="a e">
        	<table border="0" cellspacing="0"  cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
      		</td>
      	</tr>
      	</table>
 </td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a r d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e r">&nbsp</td>
  </tr>

<!--fourth-->
<tr class="box1font">
	    <td class="a d f" align="center">
	    <div align="left">
	    <table border="0" cellspacing="0" cellpadding="0" width = "200">
        <tr  class="box1font">
        	<td class=" ">
        	<table border="0" cellspacing="0" cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
        	</td>
        	<td class="a e">
        	<table border="0" cellspacing="0"  cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
      		</td>
      	</tr>
      	</table>
 </td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a r d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e r">&nbsp</td>
  </tr>

<!--fifth-->

<tr class="box1font">
	    <td class="a d f" align="center">
	    <div align="left">
	    <table border="0" cellspacing="0" cellpadding="0" width = "200">
        <tr  class="box1font">
        	<td class=" ">
        	<table border="0" cellspacing="0" cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
        	</td>
        	<td class="a e">
        	<table border="0" cellspacing="0"  cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
      		</td>
      	</tr>
      	</table>
 </td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a r d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e r">&nbsp</td>
  </tr>

<!--sixth-->

<tr class="box1font">
	    <td class="a d f" align="center">
	    <div align="left">
	    <table border="0" cellspacing="0" cellpadding="0" width = "200">
        <tr  class="box1font">
        	<td class=" ">
        	<table border="0" cellspacing="0" cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
        	</td>
        	<td class="a e">
        	<table border="0" cellspacing="0"  cellpadding="0" width = "100">
        		<tr align="center"  class="box1font">
        			<td class="e f">mm</td>
        			<td class="a e f">dd</td>
        			<td class="a e f">yy</td>
      			</tr>
      		</table>
      		</td>
      	</tr>
      	</table>
 </td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a d e" width="300">&nbsp</td>
	    <td class="a r d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e" >&nbsp</td>
	    <td class="a d e">&nbsp</td>
	    <td class="a d e r">&nbsp</td>
  </tr>

<tr class="box1font">
	    <td class="a d e" valign="top">25. FEDERAL TAX I.D. NUMBER
	     &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
	     SSN&nbsp&nbspEIN
	     <BR>
	     &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
	    &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
	    &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
                   	    &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
	    &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
	    &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
 	    &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
	    &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
 	    &nbsp&nbsp&nbsp
	    <INPUT type="checkbox"  disabled>
	    <INPUT type="checkbox"  disabled>				    </td>
	    <td class="a d e" valign="top"  colspan="3">26. PATIENT ACCOUNT 	     NO.
	     <BR>&nbsp
	     </td>
	     <td class="a r  d e" colspan="2">27. ACCEPT ASSIGNMENT ?
	  <BR>(For govt. claims, see back)
	  <BR><INPUT type="checkbox"  disabled> YES
	   <INPUT type="checkbox"  disabled>NO
	   </td>
	    <td class="a  d e" valign="top" colspan="2">28. TOTAL CHARGE
	<BR>$
	</td>
	    <td class="a  d e"  valign="top" colspan="2">29. AMOUNT PAID
	<BR>$
	</td>
	    <td class="a  d e r" valign="top" colspan="2">30. BALANCE DUE
	<BR>$
	</td>

  </tr>
<tr class="box1font">
	<td class="a d  e" valign="top" >31. SIGNATURE OF 	PHYSICIAN OR 	SUPPLIER
	<BR>&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
	INCLUDING DEGREES OR CREDENTIALS
	<BR>&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
	(I certify that the statements on the reverse
	<BR>&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp
	apply to this bill and are made a part thereof.)
	<BR><BR>
	<table border="0" cellspacing="0" cellpadding="0" width="200">
        		<tr align="left"  class="box1font">
        			<td class="  f" >SIGNED</td>
			<td class="  f" >Mr. John Adams</td>
        			<td class="  f">DATE</td>
			<td class="  f">02 Dec 1999</td>
      		</tr>
      	</table>

	</td>
	<td class="a d r e" valign="top" colspan="5">32. NAME AND ADDRESS 	OF FACILITY WHERE SERVICES WERE
	RENDERED (If other than home or office)
	<BR>
	</td>
	<td class="a  d e r" valign="top" colspan="6">33. PHYSICIAN\'S, 		SUPPLIER\'S BILLING NAME, ADDRESS, ZIP CODE & PHONE #
	<BR><BR><BR><BR>
	<table border="0" cellspacing="0" cellpadding="0" width = "250">
        		<tr align="left"  class="box1font">
        			<td class=" f"  valign="bottom">PIN#</td>
			<td class="  f" valign="bottom">SP807122323</td>
        			<td class="a  f" valign="bottom">GRP#</td>
			<td class="  f" valign="bottom">GRP9001232</td>
      		</tr>
      	</table>
	</td>

</table>
</table>

</body>';

}



1;
