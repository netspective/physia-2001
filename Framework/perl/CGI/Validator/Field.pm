##############################################################################
package CGI::Validator::Field;
##############################################################################

use strict;
use Exporter;
use Date::Manip;
use vars qw(@ISA @CHANGELOG);

use vars qw(@ISA %VALIDATE_TYPE_DATA @EXPORT);

# When changing the FLDFLAG options, you must also change them in page.js !!!!!
use enum qw(BITMASK:FLDFLAG_
	INVISIBLE CONDITIONAL_INVISIBLE
	READONLY CONDITIONAL_READONLY
	REQUIRED
	IDENTIFIER UPPERCASE UCASEINITIAL LOWERCASE TRIM
	FORMATVALUE CUSTOMVALIDATE
	CUSTOMDRAW NOBRCAPTION PERSIST
	HOME SORT
	PREPENDBLANK DEFAULTCAPTION
	);

use constant FLDFLAGS_DEFAULT => FLDFLAG_TRIM;
use constant FLDFLAGS_DISABLING_VALIDATION => FLDFLAG_INVISIBLE | FLDFLAG_READONLY;
use constant FLDFLAGS_REQUIRING_VALIDATION => FLDFLAG_REQUIRED | FLDFLAG_IDENTIFIER | FLDFLAG_UPPERCASE | FLDFLAG_TRIM | FLDFLAG_UCASEINITIAL | FLDFLAG_LOWERCASE | FLDFLAG_FORMATVALUE | FLDFLAG_CUSTOMVALIDATE;

#
# export only those flags that should be called from the outside
# note: If any flag are changed, please update page.js for mirror image.
#
@ISA = qw(Exporter);
@EXPORT = qw(
	FLDFLAG_INVISIBLE FLDFLAG_CONDITIONAL_INVISIBLE
	FLDFLAG_READONLY FLDFLAG_CONDITIONAL_READONLY
	FLDFLAG_REQUIRED
	FLDFLAG_IDENTIFIER
	FLDFLAG_TRIM
	FLDFLAG_UPPERCASE
	FLDFLAG_UCASEINITIAL
	FLDFLAG_LOWERCASE
	FLDFLAG_CUSTOMDRAW
	FLDFLAG_NOBRCAPTION
	FLDFLAG_PERSIST
	FLDFLAG_HOME
	FLDFLAG_SORT
	FLDFLAG_PREPENDBLANK
	FLDFLAG_DEFAULTCAPTION
	);

use constant ONKEYPRESSJS_DEFAULT    => 'return processKeypress_default(event)';
use constant ONKEYPRESSJS_FLOATNUM   => 'return processKeypress_float(event)';
use constant ONKEYPRESSJS_INTNUM     => 'return processKeypress_integer(event)';
use constant ONKEYPRESSJS_ALPHAONLY  => 'return processKeypress_alphaonly(event)';
use constant ONKEYPRESSJS_INTDASH    => 'return processKeypress_integerdash(event)';
use constant ONKEYPRESSJS_IDENTIFIER => 'return processKeypress_identifier(event)';
use constant ONBLUR_SSN              => 'validateChange_SSN(event)';
use constant ONBLUR_DATE           => 'validateChange_Date(event)';
use constant ONBLUR_STAMP          => 'validateChange_Stamp(event)';
use constant ONBLUR_TIME           => 'validateChange_Time(event)';
use constant ONBLUR_FLOATNUM       => 'validateChange_Float(event)';
use constant ONBLUR_PERCENTAGE     => 'validateChange_Percentage(event)';
use constant ONBLUR_CURRENCY       => 'validateChange_Currency(event)';
use constant ONBLUR_EMAIL          => 'validateChange_EMail(event)';
use constant ONBLUR_ZIP            => 'validateChange_Zip(event)';
use constant ONBLUR_PAGER          => 'validateChange_Pager(event)';
use constant ONBLUR_PHONE          => 'validateChange_Phone(event)';
use constant ONBLUR_URL            => 'validateChange_URL(event)';
use constant ONBLUR_LOWERCASE      => 'validateChange_LowerCase(event)';
use constant ONBLUR_UPPERCASE      => 'validateChange_UpperCase(event)';
use constant ONBLUR_UCASEINITIAL   => 'validateChange_UCaseInitial(event)';

