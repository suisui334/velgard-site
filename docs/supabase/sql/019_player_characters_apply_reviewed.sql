-- 019_player_characters_apply_reviewed.sql
-- M-15C reviewed APPLY-only SQL for player character registration.
-- Paste this entire file into Supabase SQL Editor only after review.
-- Do not paste the full draft file.
-- This file intentionally excludes preflight queries, rollback drafts,
-- application-flow replacement RPCs, template-output RPCs, and frontend work.

create table public.player_characters (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  pc_name text not null,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_characters_pc_name_not_blank check (length(trim(pc_name)) > 0),
  constraint player_characters_pc_name_length_check check (char_length(pc_name) <= 40),
  constraint player_characters_pc_name_single_line_check check (
    position(chr(10) in pc_name) = 0
    and position(chr(13) in pc_name) = 0
  )
);

comment on table public.player_characters is
  'Player-owned character names for future session applications and template output.';

comment on column public.player_characters.owner_user_id is
  'Owner profile id. References public.profiles(id).';

comment on column public.player_characters.pc_name is
  'Player character name managed by the owner.';

comment on column public.player_characters.is_default is
  'At most one active default character per owner.';

comment on column public.player_characters.is_active is
  'False means hidden from active choices. Physical deletion is not the initial path.';

create index player_characters_owner_idx
on public.player_characters(owner_user_id);

create index player_characters_owner_active_idx
on public.player_characters(owner_user_id, is_active);

create unique index player_characters_one_default_per_owner_idx
on public.player_characters(owner_user_id)
where is_default = true and is_active = true;

create trigger player_characters_set_updated_at
before update on public.player_characters
for each row execute function public.set_updated_at();

alter table public.player_characters enable row level security;

create policy "player_characters_select_own"
on public.player_characters
for select
to authenticated
using (auth.uid() is not null and owner_user_id = auth.uid());

-- Writes are intentionally routed through security definer RPCs.
-- No direct insert/update/delete RLS policy is added in this APPLY step.

alter table public.session_applications
  add column selected_character_id uuid null references public.player_characters(id) on delete set null,
  add column pc_name_snapshot text null;

comment on column public.session_applications.selected_character_id is
  'Optional link to the selected player character. If the character row is removed, this becomes null.';

comment on column public.session_applications.pc_name_snapshot is
  'Application-time PC name snapshot. Template and history output should prefer this value.';

alter table public.session_applications
  add constraint session_applications_pc_name_snapshot_length_check
  check (pc_name_snapshot is null or char_length(pc_name_snapshot) <= 40);

alter table public.session_applications
  add constraint session_applications_pc_name_snapshot_single_line_check
  check (
    pc_name_snapshot is null
    or (
      position(chr(10) in pc_name_snapshot) = 0
      and position(chr(13) in pc_name_snapshot) = 0
    )
  );

create index session_applications_selected_character_idx
on public.session_applications(selected_character_id);

create index session_applications_session_pc_snapshot_idx
on public.session_applications(session_id, pc_name_snapshot);

create or replace function public.get_my_player_characters()
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.owner_user_id = auth.uid()
  order by
    pc.is_active desc,
    pc.is_default desc,
    pc.updated_at desc,
    pc.created_at desc;
end;
$$;

comment on function public.get_my_player_characters() is
  'Returns the signed-in user player characters without exposing owner ids.';

