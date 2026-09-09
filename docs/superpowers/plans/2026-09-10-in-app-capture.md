# In-app photo capture — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the OS-camera round trip with an in-app burst-capture screen that hands its shots to the existing draft list, and add "Apply to all" for descriptions.

**Architecture:** A `CameraService` interface wraps `package:camera` so widgets and tests never touch the plugin; a `CaptureController` (Riverpod autoDispose Notifier) holds the session (shots, busy, torch, status); `CaptureScreen` renders it on the root navigator under `/app/tomogram/:opid/capture` and pops with the shot paths, which `TomogramScreen` adds as drafts. All inside `lib/features/tomogram/`.

**Tech Stack:** Flutter 3.19 / Dart 3.3, flutter_riverpod 2.6, go_router 14, `camera ^0.11.0+2` (new), mocktail.

**Spec:** `docs/superpowers/specs/2026-09-10-in-app-capture-design.md`

## Global Constraints

- Flutter 3.19 / Dart 3.3; never `flutter upgrade`. The only new dependency is `camera: ^0.11.0+2` (resolves to `camera_android_camerax 0.6.5+2`).
- `core` never imports `features`; cross-feature imports via barrels; all UI strings via `context.l10n` (ARB `lib/core/l10n/app_en.arb`, then `flutter gen-l10n`); widgets use design tokens only (colours, spacing, radii, `DsMotion` durations).
- Captured files are app-private (plugin cache directory); nothing is written to the device gallery.
- Camera capture preset is `ResolutionPreset.veryHigh` (1080p) so the long edge stays ≤ 1920 px; no re-encoding.
- `flutter analyze` clean and `flutter test` green before every commit. Work in `E:\Projects\personal\deCare\hms\HMSFlutter` on branch `flutter-port`. Commit with explicit paths.
- Optional plugin calls (`lockCaptureOrientation`, `setFlashMode`, `setFocusPoint`, `setExposurePoint`) must be wrapped so an unsupported device or the emulator never breaks the screen.
- Portrait only. Back camera only.

---

### Task 1: Camera service, fake, and capture session controller

**Files:**
- Modify: `pubspec.yaml` (add `camera: ^0.11.0+2`), `lib/features/tomogram/tomogram.dart` (exports)
- Create: `lib/features/tomogram/application/camera_service.dart`, `lib/features/tomogram/application/capture_controller.dart`, `test/helpers/fake_camera_service.dart`
- Test: `test/features/tomogram/capture_controller_test.dart`

**Interfaces (produced):**
```dart
abstract class CameraService {
  bool get isReady;
  double get previewAspectRatio;           // width/height; 1 until ready
  Future<void> start();
  Future<void> stop();
  Widget preview();                        // SizedBox.shrink() until ready
  Future<String> takePicture();            // JPEG path
  Future<void> setTorch(bool on);
  Future<void> focusAt(Offset normalized); // 0..1
}
class PluginCameraService implements CameraService { ... }   // package:camera
final cameraServiceProvider = Provider.autoDispose<CameraService>(...); // stop() on dispose

const int captureLimit = 20;
enum CaptureStatus { starting, ready, failed }
class CaptureState { status, shots (List<String>), busy, torch; atLimit; canShoot; copyWith }
class CaptureController extends AutoDisposeNotifier<CaptureState> {
  Future<void> start(); Future<void> stop(); Future<bool> shoot(); Future<void> remove(String path);
  Future<void> toggleTorch(); Future<void> focusAt(Offset n); Future<void> discardAll(); List<String> takeAll();
}
final captureControllerProvider = NotifierProvider.autoDispose<CaptureController, CaptureState>(CaptureController.new);
```
`FakeCameraService({Directory dir, bool failStart = false, bool failCapture = false})`: `start()` throws `StateError('no camera')` when `failStart`; `takePicture()` writes `<dir>/shot_<n>.jpg` with the bytes `[0xFF,0xD8,0xFF,0xD9]` and returns the path, or throws when `failCapture`; records `torchCalls` (List<bool>) and `focusCalls` (List<Offset>); `preview()` is `ColoredBox(key: Key('fake-preview'), color: Colors.black)`; `startCount`/`stopCount` counters.

