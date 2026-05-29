-- ============================================================
-- Velgard Supabase Free Prototype
-- 001_core_schema_draft.sql
--
-- DRAFT ONLY:
-- - 実行候補草案。まだ本番サイトへ接続しない。
-- - 実プロジェクトURL、API key、secret、実メール、実Discord IDは書かない。
-- - SQL Editorで段階実行する前提。
-- ============================================================

-- Step 1: extension
create extension if not exists "pgcrypto";

-- Step 2: core tables
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  discord_user_id text,
  discord_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_not_blank check (length(trim(display_name)) > 0),
  constraint profiles_discord_user_id_text check (
    discord_user_id is null or discord_user_id ~ '^[0-9]{17,20}$'
  )
);

create table public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, role),
  constraint user_roles_role_check check (role in ('player', 'gm', 'admin'))
);

create table public.sessions (
  id text primary key,
  title text not null,
  date date not null,
  start_time time,
  end_time time,
  gm_user_id uuid references public.profiles(id),
  gm_name text,
  status text not null default 'recruiting',
  level_range text,
  player_min integer,
  player_max integer,
  summary text,
  detail text,
  requirements text,
  visibility text not null default 'public',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sessions_id_not_blank check (length(trim(id)) > 0),
  constraint sessions_title_not_blank check (length(trim(title)) > 0),
  constraint sessions_status_check check (
    status in ('draft', 'tentative', 'recruiting', 'full', 'closed', 'finished', 'canceled')
  ),
  constraint sessions_visibility_check check (
    visibility in ('public', 'private', 'hidden')
  ),
  constraint sessions_player_range_check check (
    (player_min is null or player_min >= 0)
    and (player_max is null or player_max >= 0)
    and (player_min is null or player_max is null or player_min <= player_max)
  )
);

create table public.session_comments (
  id uuid primary key default gen_random_uuid(),
  session_id text not null references public.sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  is_application boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  constraint session_comments_body_not_blank check (length(trim(body)) > 0),
  constraint session_comments_body_length_check check (length(body) <= 4000)
);

create table public.session_applications (
  id uuid primary key default gen_random_uuid(),
  session_id text not null references public.sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  comment_id uuid references public.session_comments(id) on delete set null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  canceled_at timestamptz,
  constraint session_applications_status_check check (
    status in ('pending', 'accepted', 'rejected', 'waitlisted', 'canceled')
  ),
  constraint session_applications_unique_user unique (session_id, user_id)
);

-- Step 3: indexes
create index sessions_date_idx on public.sessions(date);
create index sessions_gm_user_id_idx on public.sessions(gm_user_id);
create index sessions_status_idx on public.sessions(status);
create index sessions_visibility_idx on public.sessions(visibility);

create index session_comments_session_id_idx on public.session_comments(session_id);
create index session_comments_user_id_idx on public.session_comments(user_id);
create index session_comments_visible_idx on public.session_comments(session_id, deleted_at);

create index session_applications_session_id_idx on public.session_applications(session_id);
create index session_applications_user_id_idx on public.session_applications(user_id);
create index session_applications_status_idx on public.session_applications(status);
create index session_applications_session_status_idx on public.session_applications(session_id, status);

-- Step 4: updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger sessions_set_updated_at
before update on public.sessions
for each row execute function public.set_updated_at();

create trigger session_comments_set_updated_at
before update on public.session_comments
for each row execute function public.set_updated_at();

create trigger session_applications_set_updated_at
before update on public.session_applications
for each row execute function public.set_updated_at();

-- Step 5: public profile view
-- profiles本体をanon全公開しない。
-- 公開列は id / display_name のみに絞る。
create view public.public_profiles
with (security_barrier = true)
as
select
  id,
  display_name
from public.profiles;
