##############################################################################
package App::Dialog::Field::Person::ID::New;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Person;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use Schema::Utilities;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	#
	# you can pass in a "types => ['x', 'y']" and "notTypes => ['a']"
	# to restrict/expand the selection
	#

	$params{name} = 'person_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	$params{type} = 'identifier';
	$params{size} = 16;
	$params{maxLength} = 16;
	$params{hints}="To use the ID autosuggestion feature, leave this field blank" unless exists $params{hints};

	return CGI::Dialog::Field::new($type, %params);
}

sub autoSuggest
{
	my ($self, $page, $validator) = @_;
	my $name = $self->{name};

	# First, retrieve names, ssn & birthdate into local variables
	my $firstname = $page->field('name_first');
	my $MI = substr($page->field('name_middle'),0,1) || "X";
	my $lastname = $page->field('name_last');
	my $ssn = $page->field('ssn');
 	my $DOB = $page->field('date_of_birth');

	#Create some commonly used intermediaries
	#First initial of first name
	my $FIFN = substr($firstname,0,1);
	#Last 4 digits of social security number
	my $L4SSN = substr($ssn,(length($ssn)-4),4);
	#Birthyear (last two digits of date_of_birth string)
	my $ldob = length($DOB);
	my $L2DOB = substr($DOB,$ldob-2,2);


	#Generate array of possibles
	my @possible = ();
	#First initial of first name plus last name, total not greater than 16 characters
	push(@possible,uc($FIFN . substr($lastname,0,15)));
	#First initial of first name plus middle initial plus last name, total not greater than 16 characters
	push (@possible, uc($FIFN . $MI . substr($lastname,0,14)));
	#Lastname + firstname
	push (@possible, uc(substr($lastname . $firstname,0,16)));
	#First initial + lastname + year of birth
	push (@possible, uc($FIFN . substr($lastname,0,13) . $L2DOB)) if(defined $DOB);
	#First initial + lastname + last 4 digits of social security
	push (@possible, uc($FIFN . substr($lastname,0,12) . $L4SSN)) if(defined $ssn);
	#First initial + middle initial + lastname + year of birth
	push (@possible, uc($FIFN . $MI . substr($lastname,0,13) . $L2DOB)) if(defined $DOB);
	#First initial + lastname + last 4 digits of social security
	push (@possible, uc($FIFN . $MI . substr($lastname,0,12) . $L4SSN)) if(defined $ssn);
	#First initial + lastname + year of birth + last 4 digits of SSN
	push (@possible, uc($FIFN . substr($lastname,0,10) . $L2DOB . $L4SSN)) if(defined $ssn);
	#First initial + middle initial + lastname + 4 digit random number
	push (@possible, uc($FIFN . $MI . substr($lastname,0,10) . int(10000*rand)));
	push (@possible, uc($FIFN . $MI . substr($lastname,0,10) . int(10000*rand)));
	push (@possible, uc($FIFN . $MI . substr($lastname,0,10) . int(10000*rand)));





	#Check array of possibles for availability, stop after three are OK

	my $goodcount = 0;
	my $count = 0;
	my @goodones = ();
	while ($goodcount < 3 && $count < scalar @possible) {
		if (! $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $possible[$count]) ){
			$goodones[$goodcount] = $possible[$count];
			$goodcount = $goodcount + 1;
			$count = $count + 1;
			}
		else {
			$count = $count + 1;
			}
		}

return qq{
	<input type="radio" name="_f_radio$name" value="$goodones[0]"
				onClick="document.dialog._f_radioperson_id[0].checked=true; document.dialog._f_person_id.value=this.value"
									> $goodones[0] &nbsp
		<input type="radio" name="_f_radio$name" value="$goodones[1]"
				onClick="document.dialog._f_person_id.value=this.value;	document.dialog._f_radioperson_id[1].checked=true"> $goodones[1] &nbsp
		<input type="radio" name="_f_radio$name" value="$goodones[2]"
				onClick="document.dialog._f_person_id.value=this.value;	document.dialog._f_radioperson_id[2].checked=true"> $goodones[2] &nbsp

	};


}



