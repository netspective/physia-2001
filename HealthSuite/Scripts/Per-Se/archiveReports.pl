#!/usr/bin/perl -I.

use strict;

my $LIMIT = 10;

print "\n-------------------------------\n";
print `date`;
print "-------------------------------\n";

opendir(DIR, ".") || die "Can't opendir .: $!\n";
for my $dir (readdir(DIR))
{
	next if $dir =~ /^\.+$/;
	next unless -d $dir;

	system(qq{
		mkdir -p $dir/archive
	});
	
	opendir(ORG, "$dir") || die "Can't opendir $dir: $!\n";
	my $count = 0;
	for my $file (reverse sort readdir(ORG))
	{
		next unless -f "$dir/$file";
		next unless $file =~ /^\d\d\d\d/;
		$count++;
		
		system "mv $dir/$file $dir/archive\n" if $count > $LIMIT;
	}
	closedir(ORG);
}