`PluginCameraService` sketch:
```dart
class PluginCameraService implements CameraService {
  CameraController? _controller;
  @override bool get isReady => _controller?.value.isInitialized ?? false;
  @override double get previewAspectRatio => isReady ? _controller!.value.aspectRatio : 1;
  @override Future<void> start() async {
    if (isReady) return;
    final cameras = await availableCameras();
    final back = cameras.where((c) => c.lensDirection == CameraLensDirection.back).firstOrNull ?? cameras.firstOrNull;
    if (back == null) throw StateError('No camera');
    final c = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    await c.initialize();
    await _tryOptional(() => c.lockCaptureOrientation(DeviceOrientation.portraitUp));
    _controller = c;
  }
  @override Future<void> stop() async { final c = _controller; _controller = null; await c?.dispose(); }
  @override Widget preview() => isReady ? CameraPreview(_controller!) : const SizedBox.shrink();
  @override Future<String> takePicture() async => (await _controller!.takePicture()).path;
  @override Future<void> setTorch(bool on) => _tryOptional(() => _controller!.setFlashMode(on ? FlashMode.torch : FlashMode.off));
  @override Future<void> focusAt(Offset n) async {
    await _tryOptional(() => _controller!.setFocusPoint(n));
    await _tryOptional(() => _controller!.setExposurePoint(n));
  }
  Future<void> _tryOptional(Future<void> Function() call) async { try { await call(); } on CameraException catch (_) {} on UnimplementedError catch (_) {} on UnsupportedError catch (_) {} }
}
```
Controller rules: `start()` sets `starting`, awaits `camera.start()`, then `ready`; any throw → `failed` (no rethrow). `shoot()` returns false without side effects when `!canShoot`; otherwise sets `busy`, awaits `takePicture()`, appends the path, clears `busy`; on throw clears `busy` and returns false. `remove(path)` removes from the list and deletes the file (`deleteFiles` from the existing files helper used by `TomogramController`). `discardAll()` deletes all files and empties the list. `takeAll()` returns a copy and empties the list without deleting. `toggleTorch()` flips `torch` and forwards `setTorch`. `ref.onDispose` deletes whatever is still in `shots`.

- [ ] **Step 1: Failing tests** (`capture_controller_test.dart`, `ProviderContainer` with `cameraServiceProvider.overrideWithValue(fake)`, temp dir created in `setUp`, deleted in `tearDown`, `container.listen(captureControllerProvider, (_, __) {})` to keep it alive):
  1. `start` → `status == ready`, `fake.startCount == 1`.
  2. `start` with `failStart` → `failed`; flipping `fake.failStart = false` and calling `start()` again → `ready`.
  3. `shoot` twice → two paths in order, both files exist, `busy` false after.
  4. `shoot` before `start` → false, no file.
  5. `shoot` while busy: gate `takePicture` with a `Completer` in the fake (add `Completer<void>? gate` honoured before writing) → second call returns false, only one file after completion.
  6. at the cap: pre-fill 20 shots via `shoot` in a loop → `atLimit`, next `shoot` false.
  7. `failCapture` → false, list unchanged, `busy` false.
  8. `remove` deletes that file only.
  9. `discardAll` deletes every file and empties the list.
  10. `takeAll` returns the paths in order, list empty afterwards, files still exist.
  11. dispose with leftover shots deletes the files (`container.dispose()` then check).
  12. `toggleTorch` → `torch` true and `fake.torchCalls == [true]`; again → `[true, false]`.
- [ ] **Step 2: Implement** per the interfaces. `flutter pub add camera:^0.11.0+2` first (commit the pubspec/lock change as part of this task).
- [ ] **Step 3: Verify and commit** — `flutter analyze && flutter test`; `feat(tomogram): camera service and capture session controller`.

---

### Task 2: Capture screen and route

