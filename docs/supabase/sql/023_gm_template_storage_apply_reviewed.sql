-- 023_gm_template_storage_apply_reviewed.sql
-- M-15I-4 reviewed APPLY for GM template preset storage.
--
-- Use this reviewed APPLY file in SQL Editor.
-- Do not paste the full draft file when applying this step.
--
-- Scope:
-- - Create public.gm_template_presets for personal template presets.
-- - Create RLS policies for owner-only rows.
-- - Create template preset RPCs.
-- - Grant EXECUTE only to authenticated.
-- - Do not create shared/admin-common templates.
-- - Do not expose owner_user_id from RPC return values.

begin;

create table public.gm_template_presets (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  template_name text not null,
  template_type text not null,
  template_body text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gm_template_presets_template_name_not_blank check (
    length(trim(template_name)) > 0
  ),
  constraint gm_template_presets_template_name_length_check check (
    char_length(trim(template_name)) between 1 and 80
  ),
  constraint gm_template_presets_template_name_single_line_check check (
    position(chr(10) in template_name) = 0
    and position(chr(13) in template_name) = 0
  ),
  constraint gm_template_presets_template_type_check check (
    template_type in (
      'call',
      'result',
      'session_post',
      'application',
      'other'
    )
  ),
  constraint gm_template_presets_template_body_not_blank check (
    length(trim(template_body)) > 0
  ),
  constraint gm_template_presets_template_body_length_check check (
    char_length(template_body) between 1 and 5000
  )
);

create index gm_template_presets_owner_active_updated_idx
on public.gm_template_presets(
  owner_user_id,
  is_active,
  updated_at desc,
  created_at desc
);

create index gm_template_presets_owner_type_active_updated_idx
on public.gm_template_presets(
  owner_user_id,
  template_type,
  is_active,
  updated_at desc,
  created_at desc
);

create trigger gm_template_presets_set_updated_at
before update on public.gm_template_presets
for each row execute function public.set_updated_at();

alter table public.gm_template_presets enable row level security;

create policy "gm_template_presets_select_own"
on public.gm_template_presets
for select
to authenticated
using (auth.uid() is not null and owner_user_id = auth.uid());

create policy "gm_template_presets_insert_own"
on public.gm_template_presets
for insert
to authenticated
with check (auth.uid() is not null and owner_user_id = auth.uid());

create policy "gm_template_presets_update_own"
on public.gm_template_presets
for update
to authenticated
using (auth.uid() is not null and owner_user_id = auth.uid())
with check (auth.uid() is not null and owner_user_id = auth.uid());

revoke all on table public.gm_template_presets from public;
revoke all on table public.gm_template_presets from anon;
revoke all on table public.gm_template_presets from authenticated;

create or replace function public.get_my_template_presets()
returns table (
  template_id uuid,
  template_name text,
  template_type text,
  template_body text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = v_actor
  ) then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    gtp.id as template_id,
    gtp.template_name,
    gtp.template_type,
    gtp.template_body,
    gtp.created_at,
    gtp.updated_at
  from public.gm_template_presets as gtp
  where gtp.owner_user_id = v_actor
    and gtp.is_active = true
  order by
    gtp.updated_at desc,
    gtp.created_at desc,
    gtp.template_name asc;
end;
$$;

