##############################################################################
package App::Statements::External;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@EXPORT $STMTMGR_EXTERNAL);

use base qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_EXTERNAL);

my $HISTORY_RECORD=App::Universal::ATTRTYPE_HISTORY;
my $WAITING_PAYMENT = App::Universal::INVOICESTATUS_AWAITINSPAYMENT;

$STMTMGR_EXTERNAL = new App::Statements::External(
	'sel_dupHistoryItems' => qq{
		select parent_id, value_text, to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date,
			count(*) as count
		from Invoice_Attribute
		where cr_user_id = 'EDI_PERSE'
		 and item_name like '%History%'
		group by parent_id, value_text, value_date having count(*) > 1	
	},
	
	'sel_minItemId' => qq{
		select min(item_id)
		from Invoice_Attribute
		where parent_id = :1
			and cr_user_id = 'EDI_PERSE'
			and item_name like '%History%'
			and value_text = :2
			and value_date = to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT')
	},
	
	'sel_firstItem' => qq{
		select item_id, value_text, to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date,
			to_char(cr_stamp, 'mm/dd/yyyy hh:mi:ss pm') as cr_stamp
		from Invoice_Attribute
		where item_id = :1
	},

	'sel_restItems' => qq{
		select item_id, value_text, to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date,
			to_char(cr_stamp, 'mm/dd/yyyy hh:mi:ss pm') as cr_stamp
		from Invoice_Attribute
		where parent_id = :1
			and item_id > :2
			and cr_user_id = 'EDI_PERSE'
			and item_name like '%History%'
			and value_text = :3
			and value_date = to_date(:4, '$SQLSTMT_DEFAULTDATEFORMAT')
		order by item_id
	},

	'sel_InvoiceAttribute' => qq{
		select * from Invoice_Attribute
		where parent_id = :1
			and item_name = :2
			and value_text = :3
			and value_date = to_date(:4, '$SQLSTMT_DEFAULTDATEFORMAT')
	},
	
	'del_InvoiceAttribute' => qq{
		delete from Invoice_Attribute where item_id = :1
	},
	
	
	# Statement for Loading Statement Ack records
	#
	'updateAckStatement'=>qq
	{
		UPDATE  Statement
                SET     ack_stamp = sysdate,
                tranmission_status  = 1,
                ext_statement_id = :1
                WHERE   ack_stamp is NULL
                AND     int_statement_id = :2
                AND   tranmission_status  = 0		
	},

	'updateAckStatus'=>qq
	{
		UPDATE 	Invoice
		SET	invoice_status  = $WAITING_PAYMENT
		WHERE	Invoice_id IN				
		(SELECT sii.member_name 
		 FROM Statement s, Statement_Inv_Ids sii
		 WHERE sii.parent_id = s.statement_id
		 AND s.ack_stamp is NULL
		 AND s.tranmission_status  = 0
		 AND  s.int_statement_id = :1
		)
	},
	
	'InsAckStatement'=>qq
	{
		INSERT INTO Invoice_History
		(cr_stamp,
		cr_user_id,
		parent_id,
		value_text,
		value_date,
		value_textb		
		)
		SELECT sysdate,
		'EDI_PERSE',
		sii.member_name,
		:1, 
		sysdate,
		:2  			
		 FROM Statement s, Statement_Inv_Ids sii
		 WHERE sii.parent_id = s.statement_id
		 AND s.ack_stamp is NULL
		 AND s.tranmission_status  = 0
		 AND sii.parent_id = :3
	},
	
);
	
1;