**Files:**
- Create: `lib/features/tomogram/presentation/capture_screen.dart`, `lib/features/tomogram/presentation/widgets/shutter_button.dart`, `lib/features/tomogram/presentation/widgets/shot_strip.dart`
- Modify: `lib/core/navigation/route_paths.dart` (`capturePattern = 'capture'`, `capture(int opid)`), `lib/features/tomogram/tomogram.dart` (`captureRoute` as a child of `tomogramDetailRoute`, exports), `lib/core/l10n/app_en.arb` (keys `captureDone, captureShutter, captureCount, captureTorchOn, captureTorchOff, captureRemoveTitle, captureRemoveBody, captureRemove, captureErrorTitle, captureErrorBody, captureRetry, captureLimit` with the spec's copy), and — only if `rootNavigatorKey` lives under `lib/app/` — create `lib/core/navigation/navigator_keys.dart` holding it and make the old location re-export it.
- Test: `test/features/tomogram/capture_screen_test.dart`, extend `test/app/router_test.dart` (or the existing route test file) with "`/app/tomogram/581/capture` resolves to `CaptureScreen` on the root navigator".

**Interfaces:**
- `CaptureScreen({Key? key})` — reads `captureControllerProvider`; pops with `List<String>` on Done, `null` on discard/close.
- `ShutterButton({required VoidCallback? onPressed, required String tooltip})` — 72 dp circle: outer ring `ds.textOnShell` 3 dp, inner disc with `ds.accentGradient`; when `onPressed == null` the disc uses `ds.textOnShellMuted`. Wrapped in `Semantics(button: true, enabled: onPressed != null, label: tooltip)` and a `Tooltip`.
- `ShotStrip({required List<String> paths, required ValueChanged<String> onTap})` — horizontal `ListView.separated`, 56 dp square thumbnails (`ClipRRect(DsRadius.smallAll)`, `Image.file(cacheWidth: 200)`), `SizedBox.shrink()` when empty; scrolls to the end after a new item (`ScrollController.animateTo` in a post-frame callback, duration `DsMotion.of(context, DsMotion.base)`).
- Route: `final GoRoute captureRoute = GoRoute(path: RoutePaths.capturePattern, parentNavigatorKey: rootNavigatorKey, pageBuilder: (c, s) => FadeThroughPage(key: s.pageKey, child: const CaptureScreen()));` added as `routes: [captureRoute]` on `tomogramDetailRoute`.

Screen behaviour per spec §5.3 (lifecycle observer; preview covering the area via `ClipRect(FittedBox(fit: BoxFit.cover, child: SizedBox(width: previewAspectRatio*1000, height: 1000, child: preview)))`, where `previewAspectRatio` is the *displayed* ratio (`1 / sensorRatio` in portrait) and not the sensor's own; tap → `focusAt`, mapped back through the cover crop into the frame's 0..1 coordinates and a 64 dp ring (`Container` with `ds.textOnShell` border, `DsRadius.full`) fading over `DsMotion.base`; flash overlay + `HapticFeedback.mediumImpact` on a successful shot unless `MediaQuery.disableAnimationsOf(context)`; `PopScope(canPop: shots.isEmpty)` with the discard dialog; cap banner via `showDsBanner(context, l10n.captureLimit(captureLimit), kind: warning)` shown once when `atLimit` becomes true; failed status → `DsEmptyState` with `DsButton.secondary(label: l10n.captureRetry, onPressed: start)`).

- [ ] **Step 1: Failing tests** (`capture_screen_test.dart`; pump `CaptureScreen` inside a `MaterialApp.router`-free harness: `pumpApp` with a `Navigator` so `pop` results can be captured — push the screen with `Navigator.push<List<String>>` from a button in a host widget and store the result):
  1. Shutter tap → one thumbnail (`find.byType(Image)` inside `ShotStrip`) and "1 photo".
  2. Done disabled at zero (`DsButton` `onPressed == null`); after two shots Done pops with the two paths in order.
  3. Tap a thumbnail → dialog "Remove this photo?" → Remove → thumbnail gone, file deleted.
  4. Close with shots → "Discard photos?" → Discard → files deleted, popped with `null`.
  5. Twenty shots → shutter disabled, banner "Up to 20 photos per session" visible once.
  6. `failStart` → "Camera unavailable" and "Try again"; set `failStart = false`, tap → preview key visible.
  7. Torch toggle: tooltip flips from "Turn torch on" to "Turn torch off"; `fake.torchCalls == [true]`.
  8. Lifecycle: `tester.binding.handleAppLifecycleStateChanged(paused)` → `fake.stopCount == 1`; `resumed` → `startCount == 2`, shots preserved.
  9. Route test: `GoRouter` from the app router with a signed-in container (`signedInContainer` helper) `go('/app/tomogram/581/capture')` → `CaptureScreen` found and `DsBottomBar` not found (root navigator).
- [ ] **Step 2: Implement**; `flutter gen-l10n`.
- [ ] **Step 3: Verify and commit** — `flutter analyze && flutter test`; `feat(tomogram): in-app burst capture screen`.

---

### Task 3: Wire the tomogram screen, retire the picker camera path, "Apply to all"

**Files:**
- Modify: `lib/features/tomogram/presentation/tomogram_screen.dart` (`onCapture` injection, camera branch → capture route, apply-to-all dialog), `lib/features/tomogram/application/media_picker_service.dart` (`pick(MediaSource)` → `pickFromGallery()`; remove the `ImageSource.camera` call), `lib/features/tomogram/application/tomogram_controller.dart` (`applyDescriptionToAll(String id)`), `lib/features/tomogram/presentation/widgets/tomogram_card.dart` (`onApplyToAll`), `lib/core/l10n/app_en.arb` (`tomogramApplyToAll`, `tomogramApplyAllTitle`, `tomogramApplyAllBody`), `README.md` (tomogram feature paragraph: in-app capture, gallery pick, apply to all)
- Test: extend `test/features/tomogram/tomogram_screen_test.dart`, `tomogram_controller_test.dart`, `media_picker_service_test.dart`

**Interfaces:**
- `TomogramScreen({..., this.onCapture})` with `final Future<List<String>?> Function(BuildContext context)? onCapture;` default `_pushCapture = (ctx) => ctx.push<List<String>>(RoutePaths.capture(_opid))`.
- `MediaPickerService.pickFromGallery() → Future<MediaPickResult>`; `deniedPermissions(MediaSource)` unchanged.
- `TomogramController.applyDescriptionToAll(String id)`.
- `TomogramCard({..., this.onApplyToAll})` renders `Align(alignment: Alignment.centerRight, child: DsButton.ghost(label: l10n.tomogramApplyToAll, onPressed: onApplyToAll))` under the field when non-null.
- Screen: `Future<void> _applyToAll(TomogramDraft source)`: `others = drafts.where((d) => d.id != source.id && d.description.trim().isNotEmpty && d.description != source.description)`; if `others.isNotEmpty` → `showDsDialog(title: tomogramApplyAllTitle, body: tomogramApplyAllBody, confirmLabel: tomogramApplyToAll)`; on confirm (or no others) → `applyDescriptionToAll(source.id)`.

- [ ] **Step 1: Failing tests**
  - Screen: "Take Photo" (camera permission granted) → `onCapture` invoked; returning two temp paths → two `TomogramCard`s; returning `null` → still the empty state; permission denied → `onPermissionsDenied` called and `onCapture` not.
  - Screen: one draft → no "Apply to all"; two drafts → each card shows it; typing "left arm" in the first and tapping its "Apply to all" copies to the second (its `DsTextField` shows "left arm"); when the second already has "other", tapping shows "Apply to all photos?" and Cancel leaves it, Apply replaces it.
  - Controller: `applyDescriptionToAll` copies the source text to all drafts and is a no-op for an unknown id.
  - Picker: `pickFromGallery` calls `pickMultiImage(maxWidth: 2000, maxHeight: 2000, imageQuality: 85)`; `verifyNever(() => picker.pickImage(...))`; the old camera tests are removed.
- [ ] **Step 2: Implement**; `flutter gen-l10n`.
- [ ] **Step 3: Verify and commit** — `flutter analyze && flutter test`; `feat(tomogram): capture from the add sheet and apply one description to all photos`.

---

### Task 4: Device verification (controller-run)

Debug build on the emulator (virtual scene camera), signed in, server on 4041:
1. Open a patient → plus → Take Photo: the capture screen covers the tab bar; preview renders; the torch toggle does not crash (emulator may ignore it).
2. Three shutter taps → three thumbnails, "3 photos"; tap the second thumbnail → Remove → "2 photos".
3. Home button, then reopen the app: shots still there, preview back.
4. Done → two draft cards. Type a description on the first, Apply to all → second shows it. Upload → success; two new files in `E:\Projects\personal\deCare\hms\Tomogram`, each ≤ 1920 px on the long edge (`identify`).
5. Back with shots on the capture screen → "Discard photos?" → files gone from the cache dir.
6. `flutter build apk --release` succeeds; install (uninstall debug first), open the capture screen once, then reinstall the debug build.
Record results in the ledger; anything failing goes to a fix round.
