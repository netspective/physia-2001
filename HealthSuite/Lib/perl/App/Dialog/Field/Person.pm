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
	$params{maxLength} = 32;

	return CGI::Dialog::Field::new($type, %params);
}

sub isValid
{
	my ($self, $page, $validator) = @_;

	my $command = $page->property(CGI::Dialog::PAGEPROPNAME_COMMAND . '_' . $validator->id());

	return () if $command ne 'add';

	if($self->SUPER::isValid($page, $validator))
	{
		my $value = $page->field($self->{name});
		$self->invalidate($page, "$self->{caption} '$value' already exists.")
			if $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $value);
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
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use Schema::Utilities;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);
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
		$params{maxLength} = 32 unless $params{maxLength};

		my $lookupType = 'person';
		if(! $params{findPopup})
		{
			if(my $types = $params{types})
			{
				if (scalar(@$types) > 1)
				{
					if (! grep { $_ eq 'patient'} @$types)
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
					$lookupType = (grep {$_ eq $$types[0]} ('Physician', 'Nurse', 'Staff'))[0] || 'person';
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

	if($self->SUPER::isValid($page, $validator))
	{
		if (my $value = $page->field($self->{name}))
		{
			return 1 if $value =~ /_\d$/;
			return 1 if $value =~ /,/;

			my $dlgName = 'patient';
			if (my $types = $self->{types})
			{
				foreach my $personType ('Guarantor', 'Patient', 'Staff', 'Nurse', 'Physician')
				{
					$dlgName = $personType if grep { $_ eq $personType } @$types;
				}
				my $createPersonHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-" . lc($dlgName) . "/$value');";
				$dlgName = "Responsible Party" if $dlgName eq "Guarantor";
				$self->invalidate($page, qq{
					$self->{caption} '$value' does not exist.<br>
					<img src="/resources/icons/arrow_right_red.gif">
					<a href="$createPersonHref">Create $dlgName ID '$value' now</a>
					})
					unless $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $value);
			}
		}
	}
	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '12/29/1999', 'MAF',
		'Dialog/Lookups',
		'Fixed lookup for person.'],
);

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

	$params{caption} = 'Complete Name<br>(last/first/middle/suffix)' unless $params{caption};
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
