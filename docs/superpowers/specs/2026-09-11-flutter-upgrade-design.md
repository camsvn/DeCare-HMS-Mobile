# Flutter 3.19 → 3.47 toolchain upgrade — design

Date: 2026-09-11. Status: approved in conversation. Grounded in the throwaway spike on branch
`spike/flutter-upgrade` (commit "wip: throwaway spike"), which built a debug APK and ran the suite
on Flutter 3.47.3.

## 1. Problem

The app is pinned to Flutter 3.19.0 (February 2024) and to the last plugin releases that still
build on it (`camera 0.11.0+2`, `connectivity_plus 6.x`). Every plugin has since moved on, the
Android toolchain (AGP 7.3.0, Gradle 7.6.3, Kotlin 1.7.10, Java 11) is below what current Flutter
requires, and each further month widens the gap. With fvm now managing SDKs the upgrade can be done
without disturbing the old install.

## 2. Goal

Move the project to the current stable Flutter and the current releases of its dependencies, with
the app verified working end to end on a device — same behaviour as today, no feature changes.

Decisions taken with the user:
- **Riverpod 3 is included, as the last task.** It is not required by the SDK upgrade (2.6.1 resolves
  and works on 3.47), and it is the one bump that rewrites application code (~10 controller files,
  ~126 mechanical API renames) rather than configuration. So the toolchain tasks land and pass the
  device check first on Riverpod 2, then Riverpod 3 follows in its own commits with a second, shorter
  device pass — the two changes stay separable in git even though they ship together.
- **`flutter_secure_storage` goes straight from 9 to 11.** v11 removes the EncryptedSharedPreferences
  backend the app uses, so the saved session on existing installs is lost: every tester logs in once
  after updating. Server URL and recent patients live in `shared_preferences` and are unaffected.
  Staging through v10 (which migrates the data) was considered and declined as not worth two releases.
- minSdk follows Flutter's default (24, Android 7.0); Android 5.x/6.x devices are dropped.

## 3. Scope

In: SDK pin via fvm, Android toolchain, dependency bumps, the code changes they force, deprecation
clean-up, the one test the new SDK breaks, CI workflow pins, CLAUDE.md/README toolchain notes,
`.gitignore`, device verification.

Out: migrating to Flutter's built-in Kotlin / new Android DSL (a warning today, not a
failure), iOS verification (configured, not built here), any feature or UI change, the release
itself (version bump and tag follow the README "Release" procedure once this is merged).

## 4. Targets

| Component | From | To |
|---|---|---|
| Flutter / Dart | 3.19.0 / 3.3 | **3.47.3 / 3.13.3** (stable, 2026-09-09), pinned in `.fvmrc` |
| Gradle wrapper | 7.6.3 | **9.4.1** (`-bin`) |
| Android Gradle Plugin | 7.3.0 | **9.2.1** — 9.1.x cannot resolve the `android-37.0` platform folder that `permission_handler_android` 14 requires; 9.2 can |
| Kotlin Gradle Plugin | 1.7.10 | **2.4.0** |
| Java (source/target, jvmTarget) | 1.8; JDK 11 locally | **17**; JDK 17 (Android Studio JBR locally, Temurin 17 on CI as today) |
| `compileSdk` | `flutter.compileSdkVersion` (34) | **37** (required by `permission_handler_android` 14.x) |
| `minSdk` | 21 | `flutter.minSdkVersion` (24) |
| `targetSdk` | `flutter.targetSdkVersion` | unchanged (36 with this SDK) |

Dependencies (all direct; `pub upgrade --major-versions` output from the spike):

| Package | From | To | Notes |
|---|---|---|---|
| flutter_riverpod | ^2.6.1 | ^3.4.3 | last task only; see §5a |
| go_router | ^14.6.2 | ^18.0.1 | URLs case-sensitive since 15 (all paths lowercase); ShellRoute observer change in 17 (no observers registered) |
| flutter_secure_storage | ^9.2.4 | ^11.1.0 | `AndroidOptions(encryptedSharedPreferences:)` removed; see §2 |
| permission_handler | ^11.3.1 | ^13.0.2 | 14.1 Android: `Permission.status` never reports `permanentlyDenied`; the gateway only tests `isGranted`/`isLimited`, unaffected |
| package_info_plus | ^8.0.2 | ^10.2.1 | |
| connectivity_plus | ^6.1.5 | ^7.3.1 | pin comment removed |
| camera | ^0.11.0+2 | ^0.12.1 | pin comment removed; capture path needs device verification (§7) |
| flutter_lints | ^3.0.0 | ^6.0.0 | analyzer was clean under it in the spike |
| shared_preferences, image_picker, url_launcher, flutter_svg, flutter_native_splash, path_provider, image, vector_graphics_compiler | | latest minors | no code impact seen |
| `environment.sdk` | >=3.3.0 | **^3.13.0** | honest lower bound for the new SDK |

## 5. Code changes forced by the upgrade

- `lib/core/storage/secure_store.dart`: drop the removed `encryptedSharedPreferences` option; leave a
  comment recording the v9→v11 data-loss decision.
- `l10n.yaml`: remove `synthetic-package: false` (no longer has an effect; the tool warns). Regenerate
  `lib/core/l10n/generated/` (committed, as before).
