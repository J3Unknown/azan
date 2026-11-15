# Azan online worship setup

The normal prayer, Quran, Qibla and reminders flow stays available without an
account. Open **Menu → Worship together** to sign in. **Menu → Profile** (also
available inside Worship together) lets you edit your name and copy your
friend code. Profiles do not upload or store photos. **Menu → Contact us** opens
an email draft to `taemaomar65@gmail.com` without requiring an account.

## Connect the separate Azan project

1. The connected Azan project is `iuuugxspcrivejcvpnoa`. All five repository migrations
   have been deployed there. They create the private `azan_private` schema, two
   public RPCs and an active hourly Cron job. The historical `azan-avatars`
   bucket is empty and its upload/read policies have been retired.
   Do not reapply those scripts to this project.
2. For another fresh project, apply the migrations in order. Enable Supabase
   Cron/`pg_cron` if it does not allow extension creation from SQL.
3. Keep `azan_private` out of the Data API's exposed schemas. Expose `public`.
   Table access is denied to clients; authenticated users call `azan_dashboard`
   and `azan_action`. Authorization runs inside those RPCs, using `auth.uid()`.
4. Under **Authentication → Sign In / Providers → Email**, enable email signup,
   turn **Confirm email OFF**, and set minimum password length to at least 8.
5. No SMTP service, email templates or Auth callback URLs are needed.
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

## Email/password accounts

Account deletion is available under **Menu → Profile → Delete account**. The
authenticated `azan_delete_account` RPC accepts a typed confirmation, never a
target user ID. It atomically deletes owned rooms, removes the user's entries
from other recipients' report snapshots, and deletes the Auth user. Foreign-key
cascades remove sessions, profile, memberships, completions and own reports.
Public dashboard/action RPCs check the account still exists, rejecting old
tokens after deletion. Report generation is serialized with deletion to avoid
recreating deleted snapshot entries. Offline device data remains untouched.

`supabase/tests/live_account_deletion.sql` verifies deletion using temporary
accounts inside a rollback-only transaction. The local database suite also
checks missing confirmation, session cleanup and preservation of other users.

Publish `docs/account-deletion.html` on a public website and enter its HTTPS URL
in Play Console's account-deletion/Data safety field. It provides deletion
instructions and an email request option for users without the app. A local
file path is not a public deletion-request URL.

The app uses email and password for login and collects a display name at signup.
Email syntax validation and the eight-character signup password minimum remain.
Successful signup creates the account, ends the automatic signup session and
returns to the login form with a success message. The user then signs in with
their email and password.

In **Authentication → Sign In / Providers → Email**, leave email signup enabled
and turn **Confirm email OFF**. The project owner saved this setting, and the
live settings endpoint confirmed `mailer_autoconfirm: true`.

There are no email-verification, OTP, resend, forgot-password or password-reset
flows in the app. No SMTP provider, sending domain, email template customization,
or Supabase paid upgrade is needed for this authentication flow. The retired
email templates and native email callback handlers were removed.

Signup and password login were also verified against the real project using a
temporary test account, including authenticated dashboard access. Its sessions
were revoked and the test account was deleted afterward. Existing accounts were
checked: none were awaiting email confirmation.

Contact Us still opens the user's own email app to compose a message to the
publisher and does not use Supabase SMTP.

## Worship rules

- New rooms can start with seven daily worship templates: Fajr, Dhuhr, Asr,
  Maghrib, Isha (1 point each), daily Quran (2), daily supplications (3), or an
  empty schedule. Owners can add up to 50 active tasks with custom names,
  descriptions, 1–1000 points, start dates, and daily, selected-weekday or
  one-date schedules. Template values remain editable in the task form.
- Tasks are self-reported; the server accepts only today's Cairo date and
  records each logical task once per room/member/day. Members can uncheck
  their own tasks today to correct mistakes; the points are removed too.
- Owners can edit or remove tasks directly on their task cards or in
  **Room details → All room tasks**.
  Versions preserve prior schedules and completed points. Edits take effect
  today; a completed task keeps its original awarded points until the member
  explicitly unchecks it. Rechecking uses the current task's points and schedule.
  Removed tasks cannot receive new completions, but their history is retained.
- Room cards open full details: today's tasks, members, individual completed
  tasks and points, owner approval controls, and friend invitations. Owners can
  delete a room after confirmation, permanently removing all its associated
  membership, task, completion and report data.
- Public-room references have 8 digits. Joining creates a request for the
  owner to approve or decline. Pending members cannot complete tasks or see
  the member list.
- Private challenges use a friend's 12-character profile code. Only the
  invited person can accept/decline; room-reference joining is disabled.
- The server limits each owner to 20 new rooms/challenges in a rolling day.
- Weeks run Friday through Thursday in `Africa/Cairo`. Cron runs hourly, making
  the report available shortly after the week ends; an app refresh also
  generates any missing reports. Reports are delivered **in the app**, with
  comparisons, per-task counts and motivational text. Email/push delivery of
  weekly reports is not configured.
- Reports appear only in the **Weekly reports** tab. Sample reports and the
  app-bar preview shortcut have been removed.
- Owners can remove members beside their progress card after confirmation.
  The server checks ownership and prevents owner self-removal. Removal revokes
  room access and task updates while retaining past completions and points.
  Public rooms require a new request and approval; private rooms require a new
  friend-code invitation.
- A task is an area to improve only if completed **less than 75%** of eligible
  days. Exactly 75% passes. For midweek joiners, days before acceptance are
  excluded. Report snapshots remain fixed after generation.
- The room list refreshes every 45 seconds while foregrounded, on resume,
  and by pulling down. Reports show the most recent 100 room/week entries.
- Profile photos have been removed. The image-picker dependency and iOS photo
  permission are removed, the profile photo column is dropped, and the retired
  empty bucket denies client access. No profile image objects exist or can be
  uploaded by the app.

## Verification

Run `flutter analyze` and `flutter test`. Database integration tests use real
embedded PostgreSQL (`@electric-sql/pglite@0.3.14`) with stubs for Supabase's auth,
storage tables and Cron registration:

```sh
node supabase/tests/flexible_community_database.mjs /absolute/path/to/@electric-sql/pglite/dist/index.js supabase/migrations
```

Those tests exercise role permissions, requests/approval, invitation privacy,
duplicate completion, date enforcement, scoring, partial weeks, report
deduplication, retired photo storage access and owner-only member removal.
They do not test Cron scheduling on the hosted project.

The rollback-only `supabase/tests/live_flexible_community.sql` test also passed against
the connected project. It exercises authenticated database roles with temporary
users and leaves no test accounts or worship data behind. Migration filenames
match the versions in the hosted migration history.
The rollback-only `supabase/tests/live_member_removal.sql` also verifies owner,
member and outsider permissions, access revocation, rejoin approval and retained
earned points against the connected project.

After deployment, run Supabase Security/Performance Advisors and test with two
real accounts: immediate signup, password login, room request/approval, private
invitation, daily completion, profile name changes, logout, and weekly reports. The project owner
can inspect `cron.job_run_details` to verify scheduled report generation.

The older `community_database.mjs` and `live_community.sql` files cover the
original fixed-task schema; use the flexible tests above for the current schema.
The latest advisor checks had no app access-policy findings. The project has an
existing [disabled leaked-password protection advisory](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection);
this Auth setting was not changed as part of the room/task migration.
