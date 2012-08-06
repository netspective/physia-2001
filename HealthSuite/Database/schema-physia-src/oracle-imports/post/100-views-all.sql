create or replace view testsAndMeasurements as
select 	trans_owner_id,trans_begin_stamp, 
	data_text_b, data_text_a, 0 as no_of_tests
from 	transaction t
where 	trans_begin_stamp =
			(select max(trans_begin_stamp)
			from transaction tt
			where t.data_text_b = tt.data_text_b
			and tt.trans_type between 12000 and 12999
			group by tt.data_text_b);


create or replace view testsAndMeasurementscount as
select	trans_owner_id, to_date('01/01/1029', 'MM/DD/YYYY') AS trans_begin_stamp,
	data_text_b, 'a' as data_text_a, count(*) as no_of_tests
from 	transaction
where 	trans_type between 12000 and 12999
group by trans_owner_id, to_date('01/01/1029', 'MM/DD/YYYY'), data_text_b,'a'
order by data_text_b;
