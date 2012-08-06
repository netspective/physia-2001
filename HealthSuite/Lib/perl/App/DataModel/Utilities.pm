##############################################################################
# Define the most common utility data objects
##############################################################################

use strict;
use Exporter;
use Class::Generate qw(class subclass);
use vars qw(@EXPORT $GENDER);

class 'App::DataModel::Enumeration' =>
[
	tableName => { type => '$', required => 1 },
	'&getSqlValue' => q { return "Hi" },
];

subclass 'App::DataModel::Lookup' =>
[
], -parent => 'App::DataModel::Enumeration';



1;