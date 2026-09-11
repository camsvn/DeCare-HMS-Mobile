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
