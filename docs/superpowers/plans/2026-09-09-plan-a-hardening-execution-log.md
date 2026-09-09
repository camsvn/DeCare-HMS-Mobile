# Plan A hardening — execution log

Ledger of the subagent-driven execution (rulings, review outcomes, parked findings). Copied from the SDD workspace on completion.

# SDD ledger — plan: E:/Projects/personal/deCare/hms/HMSFlutter/docs/superpowers/plans/2026-09-09-plan-a-hardening.md
Spec: docs/superpowers/specs/2026-09-09-hardening-and-polish-design.md (sections 2-5)
Branches: HMSServer `hardening` (new, from 28342b3); HMSFlutter `flutter-port`.

## Pre-flight scan
| Tasks | Interface | Finding |
|---|---|---|
| 1↔4 | /auth/refresh {refreshToken} -> data.accessToken; 401 JSend on auth failure | App AuthApi.refresh and interceptor assume exactly this. OK |
| 1↔2 | authentication middleware default export | Task 2 does not touch routes. OK |
| 2↔3 | Settings model attribute rename key; TomogramDetail attribute names | Task 3 must read detail attributes by their real names (verify in model). Noted in brief. |
| 3↔5 | GET /tomogram?opid= response {id,dateTime,doctorId,tomogramTypeId,details[{id,tomogramPartId,narration}]} | App TomogramSet.fromJson expects these keys. OK |
| 4↔6 | dioProvider rebuild on session change; QueuedInterceptor retry vs FormData | Brief 4 handles finalized FormData by not retrying; queue (Task 6) retries later. OK |
| 5↔6 | tomogramHistoryProvider invalidated by upload success and by queue success | Both call ref.invalidate(tomogramHistoryProvider(opid)). OK |
| 6 | appDocumentsDirProvider overridden in main.dart and tests | Defined in Task 6; no earlier consumer. OK |
Ruling: Task 7 (device verification) is controller-run, not delegated.