%VALIDATE_TYPE_DATA =
		(
			'float' =>
				{
					regExp => '^\-?\d+(\.\d+)?$',
					message => "has an invalid number (format is [-]999.999).",
					maxLength => 16,
					onValidate => \&validateMinMax,
					onKeyPressJS => ONKEYPRESSJS_FLOATNUM,
					onBlurJS => ONBLUR_FLOATNUM,
				},
			'percentage' =>
				{
					regExp => '^\d+(\.\d+)?$',
					message => "has an invalid percentage (must be between 0.00% and 100.00%).",
					maxLength => 5,
					formatValue => sub
					{
						my ($self, $page, $validator, $value) = @_;
						return undef if ! $value;
						if($value =~ m/(\d+)\%/)
						{
							return $1;
						}
						return $value;
					},
					onValidate => sub
					{
						my ($self, $page, $validator, $value) = @_;
						return () if ! $value;
						return $value < 0 || $value > 100 ?
							("$self->{caption} must be between 0% and 100%") :
							();
					},
					onKeyPressJS => ONKEYPRESSJS_FLOATNUM,
					onBlurJS => ONBLUR_PERCENTAGE,
				},
			'currency' =>
				{
					regExp => '^\-?\d+(\.\d\d)?$',
					message => "has an invalid number (format is [-]999.99).",
					maxLength => 10,
					onValidate => \&validateMinMax,
					onKeyPressJS => ONKEYPRESSJS_FLOATNUM,
					onBlurJS => ONBLUR_CURRENCY,
				},
			'integer' =>
				{
					regExp => '^\d+$',
					message => "has an invalid number (format is 999).",
					maxLength => 8,
					onValidate => \&validateMinMax,
					onKeyPressJS => ONKEYPRESSJS_INTNUM,
				},
			'date' =>
				{
					message => "has an invalid date (format is 'MM/DD/YYYY').",
					maxLength => 50,
					size => 12,
					onValidate => \&validateDateStamp,
					formatValue => \&formatDate,
					defaultValue => UnixDate('today', '%m/%d/%Y'),
					onKeyPressJS => ONKEYPRESSJS_DEFAULT,
					onBlurJS => ONBLUR_DATE,
					# we don't have a onKeyPressJS because dates/times can be text (like today, tomorrow, etc)
				},
			'alphaonly' =>
				{
					regExp => '^[a-zA-Z]+$',
					message => "accepts only letters.",
					onValidate => \&validateAlphaOnly,
					onKeyPressJS => ONKEYPRESSJS_ALPHAONLY,
				},
			'time' =>
				{
					regExp => '^(\d\d):(\d\d)\s*([AaPp][Mm])$',
					message => "has an invalid time (format is 'HH:MM am' or 'HH:MM pm').",
					maxLength => 8,
					onValidate => \&validateTime,
					formatValue => \&formatTime,
					onKeyPressJS => ONKEYPRESSJS_DEFAULT,
					onBlurJS => ONBLUR_TIME,
				},
			'stamp' =>
				{
					message => "has an invalid duration (format is 'MM/DD/YYYY HH:MMa').",
					maxLength => 50,
					size => 20,
					onValidate => \&validateDateStamp,
					formatValue => \&formatStamp,
					defaultValue => UnixDate('now', '%m/%d/%Y %I:%M %p'),
					onKeyPressJS => ONKEYPRESSJS_DEFAULT,
					onBlurJS => ONBLUR_STAMP,
				},
			'ssn' =>
				{
					regExp => '^(\d\d\d)-?(\d\d)-?(\d\d\d\d)$',
					message => "has an invalid SSN (format is 999-99-9999).",
					maxLength => 11,
					formatValue => sub
					{
						my ($self, $page, $validator, $value) = @_;
						return undef if ! $value;
						$value =~ s/$self->{regExpValidate}/$1-$2-$3/;
						return $value;
					},
					onKeyPressJS => ONKEYPRESSJS_DEFAULT,
					onBlurJS => ONBLUR_SSN,
				},
			'phone' =>
				{
					regExp => '^(\d\d\d)[\.-]?(\d\d\d)[\.-]?(\d\d\d\d)( x.+)?$',
					message => "has an invalid phone number (format is 999-999-9999 or 999.999.9999 followed by an optional extension x9999).",
					maxLength => 24,
					size => 13,
					formatValue => sub
					{
						my ($self, $page, $validator, $value) = @_;
						return undef if ! $value;
						$value =~ s/$self->{regExpValidate}/$1-$2-$3/;
						$value .= $4;
						return $value;
					},
					onKeyPressJS => ONKEYPRESSJS_DEFAULT,
					onBlurJS => ONBLUR_PHONE,
				},
			'pager' =>
				{
					regExp => '^(\d\d\d)[\.-]?(\d\d\d)[\.-]?(\d\d\d\d)( PIN .+)?$',
					message => "has an invalid phone number (format is 999-999-9999 or 999.999.9999 followed by an optional PIN p9999).",
					maxLength => 24,
					size => 13,
					formatValue => sub
					{
						my ($self, $page, $validator, $value) = @_;
						return undef if ! $value;
						$value =~ s/$self->{regExpValidate}/$1-$2-$3/;
						$value .= $4;
						return $value;
					},
					onKeyPressJS => ONKEYPRESSJS_DEFAULT,
					onBlurJS => ONBLUR_PAGER,
				},
			'zipcode' =>
				{
					regExp => '^\d\d\d\d\d(\-\d\d\d\d)?$',
					message => "has an invalid zip code (format is 99999-9999).",
					maxLength => 10,
					onKeyPressJS => ONKEYPRESSJS_INTDASH,
					onBlurJS => ONBLUR_ZIP,
				},
			'email' =>
				{
					regExp => '^.+@.+\..+$',
					message => "has an invalid e-mail address (format is name\@company.com).",
					maxLength => 64,
					onKeyPressJS => ONKEYPRESSJS_DEFAULT,
					onBlurJS => ONBLUR_EMAIL,
				},
			'url' =>
				{
					regExp => '^.+://.+$',
					message => "has an invalid URL (format is http://xyz.com/abc).",
					maxLength => 255,
					size => 64,
					onKeyPressJS => ONKEYPRESSJS_DEFAULT,
					onBlurJS => ONBLUR_URL,
				},
			'hidden' =>
				{
					formatValue => sub
					{
						my ($self, $page, $validator, $value) = @_;
						return undef if ! $value;
						return $value;
					},
				},
			'identifier' =>
				{
					onKeyPressJS => ONKEYPRESSJS_IDENTIFIER
				},
			'lowercase' =>
				{
					onBlurJS => ONBLUR_LOWERCASE
				},
			'uppercase' =>
				{
					onBlurJS => ONBLUR_UPPERCASE
				},
			'ucaseinitial' =>
				{
					onBlurJS => ONBLUR_UCASEINITIAL
				}
		);

