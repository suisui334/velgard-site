# Profile Avatar MVP Plan

Status: non-destructive preparation only. No SQL Editor execution, DB/Auth/RLS change, Storage bucket creation, Supabase Dashboard change, SQL apply, real upload, or secret handling has been performed.

## Goal

Add an account/profile avatar MVP so users can set and remove their own public icon from mypage, and so session-detail comments can show the comment author's avatar next to the display name and timestamp.

The MVP keeps email/auth identity private. Public identity remains centered on `profiles.display_name`, with avatar metadata treated as public display metadata.

## Current Findings

- `profiles` currently stores profile identity such as `display_name` and contact-related fields, but no avatar fields.
- `public_profiles` is the narrow public profile surface and currently exposes display identity only.
- Session-detail comments are loaded through `get_public_session_comments(text)` rather than direct table reads.
- `assets/js/sessionDetailApplicationComments.js` normalizes `display_name` from that RPC and renders the comment header with `.session-comment-item-head` and `.session-comment-author`.
- The comment renderer already has a natural future insertion point for an avatar element beside the author block.
- The current comment sensitive-field guard rejects known private names rather than all additional public display fields, but frontend normalization/rendering still needs a later explicit avatar update.
- mypage already has profile sections and display-name editing, so the avatar UI should live in the profile/account area after DB and Storage are ready.

## Proposed Data Model

- Storage bucket: `avatars`.
- Bucket read mode: public read, because profile icons are public display assets.
- Owner writes: authenticated users may write/update/remove only their own object prefix.
- Object path convention: a per-user folder prefix, with an image filename under it.
- DB metadata:
  - `profiles.avatar_path text`
  - `profiles.avatar_updated_at timestamptz`
- Store only the object path in DB, not a full URL.
- `public_profiles` should expose:
  - `id`
  - `display_name`
  - `avatar_path`
  - `avatar_updated_at`
- Comment display RPC/view should return `avatar_path` and `avatar_updated_at` with `display_name`.

## SQL Drafts

- `docs/supabase/sql/055_profile_avatars_storage_schema_apply_draft.sql`
  - DO NOT RUN / NOT EXECUTED / explicit approval required.
  - Adds avatar columns and safety constraint.
  - Extends `public_profiles`.
  - Extends `get_public_session_comments(text)` with public avatar metadata.
  - Drafts `avatars` bucket setup and owner-only Storage policies.
  - Drafts `update_my_avatar_path(text)` and `clear_my_avatar_path()` RPCs.
- `docs/supabase/sql/056_profile_avatars_post_apply_select_only.sql`
  - SELECT-only confirmation SQL.
  - Checks profile columns, public view shape, bucket readiness, Storage policies, avatar RPCs, comment RPC shape, and frontend-QA readiness.

## Frontend Follow-Up Plan

After 055 is applied and 056 confirms readiness:

1. Add mypage avatar controls.
   - Preview current avatar or default icon.
   - File input for png/jpeg/webp.
   - Candidate size limit: about 1MB.
   - Upload to the `avatars` bucket under the user's own prefix.
   - Call `update_my_avatar_path` after upload.
   - Remove button deletes or supersedes the storage object in a safe follow-up gate, then calls `clear_my_avatar_path`.
2. Add default avatar behavior.
   - If `avatar_path` is null, render the existing/default account icon style.
   - Do not expose raw user ids, emails, tokens, or signed URLs.
3. Add session-detail comment avatar rendering.
   - Normalize `avatar_path` and `avatar_updated_at` from public comment rows.
   - Render an avatar element near `.session-comment-author`.
   - Build public asset access at runtime from Storage helpers or a controlled bucket public path.
   - Avoid writing full image URLs into docs or UI diagnostics.
4. Add CSS.
   - Candidate classes: `.profile-avatar`, `.profile-avatar-preview`, `.session-comment-avatar`.
   - Keep comment layout usable on PC and smartphone widths.

## Safety Gates

- 055 SQL apply is an independent dangerous gate.
- 056 SELECT-only confirmation is a separate gate after 055.
- Avatar RPCs and the public comment RPC should use `security definer` with `set search_path = public`, while still keeping explicit schema references where practical.
- Frontend avatar UI wiring happens only after 056 is healthy.
- Real upload/delete QA is a separate gate because it writes Storage objects.
- No API keys, JWTs, real user ids, real object paths, signed URLs, full public URLs, or email values should be recorded.

## Apply Confirmation

Status: 055 apply and 056 SELECT-only confirmation were completed by the user in Supabase SQL Editor. Codex did not run SQL Editor or perform DB/Storage changes directly.

