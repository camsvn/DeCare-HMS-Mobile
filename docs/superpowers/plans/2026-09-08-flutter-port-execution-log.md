# SDD ledger — plan: E:/Projects/personal/deCare/hms/HMSFlutter/docs/superpowers/plans/2026-09-08-flutter-port.md
Spec: docs/superpowers/specs/2026-09-08-flutter-port-design.md
Branch: flutter-port (repo HMSFlutter). Ruling: implement on branch `flutter-port` in the new sibling repo rather than a worktree — the repo holds only docs commits and no other work is in flight; cost if wrong: none beyond a branch rename.

## Pre-flight scan (task pairs sharing files/interfaces)
| Tasks | Interface | Finding |
|---|---|---|
| 1↔all | ARB keys, AppColors/AppSpacing/AppTextStyles | Keys used later (configureUrl*, login*, home*, tomogram*, permission*, settings*, about*, common*, error*) all defined in Task 1 ARB. OK |
| 2↔6,7,8,9,10 | ApiFailure.detail/describe, unwrapEnvelope | Consumers use describe(l10n) and ApiFailure.from. OK |
| 3↔6,7,9 | normalizeServerUrl, isJwtValid, isJpegFile, deleteFiles | Signatures match. OK |
| 4↔6,7,8,9,12 | serverUrlProvider/accessTokenProvider (overridden in main), dioProvider, RoutePaths | Task 12 main.dart overrides both. RoutePaths created in Task 4 step 5 and consumed by 6-12. OK |
| 5↔6-12 | AppTextField(onChanged, inputFormatters, autofocus), PrimaryButton(color), LinkButton(color), AppHeader(rightIcon/onRightTap/leftIcon), showFlash, LoaderModal, showConfirmDialog, showAppBottomSheet, HideWithKeyboard, ExitOnDoubleBack | All parameters used downstream exist in Task 5 definitions. OK |
| 6↔11,12 | serverConfigControllerProvider (AsyncNotifier<String?>), reset(), configureRoute | Settings calls reset(); router reads valueOrNull. OK |
| 7↔11,12 | sessionControllerProvider, logout(), Session.isValid(), loginRoute | OK |
| 8↔10,12 | Patient (tomogram routes import via patient_lookup barrel), homeRoute(children:), tomogramRoutes | homeRoute takes children so patient_lookup does not import tomogram. OK |
| 9↔10 | tomogramControllerProvider(opid), MediaPickerService.pick/deniedPermissions, uuidProvider, provisional barrel replaced in Task 10 | OK |
| 11↔12 | settingsRoute(children:), aboutRoute | OK |
| 12 | flutter_native_splash moved dev→runtime dependency | Task 1 pubspec puts it in dev_dependencies; Task 12 moves it. Self-consistent. |
| Self-consistency | Task 10 test 'denied permission' needs onPermissionsDenied override; brief says to pass it. Task 5 tests reference generated l10n (exists after Task 1). | OK |
Scan clean: no rulings needed beyond the branch ruling above.

## Progress