create or replace function public.create_template_preset(
  p_template_name text,
  p_template_type text,
  p_template_body text
)
returns table (
  template_id uuid,
  template_name text,
  template_type text,
  template_body text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_template_name text;
  v_template_type text;
  v_template_body text;
  v_template_id uuid;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = v_actor
  ) then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;

  v_template_name := nullif(trim(coalesce(p_template_name, '')), '');
  if v_template_name is null then
    raise exception 'template_name_required' using errcode = '22023';
  end if;
  if char_length(v_template_name) > 80 then
    raise exception 'template_name_too_long' using errcode = '22023';
  end if;
  if position(chr(10) in v_template_name) > 0
    or position(chr(13) in v_template_name) > 0 then
    raise exception 'template_name_invalid' using errcode = '22023';
  end if;

  v_template_type := lower(nullif(trim(coalesce(p_template_type, '')), ''));
  if v_template_type is null
    or v_template_type not in (
      'call',
      'result',
      'session_post',
      'application',
      'other'
    ) then
    raise exception 'template_type_invalid' using errcode = '22023';
  end if;

  v_template_body := coalesce(p_template_body, '');
  if length(trim(v_template_body)) = 0 then
    raise exception 'template_body_required' using errcode = '22023';
  end if;
  if char_length(v_template_body) > 5000 then
    raise exception 'template_body_too_long' using errcode = '22023';
  end if;

  insert into public.gm_template_presets (
    owner_user_id,
    template_name,
    template_type,
    template_body,
    is_active
  )
  values (
    v_actor,
    v_template_name,
    v_template_type,
    v_template_body,
    true
  )
  returning id into v_template_id;

  return query
  select
    gtp.id as template_id,
    gtp.template_name,
    gtp.template_type,
    gtp.template_body,
    gtp.is_active,
    gtp.created_at,
    gtp.updated_at
  from public.gm_template_presets as gtp
  where gtp.id = v_template_id
    and gtp.owner_user_id = v_actor;
end;
$$;

create or replace function public.update_template_preset(
  p_template_id uuid,
  p_template_name text,
  p_template_type text,
  p_template_body text,
  p_is_active boolean
)
returns table (
  template_id uuid,
  template_name text,
  template_type text,
  template_body text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_template_name text;
  v_template_type text;
  v_template_body text;
  v_template_id uuid;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if p_template_id is null then
    raise exception 'template_not_found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = v_actor
  ) then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;

  v_template_name := nullif(trim(coalesce(p_template_name, '')), '');
  if v_template_name is null then
    raise exception 'template_name_required' using errcode = '22023';
  end if;
  if char_length(v_template_name) > 80 then
    raise exception 'template_name_too_long' using errcode = '22023';
  end if;
  if position(chr(10) in v_template_name) > 0
    or position(chr(13) in v_template_name) > 0 then
    raise exception 'template_name_invalid' using errcode = '22023';
  end if;

  v_template_type := lower(nullif(trim(coalesce(p_template_type, '')), ''));
  if v_template_type is null
    or v_template_type not in (
      'call',
      'result',
      'session_post',
      'application',
      'other'
    ) then
    raise exception 'template_type_invalid' using errcode = '22023';
  end if;

  v_template_body := coalesce(p_template_body, '');
  if length(trim(v_template_body)) = 0 then
    raise exception 'template_body_required' using errcode = '22023';
  end if;
  if char_length(v_template_body) > 5000 then
    raise exception 'template_body_too_long' using errcode = '22023';
  end if;

  if p_is_active is null then
    raise exception 'template_active_required' using errcode = '22023';
  end if;

  update public.gm_template_presets as gtp
  set
    template_name = v_template_name,
    template_type = v_template_type,
    template_body = v_template_body,
    is_active = p_is_active
  where gtp.id = p_template_id
    and gtp.owner_user_id = v_actor
  returning gtp.id into v_template_id;

  if v_template_id is null then
    raise exception 'template_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    gtp.id as template_id,
    gtp.template_name,
    gtp.template_type,
    gtp.template_body,
    gtp.is_active,
    gtp.created_at,
    gtp.updated_at
  from public.gm_template_presets as gtp
  where gtp.id = v_template_id
    and gtp.owner_user_id = v_actor;
end;
$$;

create or replace function public.deactivate_template_preset(
  p_template_id uuid
)
returns table (
  template_id uuid,
  template_name text,
  template_type text,
  is_active boolean,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_template_id uuid;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if p_template_id is null then
    raise exception 'template_not_found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = v_actor
  ) then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;

  update public.gm_template_presets as gtp
  set is_active = false
  where gtp.id = p_template_id
    and gtp.owner_user_id = v_actor
  returning gtp.id into v_template_id;

  if v_template_id is null then
    raise exception 'template_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    gtp.id as template_id,
    gtp.template_name,
    gtp.template_type,
    gtp.is_active,
    gtp.updated_at
  from public.gm_template_presets as gtp
  where gtp.id = v_template_id
    and gtp.owner_user_id = v_actor;
