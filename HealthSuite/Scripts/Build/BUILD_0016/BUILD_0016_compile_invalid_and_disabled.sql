rem ###############################################################
rem
rem all_compile.sql
rem
rem Purpose: Compiles all invalid objects until there are no
rem          objects left that might be compiled successfully.
rem          This is much smarter than dbms_utility.compile_schema,
rem          because the latter compiles all objects, valid or not.
rem          You can use this script after an import.
rem          The script can be used by both DBA's and normal users.
rem 
rem          The following output is spooled:
rem          - Objects that were successfully compiled
rem          - Objects that were compiled with errors
rem          - The corresponding compilation errors
rem          - The objects that are left invalid, including the
rem            the objects depending on them, also caused to be
rem            invalid
rem          The results are spooled by means of dbms_output, it
rem          might be smart to spool this to a file.
rem
rem Author:  Bernard van Aalst
rem
rem Date:    03 Jan 2000
rem
rem Usage:   In sqlplus: @all_compile
rem
rem ###############################################################

SET FEEDBACK OFF
SET SERVEROUTPUT ON
exec dbms_output.enable( 1000000)
DECLARE

  TYPE blacklist_type IS TABLE OF CHAR(1) INDEX BY BINARY_INTEGER;
                                          /* Indexed by object_id */
  blacklist blacklist_type;

  CURSOR c_inv IS
    SELECT o.owner
    ,      o.object_name
    ,      o.object_type
    ,      o.object_id
    FROM all_objects o
    WHERE o.status = 'INVALID'
    ;
  r_inv c_inv%ROWTYPE;

  v_chances_left BOOLEAN := TRUE;
  v_found        BOOLEAN;
  v_sqlerrm      VARCHAR2( 2000);

  PROCEDURE p
  ( line_in IN VARCHAR2 DEFAULT CHR( 10)
  ) AS
  BEGIN
    dbms_output.put_line( line_in);
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line( SUBSTR( line_in, 1, 255));
  END p;
  FUNCTION compile
  /*
  || Executes dynamic SQL
  */
  ( owner_in       IN  VARCHAR2
  , object_name_in IN  VARCHAR2
  , object_type_in IN  VARCHAR2
  , sqlerrm_out    OUT VARCHAR2
  ) RETURN BOOLEAN
    AS
    v_stmt   VARCHAR2( 1000);
    v_cursor BINARY_INTEGER;
    v_retval BINARY_INTEGER;
    v_status VARCHAR2( 7);
    CURSOR c_obj IS
      SELECT status
      FROM all_objects
      WHERE owner       = owner_in
      AND   object_name = object_name_in
      AND   object_type = object_type_in
      ;
  BEGIN
    IF object_type_in = 'PACKAGE BODY'
    THEN
      v_stmt := 'ALTER PACKAGE ' ||
                owner_in||'.'||object_name_in||' COMPILE BODY';
    ELSE
      v_stmt := 'ALTER '||object_type_in||' '||
                owner_in||'.'||object_name_in||' COMPILE';
    END IF;
    v_cursor := dbms_sql.open_cursor;
    dbms_sql.parse( v_cursor, v_stmt, dbms_sql.v7);
    v_retval := dbms_sql.execute( v_cursor);
    dbms_sql.close_cursor( v_cursor);
    OPEN c_obj;
    FETCH c_obj INTO v_status;
    CLOSE c_obj;
    IF v_status = 'VALID'
    THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF dbms_sql.is_open( v_cursor)
      THEN
        dbms_sql.close_cursor( v_cursor);
      END IF;
      sqlerrm_out := SQLERRM;
      RETURN FALSE;
  END compile;
