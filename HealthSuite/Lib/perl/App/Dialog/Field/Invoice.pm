##############################################################################
package App::Dialog::Field::ProcedureLine;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;

	my $nameSuffix = $params{nameSuffix} || '';
	$params{fields} = [
		new CGI::Dialog::Field(
				caption => 'Procedure',
				name => "procedure$nameSuffix",
				type => 'integer', size => 8,
				options => FLDFLAG_REQUIRED,
				findPopup => '/lookup/cpt'),
		new CGI::Dialog::Field(
				caption => 'Modifier',
				name => "procmodifier$nameSuffix",
				type => 'text', size => 4),
		#new CGI::Dialog::Field(
		#		caption => 'Diagnoses',
		#		name => "procdiags$nameSuffix",
		#		type => 'text', size => 12, maxLength => 64,
		#		findPopup => 'catalog,code'),
	];

	return CGI::Dialog::MultiField::new($type, %params);
}

##############################################################################
package App::Dialog::Field::ServicePlaceType;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;

	my $nameSuffix = $params{nameSuffix} || '';
	$params{fields} = [
		new CGI::Dialog::Field(
				caption => 'Service Place',
				name => "servplace$nameSuffix",
				size => 6, options => FLDFLAG_REQUIRED,
				defaultValue => 11,
				findPopup => '/lookup/serviceplace'),
		new CGI::Dialog::Field(
				caption => 'Service Type',
				name => "servtype$nameSuffix",
				size => 6,
				findPopup => '/lookup/servicetype'),
		new CGI::Dialog::Field(type => 'bool',
				style => 'check',
				caption => 'Lab',
				name => 'lab_indicator'),
	];

	return CGI::Dialog::MultiField::new($type, %params);
}

##############################################################################
package App::Dialog::Field::ProcedureChargeUnits;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::MultiField);

sub new
{
	my ($type, %params) = @_;

	my $nameSuffix = $params{nameSuffix} || '';
	$params{fields} = [
		new CGI::Dialog::Field(caption => 'Charge', name => "proccharge$nameSuffix", type => 'currency', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption => 'Units', name => "procunits$nameSuffix", type => 'integer', size => 6, minValue => 1, value => 1, options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption => 'EMG', name => "emg$nameSuffix", type => 'bool', style => 'check'),
	];

	return CGI::Dialog::MultiField::new($type, %params);
}

##############################################################################
package App::Dialog::Field::Diagnoses;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	return CGI::Dialog::Field::new($type, name => 'diagcodes', findPopup => '/lookup/icd', findPopupAppendValue => ', ', options => FLDFLAG_TRIM, %params);
}

##############################################################################
package App::Dialog::Field::DiagnosesCheckbox;
##############################################################################

use strict;
use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;
use App::Statements::Invoice;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;
	return CGI::Dialog::Field::new($type, type => 'select', style => 'multicheck', choiceDelim => '[,\s]+', name => 'procdiags', %params);
}

sub parseChoices
{
	my ($self, $page) = @_;

	$self->{selOptions} = $STMTMGR_INVOICE->getSingleValue($page, 0, 'selClaimDiags', $page->param('invoice_id'));
	return $self->SUPER::parseChoices($page);
}

1;