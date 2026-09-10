# DeCare HMS (Flutter)

Companion uploader for a self-hosted DeCare HMS installation. Staff configure the
server URL, log in and look up a patient by OP number, then attach tomograms: a
burst of photos taken in the in-app capture screen, or up to two JPEGs picked
from the gallery. Descriptions are set while shooting rather than typed
afterwards: a label on the capture screen rides along with every shot taken
under it and lands in the draft list as that photo's description. In the draft
list a blank description inherits the previous photo's — shown as the field's
placeholder, "Same as previous photo: Left forearm", so it is visible and a tap
to type over — and an empty field offers tap-to-fill chips built from this
patient's earlier narrations and the last labels used on the device. The whole
set uploads together (or is queued when the server is unreachable) with those
inherited descriptions as its narrations. Those recent labels are kept per
device and offered across patients and sign-ins, so they are for body-site text
("Left forearm") — not anything that identifies a patient. Flutter port of the
React Native `HMSUploader` app.

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

## Release

1. Bump `version` in `pubspec.yaml` (`x.y.z+buildNumber`) before every release build.
2. Build the signed artifacts:

   ```bash
   flutter build appbundle --release   # Play Store upload
   flutter build apk --release         # sideload/manual distribution
   ```

3. Signing reads `android/key.properties` (gitignored, local only), which points at
   `android/upload-keystore.jks` (gitignored). See `android/key.properties.example` for the
   expected keys. If `key.properties` is missing, `release` builds fall back to the debug
   signing config (this is what happens in CI — **CI does not sign releases**; only a
   machine with the real `key.properties`/keystore produces a Play-uploadable artifact).
4. **Back up `android/upload-keystore.jks` and the passwords in `android/key.properties`
   outside this repository.** The upload key cannot be recovered or reset if lost, and a
   lost upload key means the app can no longer be updated under its existing Play Store
   listing — a new listing would be required.

### CI

<!-- ![CI](https://github.com/<owner>/<repo>/actions/workflows/ci.yml/badge.svg) -->

`.github/workflows/ci.yml` runs `flutter analyze`, `flutter test`, and `flutter build apk
--debug` on every push and pull request. It never has access to signing secrets, so it
always builds the debug-signed APK described above — CI does not sign releases.

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

Features: `server_config`, `auth`, `dashboard`, `patient_lookup`, `tomogram`, `settings`.

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

### Adding a module

To register a new dashboard module:

1. Define an `AppModule` (`lib/core/modules/app_module.dart`) in the feature's barrel file and
   add it to the `appModules` list in `lib/app/modules.dart`.
2. Add ARB keys for the module's dashboard title and subtitle to `lib/core/l10n/app_en.arb`
   and run `flutter gen-l10n`; `AppModule.title`/`subtitle` read them off `AppLocalizations`.
3. Add the module's paths to `RoutePaths` (`lib/core/navigation/route_paths.dart`).
4. Give every route in `AppModule.routes` a `pageBuilder` returning
   `FadeThroughPage(key: state.pageKey, child: ...)` so it matches the rest of the app.
5. The module's routes are nested under the Home branch of the shell, so the bottom bar and
   the shell's back handling stay in place; do not add them to the root router.
6. `AppModule.badge` is an optional `Widget Function()` for the dashboard card. It takes no
   arguments — `core` knows nothing of Riverpod — so a badge that watches a provider is a
   `ConsumerWidget` of the feature's own:

   ```dart
   badge: () => const RecentCountBadge(),
   ```

   (see `lib/features/tomogram/presentation/widgets/recent_count_badge.dart`, which shows a
   `DsChip` with the count or nothing at all).

## Adding a workflow

1. Create `lib/features/<name>/` with `data/`, `application/`, `presentation/` as needed.
2. Export its public providers and a `GoRoute` (or `List<RouteBase>`) from `lib/features/<name>/<name>.dart`.
3. Add its paths to `RoutePaths` (`lib/core/navigation/route_paths.dart`).
4. Register the routes. A workflow reached from the dashboard is an `AppModule` added to
   `appModules` in `lib/app/modules.dart` (see *Adding a module* above) — `lib/app/router.dart`
   nests every module's routes under the Home branch of the shell on its own, so it needs no
   edit. Only a route that lives outside the tab shell is listed in `lib/app/router.dart`
   itself, the way `configureRoute` and `loginRoute` are.
5. Add strings to `lib/core/l10n/app_en.arb` and run `flutter gen-l10n`.
6. Add tests under `test/features/<name>/`.

## Server contract

Base URL is `<server>/api`. Endpoints: `GET /auth/healthcheck`, `POST /auth/login`,
`GET /opregister?opid=`, `POST /tomogram` (multipart: `opid`, `images`, `narrations[i]`).
Responses follow JSend. The access token is sent as `Authorization: Bearer <token>`.
