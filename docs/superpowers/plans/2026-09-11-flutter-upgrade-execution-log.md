# Flutter 3.47 upgrade — execution log

Plan: `2026-09-11-flutter-upgrade.md`. Spec: `../specs/2026-09-11-flutter-upgrade-design.md`.
Branch `flutter-upgrade` off `flutter-port`. Executed inline, one task at a time.

## Task 1 — SDK pin and dependencies

Done as planned. `fvm use 3.47.3 --force` wrote `.fvmrc` and the three analyzer excludes;
`pub get` resolved every direct dependency at latest with `flutter_riverpod` held at 2.6.1.

Deviation from the plan's expected residue: the analyzer reports **93** infos, not 44. The 44
deprecations are exactly as predicted; the other 49 come from lint rules that `flutter_lints` 6
turns on (`unnecessary_underscores` ×46, `prefer_initializing_formals` ×2,
`use_null_aware_elements` ×1). The spike missed them because its lockfile still carried
`lints` 3.0.0. All are drop-in fixes, so they join Tasks 3 (`lib/`) and 4 (`test/`) rather than
becoming their own task. Zero errors, zero warnings. Tests: `+492 -1`, the one failure being the
reduced-motion transition test the plan already schedules for Task 4.

Ruling: proceed.

## Task 2 — Android toolchain

Gradle 9.4.1 / AGP 9.2.1 / Kotlin 2.4.0 / Java 17 / `compileSdk 37` / `minSdk` = Flutter default,
plus the `gradle.properties` flags, as planned. First build failed in
`flutter_plugin_android_lifecycle` 2.0.19 (v1 embedding `PluginRegistry.Registrar`, removed in
this Flutter): Task 1's `pub get` had kept transitive packages at the old lockfile versions.
`fvm flutter pub upgrade` (constraints unchanged) moved them — lifecycle to 2.0.35 — and the debug
APK built. Analyzer (93 infos) and tests (`+492 -1`) unchanged. Lockfile committed with this task.

Ruling: proceed. Plan note for the future: after a major SDK move, `pub upgrade` transitives
before the first Gradle build.

## Task 3 — deprecations in `lib/`

27 sites in 12 files: `withOpacity` → `withValues(alpha:)` (8), `onPopInvoked` →
`onPopInvokedWithResult` (4), `__`/`___` wildcards → `_` (13), and the two
`prefer_initializing_formals` in `DefaultMediaPickerService` (Dart 3.13 private named
parameters, callers unchanged). Analyzer: 0 findings under `lib/`, 66 left under `test/`. Tests
unchanged (`+492 -1`).

Ruling: proceed.

## Task 4 — deprecations in `test/` and the transition test

66 sites. Two things the plan's mapping table got wrong, both caught by the analyzer/suite:
- `SemanticsFlags` has no `hasToggledState`, and `isSelected`/`isEnabled`/`isToggled` are
  `Tristate` (from `dart:ui`), not booleans. Assertions now read `Tristate.isTrue`,
  `isNot(Tristate.isTrue)` (the old "flag absent", which covers both `isFalse` and `none`),
  and `isNot(Tristate.none)` for "has a toggled state". `dart:ui show Tristate` is imported in
  the five files; `package:flutter/rendering.dart` became unnecessary in three and was dropped.
- The scoped `pageSlides()` finder finds **two** slides in the non-reduced test (page A settling,
  page B rising), so that assertion is `findsWidgets`, as the original was.
Analyzer: **No issues found**. Suite: **493 pass**.

Ruling: proceed.

## Task 5 — CI and documentation

Workflow pins to 3.47.3 (Java 17 already there). CLAUDE.md toolchain section rewritten (fvm,
JDK 17, Gradle/AGP/Kotlin, the two machine quirks, the "pub upgrade transitives first" lesson
from Task 2); every developer-facing command in CLAUDE.md and README is `fvm flutter …` / `fvm dart …`.
The README sentence describing what CI runs keeps bare `flutter` — the runner uses
`subosito/flutter-action`, not fvm. Riverpod bullet marked as 2.6-until-Task-7. Analyzer clean, 493 pass.

Ruling: proceed to the device pass.

## Task 6 — device pass #1 (Riverpod 2)

Emulator `emulator-5554` (Android 14, API 34), dev server on `10.0.2.2:4041`. The package was not
previously installed there, so this was a fresh install: the "URL kept, session lost" upgrade
path was not observable on this device (it will be on any tester phone carrying the old build).
Boot → splash → Configure screen with no Flutter errors in logcat; URL entry + Connect (driven via
adb) reached Sign-in with the `10.0.2.2` chip. The user then ran the full checklist — sign in and
relaunch, patient lookup and recents, in-app capture (virtual camera; plugin loads and the flow
completes), gallery pick with "Apply to all" and upload into history, offline queue drain,
Settings/About, dark mode, portrait lock, splash — and reported **all good**.

