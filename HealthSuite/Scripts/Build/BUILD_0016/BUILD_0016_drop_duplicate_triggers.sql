set feedback off
set verify off
set echo off 
set heading off
set termout off

spool drop_invitem_triggers

Select 'drop trigger '||trigger_name||';' From user_triggers 
  where table_name in ('INVOICE_ITEM', 'INVOICE_ITEM_ADJUST');
  
spool off

set feedback on
set verify on
set echo on 
set heading on
set termout on

  
start drop_invitem_triggers


start tables-code/Invoice_Item
start tables-code/Invoice_Item_Adjust
start tables-code/Invoice_Item_totals
start tables-code/Invoice_Item_Adjust_totals