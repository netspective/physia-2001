package SDE::CVS;

use strict;
use fields qw(Revision Date Name Author Locker Source State RCSfile Version);
use vars qw($AUTOLOAD);

import(__PACKAGE__, '$Id: CVS.pm,v 1.1 2000-08-31 14:25:01 robert_jenks Exp $', '$Name:  $');


sub import 
{
	my $class = shift;
	@_ or return;  # Import list of CVS keywords is required
	no strict 'refs';
        my SDE::CVS $self = { "Revision" => "fields::Revision", "Date" => "fields::Date", "Name" => "fields::Name", "Author" => "fields::Author", "Locker" => "fields::Locker", "Source" => "fields::Source", "State" => "fields::State", "RCSfile" => "fields::RCSfile", "Version" => "fields::Version" };
        bless $self, $class;

	use strict;
	foreach (@_)
	{
		my $param = $_;
		
		# Strip $'s
		$param =~ tr/\$//d;
		
		# Strip embedded line breaks
		$param =~ s/\\[\n\r]{1,2}//g;
		
		my ($name, $value) = split ':', $param, 2;
		$value = '' unless $value;

		# Strip leading/trailing spaces
		$value =~ s/^\s*(.*?)\s*$/$1/;
		
		# Store the value
		$self->$name($value);
	}
	my $callerPkg = caller();
	# Set the caller package's VERSION global
	$self->_setVERSION($callerPkg);
	# Set the caller package's CVS global
	# (used variable twice to avoid perl warning)
	no strict 'refs';
	${"$callerPkg\::CVS"} = ${"$callerPkg\::CVS"} = $self;	
}


sub Header
{
	my SDE::CVS $self = shift;
	my $value = shift;
	return unless $value;
	
	my @values = split /\s+/, $value;
	die "Incorrect 'Header' format" unless $#values >= 5;
	$self->RCSfile($values[0]);
	$self->Revision($values[1]);
	$self->Date("$values[2] $values[3]");
	$self->Author($values[4]);
	$self->State($values[5]);
	$self->Locker($values[6]) if defined $values[6];
}


sub Id
{
	my SDE::CVS $self = shift;
	return $self->Header(@_);
}


sub _setVERSION
{
	my SDE::CVS $self = shift;
	my $callerPkg = shift;

	return 0 unless defined $self->{Revision};
	my ($major,$minor) = split '\.', $self->{Revision}, 2;
	my @minor = split '\.', $minor;
	$minor = join '', map { sprintf("%03d",$_) } @minor;
	no strict 'refs';
	$self->{Version} = ${"$callerPkg\::VERSION"} = 0+"$major.$minor";
	return ${"$callerPkg\::VERSION"};
}


sub AUTOLOAD
{
	my SDE::CVS $self = shift;
	my $function = $AUTOLOAD;
	$function =~ s/.*:://;
	return if $function eq 'DESTROY';
	if (exists $self->{$function})
	{
		$self->{$function} = $_[0] if defined $_[0];
		return defined $self->{$function} ? $self->{$function} : '';
	}
	else
	{
		die "CVS Keyword '$function' not supported";
	}
}


1;
