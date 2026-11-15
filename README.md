# Azan

Azan is a Flutter prayer times and daily worship reminders app. Prayer times are
calculated for the saved device location, with AlAdhan API refresh and local
calculation fallback. The app also includes Quran audio, prayer notifications,
and a home screen prayer-times widget.

## Build for Android

Use the Flutter SDK version required by `pubspec.yaml` (Dart 3.11.1 or newer).

For a Shorebird-enabled production release, build the baseline with the Supabase
defines included, then upload the generated app bundle to Google Play:

```sh
shorebird release android --dart-define-from-file=.env
```

For later Dart-only updates, target the exact installed release and pass the
same `.env` file:

```sh
shorebird patch android --release-version=2.0.0+7 --dart-define-from-file=.env
```

Replace `2.0.0+7` with the version installed by users. Shorebird patches cannot
add build-time Supabase values if the production baseline was built without
them. In that case, create and distribute a new Shorebird release with the
defines above; a patch alone cannot enable online worship for that baseline.

For builds that are not distributed through Shorebird, use:

```sh
flutter pub get
flutter build appbundle --release --dart-define-from-file=.env
```

Before building a production bundle, set a permanent, unique Android
application ID in `android/app/build.gradle.kts`, configure the upload key in
`android/key.properties` (see `android/key.properties.example`), and increment
the `version` in `pubspec.yaml` for each Play release. Keep the keystore and
passwords private and backed up. Never commit them.

See the [privacy policy](docs/privacy-policy.md) for information about data
handled by the app.

Optional Supabase accounts, worship rooms, private challenges, weekly reports
and profiles are documented in [Supabase setup](docs/supabase-setup.md).
The existing app works without online account configuration.

Startup release notes are maintained in `lib/data/app_updates.dart`. Edit that
text list and add matching Arabic translations in
`lib/utils/helpers/app_language.dart`. Users see the popup once for each changed
list; dismissal is saved locally and works offline.
For testing, debug builds currently show it on every startup. Set
`previewAppUpdatesOnEveryStartup` to `false` in the list file after testing.
Release builds always use the once-per-changed-list behavior.

To use the connected Supabase project, put `SUPABASE_URL` and
`SUPABASE_PUBLISH_KEY` in the ignored `.env` JSON file, then run
`flutter run --dart-define-from-file=.env`, or select **Azan (.env)** in VS Code.
The `SUPABSE_PUBLISH_KEY` spelling is also accepted for existing configurations.
