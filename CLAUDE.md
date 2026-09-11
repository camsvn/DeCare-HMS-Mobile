# DeCare HMS (Flutter) — working notes for Claude

Flutter companion app for a self-hosted DeCare HMS installation: staff look up a patient by OP
number and upload sets of skin photos ("tomograms") with descriptions. Sibling repos:
`../HMSServer` (Express/TypeScript API) and `../HMSUploader` (the original React Native app this
replaces; reference only).

## Toolchain (pinned; do not upgrade without a decision)

- Flutter 3.47.3 / Dart 3.13, managed by **fvm** (`.fvmrc`). Always `fvm flutter …`; the bare
  `flutter` on PATH may be a different install. Never run `flutter upgrade`.
- Android: Gradle 9.4.1, AGP 9.2.1, Kotlin 2.4.0, Java 17, `compileSdk 37` (required by
  `permission_handler_android` 14), `minSdk` = Flutter's default (24). CI uses Temurin 17.
- Local JDK: Android Studio's JBR 17 — `fvm flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"`
  once, or set `JAVA_HOME` to it per shell. Corretto 11 on PATH is too old for AGP 9.
- Machine quirks (this Windows box): the JVM cannot reach github.com, so a new Gradle wrapper
  version must be fetched with curl into `~/.gradle/wrapper/dists/<name>/<hash>/`; the pub cache
  (C:) and the project (E:) are on different drives, which is why `kotlin.incremental=false` is
  set in `android/gradle.properties`.
- After a major SDK move, `fvm flutter pub upgrade` the transitives before the first Gradle build
  (old plugin versions may still use the removed v1 embedding). Check pub constraints before
  adding or bumping anything.

## Commands

```bash
fvm flutter gen-l10n            # after editing lib/core/l10n/app_en.arb (generated files are committed)
fvm flutter analyze             # must be clean before every commit
fvm flutter test                # must be green before every commit
fvm flutter build apk --debug   # what CI builds
fvm flutter build apk --release # signed only when android/key.properties exists (see README "Release")
```

Debug and release builds have different signatures; installing one over the other fails until
the old one is uninstalled (which wipes app data: server URL, login, recent patients).

## Architecture rules

- Feature-first: `lib/features/<name>/{data,application,presentation}` with a barrel
  `lib/features/<name>/<name>.dart`. Cross-feature imports go through barrels only.
- `lib/core/` never imports `lib/features/`. `lib/app/` wires features together (router, modules,
  session listener). Feature code never imports `lib/app/` (shared keys live in `lib/core/navigation/`).
- Riverpod 3.4: `Notifier`/`AsyncNotifier` only (no `AutoDispose*`/`Family*` classes — family
  notifiers take the argument in their constructor); `ref.watch` in `build`, `ref.read` only in
  callbacks and before the first `await`, and check `ref.mounted` after every `await` in an
  autoDispose notifier (a disposed notifier's `state`/`ref` throw); never `ref.read` an autoDispose
  provider from a getter (it disposes the provider); never read `state` inside `ref.onDispose`
  (mirror what dispose needs into a field via `listenSelf`); `AsyncValue.value` carries the
  previous value through loading/error, and a method that starts an operation keeps it with
  `keepingPrevious` from `lib/core/riverpod/riverpod_compat.dart`; automatic retry is off
  (`noRetry`) in every container and scope; `StateProvider` only from `legacy.dart`, and only in
  tests; the `Override` type comes from `package:flutter_riverpod/misc.dart`. Providers overridden
  in `main.dart` are mirrored by `test/helpers/signed_in_container.dart`; keep them in sync.
- Design system `lib/core/design/`: all colours, spacing, radii and durations come from tokens
  (`context.ds`, `context.dsType`, `DsSpace`, `DsRadius`, `DsMotion`) and `Ds*` widgets. No literal
  colours or sizes in features; a new size becomes a named constant.
- Every user-visible string goes through `context.l10n` (ARB + `fvm flutter gen-l10n`).
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
  (resized to 2000 px). Blank descriptions inherit the previous card's at upload. Screens delete
  their photos when done; `sweepStaleCache` (run from `main.dart`, not awaited) removes photo files
  older than 24 h that a killed process left in the cache directory. The offline queue's staged
  copies live in the documents directory and are outside that sweep.
- Recent labels are stored device-wide across patients by design (body-site text only).
- Versioning is calendar-based: `YYYY.M.N+build` (see README "Release"). Pushing the matching tag
  runs `.github/workflows/release.yml`, which signs from repository secrets and uploads to Firebase
  App Distribution; `ci.yml` never signs.
- Android `applicationId` (and iOS bundle id) is `com.decare.hms`, matching the Firebase Android app
  releases are distributed to. The React Native app was `com.decare.hmsuploader`, so the two install
  side by side and testers remove the old one by hand.
- Branding (icon, splash, wordmark) is documented in `docs/branding.md`;
  `fvm dart run flutter_native_splash:create` strips the portrait lock from the manifest — restore it.

## Process conventions

- Specs in `docs/superpowers/specs/`, plans and execution logs in `docs/superpowers/plans/`.
  Plans are executed task by task with a review after each task and a whole-branch review at the
  end; rulings and parked findings are recorded in the execution logs.
- Never commit `android/key.properties` or `android/upload-keystore.jks`; never write local test
  credentials into source, tests, docs or reports.
- The local dev server (`npm run dev` in `../HMSServer`, port 4041, emulator reaches it at
  `10.0.2.2:4041`) belongs to the developer: do not kill or restart it without asking.
