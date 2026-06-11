# Auth Abuse Protection Plan

## Purpose

Prepare non-destructive hardening for signup, login, and password reset abuse
before widening public access. This plan covers CAPTCHA, Auth rate-limit review,
password reset repeat-submit protection, and operational QA gates.

This planning batch did not change Supabase Dashboard settings, enter CAPTCHA
credentials, run SQL Editor, change DB/RPC/RLS, apply SQL, deploy Edge
Functions, send mail, send Discord messages, or record concrete account,
project, URL, key, token, or credential values.

## Current Local Flow

`mypage.html` loads `assets/js/mypageAuthClient.js`, which owns the anonymous
account UI:

- Login calls Supabase Auth `signInWithPassword`.
- Signup collects display name, email, password, and password confirmation,
  then calls `signUp` with the runtime mypage redirect and `display_name`
  metadata.
- Password reset sends a reset email with `resetPasswordForEmail` and the
  runtime mypage redirect.
- Password recovery completion uses the existing `updateUser({ password })`
  flow after the recovery link returns to mypage.
- Existing forms already use a busy/disabled state while an Auth request is in
  flight.

Current gaps:

- No CAPTCHA token is attached to signup, login, or password reset requests.
- Signup and password reset do not have a post-success local cooldown.
- Auth rate limits and provider-side abuse monitoring remain manual Dashboard
  and Resend review gates.

## Recommended CAPTCHA Provider

Primary candidate: Cloudflare Turnstile.

Reasons:

- Supabase Auth supports Cloudflare Turnstile as an Auth CAPTCHA provider.
- Turnstile is suitable for lower-friction public forms.
- The site is static frontend heavy, so token-based form integration is a
  natural fit.

Credential handling:

- The Turnstile site key is a public frontend value, but the concrete value
  should still not be written into docs.
- The Turnstile secret key is secret-equivalent and must only be entered in the
  Supabase Dashboard during a dedicated settings gate.
- No CAPTCHA key, token, project identifier, or concrete public deployment URL
  should be pasted into docs or chat.

## CAPTCHA Scope

MVP target:

- Signup: required.
- Password reset request: required.

Optional later target:

- Login: consider after observing public traffic. Login CAPTCHA reduces brute
  force and credential stuffing, but it adds friction to normal repeat users.

Not needed:

- Logged-in password change via `updateUser({ password })` is not an email-send
  endpoint and is behind an authenticated session. Keep it outside the initial
  CAPTCHA scope unless abuse is observed.

## Implementation Gates

### Gate 1: Turnstile/Supabase Dashboard Preparation

Human-only Dashboard work:

- Create or choose a Cloudflare Turnstile site for the public site.
- Keep the site key and secret key out of docs.
- In Supabase Authentication settings, locate Bot and Abuse Protection.
- Do not enable enforcement until the frontend can supply a CAPTCHA token for
  all Auth flows that will be protected.

Stop conditions:

- Any uncertainty about allowed hostnames.
- Any request to paste keys, tokens, project identifiers, or concrete URLs into
  docs/chat.

### Gate 2: Frontend CAPTCHA Integration

Expected frontend work:

- Load the Turnstile browser script only on pages that need Auth forms, or
  behind a small helper that is inert when no site key is configured.
- Add CAPTCHA containers to the signup and password reset forms.
- Keep the login form unchanged in the MVP unless a later gate opts into login
  CAPTCHA.
- Store the current CAPTCHA token only in memory.
- Pass the CAPTCHA token through the Supabase Auth options for signup.
- Pass the CAPTCHA token through the password reset request options if supported
  by the current Supabase JS API; otherwise stop before Dashboard enforcement
  and verify the exact supported call shape.
- Reset or re-render the CAPTCHA after each Auth request, success or failure.
- Disable submit or show a clear inline message when CAPTCHA is required but not
  completed.
- Keep failure copy generic so it does not reveal whether an email exists.

