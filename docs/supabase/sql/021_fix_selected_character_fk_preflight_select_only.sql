-- 021_fix_selected_character_fk_preflight_select_only.sql
-- M-15D correction preflight for session_applications.selected_character_id FK.
-- SELECT-only catalog/data integrity inspection. No schema, data, or privilege changes.

select
  to_regclass('public.session_applications') as session_applications_table,
  to_regclass('public.player_characters') as player_characters_table;

select
  c.table_schema,
  c.table_name,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'session_applications'
  and c.column_name = 'selected_character_id';

select
  c.table_schema,
  c.table_name,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'player_characters'
  and c.column_name = 'id';

with selected_character_fks as (
  select
    con.oid,
    con.conname,
    con.conrelid,
    con.confrelid,
    con.conkey,
    con.confkey,
    con.confdeltype
  from pg_catalog.pg_constraint con
  where con.contype = 'f'
    and con.conrelid = to_regclass('public.session_applications')
    and con.confrelid = to_regclass('public.player_characters')
)
select
  f.conname as constraint_name,
  f.conrelid::regclass as referencing_table,
  (
    select array_agg(att.attname order by cols.ord)
    from unnest(f.conkey) with ordinality as cols(attnum, ord)
    join pg_catalog.pg_attribute att
      on att.attrelid = f.conrelid
     and att.attnum = cols.attnum
  ) as referencing_columns,
  f.confrelid::regclass as referenced_table,
  (
    select array_agg(att.attname order by cols.ord)
    from unnest(f.confkey) with ordinality as cols(attnum, ord)
    join pg_catalog.pg_attribute att
      on att.attrelid = f.confrelid
     and att.attnum = cols.attnum
  ) as referenced_columns,
  case f.confdeltype
    when 'a' then 'NO ACTION'
    when 'r' then 'RESTRICT'
    when 'c' then 'CASCADE'
    when 'n' then 'SET NULL'
    when 'd' then 'SET DEFAULT'
    else f.confdeltype::text
  end as on_delete_action,
  pg_catalog.pg_get_constraintdef(f.oid) as definition
from selected_character_fks f
where (
  select array_agg(att.attname order by cols.ord)
  from unnest(f.conkey) with ordinality as cols(attnum, ord)
  join pg_catalog.pg_attribute att
    on att.attrelid = f.conrelid
   and att.attnum = cols.attnum
) = array['selected_character_id']::name[]
order by f.conname;

select
  count(*) filter (where sa.selected_character_id is null) as selected_character_id_null_count,
  count(*) filter (where sa.selected_character_id is not null) as selected_character_id_not_null_count
from public.session_applications sa;

select
  count(*) as orphan_selected_character_id_count
from public.session_applications sa
left join public.player_characters pc
  on pc.id = sa.selected_character_id
where sa.selected_character_id is not null
  and pc.id is null;

select
  exists (
    select 1
    from pg_catalog.pg_constraint con
    join pg_catalog.pg_attribute att
      on att.attrelid = con.conrelid
     and att.attnum = any(con.conkey)
    where con.contype = 'f'
      and con.conrelid = to_regclass('public.session_applications')
      and con.confrelid = to_regclass('public.player_characters')
      and att.attname = 'selected_character_id'
      and con.confdeltype = 'n'
  ) as selected_character_fk_has_on_delete_set_null;
