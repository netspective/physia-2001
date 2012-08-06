##############################################################################
package App::Statements::Device;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_DEVICE);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_DEVICE);

$STMTMGR_DEVICE = new App::Statements::Device(

	'sel_device_assoc' => qq{
		select device_name
		from device_specification, device_association
		where device_specification.device_id = device_association.device_id
			and device_specification.device_type = ?
			and device_association.org_internal_id = ?
			and device_association.document_type = ?
			and device_association.person_id = ?
	},

	'sel_person_default_device_assoc' => qq{
		select device_name
		from device_specification, device_association
		where device_specification.device_id = device_association.device_id
			and device_specification.device_type = ?
			and device_association.org_internal_id = ?
			and device_association.document_type is NULL
			and device_association.person_id = ?
	},

	'sel_doctype_default_device_assoc' => qq{
		select device_name
		from device_specification, device_association
		where device_specification.device_id = device_association.device_id
			and device_specification.device_type = ?
			and device_association.org_internal_id = ?
			and device_association.document_type = ?
			and device_association.person_id is NULL
	},

	'sel_org_default_device_assoc' => qq{
		select device_name
		from device_specification, device_association
		where device_specification.device_id = device_association.device_id
			and device_specification.device_type = ?
			and device_association.org_internal_id = ?
			and device_association.document_type is NULL
			and device_association.person_id is NULL
	},

	'sel_org_devices' => qq{
		select distinct device_name
		from device_specification, device_association
		where device_association.device_id = device_specification.device_id
		and device_specification.device_type = 0
		and device_association.org_internal_id = 1
	},

);
	
1;