sub new
{
	my $class = shift;
	my %params = @_;

	$params{type} = 'text' unless $params{type};
	$params{name} = "$params{type}_field" unless $params{name};
	unless (exists $params{caption})
	{
		$params{caption} = $params{name};
		$params{flags} |= FLDFLAG_DEFAULTCAPTION;
	}
	$params{message} = '' unless $params{message};
	$params{maxLength} = -1 unless exists $params{maxLength};
	$params{flags} = FLDFLAGS_DEFAULT unless exists $params{flags};

	my $type = $params{type};
	if(my $typeInfo = $VALIDATE_TYPE_DATA{$type})
	{
		$params{size} = ($typeInfo->{size} || ($typeInfo->{maxLength} < 24 ? $typeInfo->{maxLength} : 24)) unless defined $params{size};
		$params{maxLength} = $typeInfo->{maxLength} unless $params{maxLength} ne '' && $params{maxLength} > 0;
		$params{regExpValidate} = $typeInfo->{regExp} if ! exists $params{regExpValidate} && $typeInfo->{regExp};
		$params{regExpInvalidMsg} = $params{message} ? $params{message} : "$params{caption} $typeInfo->{message}";
		$params{formatValue} = $typeInfo->{formatValue} if exists $typeInfo->{formatValue};
		$params{onValidate} = $typeInfo->{onValidate} if exists $typeInfo->{onValidate} && ! exists $params{onValidate};		
		#$params{defaultValue} = $typeInfo->{defaultValue} if exists $typeInfo->{defaultValue} && ! exists $params{defaultValue};
		
		# Check If default value exist for type and that the programmer did not provide a default value
		if (exists $typeInfo->{defaultValue} && ! exists $params{defaultValue}) 
		{
			#If type is a date get the current date from the system and use that as the default date other wise
			#use the default specified by the type
			$params{defaultValue} = $type ne 'date' ? $typeInfo->{defaultValue} : UnixDate('today', '%m/%d/%Y'); 
		};
		$params{onKeyPressJS} = $typeInfo->{onKeyPressJS} if exists $typeInfo->{onKeyPressJS} && ! exists $params{onKeyPressJS};
		$params{onBlurJS} = $typeInfo->{onBlurJS} if exists $typeInfo->{onBlurJS} && ! exists $params{onBlurJS};
	}
	$params{onKeyPressJS} = ONKEYPRESSJS_DEFAULT unless exists $params{onKeyPressJS};
	$params{size} = 24 unless $params{size};

	$params{requiredInvalidMsg} = (defined $params{caption} ? "$params{caption} is required (can not be blank)." : '') if ! exists $params{requiredInvalidMsg};
	$params{lengthInvalidMsg} = (defined $params{caption} && defined $params{maxLength} ? "$params{caption} is too long (can be at most $params{maxLength} characters)." : '') if ! exists $params{lengthInvalidMsg};
	$params{regExpInvalidMsg} = (defined $params{caption} && defined $params{regExpValidate} ? "Data formatting error in $params{caption}. Format is $params{regExpValidate}" : '')  if ! exists $params{regExpInvalidMsg};

	# other possibilities:
	#  $params{formatValue}, if defined is a subroutine used to format the data before validating
	#  $params{onValidate}, if defined is a subroutine used to do external validation
	#  $params{onValidateData} if defined is sent into onValidate subroutine as last param
	#  $params{minValue}, if defined is the minimum value
	#  $params{maxValue}, if defined is the maximum value

	# setup flags for easier run-time checking of options
	#
	$params{flags} |= $params{options} if (exists $params{options} && defined $params{options});
	$params{flags} |= FLDFLAG_CONDITIONAL_READONLY if (exists $params{readOnlyWhen} && defined $params{readOnlyWhen});
	$params{flags} |= FLDFLAG_CONDITIONAL_INVISIBLE if (exists $params{invisibleWhen} && defined $params{invisibleWhen});
	$params{flags} |= FLDFLAG_FORMATVALUE if (exists $params{formatValue} && defined $params{formatValue});
	$params{flags} |= FLDFLAG_CUSTOMVALIDATE if (exists $params{onValidate} && defined $params{onValidate});

	return bless \%params, $class;
}