create or replace function public.create_player_character(
  p_pc_name text,
  p_is_default boolean default false
)
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
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
  v_pc_name text;
  v_make_default boolean;
  v_has_active boolean := false;
  v_character_id uuid;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_pc_name := nullif(trim(coalesce(p_pc_name, '')), '');
  if v_pc_name is null then
    raise exception 'pc_name_required' using errcode = '22023';
  end if;
  if char_length(v_pc_name) > 40 then
    raise exception 'pc_name_too_long' using errcode = '22023';
  end if;
  if position(chr(10) in v_pc_name) > 0 or position(chr(13) in v_pc_name) > 0 then
    raise exception 'pc_name_invalid' using errcode = '22023';
  end if;

  select exists (
    select 1
    from public.player_characters as pc
    where pc.owner_user_id = v_actor
      and pc.is_active = true
  )
  into v_has_active;

  v_make_default := coalesce(p_is_default, false) or not v_has_active;

  if v_make_default then
    update public.player_characters as pc
    set is_default = false
    where pc.owner_user_id = v_actor
      and pc.is_active = true;
  end if;

  insert into public.player_characters (
    owner_user_id,
    pc_name,
    is_default,
    is_active
  )
  values (
    v_actor,
    v_pc_name,
    v_make_default,
    true
  )
  returning id into v_character_id;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.id = v_character_id
    and pc.owner_user_id = v_actor;
end;
$$;

comment on function public.create_player_character(text, boolean) is
  'Creates one active player character for the signed-in user.';

create or replace function public.update_player_character(
  p_character_id uuid,
  p_pc_name text,
  p_is_default boolean default false,
  p_is_active boolean default true
)
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
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
  v_pc_name text;
  v_make_default boolean := coalesce(p_is_default, false);
  v_is_active boolean := coalesce(p_is_active, true);
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_pc_name := nullif(trim(coalesce(p_pc_name, '')), '');
  if p_character_id is null or v_pc_name is null then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;
  if char_length(v_pc_name) > 40 then
    raise exception 'pc_name_too_long' using errcode = '22023';
  end if;
  if position(chr(10) in v_pc_name) > 0 or position(chr(13) in v_pc_name) > 0 then
    raise exception 'pc_name_invalid' using errcode = '22023';
  end if;

  if v_make_default and v_is_active then
    update public.player_characters as pc
    set is_default = false
    where pc.owner_user_id = v_actor
      and pc.id <> p_character_id
      and pc.is_active = true;
  end if;

  update public.player_characters as pc
  set
    pc_name = v_pc_name,
    is_default = case when v_is_active then v_make_default else false end,
    is_active = v_is_active,
    updated_at = now()
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;

  if not found then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;
end;
$$;

comment on function public.update_player_character(uuid, text, boolean, boolean) is
  'Updates one signed-in user player character. Can also deactivate it by setting p_is_active false.';

create or replace function public.set_default_player_character(
  p_character_id uuid
)
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
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
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if p_character_id is null then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from public.player_characters as pc
    where pc.id = p_character_id
      and pc.owner_user_id = v_actor
      and pc.is_active = true
  ) then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;

  update public.player_characters as pc
  set is_default = false,
      updated_at = now()
  where pc.owner_user_id = v_actor
    and pc.is_active = true;

  update public.player_characters as pc
  set is_default = true,
      updated_at = now()
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor
    and pc.is_active = true;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;
end;
$$;

comment on function public.set_default_player_character(uuid) is
  'Sets one active signed-in user player character as default and clears the previous default.';

create or replace function public.deactivate_player_character(
  p_character_id uuid
)
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
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
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  update public.player_characters as pc
  set
    is_default = false,
    is_active = false,
    updated_at = now()
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;

  if not found then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;
end;
$$;

comment on function public.deactivate_player_character(uuid) is
  'Deactivates one signed-in user player character without removing application snapshots.';

revoke execute on function public.get_my_player_characters() from public;
revoke execute on function public.get_my_player_characters() from anon;

revoke execute on function public.create_player_character(text, boolean) from public;
revoke execute on function public.create_player_character(text, boolean) from anon;

revoke execute on function public.update_player_character(uuid, text, boolean, boolean) from public;
revoke execute on function public.update_player_character(uuid, text, boolean, boolean) from anon;

revoke execute on function public.set_default_player_character(uuid) from public;
revoke execute on function public.set_default_player_character(uuid) from anon;

revoke execute on function public.deactivate_player_character(uuid) from public;
revoke execute on function public.deactivate_player_character(uuid) from anon;

