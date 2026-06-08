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

## Account Registration Policy

Use the current Supabase Auth email and password configuration.

- Treat email addresses as private login and recovery identifiers.
- Treat `profiles.display_name` as the public user name.
- Use `profiles.display_name` for public display, session GM names, applicant display, and similar user-facing labels.
- Do not adopt username-only custom Auth at this stage.
- Do not adopt anonymous-login-only operation at this stage.
- Do not remove the email requirement at this stage.
- Keep Custom SMTP as the durable mitigation for built-in email provider rate limits.
- Keep Custom SMTP setup as an independent gate because SMTP credentials are secret-equivalent.

## Usage Scale and Reuse Assumptions

The current expected user scale is about 10 people, but the SMTP choice should leave room for gradual user growth.

The site-specific world data and the reusable operations platform should be treated separately:

- Public world content may remain Velgard-specific.
- Operational foundations such as calendar, session posts, mypage, accounts, and Discord sync should remain reusable for future TRPG worlds where practical.
- Auth email sender names and email copy should avoid depending too heavily on a single world name.
- Site-facing labels and guidance may still use the Velgard name where it helps current users.
- SMTP and Auth email design should be easy to carry forward as part of a reusable TRPG operations platform.

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

SMTP candidate priority:

1. Resend: first candidate. It is approachable for Auth and transactional email use, starts comfortably from a free tier, and should fit the current small-user operation while leaving room to grow.
2. Brevo: second candidate. It has a larger free daily sending allowance and remains a practical fallback if Resend is not suitable.
3. SendGrid and AWS SES: future candidates. They are lower priority at this stage because setup and operational overhead, or paid/production assumptions, are heavier for the current scale.

Provider selection should prefer a transactional-email setup that can support multiple future TRPG worlds without tying sender identity, templates, or operations language too tightly to Velgard alone.

## Domain Policy for Resend

If Resend is adopted, obtain an owned domain before Custom SMTP setup.

Domain naming should avoid being Velgard-specific so the Auth and SMTP foundation can be reused for future TRPG worlds.

Naming policy:

- Base name: `tsumetai-hiyasireimen`.
- First candidate: `tsumetai-hiyasireimen.com`.
- Reserve candidates: `.net`, `.jp`, or another suitable TLD if the first candidate is unavailable or not cost-effective.
- Availability, initial price, and renewal price must be checked by a human in the domain purchase screen.

Separate gates:

- Domain purchase.
- DNS change.
- Resend domain addition.
- Resend API key creation.
- Supabase Custom SMTP setting.

Domain purchase result:

- `tsumetai-hiyasireimen.com` was purchased through Cloudflare using Chrome.
- Brave showed a Cloudflare management-screen API 429 during the purchase attempt, but Chrome completed the purchase.
- DNS change, Resend domain addition, Resend API key creation, and Supabase Custom SMTP setting are not yet performed.

Resend domain verification result:

- `tsumetai-hiyasireimen.com` was added to Resend.
- Resend-specified DNS records were added in Cloudflare DNS.
- Resend showed `STATUS: Verified`.
- Resend showed `Domain verified: Your domain is ready to send emails.`
- `DNS verified` and `Domain verified` were confirmed.
- Resend API key creation, Supabase Custom SMTP setting, and repeated signup QA are not yet performed.

Do not record SMTP credentials, API keys, DNS-management secrets, real emails, user ids, JWTs, tokens, full URLs, or project refs.

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
