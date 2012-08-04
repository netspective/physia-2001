##############################################################################
package Devel::ChangeLog;
##############################################################################

use strict;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);

use enum qw(BITMASK:CHANGELOGFLAG_ USER SDE ADD UPDATE REMOVE NOTE UI DB EI);
use constant CHANGELOGFLAG_ANYVIEWER => CHANGELOGFLAG_USER | CHANGELOGFLAG_SDE;
use constant CHANGELOGFLAGS_NEWFEATURE => CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD | CHANGELOGFLAG_UI;
#
# USER   change is meant to be seen by end-user
# SDE    change is meant for development environment (not for enduser)
# ADD    feature/change was added (it's new)
# UPDATE feature/change was updated (it existed already and is now different)
# REMOVE feature/change was removed (it no longer exists)
# NOTE   simple text note
# UI     user interface change
# DB     database change
# EI     external interface change
#

@EXPORT = qw(
	CHANGELOGFLAGS_NEWFEATURE
	CHANGELOGFLAG_ANYVIEWER CHANGELOGFLAG_USER CHANGELOGFLAG_SDE
	CHANGELOGFLAG_ADD CHANGELOGFLAG_UPDATE CHANGELOGFLAG_REMOVE	CHANGELOGFLAG_NOTE
	CHANGELOGFLAG_UI CHANGELOGFLAG_DB CHANGELOGFLAG_EI
	);

sub getChangeLog
{
	my ($flags) = @_;

	my $log = [];
	my $modules = [];
	my ($module, $file);
	my $evalCode = '';
    while (($module, $file) = each %INC)
    {
		$module =~ s!/!::!g;
		$module =~ s!\..*$!!;
		next unless $module =~ m/^App::/;
		push(@$modules, $module);
		$evalCode .= "push(\@\$log, \@$module\::CHANGELOG);";
	}
	eval($evalCode);

	return ($log, $modules);
}

sub createLogStruct
{
	my ($flags, $log) = @_;

	my $struct = {};
	my @evalCode = ();
	my $count = scalar(@$log);
	for(my $i = 0; $i < $count; $i++)
	{
		# create inline perl code for categories (separated by /)
		my $item = $log->[$i];
		my @keyPerl = ();
		foreach (split(/\//, $item->[3]))
		{
			push(@keyPerl, '{\'' . $_ . '\'}');
		}
		my $keyPerl = join('->', @keyPerl);
		push(@evalCode, 'push(@{$struct->' . join('->', @keyPerl) . '->{_items}}, ' . "\$log->[$i]);");
	}
	eval(join("\n", @evalCode));

	return $struct;
}

1;