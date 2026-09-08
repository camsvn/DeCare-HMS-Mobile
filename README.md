# DeCare HMS (Flutter)

Companion uploader for a self-hosted DeCare HMS installation. Staff configure the
server URL, log in, look up a patient by OP number, attach JPEG tomograms with
narrations and upload them. Flutter port of the React Native `HMSUploader` app.

## Requirements

- Flutter 3.19.x (Dart 3.3). Run `flutter --version` to confirm.
- Android SDK for the Android build. iOS is configured but not verified here.

## Run

```bash
flutter pub get
flutter gen-l10n          # regenerates lib/core/l10n/generated from app_en.arb
flutter run
```

Tests and analysis:

```bash
flutter test
flutter analyze
```

Debug APK: `flutter build apk --debug` (output in `build/app/outputs/flutter-apk/`).

## Structure

```
lib/
  main.dart            bootstrap and provider overrides
  app/                 MaterialApp, GoRouter, redirect gate, tab shell
  core/                shared code; never imports features
    network/           Dio client, Bearer interceptor, JSend envelope, ApiFailure
    storage/           shared_preferences and secure storage providers
    navigation/        RoutePaths
    theme/ l10n/ widgets/ utils/
  features/<name>/
    <name>.dart        barrel: the only file other features may import
    data/              API classes, DTOs, repositories
    application/       Riverpod controllers and services
    presentation/      screens and feature-local widgets
```

Features: `server_config`, `auth`, `patient_lookup`, `tomogram`, `settings`.

## Adding a workflow

1. Create `lib/features/<name>/` with `data/`, `application/`, `presentation/` as needed.
2. Export its public providers and a `GoRoute` (or `List<RouteBase>`) from `lib/features/<name>/<name>.dart`.
3. Register the route in `lib/app/router.dart` and add the path to `lib/core/navigation/route_paths.dart`.
4. Add strings to `lib/core/l10n/app_en.arb` and run `flutter gen-l10n`.
5. Add tests under `test/features/<name>/`.

## Server contract

Base URL is `<server>/api`. Endpoints: `GET /auth/healthcheck`, `POST /auth/login`,
`GET /opregister?opid=`, `POST /tomogram` (multipart: `opid`, `images`, `narrations[i]`).
Responses follow JSend. The access token is sent as `Authorization: Bearer <token>`.
