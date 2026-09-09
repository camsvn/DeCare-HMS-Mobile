# SDD ledger — plan: E:/Projects/personal/deCare/hms/HMSFlutter/docs/superpowers/plans/2026-09-09-ui-redesign.md
Spec: docs/superpowers/specs/2026-09-09-ui-redesign-design.md
Branch: flutter-port (continuing on the same branch; port is complete and smoke-tested).

## Pre-flight scan
| Tasks | Interface | Finding |
|---|---|---|
| 1↔2,3 | DsColors/DsType/DsSpace/DsRadius/DsMotion, context.ds/dsType | Kit widgets use only names defined in Task 1. OK |
| 1↔4 | RoutePaths.dashboard/tomogramEntry/tomogramPattern=:opid | Task 4 nests tomogram routes under the entry route; until Task 4, test/app may fail on paths (Task 1 runs tests excluding test/app). Ruling: accepted transient red in test/app between Tasks 1 and 4; Task 4 must restore green. |
| 2,3↔5,6,7 | DsAppBar, DsBottomBar, DsListRow, DsTextField, DsButton, DsFab, showDsSheet, showDsBanner, showDsDialog, ModuleCard, DsEmptyState, DsSkeleton, DsProgressBar, DsChip | Screen tasks use these signatures verbatim. OK |
| 3↔4 | FadeThroughPage used in barrels | OK |
| 4↔6 | PatientLookupScreen rename, patientLookupRoute(children), tomogramDetailRoute/permissionRoute | Task 6 restyles the renamed screen. OK |
| 5-7 | Less code-complete than earlier tasks (behaviour lists + sketches) | Ruling: acceptable for restyle work because the kit and spec fix the design; assign sonnet/opus and review against the spec sections. Cost if wrong: an extra fix round. |
| 8 | Deletes old widgets after all screens migrate | Depends on 5-7 done. OK |

