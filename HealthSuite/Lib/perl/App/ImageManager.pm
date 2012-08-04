##############################################################################
package App::ImageManager;
##############################################################################

use strict;
use vars qw(@ISA @EXPORT %IMAGETAGS);

@ISA = qw(Exporter);
@EXPORT = qw(%IMAGETAGS);

%IMAGETAGS =
(
	'rule/horiz' => '<IMG SRC="/resources/design/bar.gif" BORDER=0 WIDTH=100% HEIGHT=1>',
	'gadget/action' => '<IMG SRC="/resources/gadgets/action-red.gif" BORDER=0>',

	'icon-l/person' => '<IMG SRC="/resources/icons/person.gif" BORDER=0>',
	'icon-m/person' => '<IMG SRC="/resources/icons/person-m.gif" BORDER=0>',
	'icon-l/org' => '<IMG SRC="/resources/icons/org.gif" BORDER=0>',
	'icon-m/org' => '<IMG SRC="/resources/icons/org-m.gif" BORDER=0>',
	'icon-l/schedule' => '<IMG SRC="/resources/icons/clock-face.gif" BORDER=0>',
	'icon-m/schedule' => '<IMG SRC="/resources/icons/clock-face-m.gif" BORDER=0>',
	'icon-l/search' => '<IMG SRC="/resources/icons/magnify-text.gif" BORDER=0>',
	'icon-m/search' => '<IMG SRC="/resources/icons/magnify-text-m.gif" BORDER=0>',
	'icon-l/home' => '<IMG SRC="/resources/icons/home.gif" BORDER=0>',
	'icon-l/people' => '<IMG SRC="/resources/icons/people.gif" BORDER=0>',
	'icon-l/accounting' => '<IMG SRC="/resources/icons/accounting.gif" BORDER=0>',
	'icon-m/sde' => '<IMG SRC="/resources/icons/sde.gif" BORDER=0>',
);

1;