- `analysis_options.yaml`: keep the excludes the Flutter tool added (`build/**`, `android/**`, `ios/**`).
- Deprecations (44 infos, all with drop-in replacements):
  - `Color.withOpacity(x)` → `withValues(alpha: x)` (8, lib + tests);
  - `PopScope.onPopInvoked` → `onPopInvokedWithResult` (4, lib);
  - `SemanticsData.hasFlag(...)` → `flagsCollection.<flag>` (27, tests only);
  - `Color.value` → `toARGB32()` (4, tests);
  - `Navigator.onPopPage` → `onDidRemovePage` (1, test).
- `test/core/design/fade_through_page_test.dart` "under reduced motion": MaterialApp's default page
  transition is now FadeForwards, which contains a `SlideTransition`; the finder catches the outer
  route's. Scope the assertion to the transition `FadeThroughPage` itself builds. The product
  behaviour (plain fade under reduced motion) is unchanged and stays asserted.
- Android:
  - `android/settings.gradle`: AGP 9.2.1, Kotlin 2.4.0.
  - `android/gradle/wrapper/gradle-wrapper.properties`: Gradle 9.4.1.
  - `android/app/build.gradle`: `compileSdk 37`, Java 17, `minSdkVersion flutter.minSdkVersion`.
  - `android/gradle.properties`: the migrator flags `android.builtInKotlin=false` /
    `android.newDsl=false` (opt-out of the built-in Kotlin path for now) and
    `kotlin.incremental=false` with a comment — Kotlin 2.x incremental compilation fails when the pub
    cache and the project sit on different Windows drives; harmless on CI.
- `.gitignore`: `.fvm/`, `android/.kotlin/`.

## 5a. Riverpod 2.6 → 3.4 (final task)

Bump `flutter_riverpod` to `^3.4.3` and apply the 3.0 API changes; behaviour is unchanged:
- `AsyncValue.valueOrNull` → `value` (which is now nullable and returns the previous value during
  loading/error, matching what `valueOrNull` did).
- `AutoDisposeNotifier` / `AutoDisposeAsyncNotifier` / `AutoDisposeFamilyNotifier` /
  `AutoDisposeFamilyAsyncNotifier` → plain `Notifier` / `AsyncNotifier`; family arguments become a
  constructor parameter of the notifier, and `NotifierProvider.autoDispose.family<N, S, Arg>(N.new)`
  → `NotifierProvider.autoDispose.family<N, S, Arg>(N.new)` with `N(this.arg)`.
- `StateProvider` moves to `package:flutter_riverpod/legacy.dart`; the three uses either import it
  or become a `Notifier<int>`/`Notifier<T>` (preferred where trivial).
- `Override` type is unchanged in name but lives in `package:flutter_riverpod/flutter_riverpod.dart`;
  the test helpers' imports are corrected.
- `AsyncValue.copyWithPrevious` is internal in 3.x; error states are set with
  `AsyncError(e, st)` and Riverpod keeps the previous value itself.
- `ProviderContainer`/`overrideWith` deprecations in tests use the 3.x replacements.
Analyzer must be clean and the suite green; then the second device pass (§7).

## 6. Process, CI and docs

- `.fvmrc` pins `3.47.3`; every command in CLAUDE.md and README becomes `fvm flutter …`.
- `ci.yml` and `release.yml`: `flutter-version: '3.47.3'`; Java 17 is already there.
- CLAUDE.md "Toolchain" section rewritten for the new pins: SDK via fvm, JDK 17 (`fvm flutter config
  --jdk-dir` to the Android Studio JBR on this machine), AGP/Gradle/Kotlin versions, the two
  machine quirks (JVM cannot reach github.com for Gradle downloads — seed the wrapper cache with
  curl; cross-drive Kotlin incremental). The Riverpod notes in "Architecture rules" are updated
  for 3.x (unified `Notifier`/`AsyncNotifier`, `legacy.dart` for `StateProvider`).
- README "Requirements" updated to match.
- Execution follows the project convention: plan in `docs/superpowers/plans/`, task-by-task with a
  review after each, execution log alongside.

## 7. Verification

Automated (all with `fvm flutter`): `analyze` clean (no errors, warnings or infos), `test` green,
`build apk --debug` succeeds locally with JDK 17. CI must pass on the PR.

On a device or emulator against the local dev server (`10.0.2.2:4041`), after installing over the
current debug build (same debug signature, so data is kept — this is the realistic upgrade path):
1. App opens; server URL is still set; the session is gone and login is requested (expected, §2);
   login succeeds and survives a relaunch.
2. Patient lookup by OP number; recent patients still listed.
3. In-app capture (camera 0.12): preview, shutter, torch, tap-to-focus, thumbnails, Done; the
   uploaded image is upright (the EXIF re-encode path still applies).
4. Gallery pick, descriptions incl. "Apply to all", upload; the set appears in history.
5. Offline queue: upload with the server stopped, restart it, queue drains.
6. Settings, About, dark mode, portrait lock, splash still correct.

This pass runs twice: once after the toolchain tasks (Riverpod 2), and again — steps 1, 3, 4 and 5,
the state-heavy flows — after the Riverpod 3 task.

## 8. Risks

- Runtime differences in `camera` 0.12 / CameraX that compile cleanly but behave differently — the
  device pass in §7 exists for this.
- Any other Windows machine quirk surfaces again only locally; CI (Ubuntu) is the reference build.
- Testers' first launch after the update asks for credentials; release notes must say so.