Ruling: proceed to Riverpod 3.

## Task 7 — Riverpod 2.6 → 3.4

As planned, with three findings the plan did not have:
- `Override` is not exported by `flutter_riverpod.dart` in 3.x; it lives in
  `package:flutter_riverpod/misc.dart` (imported with `show Override` in the three helpers).
- The suite caught one real 3.x behaviour: `TomogramScreen._upload` calls `clearAll()` after
  awaiting the offline queue's `enqueue`, and by then the screen — and its autoDispose notifier —
  may be gone; `state` on an unmounted notifier now throws `UnmountedRefException` (2.x let it
  through). `clearAll`/`remove` return early when `!ref.mounted`: the files were already deleted by
  `onDispose`. `CaptureController.shoot` deletes a photo that lands after the session is gone rather
  than leaking it.
- The mechanical `retry: noRetry` pass initially doubled the line in three files; fixed.
Analyzer **No issues found**; suite **495 pass** (493 + 2 for the compat shim); debug APK built.

Parked (for the branch review): `keepingPrevious` wraps Riverpod's `@internal`
`copyWithPrevious` under a single `// ignore`; there is no public replacement for a manual
"loading, keep the data" transition in 3.4. Revisit at Riverpod 4.

Ruling: proceed to device pass #2.

## Task 8 — device pass #2 (Riverpod 3), preliminaries

Two scares, both cleared before handing the device over:
- The Riverpod 3 build came up on the Configure screen with the pass-#1 URL and session gone.
  `dumpsys package` showed `firstInstallTime` equal to that install: Flutter's `install` command
  uninstalls an existing app before installing (`android_device.dart:419`), so the wipe was the
  tool's, not the app's. Subsequent installs use `adb install -r`, which keeps app data.
- Warm start looked slow (~16 s, later ~33 s). Measured back to back on the same emulator from
  streamed logcat (`am start` → `Fully drawn`): Riverpod 2 build 32.6 s / 42.6 s, Riverpod 3 build
  32.5 s / 34.2 s / 34.2 s — identical within noise; the time is the x86 emulator running a debug
  (JIT) build under host load, not the migration. Not a regression.

## Task 8 — device pass #2 (Riverpod 3), result

User ran the state-heavy flows on the Riverpod 3 build — connect, sign in and relaunch, in-app
capture with a removed shot, gallery upload into history, offline queue (stop server → queued →
start server → drained, label kept for suggestions), sign out/in — and reported **all good**.
The forced-401 sign-out was not exercised on the device (covered by `session_expiry_test`).

## Whole-branch review (`flutter-upgrade` vs `flutter-port`)

Verified on 2026-09-11 after the second device pass:
- `.fvmrc` 3.47.3; `fvm flutter --version` → Flutter 3.47.3 / Dart 3.13.3.
- `pub outdated`: every direct **and transitive** dependency at its latest resolvable version.
- Android: Gradle 9.4.1, AGP 9.2.1, Kotlin 2.4.0, Java 17 (source/target/jvmTarget),
  `compileSdk 37`, `minSdk`/`targetSdk` from Flutter (24/36), migrator flags + `kotlin.incremental=false`.
- Stale-version scan (`3.19`, `Dart 3.3`, Corretto, AGP/Gradle 7, Kotlin 1.7.10, `VERSION_1_8`,
  Riverpod 2 API names, `encryptedSharedPreferences`, `synthetic-package`): only comments that
  explain a decision, SVG path data, and the one intended `legacy.dart` `StateProvider` in a test.
- CI's exact sequence from a clean tree: `pub get`, `gen-l10n` (no diff), `analyze` → No issues,
  `test` → 495 pass, `build apk --debug` → built. Working tree clean; 16 commits on the branch.
- Read-through of the substantive `lib/` diff: the Riverpod 3 changes are confined to the eight
  `keepingPrevious` sites, the four notifier class headers (+ constructor args), `_ownedPaths`
  mirroring in the two file-owning controllers, `ref.mounted` guards after awaits, the
  `AuthFailureCounter`, and `retry: noRetry` in `main.dart`. No behaviour change beyond those.

Rulings:
- The behaviour change accepted by the spec stands: v9→v11 secure storage means one re-login on
  existing installs; minSdk 24 drops Android 5.x/6.x. Release notes must say both.
- `keepingPrevious` (single `// ignore: invalid_use_of_internal_member`) stays — parked for
  Riverpod 4, when a public transition API is expected.
- Automatic retry is disabled globally to keep 2.x behaviour; turning it on for specific
  providers is a product decision for later, not part of this upgrade.

Parked findings:
- Migration to AGP 9's built-in Kotlin / new DSL (Flutter warns at build time; not failing).
- `flutter install` wipes app data (uninstalls first) — use `adb install -r` when the upgrade
  path over an existing install is what is being tested.
- The forced-401 sign-out was verified by `session_expiry_test` only, not on a device.
