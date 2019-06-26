create table CSTB_PATCH_BACKUP
(
  patch_no   VARCHAR2(100),
  unit_name  VARCHAR2(100),
  unit_type  VARCHAR2(100),
  time_stamp TIMESTAMP(6),
  unit_text  CLOB
);


create or replace procedure pr_patch_backup(p_patch_no in varchar2,
                                            p_file     in varchar2) is
begin
  for i in (select object_name,
                   decode(object_type,
                          'PACKAGE BODY',
                          'PACKAGE_BODY',
                          'PACKAGE',
                          'PACKAGE_SPEC',
                          object_type) object_type
              from user_objects
             where object_name =upper(substr(substr(p_file, instr(p_file, '/', -1) + 1),1,
                                instr(substr(p_file,instr(p_file, '/', -1) + 1),'.',-1) - 1)))
  loop
    insert into cstb_patch_backup
      (patch_no, unit_name, unit_type, unit_text, time_stamp)
    values(p_patch_no,i.object_name,i.object_type,
    DBMS_METADATA.GET_DDL(i.object_type, i.object_name),
    systimestamp);
  end loop;
  commit;
end;
/
