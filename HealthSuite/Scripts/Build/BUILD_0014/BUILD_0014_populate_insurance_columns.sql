whenever sqlerror exit sql.sqlcode rollback

update insurance a
 set plan_ins_id=(select ins_internal_id from insurance b where b.ins_internal_id=a.parent_ins_id and
                    b.record_type=2) where record_type=3;


update insurance a
 set product_ins_id=(select ins_internal_id from insurance b where b.ins_internal_id=a.parent_ins_id and
                    b.record_type=1) where record_type=3 and plan_ins_id is NULL;

update insurance a
 set product_ins_id=
  (select ins_internal_id from insurance b where b.ins_internal_id=
    (select parent_ins_id from insurance c where c.ins_internal_id=b.plan_ins_id)
  )
    where plan_ins_id is not NULL and record_type=3;

commit;