BEGIN
  p( 'Start all_compile: ' || TO_CHAR( SYSDATE, 'HH24:MI:SS'));
  blacklist.DELETE;
  WHILE v_chances_left
  LOOP
    v_chances_left := FALSE;

    OPEN c_inv;
    FETCH c_inv INTO r_inv;
    v_found := c_inv%FOUND;
    WHILE blacklist.EXISTS( r_inv.object_id) AND c_inv%FOUND
    LOOP
      FETCH c_inv INTO r_inv;
      v_found := c_inv%FOUND;
    END LOOP;
    CLOSE c_inv;
    IF v_found
    THEN
      v_chances_left := TRUE;
      p( LPAD( '=', 79, '='));
      IF compile( owner_in       => r_inv.owner
                , object_name_in => r_inv.object_name
                , object_type_in => r_inv.object_type
                , sqlerrm_out    => v_sqlerrm
                )
      THEN
        p( RPAD( r_inv.object_type, 12) || ' ' || r_inv.owner || '.' || 
           r_inv.object_name || ': OK.'
         );
      ELSE
        p( RPAD( r_inv.object_type, 12) || ' ' || r_inv.owner || '.' || 
           r_inv.object_name || ': errors.'
         );
        IF v_sqlerrm IS NULL
        THEN
          FOR j IN ( SELECT line, position, text
                     FROM all_errors
                     WHERE owner = r_inv.owner
                     AND   name  = r_inv.object_name
                     AND   type  = r_inv.object_type
                     ORDER BY sequence
                   )
          LOOP
            p( 'Line ' || TO_CHAR( j.line) ||
               ', position ' || TO_CHAR( j.position) || ':');
            p( j.text);
          END LOOP;
        ELSE
          p( v_sqlerrm);
        END IF;
        blacklist( r_inv.object_id) := '';
      END IF;
    END IF;
  END LOOP;

  DECLARE
    v_first BOOLEAN := TRUE;
    CURSOR c IS
      SELECT o.owner
      ,      o.object_name
      ,      o.object_type
      ,      o.object_id
      FROM all_objects o
      WHERE o.status = 'INVALID'
      AND   NOT EXISTS
      ( SELECT NULL
        FROM all_dependencies d
        ,    all_objects o2
        WHERE d.owner            = o.owner
        AND   d.name             = o.object_name
        AND   d.type             = o.object_type
        AND   d.referenced_owner = o2.owner
        AND   d.referenced_name  = o2.object_name
        AND   d.referenced_type  = o2.object_type
        AND   o2.status          = 'INVALID'
      );

    PROCEDURE show_invalids
    ( owner_in IN VARCHAR2
    , name_in  IN VARCHAR2
    , type_in  IN VARCHAR2
    , index_in IN BINARY_INTEGER DEFAULT 1
    ) AS
      CURSOR c_dep IS
        SELECT owner, type, name
        FROM all_dependencies
        WHERE referenced_owner = owner_in
        AND   referenced_name  = name_in
        AND   referenced_type  = type_in
        ;
    BEGIN
      FOR r IN c_dep
      LOOP
        p( LPAD( '.', 2*index_in, '.') || 
           LOWER( r.type || ' ' || r.owner || '.' || r.name)
         );
        show_invalids( r.owner, r.name, r.type, index_in + 1);
      END LOOP;
    END show_invalids;
  BEGIN
    FOR r IN c
    LOOP
      IF v_first
      THEN
        p( LPAD( '=', 79, '='));
        p( 'Still invalid: (depending objects included)');
        v_first := FALSE;
      END IF;
      p( RPAD( r.object_type, 12) || ' ' || r.owner || '.' || r.object_name);
      show_invalids( r.owner, r.object_name, r.object_type);
    END LOOP;
  END;

  p( LPAD( '=', 79, '='));
  p( 'Finish all_compile: ' || TO_CHAR( SYSDATE, 'HH24:MI:SS'));
END;
/
SET FEEDBACK ON

select object_type, object_name from user_objects where status='INVALID'
order by object_type, object_name;

select constraint_name, constraint_type from user_constraints where status='DISABLED'
order by constraint_name;

select trigger_name from user_triggers where status='DISABLED' order by trigger_name;