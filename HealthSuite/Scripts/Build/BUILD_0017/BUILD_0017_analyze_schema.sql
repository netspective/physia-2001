alter session set sort_area_size=200000000;
exec dbms_utility.analyze_schema('PRO_TEST', 'COMPUTE', 0, 0, 'FOR TABLE FOR ALL INDEXES FOR ALL COLUMNS');