Task 1: dispatched (BASE 59e941e, implementer sonnet)
Task 1: review — spec ✅; one Important (plan-mandated): `flutter test` not green because test/ is empty after scaffold.
Task 1: Ruling: accept without a placeholder test — the constraint "flutter test green" is about the tests a task adds; Task 1 adds none and Task 2 adds the first real tests minutes later. A dummy test is YAGNI. Cost if wrong: one empty-test-dir report between two commits.
Task 1: complete (commits 59e941e..d80ab3d, review clean after ruling)
Task 2: dispatched (BASE d80ab3d, implementer haiku)
Task 2: review — spec ✅; one finding: transformTimeout case untested.
Task 2: fix round 1/5 (1 addressed pending re-review, 0 open — transformTimeout test; commits 91a7b1c..1901e0d)
Task 2: complete (commits d80ab3d..1901e0d, review clean)
Task 3: dispatched (BASE 1901e0d, implementer haiku)
Task 3: DONE_WITH_CONCERNS — verbatim RN regex rejects 'cutis.decare.team' and 'my-hms.example.com' (3-level domains); implementer dropped those two expectations.
Task 3: Ruling: the original regex is buggy (verified with node: it rejects the app's own production URL http://cutis.decare.team). Amend the domain alternative to `(www\.)?[\w\-]+(\.[\w\-]+)*\.[a-z]{2,}(:\d{1,5})?` so multi-level hosts and an optional port validate; everything else stays verbatim. Spec section 5 amended. Cost if wrong: a URL the old app rejected is now accepted and then fails at the health check with a clear "Host:" message, which is the safer failure.
Task 3: fix round 1/5 dispatched (regex amendment + restore test cases; FIX_BASE b61bcbe)
Task 3: fix round 1/5 done (regex widened, tests restored; commits b61bcbe..a2e23a9); full task review dispatched over 1901e0d..a2e23a9
Task 3: complete (commits 1901e0d..a2e23a9, review clean; spec docs b12259c)
Task 4: dispatched (BASE b12259c, implementer haiku)
Task 4: DONE (commit a46c525); review dispatched
Task 4: complete (commits b12259c..a46c525, review clean)
Task 5: dispatched (BASE a46c525, implementer sonnet)
Task 5: BLOCKED — ExitOnDoubleBack (as planned) uses DateTime.now(), which flutter_test's fake clock does not advance, so the "second back after window" test cannot pass.
Task 5: Ruling: plan defect. Replace the timestamp comparison with a Timer-based arm window (`_armed` flag reset by a `Timer(widget.window, ...)`, cancelled in dispose). Timers are driven by the test clock, behaviour on device is identical. Cost if wrong: none functionally; slightly different code from the plan text.
Task 5: unblocked; DONE (commit e2f11e1; flash banner timer also made cancelable); review dispatched
Task 5: review — Approved. Two Important flagged: (a) two extra trailing pump lines in exit_on_double_back_test first case; (b) LoaderModal '. . . $text . . .' literal punctuation (plan-mandated).
Task 5: Ruling (a): keep the trailing pumps — draining timers at test end is defensive and does not weaken the assertion. Cost if wrong: two redundant lines.
Task 5: Ruling (b): the dots are decoration around a localized string, not copy; keep as planned. Cost if wrong: a translator cannot restyle the decoration.
Task 5: minor (deferred): module-level `_current` OverlayEntry in flash_banner.dart; PopScope→handleBack wiring untested.
Task 5: complete (commits a46c525..e2f11e1, review clean after rulings)
Task 6: dispatched (BASE e2f11e1, implementer sonnet)
Task 6: DONE_WITH_CONCERNS (commit f589995; test literal 'http://new' -> 'http://new.example.com' since 'new' fails the validator). Ruling: accept, the test's intent is the health-check failure path. Review dispatched.
Task 6: complete (commits e2f11e1..f589995, review clean)
Task 6: minor (deferred): new Dio per health check (fine for one-shot); connect() passes untrimmed text (normalizeServerUrl trims).
Task 7: dispatched (BASE f589995, implementer sonnet)
Task 7: DONE (commit cc0872d); note: hms_circle.svg emits flutter_svg 'unhandled element <style/>' warning — carry to Task 8 (inline styles). Review dispatched.
Task 7: complete (commits f589995..cc0872d, review clean)
Task 7: minor (deferred): logout() has no try/catch around secure-store clear; Session lacks ==/hashCode.
Task 8: dispatched (BASE cc0872d, implementer sonnet) with extra instruction: inline hms_circle.svg <style> classes
Task 8: DONE_WITH_CONCERNS (commit c5f00d0). Deviations: (1) PatientLookupController.build() made synchronous; (2) OP submit IconButton no longer gated on hasText.
Task 8: Ruling (1): accept — AsyncNotifier.build may return FutureOr; sync null avoids the initial-future overwriting a set error state. Cost if wrong: none.
Task 8: Ruling (2): reject — the check button appearing only when the field has text is original behaviour. Fix belongs in the test (pump a frame after enterText). Fix round 1 dispatched.
Task 8: fix round 1/5 done (gating restored, test pumps; commits c5f00d0..7912d03); full review dispatched over cc0872d..7912d03
Task 8: complete (commits cc0872d..7912d03, review clean)
Task 8: minor (deferred): svg test depends on initializePathOpsFromFlutterCache (env assumption); converter leaves blank lines in root svg tag; RecentSearchesController._set fire-and-forget write.
Task 9: dispatched (BASE 7912d03, implementer sonnet)
Task 9: DONE_WITH_CONCERNS (commit 62000d2; MapEntry containsAll assertion replaced with key=value string comparison). Ruling: accept — MapEntry lacks ==, the substitute asserts the same fields. Review dispatched.
Task 9: complete (commits 7912d03..62000d2, review clean)
Task 9: minor (deferred): upload returns [] on non-List data instead of BadDataFailure; MediaPickResult.empty unused.
Task 10: dispatched (BASE 62000d2, implementer sonnet)
Task 10: DONE (commit 21d35e4). Deviation: core/utils/temp_files.dart deleteFiles switched to existsSync/deleteSync because FakeAsync widget tests never complete real async dart:io. Ruling: accept — best-effort cleanup of a few small files, signature unchanged. Cost if wrong: a few ms of UI-thread file IO. Review dispatched.
Task 10: complete (commits 62000d2..21d35e4, review clean)
Task 10: minor (deferred): PermissionScreen defaults to camera label on empty list; TomogramCard controller not resynced on external description change.
Task 11: dispatched (BASE 21d35e4, implementer sonnet)
Task 11: DONE_WITH_CONCERNS (commit 1e66644). Deviations: AboutScreen uses SingleChildScrollView(Column) instead of ListView (lazy build hid off-screen text in tests); two unused test imports removed. Ruling: accept both — the About content is short static text, eager layout is fine. Review dispatched.
Task 11: complete (commits 21d35e4..1e66644, review clean)
Task 11: minor (deferred): trailing Divider after Logout row; empty if-branch in AboutScreen._open.
Task 12: dispatched (BASE 1e66644, implementer opus)
Task 12: DONE (commit 90068df; splash tool stripped screenOrientation, implementer restored it). Review dispatched.
Task 12: flutter build apk --debug succeeded (app-debug.apk, 155 MB) at 90068df
Task 12: complete (commits 1e66644..90068df, review clean)
Task 12: minor (deferred): app_gate_test containers not disposed; tab bar raw Colors.white/black literals; tabs lack Semantics(selected); values-v31 LaunchTheme has no windowBackground; future flutter_native_splash:create will strip screenOrientation again.
Task 13: dispatched (BASE 90068df, implementer haiku)
Task 13: DONE (commit e72ad3a; analyze clean, 105 tests, APK built, boundaries clean); review dispatched
Final review: dispatched (opus) over 59e941e..e72ad3a with focused package final-review-focused.diff and notes file
Task 13: complete (commits 90068df..e72ad3a, review clean)
All 13 tasks complete. Awaiting final whole-branch review.
Final review: No-with-fixes. C1 gallery Permission.photos dead end below API 33; C2 back-press exits from Home (shell route swallows PopScope); I3 HideWithKeyboard no-op inside Scaffold body; I4 Image.file cacheWidth; I5 same-URL reconnect strands user; I6 health-check api test missing; I7 over-limit picks silent; plus minors M8-M15. Ruling: one fix wave (opus) from final-fix-brief.md; FIX_BASE e72ad3a. Deferred per triage: recents privacy, Session ==, tab Semantics, _current overlay, v31 windowBackground.
Final fix wave: DONE (commits 3d0d252,241e976,677ae04,df48407; 115 tests, analyze clean, APK built). HideWithKeyboard made stateful with didChangeMetrics (beyond brief, needed). Scoped re-review dispatched over e72ad3a..df48407.
Final re-review: all 15 findings ADDRESSED, deferred list untouched, no Critical/Important breakage.
Parked: over-limit flash hidden when a pick also has a non-JPEG (showFlash replaces the previous banner). Ruling: real but cosmetic; a queued-banner change belongs to the deferred _current overlay item. Cost: user misses one hint in a rare mixed pick.
Parked: back from Settings restores the Home branch last location (could be a pushed Tomogram). Ruling: matches react-navigation firstRoute semantics closely enough; revisit if users report it.
Parked: error handlers installed after the pre-frame state loads. Ruling: those loads read local storage only; acceptable.
Parked: permissionPhotos ARB key and PermissionScreen non-camera label now unreachable. Ruling: harmless dead copy, keep for a future gallery permission.
