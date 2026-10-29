# Azan

Azan is a Flutter prayer times and daily worship reminders app. Prayer times are
calculated for the saved device location, with AlAdhan API refresh and local
calculation fallback. The app also includes Quran audio, prayer notifications,
and a home screen prayer-times widget.

## Build for Android

Use the Flutter SDK version required by `pubspec.yaml` (Dart 3.11.1 or newer).

```sh
flutter pub get
flutter build appbundle --release
```

Before building a production bundle, set a permanent, unique Android
application ID in `android/app/build.gradle.kts`, configure the upload key in
`android/key.properties` (see `android/key.properties.example`), and increment
the `version` in `pubspec.yaml` for each Play release. Keep the keystore and
passwords private and backed up. Never commit them.

See the [privacy policy](docs/privacy-policy.md) for information about data
handled by the app.
