##############################################################################
package App::Statements::Document;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_DOCUMENT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_DOCUMENT);

$STMTMGR_DOCUMENT = new App::Statements::Document(
	'selMessage' => qq{
		SELECT
			Document.doc_id as message_id,
			to_char(Document.doc_orig_stamp - :2, '$SQLSTMT_DEFAULTSTAMPFORMAT') AS send_on,
			Document.doc_recv_stamp AS read_on,
			Document.doc_source_id AS from_id,
			Document.doc_name AS subject,
			Document.doc_content_small AS message,
			Document.doc_data_a AS permed_id,
			Document.doc_data_b AS priority,
			Document.doc_data_c AS common_message,
			Document.doc_source_system,
			attr_repatient.value_text AS repatient_id,
			attr_repatient.value_int AS deliver_records,
			attr_repatient.value_textB AS return_phone,
			initcap(repatient.simple_name) AS repatient_name,
			attr_phones.value_text AS return_phones
		FROM
			Person repatient,
			Document_Attribute attr_phones,
			Document_Attribute attr_repatient,
			Document
		WHERE
			Document.doc_id = :1
			AND attr_repatient.parent_id (+) = Document.doc_id
			AND attr_repatient.value_type (+) = @{[App::Universal::ATTRTYPE_PATIENT_ID]}
			AND attr_repatient.item_name (+) = 'Regarding Patient'
			AND attr_repatient.value_text = repatient.person_id (+)
			AND attr_phones.value_type (+) = @{[App::Universal::ATTRTYPE_PHONE]}
			AND attr_phones.item_name (+) = 'Return Phones'
			AND attr_phones.parent_id (+) = Document.doc_id
	},
	'selMessageToList' => qq{
		SELECT
			value_text AS to_person_id
		FROM
			Document_Attribute
		WHERE
			parent_id = :1 AND
			value_type = @{[App::Universal::ATTRTYPE_PERSON_ID]} AND
			item_name = 'To'
	},
	'selMessageCCList' => qq{
		SELECT
			value_text AS cc_person_id
		FROM
			Document_Attribute
		WHERE
			parent_id = :1 AND
			value_type = @{[App::Universal::ATTRTYPE_PERSON_ID]} AND
			item_name = 'CC'
	},
	'selMessageNotes' => qq{
		SELECT
			TO_CHAR(cr_stamp, 'IYYYMMDDHH24MISS') as when,
			person_id AS person_id,
			value_text AS notes,
			value_int AS private
		FROM
			Document_Attribute
		WHERE
			parent_id = :1 AND
			value_type = @{[App::Universal::ATTRTYPE_TEXT]} AND
			item_name = 'Notes' AND
			(value_int = 0 OR person_id = :2)
	},
	'selMessageRecipientAttrId' => qq{
		SELECT
			item_id
		FROM
			Document_Attribute
		WHERE
			parent_id = :1 AND
			value_type = @{[App::Universal::ATTRTYPE_PERSON_ID]} AND
			item_name IN ('To', 'CC') AND
			value_text = :2
	},
	'selMessagesByPerMedId' => qq{
		SELECT
			doc_id
		FROM
			Document
		WHERE
			doc_data_a = ?
	},
	'selDocumentById' => qq{
		SELECT
			doc_id,
			doc_id_alias,
			doc_message_digest,
			doc_mime_type,
			doc_header,
			doc_spec_type,
			doc_spec_subtype,
			doc_source_id,
			doc_source_type,
			doc_source_subtype,
			doc_source_system,
			doc_name,
			doc_description,
			doc_orig_stamp,
			doc_recv_stamp,
			doc_data_a AS owner_id
		FROM
			Document
		WHERE
			doc_id = ?
	},
	'selDocumentContentById' => qq{
		SELECT
			doc_content_small,
			doc_content_large
		FROM
			Document
		WHERE
			doc_id = ?
	},
);

1;
