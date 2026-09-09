# Plan B appearance and release — execution log

Ledger of the subagent-driven execution (pre-flight scan, rulings, review outcomes, parked findings). Copied from the SDD workspace on completion.

# SDD ledger — plan: docs/superpowers/plans/2026-09-09-plan-b-appearance-release.md
Spec: docs/superpowers/specs/2026-09-09-hardening-and-polish-design.md (sections 6-8). Branch flutter-port; starts after Plan A head 74599fb.

Pre-flight scan (2026-09-09):
| Pair / task | Produces vs consumes | Finding | Ruling |
| T1 <-> T2 | both mandate ds_button ghost -> accentText | duplicate mandate | T1 adds token + switches ghost (it owns accentText); T2 verifies only, no second change. Cost if wrong: none. |
| T1 <-> T2 | T1 DsColors.dark / buildDsTheme(Brightness); T2 kit tests pump widgets | T2 tests must not assume light-only | T2 tests pump with default light theme; fine. |
| T2 <-> Plan A T6 (done) | AppModule.badge -> Widget Function()? ; dashboard renders m.badge?.call() | lib/app/modules.dart and tomogram barrel currently pass a Riverpod-based badge | T2 owns the signature change and updates modules.dart + barrel + RecentCountBadge. |
| T3 <-> T4 | T3 release signing via key.properties; T4 CI runs flutter build apk --debug without key files | Gradle must tolerate missing key.properties | brief's Gradle guards with keystorePropertiesFile.exists() and debug signing fallback; consistent. |
| T3 <-> T5 | T3 produces app-release.apk; T5 installs it | ok | — |
| T4 | Java 17 (temurin) in CI vs local JDK | AGP of this project must accept JDK 17 | not a plan conflict; verified in CI when a remote exists (repo has no remote). |
| T2 | MediaQuery.withClampedTextScaling / TextScaler.linear | need Flutter >= 3.16 | 3.19 installed; ok. |
| T1 | own text consistent (ARB keys, provider, sheet, tests) | ok | — |
| T5 | controller-run device verification; release APK cold start | ok | — |

Task 1: dispatched (BASE a9cf19c).
Task 1: DONE (fcda633, 243 tests). Review dispatched.
Task 1: review Approved with Important: system-mode test tautological; third copy of signed-in test harness. Ruling: fix round 1/5 (FIX_BASE fcda633) incl. minors 3,4,5,7; minor 6 (persist-then-state) parked, consistent with other prefs controllers.
Task 1: fix round 1 done (4226d26, 244 tests). Scoped re-review dispatched.
Task 1: complete (a9cf19c..4226d26, re-review clean). Parked: MockHealthCheckApi duplicated in 3 more test files; appearance set() writes state before persist (house pattern).
Task 2: dispatched (BASE 4226d26).
Task 3 pre-check: keytool at Corretto 11 present; build-tools 35.0.0-rc1 (apksigner); .gitignore has no signing entries; build.gradle release uses signingConfigs.debug; version 1.0.0+1.
Task 2: DONE_WITH_CONCERNS (b857135, 277 tests). Ruling: accept DsAppBar clamped at 48dp with ellipsis (Scaffold caps appBar at preferredSize; brief said "grow" but only the bottom bar/rows can) — cost if wrong: long titles truncate at large text scale. Review dispatched.
Task 2: complete (4226d26..b857135, review Approved, no Important). Parked minors: badge position untested vs icon tile; DsListRow 56dp knife-edge with trailing icon; leftover literals in ds_bottom_bar/module_card; skeleton imports list row for height; unused ref in DashboardScreen; loading-list top padding mismatch in patient_lookup.
Task 3: dispatched (BASE b857135).
Task 3: DONE (b83ecf3, d074ae4). Controller check: key.properties + jks untracked, ignored, never added in history; release APK/AAB signed CN=DeCare HMS Upload. Review dispatched.
Task 3: review Approved; Important gap = CI fallback (missing key.properties) not exercised. Ruling: controller verifies directly instead of a fix round.
Task 4: dispatched (BASE d074ae4).
Task 3: complete (b857135..d074ae4). Controller verified CI fallback: without key.properties, flutter build apk --release succeeds and apksigner shows CN=Android Debug; key file restored (untracked).
Task 4: DONE (8b496de). Review dispatched.
Task 5: started (release APK d074ae4+ built, signer CN=DeCare HMS Upload).
Task 4: complete (d074ae4..8b496de, review Approved). Task 5: release 1.1.0+2 installed after uninstalling debug (signature change); cold start Displayed 8.6s first run, then 3.9s / 3.5s.
Task 5: dark mode verified on release build — Settings, About, Home, Tomogram patient screen (7 sets) render with dark palette; System option follows cmd uimode night yes/no live. Final whole-branch review dispatched (a9cf19c..8b496de) in parallel with remaining device shots.
Task 5: complete. Release 1.1.0+2 verified: cold start 3.5-3.9s (8.6s first run); dark mode on Configure, Login, Dashboard, Settings, Appearance sheet, Sign-out dialog, About, Tomogram lookup + patient (7 sets); System follows cmd uimode night live. Emulator restored: night mode off, debug build (HEAD 8b496de) reinstalled unconfigured (release/debug signatures differ, so data was wiped; user must re-enter server URL + login).
Final review (a9cf19c..8b496de): With fixes. Important: (1) ds_sheet barrierColor = textPrimary@45% inverts to a white haze in dark mode; (2) DsListRow InkWell is content-height, so icon-less Appearance rows have ~20dp tap targets. ONE fix dispatch (FIX_BASE 8b496de) incl. minors 3 (DsListRow.selected), 4 (overlay from Theme.of), 6 (CI concurrency), 7 (gradle warn + null guard), 8 (README features list/routing step). Parked: SVG empty-state literal fills on dark canvas; chip fontSize override vs spec wording; bootstrap overrides extraction.
Final fix round DONE (9341326, 2dec518, 6b94d45; 281 tests; gradle guard verified in throwaway worktree). Scoped re-review dispatched.
Final re-review clean. Controller verification on 6b94d45: flutter analyze clean, flutter test 281 passed. PLAN B COMPLETE: a9cf19c..6b94d45. Parked for later: SVG empty-state fills on dark canvas; chip fontSize override vs spec wording; extract bridge overrides to lib/app/bootstrap.dart; MockHealthCheckApi duplication; per-task minors listed above.
