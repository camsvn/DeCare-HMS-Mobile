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

Note: re-running `dart run flutter_native_splash:create` rewrites
`android/app/src/main/AndroidManifest.xml` and drops the
`android:screenOrientation="portrait"` attribute from the launcher activity.
Restore it afterwards, or the app will rotate out of portrait.

## Structure

```
lib/
  main.dart            bootstrap and provider overrides
  app/                 MaterialApp, GoRouter, redirect gate, tab shell
  core/                shared code; never imports features
    network/           Dio client, Bearer interceptor, JSend envelope, ApiFailure
    storage/           shared_preferences and secure storage providers
    navigation/        RoutePaths
    design/ l10n/ widgets/ utils/ modules/
  features/<name>/
    <name>.dart        barrel: the only file other features may import
    data/              API classes, DTOs, repositories
    application/       Riverpod controllers and services
    presentation/      screens and feature-local widgets
```

Features: `server_config`, `auth`, `patient_lookup`, `tomogram`, `settings`.

## Design system

Screens are built entirely from `lib/core/design/`:

- `lib/core/design/tokens/` — `DsColors`, `DsType`, `DsSpace`, `DsRadius`, `DsMotion`. Access
  them through `context.ds` (colours), `context.dsType` (text styles) or the static token
  classes (`DsSpace`, `DsRadius`, `DsMotion`) — never a raw `Color(0x...)`, literal size or
  font name in a screen.
- `lib/core/design/widgets/` — the shared widget library (`DsButton`, `DsTextField`,
  `DsCard`, `DsDialog`, `DsSheet`, `DsBanner` via `showDsBanner`, `DsEmptyState`,
  `DsAppBar`, `DsBottomBar`, `DsFab`, `DsIconTile`, `DsListRow`, `DsChip`,
  `DsProgressBar`, `DsSkeleton`, `DsStatusDot`, `ModuleCard`, `DsOnboardingScaffold`) plus
  the `FadeThroughPage` route transition. Import them all via `lib/core/design/design.dart`.
- The accent gradient (`ds.accentGradient`) is reserved for the primary action, module icon
  tiles, the FAB, progress indicators and the active tab underline; it is not used
  decoratively elsewhere.

To register a new dashboard module: define an `AppModule` (`lib/core/modules/app_module.dart`)
in the feature's barrel file, then add it to the `appModules` list in `lib/app/modules.dart`.

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