## Progress
Task 1: dispatched (BASE 61fa729, implementer sonnet)
Task 1: DONE (commit 0ca9f87; appOverlayStyle const->final). Review dispatched.
Task 1: complete (commits 61fa729..0ca9f87, review clean)
Task 2: dispatched (BASE 0ca9f87, implementer sonnet)
Task 2: DONE_WITH_CONCERNS (commit 9c383f5; MergeSemantics wrap, rendering import in test, unused import removed). Ruling: accept all three. Review dispatched.
Task 2: complete (commits 0ca9f87..9c383f5, review clean)
Task 2: minor (deferred): bottom bar test does not assert the inactive tab lacks isSelected.
Task 3: dispatched (BASE 9c383f5, implementer sonnet)
Task 3: DONE (commit f09f23e). Review dispatched.
Task 3: review Approved with one Important (plan-mandated): banner queue _showing can stick if the overlay unmounts mid-banner. Ruling: fix now (release the queue from dispose too) + regression test. Fix round 1/5 dispatched (FIX_BASE f09f23e).
Task 3: fix round 1/5 done (commit 6e36119); scoped re-review dispatched
Task 3: complete (commits 9c383f5..6e36119, review clean after fix round 1)
Task 4: dispatched (BASE 6e36119, implementer opus)
Task 4: DONE_WITH_CONCERNS (commit aa051c5). Ruling: module icon tiles are the dashboard designated gradient element (spec wording to amend in Task 8); tomogramRecentBadge key unused (prune in Task 8); ConnectionStatus refresh unused (deferred). Review dispatched.
Task 4: review Needs fixes — Critical: :opid declared before permission so /app/tomogram/permission hits the detail route. Minors: stale doc comment, _Staggered bypasses DsMotion.of, optimistic Connected before first check, indexOf in loop. Fix round 1/5 dispatched (FIX_BASE aa051c5).
Task 4: fix round 1/5 done (commit fba621a; DsStatusDot gained optional color; tests use tallSurface because TomogramEmptyState overflows at 800x600 — carry to Task 6 restyle). Scoped re-review dispatched.
Task 4: complete (commits 6e36119..fba621a, review clean after fix round 1)
Task 4: carry-forward: TomogramEmptyState overflows at 800x600 inside the shell (fix in Task 6 restyle); gradient wording (Task 8 spec amend); tomogramRecentBadge unused (Task 8 prune).
Task 5: dispatched (BASE fba621a, implementer opus)
Task 5: DONE_WITH_CONCERNS (commit 98304ba; app_gate_test string updated; configure test 3 still uses buildAppTheme — Task 8 to switch). Review dispatched.
Task 5: complete (commits fba621a..98304ba, review clean)
Task 5: minor (deferred to Task 8): configure test 3 uses buildAppTheme; configureUrlTitle + installation_url.png unused.
Task 6: dispatched (BASE 98304ba, implementer opus)
Task 6: DONE_WITH_CONCERNS (commit 37e4628). Rulings: accept _pop() instead of maybePop (prevents PopScope livelock); accept tomogramUpload key; keep "Grant Permission" copy (spec prose said Open settings — amend spec in Task 8); gradient rule wording to amend in Task 8 (primary action + one accent element). tallSurface removed. Review dispatched.
Task 6: review Approved with one Important: no in-flight guard on lookup (double push). Minors: FAB overlaps last card (list bottom padding 32), uploading state untested, trash icon without scrim. Fix round 1/5 dispatched (FIX_BASE 37e4628) for the Important + FAB padding + uploading-state test.
Task 6: fix round 1/5 done (commit b7b3b36). Scoped re-review dispatched.
Task 6: complete (commits 98304ba..b7b3b36, review clean after fix round 1)
Task 6: minor (deferred): DsFab has no visual disabled state.
Task 7: dispatched (BASE b7b3b36, implementer sonnet)
Task 7: DONE (commit 28e5fe9; About uses SingleChildScrollView; gate test copy updated to Sign out). Review dispatched.
Task 7: review Needs fixes — username row not mono (spec 5). Fix round 1/5 dispatched (FIX_BASE 28e5fe9): username via trailingValue with "Signed in as" title; normalize _logout notifier capture.
Task 7: fix round 1/5 done (commit 5bcd018). Scoped re-review dispatched.
Task 7: complete (commits b7b3b36..5bcd018, review clean after fix round 1)
Task 8: dispatched (BASE 5bcd018, implementer sonnet) with carry-forwards: configure test 3 -> buildDsTheme; spec amendments (gradient rule wording, Grant Permission copy, Permission.photos note already done); prune tomogramRecentBadge/configureUrlTitle/etc.
Task 8: DONE (commit 8bed51b; 140 tests, APK built). Review dispatched; emulator walkthrough started.
Task 8: complete (commits 5bcd018..8bed51b, review clean)
All 8 tasks complete. Emulator walkthrough in progress; final whole-branch review over 61fa729..8bed51b pending.
Walkthrough findings (controller): (1) Dialog/sheet surfaces show M3 lavender surface tint — set surfaceTintColor transparent; (2) tomogramEmptyBody copy says "+" at top-right, FAB is bottom-right; (3) ExitOnDoubleBack intercepts back even when the route can pop (Configure pushed from Login) — PopScope canPop should be Navigator.canPop(context); (4) first cold start after fresh debug install 1m41s (ART verifying Tink) — informational. To join the final fix wave.
Final review: With fixes. C1 M3 surfaceTint on dialog/sheet; C2 tomogramEmptyBody copy; I3 splash colour; I4 shell route FadeThroughPage; I5 kit tests gap (partial now, rest deferred); I6 a11y labels + FAB disabled; I7 ghost contrast (deferred); I8 text scaling (deferred); I9 banner queue reset; I10 shimmer reduced-motion/pumpAndSettle; minors. Ruling: one fix wave from final-fix-brief.md incl. walkthrough W3 (ExitOnDoubleBack canPop) and cheap dead-code/docs items; deferred list recorded in the brief. FIX_BASE 8bed51b.
Final fix wave: DONE_WITH_CONCERNS (10 commits 81cd473..f579fb4; 149 tests; APK built). Deviations: bottomSheetTheme for tint (no surfaceTintColor param on 3.19); FadeThroughPage reads child from settings (pageBuilder on shell froze tab switching otherwise); MergeSemantics scoped to row tap target; commonHeader now dead. Scoped re-review dispatched.
Post-fix emulator check: dialog and sheet surfaces white; tomogram empty-state copy corrected; back from pushed Configure pops to Login; sign-in and dashboard OK.
Final re-review: all findings addressed, no Critical/Important breakage.
Parked (follow-ups, with rulings): DsFab label read twice by TalkBack (add excludeFromSemantics on Tooltip) — cosmetic; ModuleCard MergeSemantics would swallow an interactive badge — no badge is interactive today; plan line 2669 still names commonHeader for permission — doc nit; DsListRow merged node lacks isButton — follow-up; exit_on_double_back_test relies on earlier drains — fine today; loading DsButton spinner blocks pumpAndSettle — pre-existing. Deferred from final review: text-scaler clamping, accentSolid text-contrast token, remaining kit tests, Inter subsetting, AppModule.badge signature, DsSkeleton rows/margin, DsRadius.sheet rename, DsChip font size, HideWithKeyboard duration, folding patient_lookup into tomogram.
All tasks complete; final review clean after one fix wave.
