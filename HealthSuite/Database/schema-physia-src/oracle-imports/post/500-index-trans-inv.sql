BEGIN
	execArbitrarySql('drop index trans_owner_id_trans_type');
END;
/

BEGIN
	execArbitrarySql('drop index invoice_client_id_type');
END;
/


create index trans_owner_id_trans_type on transaction (trans_owner_id, trans_type) tablespace ts_indexes;
create index invoice_client_id_type on invoice (client_id, client_type) tablespace ts_indexes;
