##############################################################################
package App::Page::Help;
##############################################################################

use strict;
use App::Page;
use App::Universal;


use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page);

%RESOURCE_MAP = (
	'help' => {
		_title => 'Online Help',
		_iconSmall => 'images/page-icons/help',
		_iconMedium => 'images/page-icons/help',
		_iconLarge => 'images/page-icons/help',
	},
	);

sub prepare
{
	my $self = shift;
	$self->addContent(qq{

<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
<P>
	<b>Glossary</b>
</P>
</FONT>

<TABLE WIDTH=100% CELLSPACING=0 CELLPADDING=3 BORDER=0>
  <TR>
    <TD>
    	<FONT FACE="Arial,Helvetica" SIZE=3 COLOR=DARKBLUE>
					<B>Organizational Terms</B>
		</FONT>
    </TD>
  </TR>
  <TR>
    <TD>
      <TABLE WIDTH=100% CELLSPACING=0 CELLPADDING=10 BORDER=0>
        <TR>
          <TD>
          Provider Organizations
<UL TYPE=DISC>
	<LI><B>Main Organization</B> - the name of the highest/comprehensive level of the organization.
	<LI><B>Practice/Clinic</B> - one or more providers who will bill for services under a common tax id number, includes all ancillary services billed for by the practice.
	<LI><B>Facilty/Site</B> - physically distinct places of service.
	<LI><B>Dept</B> - likely to be the first level/specialty designation as well as practicce based diagnostic services.  NOTE: Diagnostic Services which bill independently shgould be set up as a separate organization.
</UL>

          </TD>
        </TR>
        <TR>
          <TD>
          Insurance Entities
<UL TYPE=DISC>
	<LI><B>Insurance Organization</B> - the name of the highest/comprehensive level of the organization.
	<LI><B>Insurance Product</B> - one type of organizational products (e.g., HMO, PPO) that belong to an Insurance Organization.
	<LI><B>Insurance Plan</B> - one of many plan types that belong to a single Insurance Product.
	<LI><B>Personal Coverage</B> - that information which comprises the individual insurance coverage for a person.
</UL>

          </TD>
        </TR>
      </TABLE>
    </TD>
  </TR>
  <TR>
    <TD>
    	<FONT FACE="Arial,Helvetica" SIZE=3 COLOR=DARKBLUE>
					<B>Browser Structure Terms</B>
		</FONT>
    </TD>
  </TR>
  <TR>
    <TD>
      <TABLE WIDTH=100% CELLSPACING=0 CELLPADDING=10 BORDER=0>
        <TR>
          <TD>
<UL TYPE=DISC>
	<LI><B>Application Resource Locator (ARL)</B> - the "address" of a particular web page.
	<LI><B>Page</B> - Composed of Header, Body, and Footer areas.
	<LI><B>Header</B> - contains Navigation Bars (2), Time/Date Stamp, Entity name, Demographics Bar, Choose Action Menu
	<LI><B>Body</B> - Can contain Panes, Views, Dialogs, or Lookup areas.
	<LI><B>Panes</B> - can be boxed or Transparent.  Shaded Headers indicate higher activity or priority.
	<LI>User Input areas are either <B>Dialogs</B> or <B>Lookup</B> areas.
	<LI><B>Footer</B> - Contains a context-sensitive Lookup area and Feedback area (for reporting bugs, suggestions, and service requests)
</UL>

          </TD>
        </TR>
      </TABLE>
    </TD>
  </TR>
</TABLE>

<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
<P>
	<b>Data Entry and Formatting Guidelines</b>
</P>
</FONT>

<TABLE WIDTH=100% CELLSPACING=0 CELLPADDING=3 BORDER=0>
  <TR>
    <TD>
    	<FONT FACE="Arial,Helvetica" SIZE=3 COLOR=DARKBLUE>
					<B>General Guidelines</B>
		</FONT>
    </TD>
  </TR>
    <TD>
      <TABLE WIDTH=100% CELLSPACING=0 CELLPADDING=10 BORDER=0>
        <TR>
          <TD>
          	The User may use the Tab, Return, or Enter keys to navigate from
            one field to the next. After the last entry in a dialog has been made, then the keys above will submit the entered data to the database.
          </TD>
        </TR>
        <TR>
			<TD>
          	Required fields are identifiable by both the <B>Bold</B> field label and the red triangle "hats" seen within the required fields.
          	</TD>
        </TR>
      </TABLE>
    </TD>
  </TR>
  <TR>
    <TD>
    	<FONT FACE="Arial,Helvetica" SIZE=3 COLOR=DARKBLUE>
					<B>Formatting by Example</B>
		</FONT>
    </TD>
  </TR>
  <TR>
    <TD>
<table width=100% cellspacing=0 cellpadding=10 border=0>
  <tr>
    <td colspan="3"> Values can be entered in a variety of formats with a variety
      of separators (i.e., /, -, .)
      <p> <font size="2">Note: For these examples, assume today's date is April
        1, 2000. </font></p>
    </td>
  </tr>
  <tr valign="top">
    <td width="34%" rowspan="3">
      <table width="100%" border="1" cellspacing="0" bordercolor="#CCCCCC">
        <tr align="center" bgcolor="#CCCCCC">
          <td colspan="2"> <b><font size="4">Date</font></b> </td>
        </tr>
        <tr align="center">
          <td width="34%"> <b>Entered Value</b> </td>
          <td width="66%"> <b>Result </b> </td>
        </tr>
        <tr align="center">
          <td width="34%"><code>0</code></td>
          <td width="66%"><code>04/01/2000</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>5</code></td>
          <td width="66%"><code>04/05/2000</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>4/5</code></td>
          <td width="66%"><code>04/05/2000</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>4/5/1</code></td>
          <td width="66%"><code>04/05/2001</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>4/5/01</code></td>
          <td width="66%"><code>04/05/2001</code></td>
        </tr>
        <tr align="center">
		          <td width="34%"><code>040501</code></td>
		          <td width="66%"><code>04/05/2001</code></td>
        </tr>
        <tr align="center">
		          <td width="34%"><code>04052001</code></td>
		          <td width="66%"><code>04/05/2001</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>today</code></td>
          <td width="66%"><code>04/01/2000</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>now</code></td>
          <td width="66%"><code>04/01/2000</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>yesterday</code></td>
          <td width="66%"><code>03/31/2000</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>tomorrow</code></td>
          <td width="66%"><code>04/02/2000</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>4/5/1910</code></td>
          <td width="66%"><code>04/05/1910</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>4/5/10</code></td>
          <td width="66%"><code>04/05/2010</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>4/5/11</code></td>
          <td width="66%"><code>04/05/2011<br>
            <font size="1"> note: If the entered 2 digit year number is less than
            '10', then the result year is 2000 + that number. If that entered
            number is greater than '10', then the result year is 1900 + that number.
            </font> </code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>2/1</code></td>
          <td width="66%"><code>02/01/2000</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>1/1</code></td>
          <td width="66%"><code>01/01/2001 <br>
            <font size="1"> note: If the entered month is less than 3 months from
            the current month and no year is specified, then the result is the
            current year plus one. </font> </code></td>
        </tr>
      </table>
    </td>
    <td width="33%" rowspan="2">
      <table width="100%" border="1" cellspacing="0" bordercolor="#CCCCCC">
        <tr align="center" bgcolor="#CCCCCC">
          <td colspan="2"><b><font size="4">Time</font></b></td>
        </tr>
        <tr align="center">
          <td width="34%"> <b>Entered Value</b> </td>
          <td width="66%"> <b>Result </b></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>5</code></td>
          <td width="66%"><code>05:00 PM</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>9</code></td>
          <td width="66%"><code>09:00 AM<br>
            <font size="1">note: If the entered hour is greater than or equal
            to '7', then the result time is in the morning (i.e., AM), else the
            time is in the afternoon (i.e., PM).</font></code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>9:30</code></td>
          <td width="66%"><code>09:30 AM</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>5:45</code></td>
          <td width="66%"><code>05:45 AM</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>6a</code></td>
          <td width="66%"><code>06:00 AM</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>9p</code></td>
          <td width="66%"><code>09:00 PM</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>1100</code></td>
          <td width="66%"><code>11:00 AM</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>1300</code></td>
          <td width="66%"><code>1:00 PM</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>21:00</code></td>
          <td width="66%"><code>09:00 PM</code></td>
        </tr>
      </table>
    </td>
    <td width="33%">
      <table width="100%" border="1" cellspacing="0" bordercolor="#CCCCCC">
        <tr align="center" bgcolor="#CCCCCC">
          <td colspan="2"> <b><font size="4">Date/Time Stamp</font></b><br>
            <font size="1">note: Same rules as for Date and Time, but combined
            with a space separator.</font> </td>
        </tr>
        <tr align="center">
          <td width="34%"> <b>Entered Value</b> </td>
          <td width="66%"> <b>Result </b></td>
        </tr>
        <tr align="center">
          <td width="34%"><code> 0 5</code></td>
          <td width="66%"><code>04/01/2000 05:00 AM</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>15 9</code></td>
          <td width="66%"><code>04/15/2000 09:00 AM</code></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr valign="top">
    <td width="33%">
      <table width="100%" border="1" cellspacing="0" bordercolor="#CCCCCC">
        <tr align="center" bgcolor="#CCCCCC">
          <td colspan="2"> <b><font size="4">Social Security Number</font></b>
          </td>
        </tr>
        <tr align="center">
          <td width="34%"> <b>Entered Value</b> </td>
          <td width="66%"> <b>Result </b></td>
        </tr>
        <tr align="center">
          <td width="34%"><code> 123456789</code></td>
          <td width="66%"><code>123-45-6789</code></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr valign="top">
    <td colspan="2">
      <table width="100%" border="1" cellspacing="0" bordercolor="#CCCCCC">
        <tr align="center" bgcolor="#CCCCCC">
          <td colspan="2"> <b><font size="4">Zip Code</font></b> </td>
        </tr>
        <tr align="center">
          <td width="34%"> <b>Entered Value</b> </td>
          <td width="66%"> <b>Result </b></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>12345</code></td>
          <td width="66%"><code>12345</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>123456789</code></td>
          <td width="66%"><code>12345-6789</code></td>
        </tr>
        <tr align="center">
          <td width="34%"><code>12345-6789</code></td>
          <td width="66%"><code>12345-6789</code></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr valign="top">
    <td colspan="3">
      <table width="100%" border="1" cellspacing="0" bordercolor="#CCCCCC">
        <tr align="center" bgcolor="#CCCCCC">
          <td colspan="2"> <b><font size="4">Telephone</font></b> </td>
        </tr>
        <tr align="center">
          <td width="38%"> <b>Entered Value</b> </td>
          <td width="62%"> <b>Result </b></td>
        </tr>
        <tr align="center">
          <td width="38%"><code> 1234567890</code></td>
          <td width="62%"><code>123-456-7890</code></td>
        </tr>
        <tr align="center">
          <td width="38%"><code> 123456789012345</code></td>
          <td width="62%"><code>123-456-7890 x12345</code></td>
        </tr>
        <tr align="center">
          <td width="38%"><code> 1234567890 extension 12345</code></td>
          <td width="62%"><code>123-456-7890 x12345</code></td>
        </tr>
        <tr align="center">
          <td width="38%"><code> 1 23456 7890 x 12345</code></td>
          <td width="62%"><code>123-456-7890 x12345</code></td>
        </tr>
        <tr align="center">
          <td width="38%"><code> 1234567890 p12345</code></td>
          <td width="62%"><code>123-456-7890 p12345</code></td>
        </tr>
      </table>
    </td>
  </tr>
</table>
		</TD>
	</TR>
</TABLE>

	});

	return 1;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
	$self->addLocatorLinks(
			['Help', '/help'],
		);
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems, $handleExec) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	$handleExec = 1 unless defined $handleExec;

	#$self->param('_islookup', 1) if $rsrc eq 'lookup';
	#$self->param('_pm_view', $pathItems->[0]);
	#$self->param('search_type', $pathItems->[1]) unless $self->param('search_type');
	#$self->param('search_expression', $pathItems->[2]) unless $self->param('search_expression');
	#$self->param('search_compare', 'contains') unless $self->param('search_compare');
	#$self->param('execute', 'Go') if $handleExec && $pathItems->[2];  # if an expression is given, do the find immediately

	$self->printContents();

	return 0;
}

1;
