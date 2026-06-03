-- 021_fix_selected_character_fk_apply_reviewed.sql
-- M-15D correction APPLY for session_applications.selected_character_id FK.
--
-- APPLY ONLY AFTER 021_fix_selected_character_fk_preflight_select_only.sql
-- confirms:
-- - public.session_applications.selected_character_id exists.
-- - public.player_characters.id exists.
-- - current constraint name is session_applications_selected_character_id_fkey.
-- - selected_character_id has no orphan references.
--
-- Do not paste Project URL, API keys, service role keys, DB passwords,
-- direct connection strings, JWT secrets, tokens, real emails, real user IDs,
-- real Discord IDs, or other secrets into this file.

begin;

alter table public.session_applications
  drop constraint if exists session_applications_selected_character_id_fkey;

alter table public.session_applications
  add constraint session_applications_selected_character_id_fkey
  foreign key (selected_character_id)
  references public.player_characters(id)
  on delete set null;

commit;

-- ============================================================
-- POST-APPLY CHECKS
-- ============================================================

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
    when 'n' then true
    else false
  end as on_delete_set_null,
  pg_catalog.pg_get_constraintdef(f.oid) as definition
from selected_character_fks f
where f.conname = 'session_applications_selected_character_id_fkey'
order by f.conname;

select
  exists (
    select 1
    from pg_catalog.pg_constraint con
    join pg_catalog.pg_attribute att
      on att.attrelid = con.conrelid
     and att.attnum = any(con.conkey)
    where con.contype = 'f'
      and con.conname = 'session_applications_selected_character_id_fkey'
      and con.conrelid = to_regclass('public.session_applications')
      and con.confrelid = to_regclass('public.player_characters')
      and att.attname = 'selected_character_id'
      and con.confdeltype = 'n'
      and pg_catalog.pg_get_constraintdef(con.oid) like '%ON DELETE SET NULL%'
  ) as selected_character_fk_fixed;
