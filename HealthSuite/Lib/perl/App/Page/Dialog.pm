##############################################################################
package App::Page::Dialog;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Dialog::Slot;

use vars qw(@ISA);
@ISA = qw(App::Page);

sub prepare
{
	my $self = shift;

	my @pathItems = split(/\//, $self->param('arl_pathItems'));
	my $lastItemIdx = $#pathItems;
	my $command = 'add';
	my $fileName = $pathItems[0];
	my $objectName = $pathItems[$#pathItems];
	if($objectName =~ m/^(add|update|remove)$/)
	{
		$command = $objectName;
		$objectName = $pathItems[$lastItemIdx-1];
	}
	my $pkgFile = "App::Dialog::$fileName";
	my $pkgName = "App::Dialog::$objectName";

	my $object = undef;
	my $evalSrc = qq{
		require $pkgFile;
		Embed::Persistent::ReloadModules();
		\$object = new $pkgName(schema => \$self->getSchema());
	};
	eval($evalSrc);
	if($@ || $self->param('_debug'))
	{
		$evalSrc =~ s/\n/<br>/gm;
		$self->errorBox("Error Displaying Dialog", "Could not instantiate dialog '$objectName' ($pkgName) in package '$pkgFile'.<br>Format is dialog/package/name:command or dialog/name:command.<br>$evalSrc<p><pre>$@</pre>");
		return;
	}

	$self->param('_dlgcommand', $command);
	$object->handle_page($self, $command);

	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	# person_id must be the first item in the path
	return 'UIE-009010' unless $pathItems->[0];
	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}


1;