# dialog flag-management functions:
#   $self->updateFlag($mask, $onOff) -- either turn on or turn off $mask
#   $self->setFlag($mask) -- turn on $mask
#   $self->clearFlag($mask) -- turn off $mask
#   $self->flagIsSet($mask) -- return true if any $mask are set

sub flagsAsStr
{
	my $str = unpack("B32", pack("N", $_[0]->{flags}));
	$str =~ s/^0+(?=\d)// if $_[1]; # otherwise you'll get leading zeros
	return $str;
}

sub updateFlag
{
	if($_[2])
	{
		$_[0]->{flags} |= $_[1];
	}
	else
	{
		$_[0]->{flags} &= ~$_[1];
	}
}

sub setFlag
{
	$_[0]->{flags} |= $_[1];
}

sub clearFlag
{
	$_[0]->{flags} &= ~$_[1];
}

sub flagIsSet
{
	return $_[0]->{flags} & $_[1];
}

sub needsValidation
{
	my ($self, $page, $validator, $valFlags) = @_;
	my $flags = $self->{flags};

	return 0 if $flags & FLDFLAGS_DISABLING_VALIDATION;
	return $flags & FLDFLAGS_REQUIRING_VALIDATION;
}

sub validateMinMax
{
	my ($self, $page, $validator, $value) = @_;
	return () if ! $value;

	my @errors = ();
	if(exists $self->{minValue})
	{
		push(@errors, "$self->{caption} must be greater than or equal to $self->{minValue}.")
			if $value < $self->{minValue};
	}
	if(exists $self->{maxValue})
	{
		push(@errors, "$self->{caption} must be less than or equal to $self->{maxValue}.")
			if $value > $self->{maxValue};
	}
	return @errors;
}

sub validateAlphaOnly
{
	my ($self, $page, $validator, $value) = @_;
	return () if ! $value;

	my @errors = ();
	return @errors;
}

