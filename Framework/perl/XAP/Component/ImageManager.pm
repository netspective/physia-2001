##############################################################################
package XAP::Component::ImageManager;
##############################################################################

use strict;
use XAP::Component;
use base qw(XAP::Component Exporter);
use fields qw(@EXPORT imageTags images fileExtns baseDir baseUrl excludeDirs);
use Image::Info qw(image_info dim);

sub init
{
	my XAP::Component::ImageManager $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{imageTags} = exists $params{imageTags} ? $params{imageTags} : {};
	$self->{images} = exists $params{images} ? $params{images} : {};
	$self->{fileExtns} = exists $params{fileExtns} ? $params{fileExtns} : ['gif','jpg','png'];
	$self->{baseDir} = exists $params{baseDir} ? $params{baseDir} : '';
	$self->{baseUrl} = exists $params{baseUrl} ? $params{baseUrl} : '';
	$self->{excludeDirs} = exists $params{excludeDirs} ? $params{excludeDirs} : [];

	$self->buildImageTags();
	$self;
}

sub buildImageTags
{
	my XAP::Component::ImageManager $self = shift;

	my $baseDir = $self->{baseDir};
	my $excludeDirs = $self->{excludeDirs};
	my $baseUrl = $self->{baseUrl};

	foreach (@{$self->{fileExtns}})
	{
		findFiles($_, \&addImage, $baseDir, $excludeDirs, [$self, $baseUrl, $baseDir]);
	}
}

sub getImageTag
{
	my XAP::Component::ImageManager $self = shift;
	my $key = shift;
	my $args = shift;
	$args = {} unless ref($args) eq 'HASH';
	die "Image '$key' doesn't exist" unless exists $self->{images}->{$key};
	my $tag = '<img';
	# add all the default args unless overidden
	foreach (keys %{$self->{images}->{$key}})
	{
		$tag .= qq{ $_="$self->{images}->{$_}"} unless exists $args->{$_};
	}
	# add all custom args
	foreach (keys %$args)
	{
		$tag .= qq{ $_="$args->{$_}"};
	}
	$tag .= '>';
	return $tag;
}

sub addImage
{
	my ($fileName, $args) = @_;
	my XAP::Component::ImageManager $self = $args->[0];
	my ($baseUrl, $baseDir) = ($args->[1], $args->[2]);
	my ($width, $height) = dim(image_info($fileName));

	unless ($width && $height)
	{
		warn "Can't get width & height of image '$fileName'\n";
		return 0;
	}

	# strip the base directory off the full path
	my $src = "$fileName";
	$src =~ s/^$baseDir//;

	# strip the extension off to use as hash key
	my $key = $src;
	$key =~ s/\.\w+$//;

	# prepend the base url directory to the src
	$src = "$baseUrl/$src";

	# make sure $key and $src don't contain double slashes
	$src =~ s|//|/|g;
	$key =~ s|//|/|g;

	# make sure $key don't contain leading slash
	$key =~ s|^/||;

	$self->{imageTags}->{$key} = qq{<img src="$src" width="$width" height="$height" border="0">};
	$self->{images}->{$key} = {
		src => $src,
		width => $width,
		height => $height,
		border => 0,
	};
}

# Find files with specific extension and pass them to a callback function
sub findFiles # non-class method
{
	my $findExt = shift;
	my $callback = shift;
	my $baseDir = shift;
	my $excludeDirs = shift;
	my $callbackArgs = shift;

	opendir DIR, $baseDir;
	my @entries = readdir DIR;
	closedir DIR;

	foreach my $entry (@entries)
	{
		if ( -f "$baseDir/$entry" )
		{
			my $ext = '';
			$ext = $1 if $entry =~ /\.(\w+)$/;
			next unless lc($ext) eq lc($findExt);
			&$callback("$baseDir/$entry", $callbackArgs);
		}
		elsif ( -d "$baseDir/$entry")
		{
			next if grep {$_ eq $entry} @$excludeDirs;
			next if grep {$_ eq $entry} ('CVS','.','..');
			findFiles($findExt, $callback, "$baseDir/$entry", $excludeDirs, $callbackArgs);
		}
	}
}

1;

