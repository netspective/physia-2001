#!/usr/bin/perl -I.

use strict;

my $LIMIT = 10;

opendir(DIR, ".") || die "Can't opendir .: $!\n";
for my $dir (readdir(DIR))
{
	next if $dir =~ /^\.+$/;
	next unless -d $dir;

	print "\n----------------------------------\n";
	print "$dir\n";
	print "----------------------------------\n";
	
	system(qq{
		mkdir -p $dir/archive
	});
	
	opendir(ORG, "$dir") || die "Can't opendir $dir: $!\n";
	my $count = 0;
	for my $file (reverse sort readdir(ORG))
	{
		next unless -f "$dir/$file";
		next unless $file =~ /^\d\d\d\d/;
		print "$file\n";
		$count++;
		
		print "mv $dir/$file $dir/archive\n" if $count > $LIMIT;
		
	}
	closedir(ORG);
}