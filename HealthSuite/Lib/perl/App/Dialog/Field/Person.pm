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
	my $lssn = length($ssn);
	my $L4SSN = substr($ssn,$lssn-4,4);
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
	push (@possible, uc($FIFN . substr($lastname,0,13) . $L2DOB)) if $ldob > 2;
	#First initial + lastname + last 4 digits of social security
	push (@possible, uc($FIFN . substr($lastname,0,12) . $L4SSN)) if $lssn > 2;
	#First initial + middle initial + lastname + year of birth
	push (@possible, uc($FIFN . $MI . substr($lastname,0,13) . $L2DOB)) if $ldob > 2;
	#First initial + middle initial + lastname + last 4 digits of social security
	push (@possible, uc($FIFN . $MI . substr($lastname,0,12) . $L4SSN)) if $lssn > 2;
	#First initial + lastname + year of birth + last 4 digits of SSN
	push (@possible, uc($FIFN . substr($lastname,0,10) . $L2DOB . $L4SSN)) if $lssn > 2;
	#First initial + middle initial + lastname + 4 digit random number
	push (@possible, uc($FIFN . $MI . substr($lastname,0,10) . int(10000*rand)));
	push (@possible, uc($FIFN . $MI . substr($lastname,0,10) . int(10000*rand)));
	push (@possible, uc($FIFN . $MI . substr($lastname,0,10) . int(10000*rand)));





	#Check array of possibles for availability, stop after three are OK

	my $goodcount = 0;
	my $count = 0;
	my @goodones = ();
	while ($goodcount < 3 && $count < scalar @possible) {
		$possible[$count] =~ s/ //;
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

use vars qw(@ISA @PERSON_TYPES);
@ISA = qw(CGI::Dialog::Field);

@PERSON_TYPES = ('Superuser', 'Administrator', 'Physician', 'Referring-Doctor', 'Nurse', 'Staff', 'Guarantor', 'Patient', 'Insured-Person');

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
	$params{incSimpleName}=0 unless exists $params{incSimpleName};

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
		$params{type} = 'identifier' unless $params{type};
		$params{size} = 16 unless $params{size};
		$params{maxLength} = 16 unless $params{maxLength};

		my $lookupType = 'person';
		if(! $params{findPopup})
		{
			if(my $types = $params{types})
			{
				if (scalar(@$types) > 1)
				{
					if((! grep { $_ eq 'Patient'} @$types) && (grep { $_ eq 'Physician'} @$types) && (grep { $_ eq 'Referring-Doctor'} @$types))
					{
						$lookupType = 'physician-ref';
					}
					elsif (! grep { $_ eq 'Patient'} @$types)
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
					$lookupType = (grep {$_ eq $$types[0]} @PERSON_TYPES)[0] || 'person';
				}
			}
		}
		$params{findPopup} = "/lookup/\l$lookupType/id" unless $params{findPopup};

		my $addType = 'patient';
		if(! $params{addPopup})
		{
			$addType = $params{addType} || $params{types}->[0];
		}
		$params{addPopup} = "/org/#session.org_id#/dlg-add-$addType" unless $params{addPopup};
		$params{addPopupControlField} = '_f_person_id' unless exists $params{addPopupControlField};
	}
	return CGI::Dialog::Field::new($type, %params);
}

sub isPseudoResource
{
	my ($self, $page, $value) = @_;

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

		return 1 if grep(/^${stem}$/, @rovingPhysicians);
	}
}

