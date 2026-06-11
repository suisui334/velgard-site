-- 063_notification_timeline_display_diagnostics_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Diagnose why real PL comment/application actions do not appear as TIMELINE cards.
-- - Diagnose whether notification history RPCs support read notifications remaining visible.
-- - Return counts and boolean/status results only.
-- - Do not return function bodies, titles, bodies, real user ids, emails, tokens,
--   full URLs, project refs, notification ids, activity ids, session ids, or secrets.

with activity_counts as (
  select
    count(*) as total_count,
    count(*) filter (where visibility = 'public') as public_count,
    count(*) filter (where visibility = 'authenticated') as authenticated_count,
    count(*) filter (where visibility = 'private') as private_count,
    count(*) filter (where event_type = 'session_comment') as comment_count,
    count(*) filter (where event_type = 'session_application') as application_count,
    count(*) filter (
      where event_type in ('session_comment', 'session_application')
        and visibility = 'authenticated'
    ) as authenticated_pl_event_count,
    count(*) filter (
      where event_type in ('session_comment', 'session_application')
        and target_path like 'session-detail.html?id=%'
        and target_path !~* '^[a-z][a-z0-9+.-]*://'
        and position('..' in target_path) = 0
    ) as renderable_target_count,
    count(*) filter (
      where event_type in ('session_comment', 'session_application')
        and body in ('A participation application was posted.', 'A comment was posted.')
    ) as generic_body_count
  from public.activity_events
),
notification_counts as (
  select
    count(*) as total_count,
    count(*) filter (where read_at is null) as unread_count,
    count(*) filter (where read_at is not null) as read_count
  from public.user_notifications
),
timeline_rpc as (
  select
    count(*) as rpc_count,
    coalesce(bool_and(p.prosecdef), false) as security_definer,
    coalesce(bool_and(coalesce(array_to_string(p.proconfig, ','), '') ilike '%search_path=public%'), false) as search_path_public,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%visibility = ''authenticated'' and auth.uid() is not null%'), false) as has_authenticated_visibility_branch,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%order by ae.created_at desc%'), false) as has_newest_first_order,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%target_path%'), false) as returns_target_path,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%actor.display_name%'), false) as returns_actor_display_name,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%s.title%'), false) as returns_session_title
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_activity_timeline'
    and p.oid::regprocedure::text = 'get_activity_timeline(integer)'
),
comment_rpc as (
  select
    count(*) as rpc_count,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%record_activity_event%'), false) as calls_activity_helper,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%session_application%'), false) as has_application_activity_type,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%session_comment%'), false) as has_comment_activity_type,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%A participation application was posted.%'), false) as has_generic_application_body,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%A comment was posted.%'), false) as has_generic_comment_body,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%GM/admin%management comments%'), false) as documents_management_skip
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'create_application_comment'
    and p.oid::regprocedure::text = 'create_application_comment(text,text)'
),
notification_rpc as (
  select
    count(*) as rpc_count,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%p_unread_only%'), false) as has_unread_only_arg,
    coalesce(bool_or(pg_catalog.pg_get_functiondef(p.oid) like '%not coalesce(p_unread_only, false) or un.read_at is null%'), false) as supports_read_history
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_my_notifications'
    and p.oid::regprocedure::text = 'get_my_notifications(integer,boolean)'
),
output_rows as (
  select
    10 as sort_order,
    'activity_events_total_count'::text as check_name,
    case when total_count > 0 then 'ok' else 'review' end as status,
    total_count::text as result_value,
    'If this is zero after a PL comment/application, activity rows were not created.'::text as note
  from activity_counts

  union all
  select
    20,
    'activity_events_authenticated_pl_count',
    case when authenticated_pl_event_count > 0 then 'ok' else 'review' end,
    authenticated_pl_event_count::text,
    'PL comment/application activity should exist with authenticated visibility after 061.'
  from activity_counts

  union all
  select
    30,
    'activity_events_visibility_counts',
    'info',
    concat('public=', public_count, ',authenticated=', authenticated_count, ',private=', private_count),
    'Counts only; no row content or identifiers are returned.'
  from activity_counts

  union all
  select
    40,
    'activity_events_type_counts',
    'info',
    concat('comment=', comment_count, ',application=', application_count),
    'Counts only; confirms whether PL comment/application types are present.'
  from activity_counts

  union all
  select
    50,
    'activity_events_renderable_target_count',
    case when renderable_target_count > 0 then 'ok' else 'review' end,
    renderable_target_count::text,
    'Timeline links require safe relative session-detail target paths.'
  from activity_counts

  union all
  select
    60,
    'activity_events_generic_body_count',
    case when generic_body_count > 0 then 'ok' else 'review' end,
    generic_body_count::text,
    'Activity body should be generic and not raw long comment text.'
  from activity_counts

  union all
  select
    70,
    'get_activity_timeline_exists',
    case when rpc_count = 1 then 'ok' else 'review' end,
    rpc_count::text,
    'Expected exactly one timeline read RPC.'
  from timeline_rpc

  union all
  select
    80,
    'get_activity_timeline_security',
    case when security_definer and search_path_public then 'ok' else 'review' end,
    concat('security_definer=', security_definer, ',search_path_public=', search_path_public),
    'Timeline read RPC should keep security definer and search_path=public.'
  from timeline_rpc

  union all
  select
    90,
    'get_activity_timeline_authenticated_visibility_branch',
    case when has_authenticated_visibility_branch then 'ok' else 'review' end,
    has_authenticated_visibility_branch::text,
    'Authenticated activity rows require a logged-in request context.'
  from timeline_rpc

  union all
  select
    100,
    'get_activity_timeline_return_shape',
    case
      when has_newest_first_order and returns_target_path and returns_actor_display_name and returns_session_title
      then 'ok'
      else 'review'
    end,
    concat(
      'newest_first=', has_newest_first_order,
      ',target_path=', returns_target_path,
      ',actor=', returns_actor_display_name,
      ',session_title=', returns_session_title
    ),
    'Return shape should match the existing timeline frontend.'
  from timeline_rpc

  union all
  select
    110,
    'create_application_comment_activity_patterns',
    case
      when calls_activity_helper
       and has_application_activity_type
       and has_comment_activity_type
       and has_generic_application_body
       and has_generic_comment_body
      then 'ok'
      else 'review'
    end,
    concat(
      'helper=', calls_activity_helper,
      ',application=', has_application_activity_type,
      ',comment=', has_comment_activity_type,
      ',generic_application=', has_generic_application_body,
      ',generic_comment=', has_generic_comment_body
    ),
    'Static RPC pattern check; real row creation is checked by activity counts above.'
  from comment_rpc

  union all
  select
    120,
    'create_application_comment_management_activity_skip_note',
    case when documents_management_skip then 'ok' else 'review' end,
    documents_management_skip::text,
    'Management comments should stay out of shared activity in the MVP.'
  from comment_rpc

  union all
  select
    130,
    'get_my_notifications_history_support',
    case when rpc_count = 1 and has_unread_only_arg and supports_read_history then 'ok' else 'review' end,
    concat('rpc=', rpc_count, ',arg=', has_unread_only_arg, ',history=', supports_read_history),
    'Notification list RPC should support read+unread history when p_unread_only=false.'
  from notification_rpc

  union all
  select
    140,
    'notification_read_state_counts',
    'info',
    concat('total=', total_count, ',unread=', unread_count, ',read=', read_count),
    'Counts only; read notifications should remain available to the list RPC.'
  from notification_counts

  union all
  select
    150,
    'diagnosis_next_step',
    case
      when (select authenticated_pl_event_count from activity_counts) = 0 then 'review'
      when (select has_authenticated_visibility_branch from timeline_rpc) then 'ok'
      else 'review'
    end,
    case
      when (select authenticated_pl_event_count from activity_counts) = 0 then 'activity_missing'
      when (select has_authenticated_visibility_branch from timeline_rpc) then 'check_logged_in_frontend'
      else 'timeline_rpc_visibility_review'
    end,
    'activity_missing means instrumentation did not produce rows; check_logged_in_frontend means verify logged-in timeline rendering.'
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order;
