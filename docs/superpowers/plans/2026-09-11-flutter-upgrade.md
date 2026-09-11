# Flutter 3.47 Toolchain Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the app from Flutter 3.19.0 to 3.47.3 with every dependency current (Riverpod 3 last), the Android toolchain modernised, analyzer and tests clean, and the app verified on a device.

**Architecture:** Toolchain first, code second, Riverpod last. Tasks 1–5 change configuration and mechanical deprecations on Riverpod 2.6.1 so the SDK move is verified in isolation (Task 6 device pass). Task 7 then migrates to Riverpod 3 in its own commits with a short second device pass. Every task ends with `fvm flutter analyze` and `fvm flutter test` in a known state.

**Tech Stack:** Flutter 3.47.3 / Dart 3.13.3 via fvm 4.x; Gradle 9.4.1, AGP 9.2.1, Kotlin 2.4.0, JDK 17; flutter_riverpod 3.4.3 (Task 7).

**Spec:** `docs/superpowers/specs/2026-09-11-flutter-upgrade-design.md`

## Global Constraints

- Flutter **3.47.3** pinned in `.fvmrc`; every command is `fvm flutter …` (never bare `flutter`, which is the old 3.19 install).
- Every Gradle-touching command needs JDK 17: prefix with `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"` in Git Bash (`$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'` in PowerShell).
- `fvm flutter analyze` must report **No issues found** and `fvm flutter test` must be green before every commit from Task 4 onward; Tasks 1–3 record their expected residual counts explicitly.
- No feature or UI change. Copy, colours, spacing and behaviour are untouched; deprecation replacements are drop-in.
- `flutter_riverpod` stays `^2.6.1` until Task 7.
- Commit messages follow the repo style (`build:`, `fix:`, `test:`, `ci:`, `docs:`, `refactor:`) and end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Never commit `android/key.properties`, `android/upload-keystore.jks`, `.fvm/`, `android/.kotlin/`.
- The Gradle wrapper cannot download distributions on this machine (the JVM cannot reach github.com). Gradle 9.4.1 is already seeded in `~/.gradle/wrapper/dists/gradle-9.4.1-bin/`; do not change the wrapper version.
- Execution log: `docs/superpowers/plans/2026-09-11-flutter-upgrade-execution-log.md` — one entry per task (what was done, review ruling, parked findings).

---

### Task 1: Pin the SDK and bump dependencies (Riverpod excepted)

**Files:**
- Create: `.fvmrc`
- Modify: `.gitignore`, `pubspec.yaml`, `pubspec.lock`, `l10n.yaml`, `analysis_options.yaml`, `lib/core/storage/secure_store.dart:11-15`, `lib/core/l10n/generated/*` (regenerated)

**Interfaces:**
- Produces: a project that resolves and analyzes on 3.47.3 with exactly 44 `deprecated_member_use` infos and 1 failing test (both fixed in Tasks 3–4).

- [ ] **Step 1: Pin the SDK with fvm**

Run: `fvm use 3.47.3 --force` (the SDK is already installed; this writes `.fvmrc`, runs `pub get`, and lets the Flutter tool edit `analysis_options.yaml`).
Expected: `.fvmrc` contains `{"flutter": "3.47.3"}`; `fvm flutter --version` prints `Flutter 3.47.3 … Dart 3.13.3`.

- [ ] **Step 2: Ignore fvm and Kotlin caches**