sub validateDateStamp
{
	my ($self, $page, $validator, $value) = @_;

	return () if ! $value;

	my $caption = $self->{caption};
	my $isStamp = ($self->{type} eq 'stamp');
	my $valueFmt = $isStamp ? $page->defaultUnixStampFormat() : $page->defaultUnixDateFormat();

	my @errors = ();
	my $realValue = ParseDate($value);

	if($realValue)
	{
		my ($preDate, $postDate) = (($self->{pastOnly} ? 'tommorrow' : $self->{preDate}), ($self->{futureOnly} ? 'yesterday' : $self->{postDate}));
		if($preDate || $postDate)
		{
			$realValue = Date_SetTime($realValue, "00:00") unless $isStamp;
			if($preDate)
			{
				if(my $checkDate = $isStamp ? Date_SetTime(ParseDate($preDate), "00:00") : ParseDate($preDate))
				{
					if ($realValue gt $checkDate)
					{
						push(@errors, "$caption must be before " . UnixDate($checkDate,  $valueFmt));
					}
				}
			}
			if($postDate)
			{
				if(my $checkDate = $isStamp ? Date_SetTime(ParseDate($postDate), "00:00") : ParseDate($postDate))
				{
					if ($realValue lt $checkDate)
					{
						push(@errors, "$caption must be after " . UnixDate($checkDate,  $valueFmt));
					}
				}
			}
		}
	}
	else
	{
		push(@errors, "Invalid $self->{type} specified for $caption (does not exist). The date format is: MM/DD/YYYY");
	}

	return @errors;
}

sub formatDate
{
	my ($self, $page, $validator, $value) = @_;
	return undef if ! $value;

	$value =~ s/^(\d\d)(\d\d)(\d\d\d\d)$/$1\/$2\/$3/;
	if(my $dateValue = ParseDate($value))
	{
		return UnixDate($dateValue, $page->defaultUnixDateFormat())
	}
	return $value;
}

sub validateTime
{
	my ($self, $page, $validator, $value) = @_;
	return () if ! $value;

	my @errors = ();
	my ($hours, $minutes, $tt) = $value =~ m/$self->{regExpValidate}/;
	push(@errors, "$self->{caption}: Invalid hour specified (can only be 0-12)") if $hours < 0 || $hours > 12;
	push(@errors, "$self->{caption}: Invalid minute specified (can only be 0-60)") if $minutes < 0 || $minutes > 60;
	return @errors;
}

sub formatTime
{
	my ($self, $page, $validator, $value) = @_;
	return undef if ! $value;

	if($value =~ m/$self->{regExpValidate}/)
	{
		my $tt = uc($3);
		$tt = 'AM' if $tt eq 'A';
		$tt = 'PM' if $tt eq 'P';
		return sprintf("%02d:%02d %s", $1, $2, $tt);
	}
	return $value;
}

sub formatStamp
{
	my ($self, $page, $validator, $value) = @_;
	return undef if ! $value;

	$value =~ s/^(\d\d)(\d\d)(\d\d\d\d)$/$1\/$2\/$3/;
	if(my $dateValue = ParseDate($value))
	{
		return UnixDate($dateValue, $page->defaultUnixStampFormat());
	}
	return $value;
}

sub invalidate
{
	my ($self, $page) = (shift, shift);
	$page->paramValidationError($self->{name}, @_);
}

sub execCustomValidate
{
	my ($self, $page, $validator, $value) = @_;

	if(exists $self->{onValidate})
	{
		my @invalidMsg;
		eval
		{
			if(ref $self->{onValidate} eq 'CODE')
			{
				@invalidMsg = &{$self->{onValidate}}($self, $page, $validator, $value, $self->{onValidateData});
			}
			elsif($self->{onValidate})
			{
				@invalidMsg = ("USAGE ERROR: $self->{name} -- use \\&$self->{onValidate} format for onValidate");
			}
		};
		$self->invalidate($page, $@) if $@;
		$self->invalidate($page, @invalidMsg) if @invalidMsg;
		return scalar(@invalidMsg) > 0 ? 0 : 1;
	}
	return 1;
}

sub populateValue
{
	my ($self, $page, $validator, $valFlags) = @_;

	# if there is more than one entry, we're not populating (checkbox/multilist/etc)
	my $fieldName = $page->fieldPName($self->{name});
	return 1 if scalar(my @items = $page->param($fieldName)) > 1;

	my $value = $page->param($fieldName) || (($self->{flags} & FLDFLAG_PERSIST) ? $page->cookie($self->{cookieName}) : '') || $self->{defaultValue};
	if($value)
	{
		$value = uc($value) if $self->{flags} & FLDFLAG_UPPERCASE;
		$value = &{$self->{formatValue}}($self, $page, $validator, $value) if ref $self->{formatValue} eq 'CODE';
	}
	elsif(my $synonyms = $self->{valueSynonym})
	{
		$synonyms = [$synonyms] unless ref $synonyms eq 'ARRAY';
		foreach (@$synonyms)
		{
			next if scalar(my @items = $page->param($_)) > 1;
			$value = $page->param($_);
			if($value)
			{
				$value = uc($value) if $self->{flags} & FLDFLAG_UPPERCASE;
				$value = &{$self->{formatValue}}($self, $page, $validator, $value) if ref $self->{formatValue} eq 'CODE';
				last;
			}
		}
	}
	$page->param($fieldName, $value) if defined($value);

	return 1;
}