sub isValid
{
	my ($self, $page, $validator) = @_;
	my $suggestion = " ";

	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $validator->id());

	return () if $command ne 'add';

	if($self->SUPER::isValid($page, $validator))
	{

		my $value = $page->field($self->{name});
		my $suggest = 0;
		unless($value)
		{
			$suggest = 1;
		}
		elsif($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selRegistry', $value))
		{
			$self->invalidate($page, "$self->{caption} '$value' already exists.");
			$suggest = 1;
		}
		if($suggest)
		{
			my $suggestion = $self->autoSuggest($page,$validator);
			$self->invalidate($page, "Please select an ID:<BR>$suggestion");
		}
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

##############################################################################
package App::Dialog::Field::Person::ID;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Scheduling;
use App::Statements::Org;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use Schema::Utilities;

use vars qw(@ISA);
@ISA = qw(CGI::Dialog::Field);

use enum qw(:IDENTRYSTYLE_ TEXT SELECT);

sub new
{
	my ($type, %params) = @_;

	#
	# you can pass in a "types => ['x', 'y']" and "notTypes => ['a']"
	# to restrict/expand the selection
	#

	$params{idEntryStyle} = IDENTRYSTYLE_TEXT unless exists $params{idEntryStyle};
	$params{name} = 'person_id' unless $params{name};

	$params{options} = 0 unless exists $params{options};
	$params{options} |= FLDFLAG_IDENTIFIER;

	if($params{idEntryStyle} == IDENTRYSTYLE_SELECT)
	{
		$params{type} = 'foreignKey';
		$params{fKeyTable} = 'PERSON outer';
		$params{fKeySelCols} = 'PERSON_ID, SIMPLE_NAME';
		$params{fKeyValueCol} = 0;
		$params{fKeyDisplayCol} = 1;
		$params{fKeyOrderBy} = 'name_last, name_first';

		my $typeCond =
			$params{types} || $params{notTypes} ?
				Schema::Utilities::createInclusionExclusionConds('pc.MEMBER_NAME', $params{types}, $params{notTypes}, 1) :
				'';
		$params{fKeyWhere} = "exists (select 1 from PERSON inner, PERSON_CATEGORY pc where outer.PERSON_ID = inner.PERSON_ID and inner.PERSON_ID = pc.PARENT_ID and $typeCond)" if $typeCond;
	}

	else
	{
		$params{type} = 'identifier';
		$params{size} = 16 unless $params{size};
		$params{maxLength} = 16 unless $params{maxLength};

		my $lookupType = 'person';
		if(! $params{findPopup})
		{
			if(my $types = $params{types})
			{
				if (scalar(@$types) > 1)
				{
					if (! grep { $_ eq 'Patient'} @$types)
					{
						$lookupType = 'associate';
					}
					else
					{
						$lookupType = 'person';
					}
				}
				elsif (scalar(@$types))
				{
					$lookupType = (grep {$_ eq $$types[0]} ('Physician', 'Nurse', 'Staff', 'Guarantor', 'Patient'))[0] || 'person';
				}
			}
		}
		$params{findPopup} = "/lookup/\l$lookupType/id" unless $params{findPopup};
	}
	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;
	return 0 unless $self->SUPER::isValid($page, $validator);

	if (my $value = $page->field($self->{name}))
	{
		if ($value =~ /_\d$/ && $self->{types} && $self->{types}->[0] eq 'Physician')
		{
			my $rovingHash = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
				'selRovingPhysicianTypes');

			my @rovingPhysicians = ();
			for (@$rovingHash)
			{
				push(@rovingPhysicians, $_->{caption});
			}
			my $stem = $value;
			$stem =~ s/_\d$//;
			return 1 if grep(/${stem}/, @rovingPhysicians);
		}

		return 1 if $value =~ /,/;

		my $dlgName = 'patient';
		if (my $types = $self->{types})
		{
			foreach my $personType ('Guarantor', 'Patient', 'Staff', 'Nurse', 'Physician')
			{
				$dlgName = $personType if grep { $_ eq $personType } @$types;
			}
			my $invMsg = qq{$self->{caption} '$value' does not exist. &nbsp; Add '$value' as a };
			foreach $types (@$types)
			{
				my $createPersonHref;
				if ($self->{useShortForm})
				{
					$createPersonHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-shortformPerson/$value');" ;
				}
				else
				{
					$createPersonHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-" . lc($types) . "/$value');";
					#$types = "Responsible Party" if $types eq "Guarantor";
				}
				unless ($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $value))
				{
					$invMsg .= qq{<a href="$createPersonHref">$types</a> }
				}
			}

			if ($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selCategory', $value,
				$page->session('org_internal_id')))
			{
				if ( ($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selRegistry', $value))
					&& ((my $category = $self->{types}->[0]) ne 'Patient') )
				{
					$self->invalidate($page, qq{'$value' is not a $category in this Org.})
						unless $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,
						'selVerifyCategory', $value, $page->session('org_internal_id'), $category);
				}
			}
			else
			{
				$self->invalidate($page, $invMsg);
			}
		}
		else
		{
			my $orgIntId = $page->session('org_internal_id');
			$self->invalidate($page, "You do not have permission to select people outside of your organization.")
			unless $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selCategory', $value, $orgIntId) ;
		}
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

##############################################################################
package App::Dialog::Field::Person::Name;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use Schema::Utilities;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::MultiField);

#use enum qw(:IDENTRYSTYLE_ TEXT SELECT);

sub new
{
	my ($type, %params) = @_;

	#$params{caption} = 'Complete Name<br>(last/first/middle/suffix)' unless $params{caption};
	$params{options} = 0 unless exists $params{options};
	$params{name} = 'person_id' unless $params{name};

	$params{fields} = [
			#new CGI::Dialog::Field(name => 'name_prefix', type => 'select', selOptions => ';Mr.;Mrs.;Ms.;Dr.', caption => 'Prefix'),
			new CGI::Dialog::Field(name => 'name_last', caption => 'Last Name',	options => FLDFLAG_REQUIRED, size => 16),
			new CGI::Dialog::Field(name => 'name_first', caption => 'First Name', options => FLDFLAG_REQUIRED, size => 12),
			new CGI::Dialog::Field(name => 'name_middle', caption => 'Middle Name',	size => 8),
			new CGI::Dialog::Field(name => 'name_suffix', caption => 'Suffix', size => 16),

		];
	return CGI::Dialog::MultiField::new($type, %params);
}

1;
