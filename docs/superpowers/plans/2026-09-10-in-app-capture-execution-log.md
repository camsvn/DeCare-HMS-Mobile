# In-app capture — execution log

Ledger of the subagent-driven execution (pre-flight scan, rulings, review outcomes, device checks, parked findings). Copied from the SDD workspace on completion.

# SDD ledger — plan: docs/superpowers/plans/2026-09-10-in-app-capture.md
Spec: docs/superpowers/specs/2026-09-10-in-app-capture-design.md. Branch flutter-port.

Pre-flight scan (2026-09-10):
| T1 -> T2 | CameraService/CaptureController/captureControllerProvider names | consumed verbatim by the screen | consistent |
| T2 <-> T3 | RoutePaths.capture(opid) produced by T2, pushed by T3 _pushCapture | consistent |
| T2 | rootNavigatorKey location unknown at planning time | plan carries the conditional move to core/navigation | ruling below once checked |
| T3 | pick(MediaSource) -> pickFromGallery(); deniedPermissions unchanged | screen + tests updated in the same task | consistent |
| T1 | FakeCameraService gate Completer used by test 5 | brief names it | consistent |

Ruling: rootNavigatorKey is declared in lib/app/router.dart -> Task 2 moves it to lib/core/navigation/navigator_keys.dart and router.dart re-exports it (features may not import app/). Cost if wrong: one import churn.
Task 1: dispatched (BASE ad49c68).
Task 1: DONE_WITH_CONCERNS (8aa7d20, 303 tests). Ruling: toggleTorch/focusAt must be no-ops in the controller when status != ready (defensive, cheap); stop() resetting status/torch accepted. Review dispatched.
Task 1: review Needs fixes — (1) ready-guard ruling not applied; (2) _camera via ref.read of an autoDispose provider can dispose the real service mid-session; (3) failed initialize() leaks the native controller. Fix round 1/5 dispatched (FIX_BASE 8aa7d20) incl. minors 1,2,3,5.
Task 1: fix round 1 done (9eecf11, 307 tests; RED showed created==3 services under ref.read). Scoped re-review dispatched.
Task 1: complete (ad49c68..9eecf11, re-review clean). Parked: dispose() throwing inside the failed-initialize catch would mask the original error (no behavioural effect).
Task 2: dispatched (BASE 9eecf11).
Task 2: DONE_WITH_CONCERNS (c3ad749, 316 tests). Rulings: start() in post-frame callback accepted (Riverpod forbids provider writes during build); lifecycle test via SystemChannels.lifecycle accepted (handleAppLifecycleStateChanged is @protected); signedInContainer gains overrides param accepted; failure panel on ds.canvas accepted. Spec gap: no danger banner on failed capture -> fix round with new key captureFailed ("Could not take the photo. Try again."), shown when the shutter was enabled and shoot() returned false. Review dispatched.
Task 2: review Approved with Important: tap-to-focus ignores BoxFit.cover crop (brief formula was wrong, plan-mandated) and has no test. Fix round 1/5 dispatched (FIX_BASE c3ad749) incl. captureFailed banner (spec gap), flash timing, overlay extraction, system-back test, thumbnail semantics. Parked: pause/resume race can land on failure panel (Try again recovers); bottom row flex on 320dp; haptic suppressed under reduced motion (brief-mandated).
Task 2: fix round 1 done (02b6b91, 324 tests). Scoped re-review dispatched. Task 3: dispatched in parallel (BASE 02b6b91) — touches tomogram_screen/picker/card, disjoint from the Task 2 fix files.
Task 2: complete (9eecf11..02b6b91, re-review clean). Carry to Task 4: verify on device that previewAspectRatio describes the same frame setFocusPoint addresses.
Task 3: DONE (d232342, 329 tests). Review dispatched. Task 4 prep: building debug APK at d232342.
Task 3: complete (02b6b91..d232342, review Approved, no Important). Parked minors: apply-all tests read controller text not painted text; predicate uses build-time source; empty description can be applied (spec-literal); captured paths skip isJpegFile; no spacing token above Apply-to-all button. Task 4: dev server on 4041 found down at start of device checks; started it (npm run dev) for verification.
Task 4 (device, debug d232342): capture screen on root navigator (no tab bar), preview live, torch toggle ok (emulator ignores), 3 shots -> 3 thumbnails "3 photos"; thumbnail tap -> Remove dialog -> "2 photos"; home+resume kept shots (torch reset, preview back); Done -> 2 drafts; Apply to all copied text; Upload -> 17_18/17_19.JPEG 1280x720 (emulator camera max 720p); history now 8 sets; discard: cache/CAP*.jpg present while held, 0 after Discard. Release build (R8) 24.5MB: signed in, opened capture, took a shot, no FATAL/ClassNotFound in logcat. Final whole-branch review dispatched (ad49c68..d232342).
Task 4 correction: first release pass stopped at the camera permission screen (fresh install); after pm grant CAMERA the release build opened the capture screen and took 2 shots with no FATAL/ClassNotFound. Task 4: complete. Emulator restored to debug d232342, camera granted, configured and signed in.
Final review (ad49c68..d232342): With fixes. Important: (1) PluginCameraService.start() not cancellable -> camera leak on fast back during cold start; (2) previewAspectRatio is sensor (landscape) ratio while CameraPreview displays 1/ratio in portrait -> stretched preview + wrong focus frame; (3) uploads now carry EXIF orientation instead of baked rotation -> check viewer. ONE fix dispatch (FIX_BASE d232342) for 1,2 + minors 4,5,6; item 3 decided after EXIF check.
Final fix rounds done: d3e063f (cancellable start, displayed ratio), 4d2cad1 (orphan delete), 0ae79d0 (docs), cba4a0f (orientation bake, image ^4.1.7; ruling: bake upright pixels because viewers unknown and old path uploaded upright). 343 tests. Scoped re-review dispatched; device re-check of preview shape + baked orientation in progress.
Device re-check (debug cba4a0f): preview shape correct after displayed-ratio fix (checkerboard squares square, upright), shot -> draft, upload 18_20.JPEG 720x1280 with no EXIF orientation tag (bake verified). Re-review: findings 1-6 addressed; NEW Important: _close/_confirmRemove not gated by _finishing -> pending _done() could pop the discard dialog with List<String> (TypeError, shots lost). Fix round 3 dispatched. Parked: unbounded parallel bakes (serialize, minor); lifecycle stop/start race pre-existing; takePicture _controller! surfaces as captureFailed.
Fix round 3 done (bf0fa8d, 344 tests). Scoped re-review dispatched. Controller verification on bf0fa8d and debug reinstall running.
Round-3 re-review clean. Controller verification on bf0fa8d: analyze clean, 344 tests. IN-APP CAPTURE PLAN COMPLETE: ad49c68..bf0fa8d. Parked for later: no timeout on Done flush (hang keeps the screen frozen); lifecycle stop/start race on fast pause/resume (Try again recovers); takePicture _controller! surfaces as captureFailed; doubled torch guard; .tmp sweep on takeAll paths; physical-device pass for focus/torch/1080p before clinic rollout.
