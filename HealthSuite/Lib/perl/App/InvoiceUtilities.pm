##############################################################################
package App::InvoiceUtilities;
##############################################################################

use strict;
use Exporter;

use DBI::StatementManager;
use App::Statements::Invoice;

use Date::Calc qw(:all);
use Date::Manip;

use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(
	addHistoryItem
);


sub addHistoryItem
{
	my ($page, $invoiceId, %data) = @_;

	$page->schemaAction(
		'Invoice_History', 'add',
		parent_id => $invoiceId,
		%data,
		#value_text => || undef,
		#value_textB => || undef,
		#value_int => || undef,
		#value_intB => || undef,
		#value_float => || undef,
		#value_floatB => || undef,
		#value_date => || undef,
		#value_dateEnd => || undef,
		#value_dateA => || undef,
		#value_dateB => || undef,
		_debug => 0
	);

	return;
}

1;