- `055_profile_avatars_storage_schema_apply_draft.sql` was executed once and succeeded.
- `056_profile_avatars_post_apply_select_only.sql` was executed as the post-apply SELECT-only confirmation and returned OK results.
- `profiles.avatar_path` and `profiles.avatar_updated_at` are confirmed ready.
- `public_profiles` exposes the public avatar metadata columns.
- The `avatars` bucket exists with public read, png/jpeg/webp support, and the expected approximate 1MB limit.
- Storage policy state matches the MVP model: public read plus authenticated owner-path insert/update/delete.
- Avatar metadata update/clear RPCs exist, are authenticated-only, and are not executable by anon.
- `security definer` avatar/comment RPCs are confirmed with `search_path=public`.
- The public comment display RPC returns avatar metadata.
- `post_apply_ready_for_avatar_frontend_qa=true`.
- The next step is a frontend implementation gate for mypage avatar UI and session-detail comment avatar display.

No real user id, avatar object path, signed URL, email, JWT, token, project ref, or Storage internal value was recorded.

## Frontend Implementation

Status: frontend wiring is implemented; real upload/delete QA is still a separate Storage-writing gate.

- mypage now includes an account icon block in the profile area.
- The block shows the current avatar when public metadata exists, otherwise it shows a default round initial placeholder.
- The file picker accepts png/jpeg/webp and rejects unsupported MIME types or files over about 1MB before upload.
- Upload writes only to the `avatars` Storage bucket under the signed-in user's own object prefix, then calls `update_my_avatar_path`.
- If metadata recording fails after upload, the newly uploaded object is removed from `avatars` before reporting failure.
- Delete removes the current `avatars` object and then calls `clear_my_avatar_path`.
- The implementation does not add direct Supabase table `.insert` / `.update` / `.delete` / `.upsert` calls.
- Session-detail comments now normalize `avatar_path` / `avatar_updated_at` returned by the public comment RPC and display a small round avatar beside the comment author.
- Comments fall back to the default initial placeholder when no avatar path is present or when image loading fails.
- mypage/session-detail cache-bust values were updated so the frontend change can be served with the new CSS and JS.
- No real avatar upload, deletion, signed URL recording, or real object path recording was performed in this implementation batch.

## Real Upload QA

Status: partial public-site QA completed from the logged-in mypage UI; comment-page visual confirmation remains a follow-up check.

- The public mypage was refreshed after the avatar frontend cache-bust was available.
- No pre-existing avatar was detected before the test, so the QA did not overwrite a user-configured icon.
- A generated png image under the size limit was selected through the avatar file input and submitted through the existing upload UI handler.
- `upload_success=true`.
- `preview_updated=true`.
- The delete action was executed through the existing delete UI handler; the preview returned to the default avatar state.
- `delete_success=true`.
- `default_restored=true`.
- The delete flow is treated as OK because returning to the default state requires the delete handler to complete its Storage remove + metadata-clear path.
- `oversize_rejected=true`.
- `unsupported_type_rejected=true`.
- `comment_avatar_visible=not_checked`: no safe existing comment-detail target was opened during this gate, so the live comment avatar display remains a follow-up browser check.
- No real user id, avatar object path, signed URL, email, JWT, token, project ref, full URL, or Storage internal value was recorded.

## Comment Avatar Preview

Status: frontend-only avatar preview modal implemented for session-detail comments.

- Comment avatars are now rendered as clickable/tappable buttons.
- When an avatar image exists, selecting the small round icon opens a lightweight preview overlay with the larger image and the commenter display name.
- When the avatar is unset or fails to load, selecting the default icon opens the same overlay with the enlarged default initial placeholder and a default-icon note.
- The overlay can be closed with the close button, backdrop click/tap, or Escape key.
- The dialog constrains image size for PC and smartphone viewports so the preview does not overflow the screen.
- This change does not add SQL, DB/Auth/RLS, Storage, Dashboard, upload/delete, Discord, or secret-handling work.

## MVP QA Checklist

- User can upload a png/jpeg/webp icon within the size limit.
- Wrong file type and oversized files are rejected before upload.
- User can clear their icon and return to the default icon.
- User cannot overwrite another user's avatar object path.
- `profiles.avatar_path` stores an object key, not a full URL.
- `public_profiles` exposes only display-safe fields.
- Session-detail comments show the author's avatar or default icon.
- Comment display does not expose raw user ids, emails, tokens, session ids, Discord ids, or full URLs.
- PC and smartphone layouts remain readable.

## Not Performed

- No SQL Editor execution by Codex.
- No additional Storage bucket change after the approved 055 apply.
- No additional DB/Auth/RLS mutation after the approved 055 apply.
- No Supabase Dashboard operation.
- No real avatar upload/delete.
- No secret or token recording.