Append to `.gitignore` (keep the file's existing sections):

```gitignore

# FVM SDK symlink (the pin itself, .fvmrc, is committed)
.fvm/
# Kotlin 2.x session data
android/.kotlin/
```

- [ ] **Step 3: Bump the Dart SDK bound and dependencies in `pubspec.yaml`**

Replace the `environment` and the dependency lines so the file reads (the `flutter_native_splash:` configuration block and everything under `flutter:` are unchanged):

```yaml
environment:
  sdk: ^3.13.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
  # Riverpod 3 is a separate migration (see the upgrade spec, §5a); the rest of
  # the toolchain lands on 2.x first so a regression can be attributed.
  flutter_riverpod: ^2.6.1
  go_router: ^18.0.1
  dio: ^5.11.1
  shared_preferences: ^2.5.5
  # v11 dropped the EncryptedSharedPreferences backend v9 used; existing
  # installs lose the saved session and log in once more. Decided 2026-09-11.
  flutter_secure_storage: ^11.1.0
  image_picker: ^1.2.3
  permission_handler: ^13.0.2
  uuid: ^4.6.0
  url_launcher: ^6.3.2
  flutter_svg: ^2.3.0
  flutter_native_splash: ^2.4.8
  package_info_plus: ^10.2.1
  connectivity_plus: ^7.3.1
  path_provider: ^2.1.6
  camera: ^0.12.1
  # CameraX writes sensor-oriented JPEGs with an EXIF orientation tag. The
  # clinic's viewers are unknown and may ignore EXIF, and the picker path this
  # replaces uploaded upright pixels, so the rotation is baked in before upload.
  image: ^4.9.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mocktail: ^1.0.5
  vector_graphics_compiler: ^1.3.0
```

Delete the two old comments that justified the `connectivity_plus` 6.x and `camera` 0.11 pins (they referred to Flutter 3.19).

- [ ] **Step 4: Resolve**

Run: `fvm flutter pub get`
Expected: `Got dependencies!`, no "newer versions incompatible" line for direct dependencies. Then `fvm flutter pub outdated` shows `direct dependencies: all up-to-date` except `flutter_riverpod` (3.4.3 resolvable, deliberately held).

- [ ] **Step 5: Drop the removed secure-storage option**

In `lib/core/storage/secure_store.dart`, replace the constructor initialiser:

```dart
class FlutterSecureStore implements SecureStore {
  // flutter_secure_storage 11 encrypts with its own cipher on Android; the
  // `encryptedSharedPreferences` option v9 needed no longer exists. Data
  // written by v9 is not readable by v11 — accepted: the only thing stored
  // here is the session, and testers log in once more after the upgrade.
  FlutterSecureStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();
```

- [ ] **Step 6: Remove the dead l10n option and regenerate**

In `l10n.yaml` delete the line `synthetic-package: false`. Run: `fvm flutter gen-l10n`.
Expected: no warning about `synthetic-package`; `lib/core/l10n/generated/app_localizations*.dart` changed (new generator header/format only — `git diff --stat` shows those two files).

- [ ] **Step 7: Check `analysis_options.yaml`**

The Flutter tool added three excludes in Step 1. Confirm the `analyzer:` block reads:

```yaml
analyzer:
  exclude:
    - lib/core/l10n/generated/**
    - build/**
    - android/**
    - ios/**
```

- [ ] **Step 8: Analyze and test — record the expected residue**

Run: `fvm flutter analyze`
Expected: `44 issues found`, all `info • … deprecated_member_use` (27 `hasFlag`, 8 `withOpacity`, 4 `value`, 4 `onPopInvoked`, 1 `onPopPage`). Zero errors, zero warnings. Anything else is a real problem — stop and investigate.

Run: `fvm flutter test`
Expected: `+492 -1`; the single failure is `test/core/design/fade_through_page_test.dart: under reduced motion it is a plain fade, and a short one` (fixed in Task 4).

- [ ] **Step 9: Commit**

```bash
git add .fvmrc .gitignore pubspec.yaml pubspec.lock l10n.yaml analysis_options.yaml lib/core/storage/secure_store.dart lib/core/l10n/generated
git commit -m "build: Flutter 3.47.3 via fvm, dependencies to current (Riverpod held at 2.x)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Android toolchain

**Files:**
- Modify: `android/settings.gradle:22-23`, `android/gradle/wrapper/gradle-wrapper.properties:5`, `android/app/build.gradle:43,47-52,64`, `android/gradle.properties`

**Interfaces:**
- Produces: `fvm flutter build apk --debug` succeeds.

- [ ] **Step 1: Plugin versions**

In `android/settings.gradle` change the two plugin lines to:

```groovy
    id "com.android.application" version "9.2.1" apply false
    id "org.jetbrains.kotlin.android" version "2.4.0" apply false
```

- [ ] **Step 2: Gradle wrapper**

In `android/gradle/wrapper/gradle-wrapper.properties`:

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-9.4.1-bin.zip
```

- [ ] **Step 3: App module**

In `android/app/build.gradle`:
- `compileSdk flutter.compileSdkVersion` → `compileSdk 37` with the comment `// permission_handler_android 14 requires 37; Flutter's default is still 36.` on the line above.
- `sourceCompatibility JavaVersion.VERSION_1_8` / `targetCompatibility JavaVersion.VERSION_1_8` → `JavaVersion.VERSION_17` (both).
- `jvmTarget = '1.8'` → `jvmTarget = '17'`.
- `minSdkVersion 21` → `minSdkVersion flutter.minSdkVersion` (24 with this SDK; Android 5/6 dropped — spec §2).

- [ ] **Step 4: Gradle properties**

Replace `android/gradle.properties` with:

```properties
org.gradle.jvmargs=-Xmx4G
android.useAndroidX=true
android.enableJetifier=true
# Flutter's migrator opts the project out of AGP 9's built-in Kotlin and new
# DSL; the app still applies the Kotlin Gradle plugin itself. Migration to
# built-in Kotlin is a separate piece of work.
android.builtInKotlin=false
android.newDsl=false
# Kotlin 2.x incremental compilation fails ("this and base files have
# different roots") when the pub cache and the project are on different
# Windows drives. Non-incremental is a little slower and always correct.
kotlin.incremental=false
```

- [ ] **Step 5: Build**

Run (Git Bash): `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" fvm flutter build apk --debug`
Expected: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`. A warning about the Kotlin Gradle Plugin / built-in Kotlin is expected and fine; an error mentioning `android-37` means the app `compileSdk` edit was missed; a Kotlin "different roots" error means Step 4 was missed.

- [ ] **Step 6: Analyze and test unchanged**

Run: `fvm flutter analyze` → still `44 issues found`, infos only. `fvm flutter test` → still `+492 -1`.

- [ ] **Step 7: Commit**

```bash
git add android/settings.gradle android/gradle/wrapper/gradle-wrapper.properties android/app/build.gradle android/gradle.properties
git commit -m "build(android): Gradle 9.4.1, AGP 9.2.1, Kotlin 2.4, Java 17, compileSdk 37

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Deprecations in `lib/`

**Files:**
- Modify: `lib/features/tomogram/presentation/capture_screen.dart:351,404`, `lib/features/tomogram/presentation/tomogram_screen.dart:216`, `lib/features/tomogram/presentation/widgets/photo_viewer.dart:223-224`, `lib/features/tomogram/presentation/widgets/tomogram_card.dart:153`, plus any other `withOpacity`/`onPopInvoked` site the analyzer lists under `lib/`

**Interfaces:**
- Produces: `fvm flutter analyze` lists infos only under `test/`.

- [ ] **Step 1: List the exact sites**

Run: `fvm flutter analyze 2>&1 | grep -E "lib[\\/]"`
Expected: 12 lines — `withOpacity` (8) and `onPopInvoked` (4).

- [ ] **Step 2: `withOpacity` → `withValues`**

At every listed `lib/` site replace `.withOpacity(x)` with `.withValues(alpha: x)`. Same numeric argument, same result; e.g.

```dart
// before
color: context.ds.overlay.withOpacity(0.6),
// after
color: context.ds.overlay.withValues(alpha: 0.6),
```

Colours still come from tokens (`context.ds…`) — do not introduce literals.

- [ ] **Step 3: `PopScope.onPopInvoked` → `onPopInvokedWithResult`**

At each `PopScope(` in `capture_screen.dart` and `tomogram_screen.dart` the callback gains a second, unused parameter:

```dart
// before
onPopInvoked: (didPop) {
// after
onPopInvokedWithResult: (didPop, _) {
```

The body is unchanged.

- [ ] **Step 4: Verify**

Run: `fvm flutter analyze 2>&1 | grep -cE "lib[\\/]"` → `0`. Total should now read `32 issues found` (all under `test/`).
Run: `fvm flutter test` → `+492 -1` (the same single failure).

- [ ] **Step 5: Commit**

```bash
git add lib
git commit -m "refactor: replace withOpacity and onPopInvoked deprecations

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Deprecations in `test/` and the transition test

**Files:**
- Modify: `test/core/design/ds_bottom_bar_test.dart`, `ds_button_test.dart`, `ds_fab_test.dart`, `ds_list_row_test.dart`, `ds_sheet_test.dart`, `fade_through_page_test.dart`, `test/features/tomogram/capture_screen_test.dart`, `label_pill_test.dart`, `photo_viewer_test.dart`, `shot_preview_screen_test.dart`

**Interfaces:**
- Produces: analyzer **No issues found**; suite fully green.

- [ ] **Step 1: `SemanticsData.hasFlag` → `flagsCollection` (27 sites)**

`hasFlag(SemanticsFlag.isButton)` becomes a boolean field on `flagsCollection`. Mapping used in this suite:

| before | after |
|---|---|
| `data.hasFlag(SemanticsFlag.isButton)` | `data.flagsCollection.isButton` |
| `data.hasFlag(SemanticsFlag.hasEnabledState)` | `data.flagsCollection.hasEnabledState` |
| `data.hasFlag(SemanticsFlag.isEnabled)` | `data.flagsCollection.isEnabled` |
| `data.hasFlag(SemanticsFlag.isSelected)` | `data.flagsCollection.isSelected` |
| `data.hasFlag(SemanticsFlag.isHeader)` | `data.flagsCollection.isHeader` |
| `data.hasFlag(SemanticsFlag.hasToggledState)` / `isToggled` | `flagsCollection.hasToggledState` / `.isToggled` |
| `data.hasFlag(SemanticsFlag.isTextField)` | `flagsCollection.isTextField` |

For any flag not in the table use the identically named getter on `flagsCollection`. Negations (`isFalse` / `!`) stay as they were.

- [ ] **Step 2: `Color.value` → `toARGB32()` (4 sites in `ds_sheet_test.dart:78,135`)**

```dart
// before
expect(paint.color.value, expected.withOpacity(0.5).value);
// after
expect(paint.color.toARGB32(), expected.withValues(alpha: 0.5).toARGB32());
```

(These two lines also carry the last two `withOpacity` sites — replace them in the same edit.)

- [ ] **Step 3: `Navigator.onPopPage` → `onDidRemovePage` (`fade_through_page_test.dart:13`)**

```dart
// before
onPopPage: (route, result) => false,
// after
onDidRemovePage: (page) {},
```

- [ ] **Step 4: Fix the reduced-motion assertion (`fade_through_page_test.dart:44-53`)**

MaterialApp's default page transition is now `FadeForwardsPageTransitionsBuilder`, which wraps the *home route* — and therefore the whole nested `Navigator` the test builds — in `SlideTransition`s; `find.ancestor(of: find.text('B'), matching: find.byType(SlideTransition))` walks up past the nested Navigator and catches those. Scope the search to the nested Navigator's subtree, which contains only what `FadeThroughPage.buildTransitions` builds around the page content. Add a helper at the top of `main()` (after the `app()` helper) and use it in both transition tests:

```dart
  /// The `Navigator(pages:)` the test builds — `.last` because the
  /// MaterialApp's own root Navigator comes first in tree order. Transitions
  /// found below it belong to FadeThroughPage; anything above belongs to the
  /// MaterialApp's home route and is not under test.
  Finder pageSlides() => find.descendant(of: find.byType(Navigator).last, matching: find.byType(SlideTransition));
```

```dart
  testWidgets('under reduced motion it is a plain fade, and a short one', (tester) async {
    await tester.pumpWidget(app(const [pageA], reduceMotion: true));
    await tester.pumpWidget(app(const [pageA, pageB], reduceMotion: true));
    await tester.pump();
    expect(pageSlides(), findsNothing);
    final route = ModalRoute.of(tester.element(find.text('B')))! as PageRoute<void>;
    expect(route.transitionDuration, DsMotion.fast);
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });
```

In the sibling test that asserts the slide *is* present without reduced motion, replace its `find.ancestor(of: find.text('B'), matching: find.byType(SlideTransition))` with `pageSlides()` as well (expecting `findsOneWidget`), so that test stops passing vacuously on the MaterialApp's slides. Run the file: both must pass; if `pageSlides()` finds nothing in the non-reduced test, the `.last` Navigator is wrong — print `find.byType(Navigator).evaluate().length` and pick the nested one.

- [ ] **Step 5: Run the file, then everything**

Run: `fvm flutter test test/core/design/fade_through_page_test.dart` → all pass.
Run: `fvm flutter analyze` → `No issues found!`
Run: `fvm flutter test` → all pass (`+493`).

- [ ] **Step 6: Commit**

```bash
git add test
git commit -m "test: Flutter 3.47 API replacements and a scoped reduced-motion assertion

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: CI and documentation

**Files:**
- Modify: `.github/workflows/ci.yml:28`, `.github/workflows/release.yml:27`, `CLAUDE.md` (Toolchain and Commands sections), `README.md` (Requirements, Run, Release sections)

- [ ] **Step 1: Workflows**

In both workflow files change `flutter-version: '3.19.0'` to `flutter-version: '3.47.3'`. Java 17 is already configured; nothing else changes.

- [ ] **Step 2: CLAUDE.md toolchain section**

Replace the "Toolchain (pinned; do not upgrade without a decision)" section with:

```markdown
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
- Check pub constraints before adding or bumping anything; `flutter_riverpod` is 3.x (see the
  Riverpod notes under Architecture rules).
```

Update the "Commands" block to prefix every command with `fvm ` (e.g. `fvm flutter gen-l10n`).

- [ ] **Step 3: CLAUDE.md Riverpod bullet**

The Riverpod bullet under "Architecture rules" is rewritten in Task 7 (it must describe 3.x only once 3.x is in). In this task change only its version: `Riverpod 2.6:` → `Riverpod (2.6 until the Riverpod 3 task lands):`.

- [ ] **Step 4: README**

"Requirements": `- Flutter 3.19.x (Dart 3.3). Run \`flutter --version\` to confirm.` → `- Flutter 3.47.3 (Dart 3.13) through [fvm](https://fvm.app): \`fvm install\` in the repo picks up \`.fvmrc\`. Run \`fvm flutter --version\` to confirm.` Add `- JDK 17 for the Android build (Android Studio's bundled JBR works).` Prefix every `flutter` command in the README with `fvm `.

- [ ] **Step 5: Verify and commit**

Run: `fvm flutter analyze` → No issues; `fvm flutter test` → green (docs only, but the gate is the gate).

```bash
git add .github/workflows/ci.yml .github/workflows/release.yml CLAUDE.md README.md
git commit -m "ci,docs: Flutter 3.47.3 in the workflows and the toolchain notes

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Device pass #1 (Riverpod 2)

**Files:**
- Modify: `docs/superpowers/plans/2026-09-11-flutter-upgrade-execution-log.md` (results)

Prerequisite: the developer's dev server is running (`npm run dev` in `../HMSServer`, port 4041). Do not start or restart it yourself — ask.

- [ ] **Step 1: Install over the current debug build**

Run: `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" fvm flutter run --debug` on the connected emulator/device that has the current app installed (debug over debug keeps app data — the realistic upgrade path).
Expected: the app starts with the server URL still set and **asks to log in** (the saved session was in the old secure-storage backend — spec §2).

- [ ] **Step 2: Walk the checklist**

Record pass/fail per line in the execution log:
1. Login with the developer's credentials (typed by the user, never written down); relaunch — still signed in.
2. Look up a patient by OP number; the recent-patients list still shows earlier entries.
3. In-app capture: preview appears, shutter takes a shot, torch toggles, tap-to-focus, thumbnails accumulate, Done returns the set; after upload the image on the server is upright.
4. Gallery pick of 2+ photos, descriptions incl. "Apply to all", upload; the set appears in history.
5. Offline queue: ask the user to stop the dev server, upload (queued), ask them to start it again, queue drains.
6. Settings and About render; toggle dark mode; rotate — portrait lock holds; cold start shows the splash.

- [ ] **Step 3: Log and commit**

Write the results under a "Task 6 — device pass #1" heading in the execution log. Any failure is a blocker: fix it as its own commit (with a test where feasible) before Task 7.

```bash
git add docs/superpowers/plans/2026-09-11-flutter-upgrade-execution-log.md
git commit -m "docs: device pass on Flutter 3.47.3 (Riverpod 2)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Riverpod 2.6 → 3.4

**Files:**
- Create: `lib/core/riverpod/riverpod_compat.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `lib/app/router.dart`, `lib/app/session_expiry_listener.dart`, `lib/core/network/dio_client.dart`, `lib/features/auth/application/session_controller.dart`, `lib/features/auth/presentation/login_screen.dart`, `lib/features/dashboard/application/connection_status_controller.dart`, `lib/features/dashboard/presentation/widgets/context_strip.dart`, `lib/features/patient_lookup/application/patient_lookup_controller.dart`, `lib/features/server_config/application/server_config_controller.dart`, `lib/features/settings/presentation/settings_screen.dart`, `lib/features/tomogram/application/{capture_controller,tomogram_controller,tomogram_history_controller,upload_queue_controller,description_suggestions}.dart`, `lib/features/tomogram/presentation/widgets/pending_uploads_sheet.dart`, `test/helpers/{pump_app,signed_in_container}.dart`, `test/features/dashboard/{connection_status_controller_test,dashboard_screen_test}.dart`, `test/features/tomogram/{tomogram_screen_test,upload_queue_controller_test,shot_preview_screen_test}.dart`, `test/app/session_expiry_test.dart`, every test file that constructs a `ProviderContainer(`, `CLAUDE.md`

**Interfaces:**
- Produces: `lib/core/riverpod/riverpod_compat.dart` exporting
  - `Duration? noRetry(int retryCount, Object error)` — always `null`;
  - `extension AsyncValueKeepPrevious<T> on AsyncValue<T> { AsyncValue<T> keepingPrevious(AsyncValue<T> previous); }`.
- Family notifiers take their argument in the constructor: `TomogramController(this.opid)`, `TomogramHistoryController(this.opid)`; `build()` has no parameter.
- `authFailureProvider` becomes `NotifierProvider<AuthFailureCounter, int>` with `void bump()`.

Riverpod 3 facts this task relies on (verified against riverpod 3.4.3 sources):
- `AsyncValue.value` returns the previous value during loading/error when one was carried, else `null` — the same as 2.x `valueOrNull`.
- `AsyncValue.copyWithPrevious` is `@internal`; assigning `state` in a notifier does **not** preserve the previous value by itself. There is no public replacement for a manual "loading, keep the data" transition, hence the single-site shim below.
- Failing provider builds are retried automatically with back-off unless `retry` returns `null`. The app's error states have explicit retry affordances, so retry is disabled to keep 2.x behaviour.
- Reading `state` inside a `ref.onDispose` callback asserts in debug ("Cannot use Ref … inside life-cycles"); the two controllers that do so mirror the paths they own into a plain field instead.
- `ref.*` after the provider is disposed throws `UnmountedRefException`; awaited methods in autoDispose notifiers check `ref.mounted` after each `await` before touching `ref` or `state`.
- `StateProvider` lives in `package:flutter_riverpod/legacy.dart`; family `overrideWith` is deprecated in favour of `overrideWith2((arg) => …)`.

- [ ] **Step 1: Compat file (with its test)**

Create `lib/core/riverpod/riverpod_compat.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod 3 retries a provider whose `build` threw, with back-off. Every
/// error state in this app has its own retry affordance (banner, button, the
/// offline queue), so automatic retries would only make the UI flicker
/// between error and loading. Passed as `retry:` to every container/scope.
Duration? noRetry(int retryCount, Object error) => null;

extension AsyncValueKeepPrevious<T> on AsyncValue<T> {
  /// Riverpod 3 made `copyWithPrevious` internal without a public way to say
  /// "loading (or failed), but keep showing the data we had". Controllers
  /// that start an operation from a method (login, connect, search, the upload
  /// queue) need exactly that, so the internal call is confined to this one
  /// place. Revisit when Riverpod 4 offers a public transition API.
  AsyncValue<T> keepingPrevious(AsyncValue<T> previous) =>
      // ignore: invalid_use_of_internal_member
      copyWithPrevious(previous);
}
```

Create `test/core/riverpod/riverpod_compat_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';

void main() {
  test('keepingPrevious carries the old data through loading and error', () {
    const data = AsyncData<int>(1);
    final loading = const AsyncLoading<int>().keepingPrevious(data);
    expect(loading.isLoading, isTrue);
    expect(loading.value, 1);
    final error = AsyncError<int>('boom', StackTrace.empty).keepingPrevious(loading);
    expect(error.hasError, isTrue);
    expect(error.value, 1);
  });

  test('noRetry never schedules a retry', () {
    expect(noRetry(0, Exception()), isNull);
    expect(noRetry(5, StateError('x')), isNull);
  });
}
```

This test cannot compile until Step 2 (the extension type-checks against 3.x). Write it now, run it after Step 2.

- [ ] **Step 2: Bump**

In `pubspec.yaml` replace the `flutter_riverpod` lines (comment included) with `flutter_riverpod: ^3.4.3`. Run `fvm flutter pub get`.
Expected: `> flutter_riverpod 3.4.3`, `> riverpod 3.4.3`. `fvm flutter analyze` now reports ~126 errors — the map for the rest of this task.

Run: `fvm flutter test test/core/riverpod/riverpod_compat_test.dart` → passes.

- [ ] **Step 3: `valueOrNull` → `value` everywhere**

Mechanical: every `.valueOrNull` in `lib/` and `test/` becomes `.value` (27 sites — `lib/app/router.dart:48-49`, `session_expiry_listener.dart:33`, `session_controller.dart:34,40`, `login_screen.dart:53`, `connection_status_controller.dart:14`, `context_strip.dart:49,51,56`, `settings_screen.dart:60,62,64`, `description_suggestions.dart:43`, `upload_queue_controller.dart:189,216,221,231`, `pending_uploads_sheet.dart:29`, `main.dart:30-31`, `test/helpers/signed_in_container.dart:60-61`, `connection_status_controller_test.dart:57,66,75`, `tomogram_screen_test.dart:130`). Where the old code read `.valueOrNull?.x`, the new code is `.value?.x`; `.valueOrNull ?? y` → `.value ?? y`.

- [ ] **Step 4: `copyWithPrevious` → `keepingPrevious`**

Add `import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';` and replace at all 8 sites:

`session_controller.dart`:
```dart
    state = const AsyncLoading<Session?>().keepingPrevious(state);
    …
      state = AsyncError<Session?>(e, st).keepingPrevious(state);
```
`server_config_controller.dart` (3 sites), `patient_lookup_controller.dart` (2 sites): same shape.
`upload_queue_controller.dart:208`:
```dart
    state = _running ? const AsyncLoading<List<PendingUpload>>().keepingPrevious(data) : data;
```

- [ ] **Step 5: Unified notifier classes and family constructor arguments**

`patient_lookup_controller.dart`:
```dart
class PatientLookupController extends AsyncNotifier<Patient?> {
  …unchanged body…
}

final patientLookupControllerProvider =
    AsyncNotifierProvider.autoDispose<PatientLookupController, Patient?>(PatientLookupController.new);
```
(`autoDispose` stays on the provider; only the base class changes.)

`capture_controller.dart`: `extends AutoDisposeNotifier<CaptureState>` → `extends Notifier<CaptureState>`; provider unchanged.

`tomogram_history_controller.dart`:
```dart
class TomogramHistoryController extends AsyncNotifier<List<TomogramSet>> {
  TomogramHistoryController(this.opid);

  final int opid;

  @override
  Future<List<TomogramSet>> build() => ref.read(tomogramHistoryApiProvider).list(opid);
}

final tomogramHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<TomogramHistoryController, List<TomogramSet>, int>(TomogramHistoryController.new);
```

`tomogram_controller.dart`: `extends AutoDisposeFamilyNotifier<TomogramState, int>` → `extends Notifier<TomogramState>` with `TomogramController(this.opid); final int opid;`, `build(int arg)` → `build()`, and every `arg` in the class → `opid` (lines 111, 119). Provider declaration unchanged.

- [ ] **Step 6: No `state` inside `onDispose`**

`tomogram_controller.dart` — keep the file paths in a field that `listenSelf` maintains, and read the field on dispose:

```dart
  /// Paths of the drafts currently held. `onDispose` runs after the notifier
  /// is unmounted, when `state` may no longer be read, so the list is mirrored
  /// here as the state changes.
  List<String> _ownedPaths = const [];

  @override
  TomogramState build() {
    listenSelf((_, next) => _ownedPaths = next.drafts.map((d) => d.filePath).toList());
    ref.onDispose(() {
      if (_ownedPaths.isNotEmpty) deleteFiles(_ownedPaths);
    });
    return const TomogramState();
  }
```

`capture_controller.dart` — same pattern with `next.shots.map((s) => s.path)` and `deleteFiles(_withTempSiblings(_ownedPaths))`; keep the existing comment about `.tmp` siblings.

- [ ] **Step 7: `ref.mounted` after awaits in autoDispose notifiers**

`tomogram_controller.dart` `upload()` after `await ref.read(tomogramApiProvider).upload(opid, drafts);`:
```dart
    if (!ref.mounted) return; // the screen closed mid-upload; nothing left to update
```
before `ref.invalidate(tomogramHistoryProvider(opid));` and again before the `recentLabelsProvider` read at line 126. In `capture_controller.dart` add the same guard after each `await _camera.*` that is followed by a `state =` assignment (`start`, `setZoom` loop, `stop`, `takePicture`, `setTorch`, `focusAt`). `patient_lookup_controller.search`: after the `await`, `if (!ref.mounted) return null;` before `state = AsyncData(patient)` (and in the catch, before setting the error).

- [ ] **Step 8: `StateProvider` sites**

`lib/core/network/dio_client.dart` — replace the `StateProvider` with a notifier:
```dart
/// Bumped whenever a protected request stays 401 after a refresh attempt.
/// `SessionExpiryListener` watches it and signs the user out.
class AuthFailureCounter extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final authFailureProvider = NotifierProvider<AuthFailureCounter, int>(AuthFailureCounter.new);
```
and line 67: `onAuthFailure: () => ref.read(authFailureProvider.notifier).bump(),`.
`test/app/session_expiry_test.dart`: every `c.read(authFailureProvider.notifier).state++` → `c.read(authFailureProvider.notifier).bump()`.
`test/features/tomogram/upload_queue_controller_test.dart:22`: add `import 'package:flutter_riverpod/legacy.dart';` and keep the `StateProvider<String?>` (test-only scaffolding; `legacy.dart` is the supported home).

- [ ] **Step 9: Disable automatic retry**

`lib/main.dart:26`: `ProviderContainer(retry: noRetry, overrides: [` (import the compat file).
`test/helpers/pump_app.dart:17`: `ProviderScope(retry: noRetry, overrides: overrides, …`.
`test/helpers/signed_in_container.dart:55`: `ProviderContainer(retry: noRetry, overrides: [`.
Every other `ProviderContainer(` in `test/` (18 sites — list with `grep -rn "ProviderContainer(" test`): add `retry: noRetry,` as the first named argument and the import. Widget tests that build their own `ProviderScope(` (grep `ProviderScope(` in `test/`): same.

- [ ] **Step 10: Test-only API changes**

`test/features/tomogram/shot_preview_screen_test.dart`: `_FakeHistory` gains the family argument and the override uses `overrideWith2`:
```dart
class _FakeHistory extends TomogramHistoryController {
  _FakeHistory(super.opid, this.narrations);
  final List<String> narrations;
  @override
  Future<List<TomogramSet>> build() async => [ …unchanged… ];
}
…
        tomogramHistoryProvider.overrideWith2((opid) => _FakeHistory(opid, narrations)),
```
`test/features/dashboard/dashboard_screen_test.dart:4`: the analyzer flagged the `flutter_riverpod` import as unused *and* `Override` as not a type — they are the same problem: keep the import (it supplies `Override`). If `Override` still fails to resolve in any file, it is shadowed by another import; qualify it with `import 'package:flutter_riverpod/flutter_riverpod.dart' as rp;` → `List<rp.Override>`.

- [ ] **Step 11: Analyzer clean, suite green**

Run: `fvm flutter analyze` → `No issues found!` (no `invalid_use_of_internal_member` anywhere except the one ignored line in the compat file).
Run: `fvm flutter test` → all pass. Failures to expect and how to read them:
- `UnmountedRefException` → a `ref.mounted` guard missing after an `await` (Step 7).
- "Cannot use Ref … inside life-cycles" → a `state` read still inside `onDispose` (Step 6).
- A test that waited for an error state and now sees loading again → a container without `retry: noRetry` (Step 9).
- A value expected to survive an error/loading transition is `null` → a `copyWithPrevious` site converted to a plain `AsyncLoading()`/`AsyncError()` instead of `keepingPrevious` (Step 4).

- [ ] **Step 12: Build and CLAUDE.md**

Run: `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" fvm flutter build apk --debug` → `✓ Built`.

Rewrite the Riverpod bullet in CLAUDE.md "Architecture rules":

```markdown
- Riverpod 3.4: `Notifier`/`AsyncNotifier` only (no `AutoDispose*`/`Family*` classes — family
  notifiers take the argument in their constructor); `ref.watch` in `build`, `ref.read` only in
  callbacks and before the first `await`, and check `ref.mounted` after every `await` in an
  autoDispose notifier; never read `state` inside `ref.onDispose` (mirror what dispose needs into
  a field via `listenSelf`); `AsyncValue.value` carries the previous value through loading/error,
  and a method that starts an operation keeps it with `keepingPrevious` from
  `lib/core/riverpod/riverpod_compat.dart`; automatic retry is off (`noRetry`) everywhere;
  `StateProvider` only from `legacy.dart`, and only in tests. Providers overridden in `main.dart`
  are mirrored by `test/helpers/signed_in_container.dart`; keep them in sync.
```

- [ ] **Step 13: Commit (two commits)**

```bash
git add lib/core/riverpod test/core/riverpod pubspec.yaml pubspec.lock
git commit -m "build: flutter_riverpod 3.4 with retry disabled and a keep-previous shim

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git add lib test CLAUDE.md
git commit -m "refactor: Riverpod 3 API — unified notifiers, value, mounted guards, legacy StateProvider

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Device pass #2 (Riverpod 3) and wrap-up

**Files:**
- Modify: `docs/superpowers/plans/2026-09-11-flutter-upgrade-execution-log.md`

- [ ] **Step 1: Install and run the state-heavy flows**

`JAVA_HOME=… fvm flutter run --debug` over the Task 6 install. Checklist items **1, 3, 4, 5** from Task 6 (login/relaunch, capture, gallery upload, offline queue), plus: sign out and back in; force a 401 by asking the user to restart the dev server with a changed JWT secret if they are willing — otherwise note it as not exercised.

- [ ] **Step 2: Log, then the whole-branch review**

Record results under "Task 8 — device pass #2". Then run the project's whole-branch review (per CLAUDE.md process conventions) on `flutter-upgrade` vs `flutter-port`; record rulings and parked findings (the `keepingPrevious` internal-API shim is a known parked item).

```bash
git add docs/superpowers/plans/2026-09-11-flutter-upgrade-execution-log.md
git commit -m "docs: device pass on Riverpod 3 and the branch review

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 3: Hand back**

Report: the branch is ready for a PR into `flutter-port` (or `main`, the user's call); the release (version bump to `2026.9.2+4`, tag) is a separate step per README, and its release notes must mention the one-time re-login and the Android 7.0 minimum.
