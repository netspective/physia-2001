###############################################################################
package App::Device;
###############################################################################

use strict;
use CGI::Page;
use CGI::ImageManager;
use App::Universal;
use Date::Manip;

use DBI::StatementManager;
use App::Statements::Page;
use App::Statements::Person;
use App::Statements::Component;
use App::Statements::Device;
use Schema::API;

# Get a printer device name that is appropriate for the current document type, organization and
# person...
sub getPrinter {
	my ($page, $docType) = @_;
	
	my $currUserID = $page->session ('user_id');
	my $currOrgID = $page->session ('org_internal_id');
	
	my $deviceName;
	
	# Try to get an exact match for document type, person and organization...
	if ($STMTMGR_DEVICE->recordExists($page, STMTMGRFLAG_NONE, 'sel_device_assoc', 0, $currOrgID, $docType, $currUserID)) {
		$deviceName = $STMTMGR_DEVICE->getRowAsArray($page, STMTMGRFLAG_NONE, 'sel_device_assoc', 0, $currOrgID, $docType, $currUserID);
	# Try to get the default printer for this person and org
	} elsif ($STMTMGR_DEVICE->recordExists($page, STMTMGRFLAG_NONE, 'sel_person_default_device_assoc', 0, $currOrgID, $currUserID)) {
		$deviceName = $STMTMGR_DEVICE->getRowAsArray($page, STMTMGRFLAG_NONE, 'sel_person_default_device_assoc', 0, $currOrgID, $currUserID);
	# Try to get the default printer for this document type in this organization...
	} elsif ($STMTMGR_DEVICE->recordExists($page, STMTMGRFLAG_NONE, 'sel_doctype_default_device_assoc', 0, $currOrgID, $docType)) {
		$deviceName = $STMTMGR_DEVICE->getRowAsArray($page, STMTMGRFLAG_NONE, 'sel_doctype_default_device_assoc', 0, $currOrgID, $docType);
	# Try to get the default printer for this organization...
	} elsif ($STMTMGR_DEVICE->recordExists($page, STMTMGRFLAG_NONE, 'sel_org_default_device_assoc', 0, $currOrgID)) {
		$deviceName = $STMTMGR_DEVICE->getRowAsArray($page, STMTMGRFLAG_NONE, 'sel_org_default_device_assoc', 0, $currOrgID);
	}
	
	return $$deviceName[0];
}

# Get a printer device name AND open a printhandle to that device... combination of prev and next
# functions...
sub getPrintHandle {
	my ($page, $docType) = @_;
	
	my $printerDevice = getPrinter ($page, $docType);
	my $printHandle;
	
	if ($printerDevice) {
		$printHandle = IO::File->new ("| lpr -P $printerDevice");
	}
	
	return $printHandle;
}

# Create and open a printerhandle for a device previously obtained from getPrinter()
sub openPrintHandle {
	my ($deviceName) = @_;
	
	my $printHandle = IO::File->new ("| lpr -P $deviceName");
	
	return $printHandle;
}

# Close a printhandle previously opened from openPrintHandle()
sub closePrintHandle {
	my ($printHandle) = @_;
	
	$printHandle->close;
}

# Output any arbitrary data to a specified printer...
sub echoToPrinter {
	my ($deviceName, $data) = @_;
	
	my $printHandle = IO::File->new ("| lpr -P $deviceName");
	
	print $printHandle $data."\n\n";
	
	$printHandle->close;
}

1;