grant execute on function public.get_my_player_characters() to authenticated;
grant execute on function public.create_player_character(text, boolean) to authenticated;
grant execute on function public.update_player_character(uuid, text, boolean, boolean) to authenticated;
grant execute on function public.set_default_player_character(uuid) to authenticated;
grant execute on function public.deactivate_player_character(uuid) to authenticated;

notify pgrst, 'reload schema';

select
  'player_characters_table' as check_name,
  exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'player_characters'
      and table_type = 'BASE TABLE'
  ) as ok;

select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'player_characters'
order by ordinal_position;

select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'session_applications'
  and column_name in ('selected_character_id', 'pc_name_snapshot')
order by ordinal_position;

select
  c.conname as constraint_name,
  c.conrelid::regclass::text as table_name,
  a.attname as column_name,
  c.confrelid::regclass::text as references_table,
  af.attname as references_column,
  c.confdeltype,
  c.confdeltype = 'n' as on_delete_set_null
from pg_constraint c
join pg_class t
  on t.oid = c.conrelid
join pg_namespace nt
  on nt.oid = t.relnamespace
join unnest(c.conkey) with ordinality as ck(attnum, ord)
  on true
join pg_attribute a
  on a.attrelid = c.conrelid
 and a.attnum = ck.attnum
join unnest(c.confkey) with ordinality as fk(attnum, ord)
  on fk.ord = ck.ord
join pg_attribute af
  on af.attrelid = c.confrelid
 and af.attnum = fk.attnum
where nt.nspname = 'public'
  and t.relname = 'session_applications'
  and c.contype = 'f'
  and a.attname = 'selected_character_id';

with expected_functions(function_name, identity_args) as (
  values
    ('get_my_player_characters', ''),
    ('create_player_character', 'p_pc_name text, p_is_default boolean'),
    ('update_player_character', 'p_character_id uuid, p_pc_name text, p_is_default boolean, p_is_active boolean'),
    ('set_default_player_character', 'p_character_id uuid'),
    ('deactivate_player_character', 'p_character_id uuid')
),
actual_functions as (
  select
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as identity_args,
    p.oid::regprocedure as signature,
    p.prosecdef as security_definer
  from pg_proc p
  join pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
)
select
  e.function_name,
  e.identity_args,
  a.signature,
  a.security_definer,
  a.security_definer is true as ok
from expected_functions e
left join actual_functions a
  on a.function_name = e.function_name
 and a.identity_args = e.identity_args
order by e.function_name;

with expected_grants(function_name, grantee, expected_execute) as (
  values
    ('get_my_player_characters', 'authenticated', true),
    ('get_my_player_characters', 'anon', false),
    ('get_my_player_characters', 'public', false),
    ('create_player_character', 'authenticated', true),
    ('create_player_character', 'anon', false),
    ('create_player_character', 'public', false),
    ('update_player_character', 'authenticated', true),
    ('update_player_character', 'anon', false),
    ('update_player_character', 'public', false),
    ('set_default_player_character', 'authenticated', true),
    ('set_default_player_character', 'anon', false),
    ('set_default_player_character', 'public', false),
    ('deactivate_player_character', 'authenticated', true),
    ('deactivate_player_character', 'anon', false),
    ('deactivate_player_character', 'public', false)
),
actual_grants as (
  select
    routine_name as function_name,
    lower(grantee) as grantee,
    bool_or(privilege_type = 'EXECUTE') as actual_execute
  from information_schema.routine_privileges
  where routine_schema = 'public'
    and routine_name in (
      'get_my_player_characters',
      'create_player_character',
      'update_player_character',
      'set_default_player_character',
      'deactivate_player_character'
    )
  group by routine_name, lower(grantee)
)
select
  e.function_name,
  e.grantee,
  e.expected_execute,
  coalesce(a.actual_execute, false) as actual_execute,
  coalesce(a.actual_execute, false) = e.expected_execute as ok
from expected_grants e
left join actual_grants a
  on a.function_name = e.function_name
 and a.grantee = e.grantee
order by e.function_name, e.grantee;
