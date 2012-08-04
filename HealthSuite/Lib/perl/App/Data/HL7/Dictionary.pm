##############################################################################
package App::Data::HL7::Dictionary;
##############################################################################

use strict;
use Exporter;
use XML::Parser;
use vars qw(%HL7_APPLICATIONS @EXPORT);

@EXPORT = qw(%HL7_APPLICATIONS HL7_OPTIONALITY HL7_FIELDDEFN_LOCATION);

#
# the key for %HL7_APPLICATIONS is an application name
# the value is an array reference to application information
#
# for HL7_APPINFO_FIELDEFNS
#   the key is field definition name (human-readable)
#   the value is an array reference to location, etc (HL7_FIELDDEFN_*)
#
%HL7_APPLICATIONS = ();

use constant HL7_APPINFO_FIELDDEFNS => 0;
use constant HL7_FIELDDEFN_LOCATION => 0;

sub getAppInfo
{
	my ($appName) = @_;
	
	unless(exists $HL7_APPLICATIONS{$appName})
	{
		my $appInfo = ($HL7_APPLICATIONS{$appName} = []);
		$appInfo->[HL7_APPINFO_FIELDDEFNS] = {};
	}
	
	return $HL7_APPLICATIONS{$appName};
}

sub getFieldInfo
{
	my ($appName, $fieldName) = @_;
	
	if(my $appInfo = $HL7_APPLICATIONS{$appName})
	{
		return $appInfo->[HL7_APPINFO_FIELDDEFNS]->{$fieldName} if exists $appInfo->[HL7_APPINFO_FIELDDEFNS]->{$fieldName};
	}
	if(my $appInfo = $HL7_APPLICATIONS{'default'})
	{
		return $appInfo->[HL7_APPINFO_FIELDDEFNS]->{$fieldName};
	}
	return undef;
}

use vars qw($IN_DICTIONARY $ACTIVE_APPLICATION $ACTIVE_FIELDDEFNS);

$IN_DICTIONARY = 0;
$ACTIVE_APPLICATION = undef;
$ACTIVE_FIELDDEFNS = undef;

sub handle_start
{
	my ($expat, $element) = (shift, shift);
	my (%attrs) = @_;
	
	if($element eq 'hl7-dictionary')
	{
		$IN_DICTIONARY = 1;
	}
	elsif($element eq 'field-defns' && $IN_DICTIONARY)
	{
		$ACTIVE_APPLICATION = getAppInfo($attrs{application});
		$ACTIVE_FIELDDEFNS = $ACTIVE_APPLICATION->[HL7_APPINFO_FIELDDEFNS];
	}
	elsif($element eq 'field-defn' && $ACTIVE_FIELDDEFNS)
	{
		print STDERR "Duplicate field definition encountered ()\n" if exists $ACTIVE_FIELDDEFNS->{$attrs{name}};
		$ACTIVE_FIELDDEFNS->{$attrs{name}} = [$attrs{location}];
	}
}

sub handle_end
{
	my ($expat, $element) = @_;
	
	if($element eq 'hl7-dictionary')
	{
		$IN_DICTIONARY = 0;
	}
	elsif($element eq 'field-defns' && $IN_DICTIONARY)
	{
		$ACTIVE_APPLICATION = undef;
		$ACTIVE_FIELDDEFNS = undef;
	}	
}

my $parser = new XML::Parser(Handlers => { Start => \&handle_start, End => \&handle_end });
$parser->parse(*DATA);
undef $parser;

1;

__DATA__
<mdl>
	<hl7-dictionary>
		<field-defns application="default">
			<field-defn name="Sending Application" location="MSH-3"/>
			<field-defn name="Sending Facility" location="MSH-4"/>
			<field-defn name="Receiving Application" location="MSH-5"/>
			<field-defn name="Receiving Facility" location="MSH-6"/>
			<field-defn name="Message Type" location="MSH-9-1"/>
		
			<field-defn name="Patient ID" location="PID-3"/>
			<field-defn name="Patient Name" location="PID-6"/>
			<field-defn name="Patient Last Name" location="PID-6-1"/>
			<field-defn name="Patient First Name" location="PID-6-2"/>
			<field-defn name="Patient DOB" location="PID-8"/>
			<field-defn name="Patient Gender" location="PID-9"/>
			<field-defn name="Patient SSN" location="PID-20"/>
			
			<field-defn name="Ordering Physician" location="OBR-17"/>
			
			<field-defn name="Test Control No." location="OBR-4"/>
			<field-defn name="Test Name" location="OBR-5"/>
			<field-defn name="Test Specimen Date" location="OBR-8"/>
			<field-defn name="Test Report Date" location="OBR-23"/>
			
		</field-defns>
		
		<!-- LABCORP definitions -->
		<field-defns application="LCS">
			<field-defn name="Ordering Physician" location="ORC-13"/>
		</field-defns>
	</hl7-dictionary>
</mdl>