# Supabase Auth Custom SMTP Plan

## Purpose

New account signup was blocked by the Supabase Auth built-in email provider send-rate limit.

Confirmed cause:

- Brave DevTools Network showed the `signup` request returned HTTP 429.
- Auth error code was `over_email_send_rate_limit`.
- Auth error message type was `email rate limit exceeded`.
- 054 SELECT-only confirmation found no issue in profile handler, Auth users trigger, `profiles`, `display_name`, `public_profiles`, or missing profile count.
- Dashboard checks found the Email provider enabled, the Site URL set for the public site, and the public site included in Redirect URLs.

Conclusion: the failure is an Auth email sending rate limit, not DB/RLS/RPC/profile-trigger wiring.

## Current Scope

This document is planning only.

Not performed in this batch:

- Supabase Dashboard setting change.
- SMTP credential entry.
- Secret recording or switching.
- SQL Editor execution.
- DB/RPC/RLS change.
- SQL apply.
- Edge Function deploy.
- Discord operation.
- Signup retry using real account details.

Do not record:

- SMTP host credentials.
- SMTP username or password.
- Real email addresses.
- Auth user ids.
- JWTs or tokens.
- Full Supabase URLs.
- Project ref.
- Secret values.

## Short-Term Workaround

Wait before retrying signup.

The built-in provider can hit rate limits during repeated testing. A delayed retry can succeed, but it is not a durable production solution.

## Durable Mitigation

Configure Supabase Auth Custom SMTP.

This must be a separate gate because SMTP settings use secret-equivalent values. The setup should be performed in the Supabase Dashboard by the user, without posting values to chat, docs, console, or GitHub.

## Setup Gate

Before setup:

- Confirm the SMTP provider and sender identity are approved for the site.
- Confirm the sender address/domain is verified by the provider where required.
- Confirm the Site URL remains the public site.
- Confirm Redirect URLs still include the public site.
- Confirm no SMTP credentials will be pasted into chat, docs, console, or GitHub.

During setup:

- Enter Custom SMTP settings only in the Supabase Dashboard.
- Do not expose SMTP host credentials in logs or screenshots.
- Do not change DB/RPC/RLS.
- Do not run SQL.
- Do not deploy Edge Functions.
- Do not modify Discord settings.

After setup:

- Record only that Custom SMTP was configured.
- Do not record SMTP values.
- Keep the built-in provider rate-limit incident linked to this mitigation.

## Post-Setup QA Gate

Run signup QA after Custom SMTP setup.

Recommended checks:

- Attempt multiple new signups in sequence using user-managed test addresses.
- Confirm `signup` no longer returns HTTP 429.
- Confirm confirmation email arrives.
- Confirm a new Auth user row is created.
- Confirm the new user can complete the confirmation flow.
- Confirm the account can log in after confirmation.
- Confirm a profile row is created or available after signup.
- Confirm no real email, user id, JWT, token, full URL, or project ref is recorded.

Expected status-only record:

- `signup_http_429_reproduced=false`
- `confirmation_email_received=true`
- `new_auth_user_created=true`
- `account_confirmed=true`
- `login_after_confirmation=true`
- `profile_ready=true`

## Stop Conditions

Stop and do not continue if:

- SMTP credentials would need to be shared in chat/docs/GitHub/console.
- Dashboard setting values are uncertain.
- Signup still returns HTTP 429 after Custom SMTP setup.
- Confirmation email does not arrive.
- New Auth user is not created.
- Profile creation appears broken.
- Any real email, token, user id, full URL, or project ref would be exposed.

## Next Gate

Supabase Auth Custom SMTP setup gate.

Only after that gate should signup QA be repeated. Session-post registration, Discord sync QA, deletion QA, and notification QA should remain paused until signup is stable.
