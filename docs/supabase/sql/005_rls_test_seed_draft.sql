-- Supabase Step 5 RLS test seed draft
-- Purpose:
--   Prepare prototype-only test profiles, roles, and sessions for RLS testing.
--
-- DRAFT ONLY:
--   Do not run against production.
--   Do not commit a copy after replacing placeholders.
--   Do not paste Project URL, API keys, service role keys, JWT secrets,
--   DB passwords, real emails, real Discord IDs, webhook URLs, or bot tokens.
--
-- Replace these placeholders inside Supabase SQL Editor only.
-- Do not write real Auth UUIDs into this repository.
--
--   <PLAYER_A_ID>
--   <PLAYER_B_ID>
--   <GM_A_ID>
--   <GM_B_ID>
--   <ADMIN_ID>

-- 1. Test profiles.
-- Auth users must already exist before these rows are inserted.
insert into public.profiles (
  id,
  display_name,
  discord_user_id,
  discord_name
)
values
  ('<PLAYER_A_ID>'::uuid, 'RLS Test Player A', null, null),
  ('<PLAYER_B_ID>'::uuid, 'RLS Test Player B', null, null),
  ('<GM_A_ID>'::uuid, 'RLS Test GM A', null, null),
  ('<GM_B_ID>'::uuid, 'RLS Test GM B', null, null),
  ('<ADMIN_ID>'::uuid, 'RLS Test Admin', null, null)
on conflict (id) do update
set
  display_name = excluded.display_name,
  discord_user_id = excluded.discord_user_id,
  discord_name = excluded.discord_name,
  updated_at = now();

-- 2. Test global roles.
insert into public.user_roles (
  user_id,
  role
)
values
  ('<PLAYER_A_ID>'::uuid, 'player'),
  ('<PLAYER_B_ID>'::uuid, 'player'),
  ('<GM_A_ID>'::uuid, 'player'),
  ('<GM_A_ID>'::uuid, 'gm'),
  ('<GM_B_ID>'::uuid, 'player'),
  ('<GM_B_ID>'::uuid, 'gm'),
  ('<ADMIN_ID>'::uuid, 'admin')
on conflict (user_id, role) do nothing;

-- 3. Test sessions.
insert into public.sessions (
  id,
  title,
  date,
  start_time,
  end_time,
  gm_user_id,
  gm_name,
  status,
  level_range,
  player_min,
  player_max,
  summary,
  detail,
  requirements,
  visibility
)
values
  (
    'rls-test-public-recruiting',
    'RLS Test Public Recruiting',
    '2026-07-01',
    '21:00',
    '23:30',
    '<GM_A_ID>'::uuid,
    'RLS Test GM A',
    'recruiting',
    '3Lv',
    3,
    5,
    'RLS test session that should accept application comments.',
    'Prototype-only test data.',
    'Prototype-only test requirements.',
    'public'
  ),
  (
    'rls-test-public-tentative',
    'RLS Test Public Tentative',
    '2026-07-02',
    '21:00',
    '23:30',
    '<GM_A_ID>'::uuid,
    'RLS Test GM A',
    'tentative',
    '3Lv',
    3,
    5,
    'RLS test tentative session that should accept application comments.',
    'Prototype-only test data.',
    null,
    'public'
  ),
  (
    'rls-test-public-full',
    'RLS Test Public Full',
    '2026-07-03',
    '21:00',
    '23:30',
    '<GM_A_ID>'::uuid,
    'RLS Test GM A',
    'full',
    '3Lv',
    3,
    5,
    'RLS test full session that should reject new applications.',
    'Prototype-only test data.',
    null,
    'public'
  ),
  (
    'rls-test-public-closed',
    'RLS Test Public Closed',
    '2026-07-04',
    '21:00',
    '23:30',
    '<GM_A_ID>'::uuid,
    'RLS Test GM A',
    'closed',
    '3Lv',
    3,
    5,
    'RLS test closed session that should reject new applications.',
    'Prototype-only test data.',
    null,
    'public'
  ),
  (
    'rls-test-public-finished',
    'RLS Test Public Finished',
    '2026-07-05',
    '21:00',
    '23:30',
    '<GM_A_ID>'::uuid,
    'RLS Test GM A',
    'finished',
    '3Lv',
    3,
    5,
    'RLS test finished session that should reject new applications.',
    'Prototype-only test data.',
    null,
    'public'
  ),
  (
    'rls-test-public-canceled',
    'RLS Test Public Canceled',
    '2026-07-06',
    '21:00',
    '23:30',
    '<GM_A_ID>'::uuid,
    'RLS Test GM A',
    'canceled',
    '3Lv',
    3,
    5,
    'RLS test canceled session that should reject new applications.',
    'Prototype-only test data.',
    null,
    'public'
  ),
  (
    'rls-test-private-recruiting',
    'RLS Test Private Recruiting',
    '2026-07-07',
    '21:00',
    '23:30',
    '<GM_A_ID>'::uuid,
    'RLS Test GM A',
    'recruiting',
    '3Lv',
    3,
    5,
    'RLS test private session that should not leak to unrelated users.',
    'Prototype-only test data.',
    null,
    'private'
  ),
  (
    'rls-test-hidden-recruiting',
    'RLS Test Hidden Recruiting',
    '2026-07-08',
    '21:00',
    '23:30',
    '<GM_A_ID>'::uuid,
    'RLS Test GM A',
    'recruiting',
    '3Lv',
    3,
    5,
    'RLS test hidden session that should not leak to unrelated users.',
    'Prototype-only test data.',
    null,
    'hidden'
  ),
  (
    'rls-test-other-gm-recruiting',
    'RLS Test Other GM Recruiting',
    '2026-07-09',
    '21:00',
    '23:30',
    '<GM_B_ID>'::uuid,
    'RLS Test GM B',
    'recruiting',
    '3Lv',
    3,
    5,
    'RLS test public session owned by another GM.',
    'Prototype-only test data.',
    null,
    'public'
  )
on conflict (id) do update
set
  title = excluded.title,
  date = excluded.date,
  start_time = excluded.start_time,
  end_time = excluded.end_time,
  gm_user_id = excluded.gm_user_id,
  gm_name = excluded.gm_name,
  status = excluded.status,
  level_range = excluded.level_range,
  player_min = excluded.player_min,
  player_max = excluded.player_max,
  summary = excluded.summary,
  detail = excluded.detail,
  requirements = excluded.requirements,
  visibility = excluded.visibility,
  updated_at = now();

-- 4. Seed verification.
select
  id,
  status,
  visibility,
  public.can_apply_to_session(id) as can_apply
from public.sessions
where id like 'rls-test-%'
order by date, id;