sub isValid
{
	my ($self, $page, $validator, $valFlags) = @_;

	my $fieldName = $page->fieldPName($self->{name});

	# if there is more than one entry, we're not validating (checkbox/multilist/etc)
	return 1 if scalar(my @items = $page->param($fieldName)) > 1;

	my $flags = $self->{flags};
	my $validSoFar = 1; # this is changed by $self->invalidate when errors found

	my $value = $page->param($fieldName);
	if($value)
	{
		$value = uc($value) if $flags & (FLDFLAG_IDENTIFIER | FLDFLAG_UPPERCASE);
		$value = ucfirst($value) if $flags & FLDFLAG_UCASEINITIAL;
		$value = lc($value) if $flags & FLDFLAG_LOWERCASE;
		if($flags & (FLDFLAG_IDENTIFIER | FLDFLAG_TRIM))
		{
			$value =~ s/^\s+//;
			$value =~ s/\s+$//;
		}
		$value = &{$self->{formatValue}}($self, $page, $validator, $value) if ref $self->{formatValue} eq 'CODE';
	}

	if(($flags & FLDFLAG_REQUIRED) && ($value eq '' || ! defined($value)))
	{
		$self->invalidate($page, $self->{requiredInvalidMsg});
		$validSoFar = 0;
	}
	elsif(exists $self->{maxLength} && $self->{maxLength} > 0 && length($value) > $self->{maxLength})
	{
		my $valLen = length($value);
		$self->invalidate($page, "$self->{caption} is too long (it is $valLen characters long, but it is restricted to at most $self->{maxLength} characters).");
		$validSoFar = 0;
	}
	elsif($self->{regExpValidate} && $value && $value !~ m/$self->{regExpValidate}/)
	{
		$self->invalidate($page, $self->{regExpInvalidMsg});
		$validSoFar = 0;
	}
	elsif(($flags & FLDFLAG_IDENTIFIER) && defined($value) && $value ne '' && $value !~ m/^[\w_\-]+$/)
	{
		$self->invalidate($page, "$self->{caption} '$value' can only have [A-Z 0-9 _ -] characters (no spaces, tabs, commas, etc.)");
		$validSoFar = 0;
	}

	# if there are no general errors, check for specific field errors
	if($validSoFar)
	{
		$validSoFar = $self->execCustomValidate($page, $validator, $value);
	}

	# in case the value was changed anywhere (due to formatting) set the CGI parameter, too
	$page->param($fieldName, $value) if $value ne '' && defined($value);
	$page->addCookie(-name => $self->{cookieName}, -value => $value, -expires => '+1y') if $flags & FLDFLAG_PERSIST;

	# return TRUE if there were no errors, FALSE otherwise
	return $validSoFar;
}

sub generateJavaScript
{
	my ($self, $page, $key, $level) = @_;

	$level = 0 unless $level;
	return if $level > 3;

	if(defined $key && exists $self->{$key})
	{
		my $javaScript = $self->{$key};
		if(ref $javaScript eq 'SUB')
		{
			$javaScript = &{$javaScript}($self);
		}
		elsif(ref $javaScript eq 'ARRAY')
		{
			$javaScript = join("\n", @{$javaScript});
		}

		# each attribute ends in JS, but HTML tags don't -- for instance
		#   onKeyPressJS needs to be ONKEYPRESS="blah"
		my $jsAttr = uc($key);
		$jsAttr =~ s/JS$//;

		return "$jsAttr=\"$javaScript\"";
	}
	elsif(! defined $key)
	{
		my @all = ();
		foreach ('onKeyPressJS', 'onBlurJS')
		{
			push(@all, $self->generateJavaScript($page, $_, $level+1));
		}
		return join(' ', @all);
	}
}
use constant DATE_FIELD => 'Dialog/AnyDate';

1;
