##############################################################################
package CGI::ImageManager;
##############################################################################

use strict;
use vars qw(@ISA @EXPORT %IMAGETAGS %IMAGE_TYPES %IMAGES);
use Image::Info qw(image_info dim);

@ISA = qw(Exporter);
@EXPORT = qw(%IMAGETAGS &getImageTag);

%IMAGETAGS = ();


sub buildImageTags
{
	my $IMAGE_TYPES = shift;
	
	foreach my $type (keys %{$IMAGE_TYPES})
	{
		next unless $$IMAGE_TYPES{$type}->{baseDir};
		foreach my $findExt ('gif','jpg','png')
		{
			my $baseDir = $$IMAGE_TYPES{$type}->{baseDir};
			my $excludeDirs = defined $$IMAGE_TYPES{$type}->{excludeDirs} ? $$IMAGE_TYPES{$type}->{excludeDirs} : [];
			my $baseUrl = defined $$IMAGE_TYPES{$type}->{baseUrl} ? $$IMAGE_TYPES{$type}->{baseUrl} : '';
			findFiles($findExt, \&addImage, $baseDir, $excludeDirs, [ $baseUrl, $baseDir ]);
		}
	}
}


sub addImage
{
	my ($fileName, $args) = @_;
	my ($baseUrl, $baseDir) = @$args;
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
	
	$IMAGETAGS{$key} = qq{<img src="$src" width="$width" height="$height" border="0">};
	$IMAGES{$key} = {
		src => $src,
		width => $width,
		height => $height,
		border => 0,
	};
}


sub getImageTag
{
	my $key = shift;
	my $args = shift;
	$args = {} unless ref($args) eq 'HASH';
	die "Image '$key' doesn't exist" unless exists $IMAGES{$key};
	my $tag = '<img';
	# add all the default args unless overidden
	foreach (keys %{$IMAGES{$key}})
	{
		$tag .= qq{ $_="$IMAGES{$key}->{$_}"} unless exists $args->{$_};
	}
	# add all custom args
	foreach (keys %$args)
	{
		$tag .= qq{ $_="$args->{$_}"};
	}
	$tag .= '>';
	return $tag;
}


# Find files with specific extension and pass them to a callback function
sub findFiles
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

__END__

=head1 NAME

CGI::ImageManager - Pre-Generates HTML E<lt>imgE<gt> Tags

=head1 SYNOPSIS

 use CGI::ImageManager;

 my %IMAGE_TYPES = {
	'resources' => {
		baseDir => '/path/to/image/files',
		excludeDirs => ['CVS','private',],
		baseUrl => '/url/path/to/baseDir',
		},
	};

 CGI::ImageManager::buildImageTags(\%IMAGE_TYPES);

 print $IMAGETAGS{'icons/help'};
 print getImageTag('icons/help', {title => 'tool tip'});

=head1 DESCRIPTION

Using this package you can pre-generate HTML E<lt>imgE<gt> tags for all of
the images used by your application.

ImageManager scans requested directories for all image files ('gif', 'jpg',
and 'png').  It then uses Image::Info to interrogate the image for it's
width and height.  It then stores this information and generates a proper 
E<lt>imgE<gt> tag in an exported HASH called %IMAGETAGS.

You can then insert the resulting tags into your HTML output for the
negligable performance cost of a HASH lookup. Alternatively you can use the
B<getImageTag> subroutine to build a tag at runtime with custom and
overidden attributes.

ImageManager takes preference to 'jpg' files over 'gif' files and 'png'
files over 'jpg'.  The HASH keys for %IMAGETAGS are the image file name
(relative to the baseDir) without the file extension.

Therefore, if you have:

 icons/sample.gif
 icons/sample.png

only the png version will be available as $IMAGETAGS{'icons/sample'}

This makes it easy to convert images between formats without having to
modify your application.

=cut