## Progress
Task 1: dispatched (server BASE 28342b3, implementer sonnet)
Task 1: DONE_WITH_CONCERNS (server commit ea30f32). Finding: Database.ts sets query:{raw:true} globally, so findOne returns plain objects — Tasks 2/3 must use property access (row.value, m.id, m.date, d.masterid), not .get(). Ruling: carry into briefs; do not change the global option (other code relies on it). Review dispatched.
Task 4: dispatched in parallel with server review (app BASE 1e1b068, implementer opus)
Task 1: complete (server 28342b3..ea30f32, review clean)
Task 2: dispatched (server BASE ea30f32, implementer sonnet)
Task 2: DONE (server 1816b38). Note: report assumed PrimaryDoctorID row absent; it exists (=1, same as fallback). Review dispatched.
Task 2: complete (server ea30f32..1816b38, review clean; report misstatement about PrimaryDoctorID corrected here: row exists = 1)
Task 3: dispatched (server BASE 1816b38, implementer sonnet)
Task 3: DONE (server cdedf4f). Review dispatched.
Task 3: complete (server 1816b38..cdedf4f, review clean). Server side of Plan A done on branch hardening (ea30f32, 1816b38, cdedf4f).
Task 4: DONE_WITH_CONCERNS (app b58163d). Deviations: plain Interceptor + single-flight refresh instead of QueuedInterceptor (proved deadlock when /auth/refresh 401s); showDsBannerIn(OverlayState). Ruling: accept both. Review dispatched.
Task 4: review Needs fixes — onAuthFailure fires twice on retry-401 (line 76 + 101), listener guard racy because logout nulls state after await. Fix round 1/5 dispatched (FIX_BASE b58163d).
Task 4: fix round 1 done (2f798de, 165 tests). Scoped re-review dispatched.
Task 4: complete (app 1e1b068..2f798de, re-review clean). Parked for Task 6: a 401 on a multipart upload refreshes but does not retry (FormData finalized); the queue retries later with the fresh token.
Task 5: dispatched (BASE 2f798de).
Task 5: DONE (7ac3bed, 178 tests). Review dispatched.
Task 5: review Approved with Important plan-mandated finding (expanded history rows uncapped in fixed Column -> RenderFlex overflow with ~20 sets). Ruling: fix now, cap expanded rows to newest 5 + minors 2,3 — cheap, prevents a visible layout bug — cost if wrong: one small round. Fix round 1/5 dispatched (FIX_BASE 7ac3bed). Parked minors 4-7 for final review.
Task 5: fix round 1 done (7e26bb1, 182 tests). Scoped re-review dispatched.
Task 5: complete (2f798de..7e26bb1, re-review clean). Parked for final review: history ordering trusts server newest-first (no client sort); error branch discards failure type; module-level DateFormat snapshot.
Task 6: dispatched (BASE 7e26bb1).
Task 7 (partial, controller): server auth verified — GET /api/opregister?opid=1 without token -> 401 {"status":"fail","data":"Authentication required"}; healthcheck 200; emulator-5554 attached.
Task 6: DONE_WITH_CONCERNS (6007836 + 14732aa, 214 tests, debug apk builds). Ruling: accept connectivity_plus ^6.1.5 instead of ^7.3.1 — 7.x gradle reads flutter.compileSdkVersion which Flutter 3.19 does not expose (BUILD FAILED verified); 6.1.5 has the same Dart API — cost if wrong: a version bump when the SDK is upgraded. Review dispatched.
Task 7 prep: history endpoint live — OP 581 has 3 sets (masters 6,7,8), OP 580 has 2 (5,9); Tomogram folder E:/Projects/personal/deCare/hms/Tomogram newest 9_9.JPEG.
Task 6: review Needs fixes — Important: (1) reconnect trigger never fires if app launched offline (_lastOnline=true seed, plan-mandated), (2) pending sheet Column does not scroll, Retry unreachable past ~5 entries. Fix round 1/5 dispatched (FIX_BASE 14732aa) incl. minors 3,4,6,7,9. Parked minors 5 (lastError class name in copy, plan-mandated) and 8 (mutators assume loaded state) for final review.
Task 6: fix round 1 done (74599fb, 222 tests). Ruling: accept ConstrainedBox(maxHeight)+SingleChildScrollView instead of Flexible for the sheet — Flexible asserts under showDsSheet unbounded height (evidence in report); cost if wrong: measured chrome constant 150 drifts, guarded by 8-entry test. Scoped re-review dispatched.
Task 7: history verified on emulator — OP 581 card "Already uploaded / 6 sets / Last 9 Sep 18:51" (API returns 6, 13:21Z shown in IST), expands to 5 rows + "and 1 more"; installed debug APK @74599fb.
Task 6: complete (7e26bb1..74599fb, re-review clean). Parked for final review: sheet does not auto-close when last entry removed; 401 class name leaks as lastError copy; mutators assume loaded state.
Task 7: complete. Offline: wifi+data disabled, camera photo + description, Upload -> "Saved offline" banner + pop; dashboard "1 pending" chip + sheet (SAJU, 1, Retry now); network re-enabled -> uploaded within ~12s, chip gone, Tomogram/10_10.JPEG 1440x1920 28.6KB, history shows narration "offline queue test". Limitation: emulator camera is natively 1440x1920 and MediaStore would not index a pushed 4000px file from adb shell, so the >2000px downscale is evidenced by the picker-arg unit tests only. Observation (out of plan scope): dashboard connection dot stayed "Connected" while offline (health check cached, not re-run on return).
Final whole-branch review dispatched: app 1e1b068..74599fb, server 28342b3..cdedf4f.
Final review (app 1e1b068..74599fb, server 28342b3..cdedf4f): With fixes. Important: (1) transient refresh failure -> false sign-out; (2) queue runs signed-out / counts 401 attempts / no post-login trigger; (3) server upload settings lookup outside try/catch. Rollout: RN client breaks on deploy (spec acknowledged); plan doc carries local credentials (aa9a6f1) -> scrub. Minors parked unless cheap. ONE fix dispatch (FIX_BASE app 74599fb, server cdedf4f).
Final fix round DONE_WITH_CONCERNS: app 796b713, 27e4098, 805d97f (232 tests); server eddef2d (tsc clean). Dev server confirmed up afterwards (healthcheck 200). Scoped re-review dispatched.
Final re-review clean. Residual parked for the user: server tomogram.ts transaction().then chain (pre-existing, lines ~112-134) has no terminal .catch — same class as the fixed bug; rollout notes from the final review (RN client breaks on deploy; refresh tokens non-revocable 5d; seed SQL for fresh DBs; no idempotency key on re-sent uploads). PLAN A COMPLETE: app 1e1b068..805d97f (232 tests), server 28342b3..eddef2d.