Suggested UI copy:

- Signup/reset CAPTCHA incomplete: ask the user to complete verification before sending.
- Auth request failure: keep a generic retry-later message.
- Reset success: keep the existing non-enumerating success message.

Cache-bust:

- Update `mypage.html` cache-bust only in the frontend implementation gate.

### Gate 3: Supabase CAPTCHA Enforcement

Human-only Dashboard work after frontend deploy:

- Enable CAPTCHA protection.
- Select Cloudflare Turnstile.
- Enter the Turnstile secret key.
- Save once.

Do not combine this gate with unrelated Auth, DB, RLS, or SMTP changes.

### Gate 4: CAPTCHA QA

Confirm without recording concrete emails, URLs, tokens, project identifiers, or
keys:

- Signup form displays CAPTCHA.
- Signup cannot be submitted without completing CAPTCHA.
- Signup succeeds after CAPTCHA and confirmation email arrives through Custom
  SMTP.
- Password reset form displays CAPTCHA.
- Password reset cannot be submitted without completing CAPTCHA.
- Password reset email arrives after CAPTCHA.
- Reset link returns to mypage and password update still works.
- Existing login remains usable.
- Expected Auth errors are generic and do not expose account existence.
- HTTP 429 / email-rate-limit errors do not recur during normal low-volume QA.

Rollback:

- If protected Auth requests fail after Dashboard enforcement, first disable
  Supabase CAPTCHA enforcement in Dashboard.
- Then revert or adjust the frontend CAPTCHA cache-bust in a separate code
  gate.

## Rate Limits Review

Supabase Auth rate-limit review is a Dashboard/settings gate, not a SQL task.

Review targets:

- Email-send endpoints covering signup and password reset.
- Per-user resend windows for signup confirmation and password reset.
- OTP/magic-link limits, even if not currently used.
- Verification and token-refresh limits for awareness.
- Custom SMTP send-rate behavior after Resend migration.

Operational notes:

- Do not change values during the initial review.
- Record only status/decision summaries, not concrete project identifiers or
  secrets.
- Coordinate any future changes with expected event traffic so legitimate users
  are not blocked.
- Review Resend logs, bounce/suppression state, and domain reputation after
  public signup is enabled more broadly.

## Password Reset Repeat-Submit Protection

Frontend cooldown is a helper, not the primary security boundary. The primary
controls remain Supabase rate limits and CAPTCHA.

Recommended frontend gate:

- Keep the existing request-in-flight disabled state.
- After a successful reset request, disable the reset submit for a short local
  cooldown.
- Use `sessionStorage` for a coarse timestamp and do not store the email address
  in browser storage.
- Apply a similar short local cooldown to signup after success or repeated
  failure if public abuse begins.
- Show generic wait text rather than account-specific information.

Suggested QA:

- Double-clicking the reset submit sends only one request.
- Refreshing the page does not expose the submitted email address.
- Cooldown expires naturally.
- Browser storage does not contain email addresses, tokens, or keys.

## Future Options

If public exposure grows:

- Add invite codes or admin approval before first write actions.
- Require confirmed email before comment/application/session-post creation.
- Add account-age checks for comment/application posting.
- Add server-side comment/application cooldowns and URL-count limits.
- Monitor Resend bounce/suppression and Auth 429 counts.

## Next Gates

1. Dashboard preparation gate: create/confirm Turnstile site and Supabase CAPTCHA
   settings without enabling enforcement prematurely.
2. Frontend implementation gate: add Turnstile widgets and Auth `captchaToken`
   plumbing for signup and reset.
3. Dashboard enforcement gate: enable Supabase CAPTCHA once frontend is live.
4. QA gate: verify signup, password reset, login, and non-enumerating failure
   behavior.
5. Rate-limit review gate: inspect current Supabase Auth rate limits and Resend
   abuse signals; change values only in a separate explicit settings gate.
