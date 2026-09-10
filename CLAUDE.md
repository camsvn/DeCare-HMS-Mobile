# DeCare HMS (Flutter) — working notes for Claude

Flutter companion app for a self-hosted DeCare HMS installation: staff look up a patient by OP
number and upload sets of skin photos ("tomograms") with descriptions. Sibling repos:
`../HMSServer` (Express/TypeScript API) and `../HMSUploader` (the original React Native app this
replaces; reference only).

## Toolchain (pinned; do not upgrade without a decision)

- Flutter 3.19.0 / Dart 3.3 — the installed SDK. Never run `flutter upgrade`.
- `camera ^0.11.0+2` is the last release that supports this Flutter; `connectivity_plus ^6.1.5`
  because 7.x needs a newer Gradle plugin. Check pub constraints before adding or bumping anything.
- Java: Amazon Corretto 11 locally; CI uses Temurin 17 with AGP 7.3.0 / Gradle 7.6.3.

## Commands

```bash
flutter gen-l10n            # after editing lib/core/l10n/app_en.arb (generated files are committed)
flutter analyze             # must be clean before every commit
flutter test                # must be green before every commit
flutter build apk --debug   # what CI builds
flutter build apk --release # signed only when android/key.properties exists (see README "Release")
```

Debug and release builds have different signatures; installing one over the other fails until
the old one is uninstalled (which wipes app data: server URL, login, recent patients).

## Architecture rules

- Feature-first: `lib/features/<name>/{data,application,presentation}` with a barrel
  `lib/features/<name>/<name>.dart`. Cross-feature imports go through barrels only.
- `lib/core/` never imports `lib/features/`. `lib/app/` wires features together (router, modules,
  session listener). Feature code never imports `lib/app/` (shared keys live in `lib/core/navigation/`).
- Riverpod 2.6: prefer `Notifier`/`AsyncNotifier`; `ref.watch` in `build`, `ref.read` only in
  callbacks and before the first `await`; never `ref.read` an autoDispose provider from a getter
  (it disposes the provider). Providers overridden in `main.dart` are mirrored by
  `test/helpers/signed_in_container.dart`; keep them in sync.
- Design system `lib/core/design/`: all colours, spacing, radii and durations come from tokens
  (`context.ds`, `context.dsType`, `DsSpace`, `DsRadius`, `DsMotion`) and `Ds*` widgets. No literal
  colours or sizes in features; a new size becomes a named constant.
- Every user-visible string goes through `context.l10n` (ARB + `flutter gen-l10n`).
- Dark mode is real: pump widget tests with `buildDsTheme(Brightness.dark)` where colour matters.
- Tests are behavioural (real temp files, rendered text, geometry, semantics), not mock choreography.
  Fakes live in `test/helpers/`.

## Domain facts worth knowing

- Server contract: JSend envelopes; `POST /api/auth/login`, `POST /api/auth/refresh`,
  `GET /api/opregister?opid=`, `GET /api/tomogram?opid=`, `POST /api/tomogram` (multipart `opid`,
  `images`, `narrations[i]`). Access token 2 h, refresh 5 days; a 401 triggers one refresh + retry;
  multipart bodies are not retried (the offline queue re-sends later).
- Photos: captured in-app (CameraX writes sensor-oriented JPEGs with an EXIF orientation tag, so
  they are re-encoded upright in a background isolate before upload) or picked from the gallery
  (resized to 2000 px). Blank descriptions inherit the previous card's at upload.
- Recent labels are stored device-wide across patients by design (body-site text only).
- Versioning is calendar-based: `YYYY.M.N+build` (see README "Release"). Pushing the matching tag
  runs `.github/workflows/release.yml`, which signs from repository secrets and uploads to Firebase
  App Distribution; `ci.yml` never signs.
- Android `applicationId` (and iOS bundle id) is `com.decare.hms`, matching the Firebase Android app
  releases are distributed to. The React Native app was `com.decare.hmsuploader`, so the two install
  side by side and testers remove the old one by hand.
- Branding (icon, splash, wordmark) is documented in `docs/branding.md`;
  `dart run flutter_native_splash:create` strips the portrait lock from the manifest — restore it.

## Process conventions

- Specs in `docs/superpowers/specs/`, plans and execution logs in `docs/superpowers/plans/`.
  Plans are executed task by task with a review after each task and a whole-branch review at the
  end; rulings and parked findings are recorded in the execution logs.
- Never commit `android/key.properties` or `android/upload-keystore.jks`; never write local test
  credentials into source, tests, docs or reports.
- The local dev server (`npm run dev` in `../HMSServer`, port 4041, emulator reaches it at
  `10.0.2.2:4041`) belongs to the developer: do not kill or restart it without asking.
