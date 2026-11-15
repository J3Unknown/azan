# Azan online worship setup

The normal prayer, Quran, Qibla and reminders flow stays available without an
account. Open **Menu → Worship together** to sign in. Open **Profile** there
to edit your name/photo and copy your friend code. **Menu → Contact us** opens
an email draft to `taemaomar65@gmail.com` without requiring an account.

## Connect the separate Azan project

1. The connected Azan project is `iuuugxspcrivejcvpnoa`. Both repository migrations
   have been deployed there. They create the private `azan_private` schema, two
   public RPCs, a private `azan-avatars` bucket and an active hourly Cron job.
   Do not reapply those scripts to this project.
2. For another fresh project, apply the migrations in order. Enable Supabase
   Cron/`pg_cron` if it does not allow extension creation from SQL.
3. Keep `azan_private` out of the Data API's exposed schemas. Expose `public`.
   Table access is denied to clients; authenticated users call `azan_dashboard`
   and `azan_action`. Authorization runs inside those RPCs, using `auth.uid()`.
4. Under **Authentication → Providers → Email**, enable email signup and
   **Confirm email**; set minimum password length to at least 8.
5. Under **Authentication → URL Configuration**, add this exact redirect:
   `com.unknown.azan://auth-callback`. Android and iOS handlers are included.
   Use the same device/app installation for the email link and the original
   signup/reset request (Supabase's PKCE flow).
6. Keep the public connection values in the ignored root `.env` file:

   ```dotenv
   SUPABASE_URL=https://iuuugxspcrivejcvpnoa.supabase.co
   SUPABASE_PUBLISH_KEY=YOUR_PUBLISHABLE_KEY
   ```

   The spelling `SUPABSE_PUBLISH_KEY` is also accepted; `SUPABASE_PUBLISH_KEY`
   takes precedence if both are defined. Run/build with Flutter's native
   environment-file option (the `.env` is not bundled as an asset):

   ```sh
   flutter run --dart-define-from-file=.env
   flutter build appbundle --release --dart-define-from-file=.env
   ```

   VS Code's **Azan (.env)** launch configuration passes this option automatically.
   Never put a secret/service-role key in the app. Missing configuration keeps online
   features unavailable while preserving the existing app.

If the app's permanent application ID changes, update the custom URI scheme in
`CommunityService.redirect`, AndroidManifest, Info.plist and the dashboard's
redirect allowlist together. Web/desktop auth redirects need platform-specific
configuration before those platforms are distributed; the included callback
configuration targets Android and iOS.

## Email confirmation and password resets

Resend has an ongoing free transactional tier of **3,000 emails/month with a
100/day limit**. Check [current pricing](https://resend.com/pricing) before
launch. A verified sender domain is required; a Gmail recipient address does
not provide that domain. Domain registration itself may cost money.

After verifying your domain in Resend, configure Supabase **Authentication →
Email → SMTP Settings** using Resend's SMTP credentials:

- Host `smtp.resend.com`, port `465`.
- Username `resend`, password your Resend API key.
- Sender an address on your verified domain, for example `auth@yourdomain.com`.
- Sender name `Azan`.

See [Resend's Supabase guide](https://resend.com/docs/send-with-supabase-smtp)
and [Supabase SMTP documentation](https://supabase.com/docs/guides/auth/auth-smtp).
Keep SMTP credentials server-side in Supabase. Configure auth email rate limits
to fit the provider quota. The built-in Supabase sender is for testing and is
restricted; it is not a substitute for production SMTP.

The app includes login, signup, resend confirmation, forgot-password and a
new-password form opened by the recovery link. Email delivery cannot be
verified until the project, verified sender and SMTP are configured. Contact Us
uses the user's email app and needs no SMTP credentials.

## Worship rules

- Every accepted room member receives seven daily tasks: Fajr, Dhuhr, Asr,
  Maghrib, Isha (1 point each), daily Quran (2), daily supplications (3).
- Tasks are self-reported; the server accepts only today's Cairo date and
  records each task once per room/member/day. Completed tasks cannot be undone.
- Public-room references have 8 digits. Joining creates a request for the
  owner to approve or decline. Pending members cannot complete tasks or see
  the member list.
- Private challenges use a friend's 12-character profile code. Only the
  invited person can accept/decline; room-reference joining is disabled.
- The server limits each owner to 20 new rooms/challenges in a rolling day.
- Weeks run Monday through Sunday in `Africa/Cairo`. Cron runs hourly, making
  the report available shortly after the week ends; an app refresh also
  generates any missing reports. Reports are delivered **in the app**, with
  comparisons, per-task counts and motivational text. Email/push delivery of
  weekly reports is not configured.
- A task is an area to improve only if completed **less than 75%** of eligible
  days. Exactly 75% passes. For midweek joiners, days before acceptance are
  excluded. Report snapshots remain fixed after generation.
- The room list refreshes every 45 seconds while foregrounded, on resume,
  and by pulling down. Reports show the most recent 100 room/week entries.
- Photos accept JPEG, PNG and WebP up to **2,097,152 bytes (2 MiB)**. Both client
  and storage enforce size; the client checks file signatures. Photos stay
  private and the profile uses an expiring signed URL. Replacements use one
  filename per supported format, limiting retained uploads to three per user.

## Verification

Run `flutter analyze` and `flutter test`. Database integration tests use real
embedded PostgreSQL (`@electric-sql/pglite@0.3.14`) with stubs for Supabase's auth,
storage tables and Cron registration:

```sh
node supabase/tests/community_database.mjs /absolute/path/to/@electric-sql/pglite/dist/index.js supabase/migrations/20261115134912_worship_community.sql
```

Those tests exercise role permissions, requests/approval, invitation privacy,
duplicate completion, date enforcement, scoring, partial weeks, report
deduplication and storage ownership. They do not test hosted SMTP, the actual
Storage HTTP size check, deep linking on physical devices or Cron scheduling.

The rollback-only `supabase/tests/live_community.sql` test also passed against
the connected project. It exercises authenticated database roles with temporary
users and leaves no test accounts or worship data behind. Migration filenames
match the versions in the hosted migration history.

After deployment, run Supabase Security/Performance Advisors and test with two
real accounts: email confirmation, room request/approval, private invitation,
daily completion, signed photo upload, oversized file rejection, recovery from
both a running and closed app, and weekly report delivery. The project owner
can inspect `cron.job_run_details` to verify scheduled report generation.