end;
$$;

revoke all on function public.get_my_template_presets() from public;
revoke all on function public.get_my_template_presets() from anon;
revoke all on function public.get_my_template_presets() from authenticated;

revoke all on function public.create_template_preset(text, text, text) from public;
revoke all on function public.create_template_preset(text, text, text) from anon;
revoke all on function public.create_template_preset(text, text, text) from authenticated;

revoke all on function public.update_template_preset(uuid, text, text, text, boolean) from public;
revoke all on function public.update_template_preset(uuid, text, text, text, boolean) from anon;
revoke all on function public.update_template_preset(uuid, text, text, text, boolean) from authenticated;

revoke all on function public.deactivate_template_preset(uuid) from public;
revoke all on function public.deactivate_template_preset(uuid) from anon;
revoke all on function public.deactivate_template_preset(uuid) from authenticated;

grant execute on function public.get_my_template_presets() to authenticated;
grant execute on function public.create_template_preset(text, text, text) to authenticated;
grant execute on function public.update_template_preset(uuid, text, text, text, boolean) to authenticated;
grant execute on function public.deactivate_template_preset(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;

-- ============================================================
-- POST-APPLY CHECKS
-- ============================================================

select
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns as c
where c.table_schema = 'public'
  and c.table_name = 'gm_template_presets'
order by c.ordinal_position;

select
  con.conname,
  con.contype,
  pg_catalog.pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint as con
where con.conrelid = to_regclass('public.gm_template_presets')
order by con.contype, con.conname;

with target_functions as (
  select
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    p.proconfig as function_config,
    pg_catalog.pg_get_function_result(p.oid) as result_type
  from pg_catalog.pg_proc as p
  join pg_catalog.pg_namespace as n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'get_my_template_presets',
      'create_template_preset',
      'update_template_preset',
      'deactivate_template_preset'
    )
)
select
  count(*) as function_count,
  bool_and(security_definer) as all_security_definer,
  bool_and(coalesce(function_config::text, '') like '%search_path%') as all_have_search_path,
  string_agg(signature, ', ' order by signature) as signatures
from target_functions;

with expected_grants(routine_name, grantee, expected_execute) as (
  values
    ('get_my_template_presets', 'authenticated', true),
    ('get_my_template_presets', 'anon', false),
    ('get_my_template_presets', 'public', false),
    ('create_template_preset', 'authenticated', true),
    ('create_template_preset', 'anon', false),
    ('create_template_preset', 'public', false),
    ('update_template_preset', 'authenticated', true),
    ('update_template_preset', 'anon', false),
    ('update_template_preset', 'public', false),
    ('deactivate_template_preset', 'authenticated', true),
    ('deactivate_template_preset', 'anon', false),
    ('deactivate_template_preset', 'public', false)
),
actual_grants as (
  select
    rp.routine_name,
    lower(rp.grantee) as grantee,
    true as actual_execute
  from information_schema.routine_privileges as rp
  where rp.routine_schema = 'public'
    and rp.routine_name in (
      'get_my_template_presets',
      'create_template_preset',
      'update_template_preset',
      'deactivate_template_preset'
    )
    and rp.privilege_type = 'EXECUTE'
)
select
  eg.routine_name,
  eg.grantee,
  eg.expected_execute,
  coalesce(ag.actual_execute, false) as actual_execute,
  coalesce(ag.actual_execute, false) = eg.expected_execute as ok
from expected_grants as eg
left join actual_grants as ag
  on ag.routine_name = eg.routine_name
 and ag.grantee = eg.grantee
order by eg.routine_name, eg.grantee;

select
  p.policyname,
  p.roles,
  p.cmd
from pg_catalog.pg_policies as p
where p.schemaname = 'public'
  and p.tablename = 'gm_template_presets'
order by p.policyname;