sub isValid
{
	my ($self, $page, $validator) = @_;
	return 0 unless $self->SUPER::isValid($page, $validator);

	# If they entered a value
	if (my $value = $page->field($self->{name}))
	{
		# Require one of ther person types specified or any valid person type
		my $types = defined $self->{types} ? $self->{types} : \@PERSON_TYPES;
		#unshift @{$types}, 'Administrator' unless grep {$_ eq 'Administrator'} @{$types};
		#unshift @{$types}, 'SuperUser' unless grep {$_ eq 'Administrator'} @{$types};

		my @idList = split(/\s*,\s*/, $value);

		for my $id (@idList)
		{
			next if $self->isPseudoResource($page, $id);
			next unless $id;
			my $capId = uc($id);

			# Build an appropriate Invalidation Message for use if the requested ID doesn't exist
			my $doesntExistMsg = qq{$self->{caption} '$id' does not exist. &nbsp; Add '$id' as a };
			if ($self->{useShortForm})
			{
				my $createPersonHref = qq{javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-shortformPerson/$id');};
				$doesntExistMsg .= qq{<a href="$createPersonHref">Patient</a> };
			}
			else
			{
				foreach $types (@$types)
				{
					my $createPersonHref;

					$createPersonHref = $types eq 'Insured-Person' ? "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-" . 'insured-Person' . "/$id');"
															:"javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-" . lc($types) . "/$id');" ;
					$doesntExistMsg .= qq{<a href="$createPersonHref">$types</a>, };
				}
				$doesntExistMsg =~ s/, $//;
				$doesntExistMsg =~ s/, ([^,]+)$/, or a $1/;
			}

			# If the person record doesn't exist (in any org)...
			unless($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $capId))
			{
				$self->invalidate($page, $doesntExistMsg);
			}
			# Else (the person exists) unless the person isn't in their org...
			elsif(! $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selCategory', $capId, $page->session('org_internal_id')))
			{
				$self->invalidate($page, "You do not have permission to select people outside of your organization.");
			}
			# Else (the person exists in our org)
			else
			{
				#my $categories = $STMTMGR_PERSON->getSingleValueList($page, STMTMGRFLAG_NONE, 'selCategory', $capId, $page->session('org_internal_id'));

				# Unless one of the person types requested matches one of the categories that this person is...
				#unless (grep {my $type = $_; grep {$_ eq $type} @$categories} @$types)
				#{
				#	my $typesStr = join(', ', @$types);
				#	$self->invalidate($page, qq{'$id' is not a $typesStr in this Org.});
				#}
			}
		}
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}



#
#Adds simple name next to patient person_id
sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $html;
	if ((grep {$_ eq 'Patient'} @{$self->{types}})||$self->{incSimpleName})
	{
		#$page->addError("Include");
		my $value = $page->field($self->{name});
		#Get the name for the person
		my $patData = $STMTMGR_PERSON->getSingleValue($page,STMTMGRFLAG_NONE,'selPersonSimpleNameById',$value);
		$self->{postHtml} =qq{<INPUT TYPE="HIDDEN" NAME="_f_$self->{name}_simple_name_h"  TYPE='text' size=30 STYLE="color:red" VALUE='$patData'>
			<SPAN ID="_f_$self->{name}_simple_name_s">$patData </SPAN>};
	}
	$html = $self->SUPER::getHtml($page, $dialog, $command, $dlgFlags);
	return $html;
};

##############################################################################
package App::Dialog::Field::MultiPerson::ID;
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

use vars qw(@ISA @PERSON_TYPES);
@ISA = qw(CGI::Dialog::Field);

@PERSON_TYPES = ('Physician', 'Nurse', 'Staff', 'Guarantor', 'Patient', 'Insured-Person');

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
	$params{type} = 'text';
	$params{size} = 40 unless exists $params{size};
	$params{maxLength} = 255 unless exists $params{maxLength};
	$params{options} |=FLDFLAG_UPPERCASE;
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
		my $lookupType = 'person';
		if(! $params{findPopup})
		{
			if(my $types = $params{types})
			{
				if (scalar(@$types) > 1)
				{
					if((! grep { $_ eq 'Patient'} @$types) && (grep { $_ eq 'Physician'} @$types) && (grep { $_ eq 'Referring-Doctor'} @$types))
					{
						$lookupType = 'physician-ref';
					}
					elsif (! grep { $_ eq 'Patient'} @$types)
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
					$lookupType = (grep {$_ eq $$types[0]} @PERSON_TYPES)[0] || 'person';
				}
			}
		}
		$params{findPopup} = "/lookup/\l$lookupType/id" unless $params{findPopup};

		my $addType = 'patient';
		if(! $params{addPopup})
		{
			$addType = $params{addType} || $params{types}->[0];
		}
		$params{addPopup} = "/org/#session.org_id#/dlg-add-$addType" unless $params{addPopup};
		$params{addPopupControlField} = '_f_person_id' unless exists $params{addPopupControlField};
	}

	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;
	return 0 unless $self->SUPER::isValid($page, $validator);

	# If they entered a value
	if (my $value = $page->field($self->{name}))
	{

		# Require one of ther person types specified or any valid person type
		my $types = defined $self->{types} ? $self->{types} : \@PERSON_TYPES;


		# If the person record doesn't exist (in any org)...
		my @perList = split(/\s*,\s*/,$value);
		foreach my $id (@perList)
		{
			next if $id eq '';
			$id = uc($id);
			# Build an appropriate Invalidation Message for use if the requested ID doesn't exist
			my $doesntExistMsg = qq{$self->{caption} '$id' does not exist. &nbsp; Add '$id' as a };
			foreach $types (@$types)
			{
				my $createPersonHref;
				$createPersonHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-" . lc($types) . "/$id');";
				$doesntExistMsg .= qq{<a href="$createPersonHref">$types</a>, };
			}
			$doesntExistMsg =~ s/, $//;
			$doesntExistMsg =~ s/, ([^,]+)$/, or a $1/;
			unless($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $id))
			{
				$self->invalidate($page, $doesntExistMsg);
			}
			# Else (the person exists) unless the person isn't in their org...
			elsif(! $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selCategory', $id, $page->session('org_internal_id')))
			{
				$self->invalidate($page, "$id does not belong to your organization.");
			}
			# Else (the person exists in our org)
			else
			{
				my $categories = $STMTMGR_PERSON->getSingleValueList($page, STMTMGRFLAG_NONE, 'selCategory', $id, $page->session('org_internal_id'));

				# Unless one of the person types requested matches one of the categories that this person is...
				unless (grep {my $type = $_; grep {$_ eq $type} @$categories} @$types)
				{
					my $typesStr = join(', ', @$types);
					$self->invalidate($page, qq{'$id' is not a $typesStr in this Org.});
				}
			}
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

	my $lastNameOptions = ($params{options} == FLDFLAG_HOME) ? FLDFLAG_REQUIRED | FLDFLAG_HOME : FLDFLAG_REQUIRED;

	$params{fields} = [
			#new CGI::Dialog::Field(name => 'name_prefix', type => 'select', selOptions => ';Mr.;Mrs.;Ms.;Dr.', caption => 'Prefix'),
			new CGI::Dialog::Field(name => 'name_last', caption => 'Last Name',	options => $lastNameOptions, size => 16),
			new CGI::Dialog::Field(name => 'name_first', caption => 'First Name', options => FLDFLAG_REQUIRED, size => 12),
			new CGI::Dialog::Field(name => 'name_middle', caption => 'Middle Name',	size => 8),
			new CGI::Dialog::Field(name => 'name_suffix', caption => 'Suffix', size => 16),

		];
	return CGI::Dialog::MultiField::new($type, %params);
}

1;
