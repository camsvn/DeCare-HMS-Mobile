# In-app photo capture — design

Date: 2026-09-10. Status: approved in conversation (option 1 of the two proposed).

## 1. Problem

Capturing a photo for a tomogram set today means: plus button → sheet → "Take Photo" → the OS
camera app launches → shutter → confirm → back to the draft list. Four taps and a camera-app
launch per photo. Clinics capture several angles per patient, so the round trips dominate the
visit. The gallery path is fine (multi-pick into drafts) and is unchanged by this design.

## 2. Goal

Replace the OS camera round trip with an in-app capture screen: shoot many photos in one session
with one tap each, review them in a thumbnail strip, remove mistakes, then hand the whole set to
the existing draft list, which already provides preview, per-photo description and delete before
upload. Add an "Apply to all" action so one description can be copied to every photo of a series.

Decisions taken with the user:
- Descriptions stay per photo, plus "Apply to all".
- Captured photos are app-private; nothing is written to the device gallery.
- Minimal controls: shutter, thumbnail strip with count, Done, torch toggle, tap to focus. Back
  camera only, portrait only.

## 3. Scope

In: capture screen and its session state, camera service abstraction, route, wiring from the add
sheet, removal of the picker's camera branch, "Apply to all", tests, device verification.
Out: zoom, front camera, video, gallery saving, editing/cropping, changing the upload contract.

## 4. User flow

1. Tomogram screen → plus → sheet → "Take Photo".
2. Camera permission is checked as today (`MediaPickerService.deniedPermissions(camera)`); if
   denied the existing permission screen is pushed and the flow stops.
3. The capture screen opens full screen (root navigator, no tab bar), dark shell.
4. Each shutter tap takes one photo: brief white flash, haptic tick, shutter disabled until the
   file is written, thumbnail appended to the strip, count updated.
5. Tapping a thumbnail asks "Remove this photo?"; confirming deletes the file and the thumbnail.
6. Done (enabled once there is at least one shot) returns the file paths in capture order; the
   tomogram screen adds them as drafts exactly as picker results are added.
7. Close with shots taken asks "Discard photos?" (existing copy); confirming deletes the files.
8. Soft cap of 20 shots per session: at the cap the shutter is disabled and a warning banner
   says "Up to 20 photos per session". Done still works.
9. In the draft list, when more than one draft exists, each card shows "Apply to all" under its
   description. If other drafts already have different non-empty descriptions, a dialog asks
   "Apply to all photos?" before overwriting.

Failure paths:
- Camera cannot start (no camera, in use by another app, permission revoked mid-way): the screen
  shows the empty-state pattern "Camera unavailable" with "Try again" and the close button.
- A capture fails: danger banner with the generic failure copy; the session continues.
- App goes to background: the camera is released; on resume it is re-initialised. Shots taken so
  far are kept (they are files on disk).

## 5. Architecture

Everything lives in the tomogram feature. No `core` change except a navigator key (see 5.4).

### 5.1 Camera service (`lib/features/tomogram/application/camera_service.dart`)

```dart
abstract class CameraService {
  bool get isReady;
  double get previewAspectRatio;           // width / height of the preview, 1 before ready
  Future<void> start();                    // back camera, ResolutionPreset.veryHigh, no audio
  Future<void> stop();                     // releases the device; start() may follow
  Widget preview();                        // CameraPreview once ready, else SizedBox.shrink()
  Future<String> takePicture();            // JPEG path in app-private storage
  Future<void> flush();                    // waits for the shots' background post-processing
  Future<void> setTorch(bool on);
  Future<void> focusAt(Offset normalized); // 0..1 in preview coordinates
}
```

`PluginCameraService` wraps `package:camera` 0.11.0+2 (`camera_android_camerax` 0.6.5 on
Android). `start()` calls `availableCameras()`, picks the first back camera, creates the
controller with `ResolutionPreset.veryHigh` (1080p, so the long edge is at most 1920 px and the
existing 2000 px rule holds without a resize), `enableAudio: false`, initialises it and tries
`lockCaptureOrientation(DeviceOrientation.portraitUp)`; unsupported optional calls
(`lockCaptureOrientation`, `setFocusPoint`, `setExposurePoint`, `setFlashMode`) are caught and
ignored so the screen never fails on an emulator or a low-end device. `takePicture()` returns the
plugin's `XFile.path`; the plugin writes into the app's cache directory, which is private to the
app and is where picker files already live. `cameraServiceProvider` is an `autoDispose`
`Provider<CameraService>` that stops the service on dispose.

**Orientation is baked in the background.** CameraX writes a *sensor-oriented* JPEG with an EXIF
`Orientation` tag: a portrait shot from the back camera is 1280x720 tagged `Orientation = 6`
(device-verified), where the picker path this screen replaces uploaded upright pixels (1440x1920,
`Orientation = 1`). The clinic's viewers are unknown and may ignore EXIF, so
`bakeJpegOrientation(path)` (`lib/features/tomogram/application/jpeg_orientation.dart`, on
`image: ^4.1.7`) rewrites the file so its pixels are upright and the tag is gone: read the raw
EXIF orientation (not the decoded image's — that decoder applies and clears the tag itself), and
if it is absent or 1 leave the file byte for byte alone, otherwise `bakeOrientation` +
`encodeJpg(quality: 90)` into `<path>.tmp` and rename over the original, so an interrupted write
cannot truncate a photo. The work runs in an isolate via `compute`, and `takePicture()` returns
the path without waiting for it, so a burst stays one tap per photo. `PluginCameraService` tracks
the outstanding bakes and `flush()` waits for them; a bake that fails is logged in debug only and
leaves the original file in place, because uploading a sideways photo beats losing it. Callers
must `flush()` before handing a path on or deleting it — a `.tmp` sibling is otherwise orphaned.

Tests use `FakeCameraService` (`test/helpers/fake_camera_service.dart`): records calls, can be
told to fail `start()`, `takePicture()` or `flush()`, can gate `start()`, `takePicture()` and
`flush()` on a `Completer` so a test can hold one in flight, writes a tiny JPEG stub into a temp
directory per shot, and renders a keyed `ColoredBox` as the preview.

### 5.2 Capture session (`lib/features/tomogram/application/capture_controller.dart`)

```dart
const int captureLimit = 20;
enum CaptureStatus { starting, ready, failed }

class CaptureState {
  final CaptureStatus status;
  final List<String> shots;   // capture order
  final bool busy;            // a takePicture is in flight
  final bool torch;
  bool get atLimit => shots.length >= captureLimit;
  bool get canShoot => status == CaptureStatus.ready && !busy && !atLimit;
}

class CaptureController extends AutoDisposeNotifier<CaptureState> {
  Future<void> start();          // status starting → ready | failed
  Future<void> stop();           // background: release the camera, keep shots
  Future<bool> shoot();          // false when !canShoot or the capture failed
  Future<void> remove(String path);  // deletes the file
  Future<void> toggleTorch();
  Future<void> focusAt(Offset normalized);
  Future<void> discardAll();     // deletes every shot's file
  Future<List<String>> takeAll();// hands the paths over and forgets them (files are kept)
}
```

`takeAll`, `remove` and `discardAll` await `CameraService.flush()` first, so nothing is handed
over or deleted while the camera is still rewriting it; a flush that fails is ignored rather than
allowed to lose the shots. Files that the controller still owns when it is disposed (screen
closed by any other path) are deleted, mirroring `TomogramController`, along with any `<path>.tmp`
sibling a bake left behind — that cleanup is synchronous best effort, since a dispose callback
cannot wait for a flush.

### 5.3 Capture screen (`lib/features/tomogram/presentation/capture_screen.dart` + widgets)

- `CaptureScreen` is a `ConsumerStatefulWidget` with `WidgetsBindingObserver`: `start()` from a
  post-frame callback in `initState` (not in `initState` itself — `start()` moves the session's
  state, and a provider may not be modified while the tree reading it is building), `stop()` on
  any non-`resumed` lifecycle state, `start()` again on `resumed`. The release is latched by a
  `_backgrounded` flag, because one real pause arrives as three states (`inactive`, `hidden`,
  `paused`) and only the first of them should hand the device back.
- Layout, top to bottom, on `ds.shell`:
  - Preview area: the camera preview scaled to cover the area
    (`ClipRect(FittedBox(fit: BoxFit.cover, child: SizedBox(width: previewAspectRatio * 1000,
    height: 1000, child: preview)))`, where `previewAspectRatio` is the ratio the preview is
    *displayed* at — a portrait preview of a landscape sensor, so `1 / sensorRatio` — not the
    sensor's own ratio), with a `GestureDetector` that maps the tap through that same cover crop
    into the frame's own 0..1 coordinates, calls `focusAt`, and shows a 64 dp focus ring at the
    tap point for `DsMotion.base`.
  - Top overlay row: close button (left, `MaterialLocalizations.closeButtonTooltip`), torch toggle
    (right, `Icons.flashlight_on_outlined` / `flashlight_off_outlined`, tooltips
    `captureTorchOn` / `captureTorchOff`).
  - Bottom panel (`DsSpace.x3` padding): the thumbnail strip (horizontal `ListView`, 56 dp square
    `Image.file` thumbnails with `cacheWidth: 200`, newest last, auto-scrolls to the end on add),
    then a row with the count chip (`captureCount`, mono, `onShell`), the shutter (72 dp circle,
    accent gradient, white inner ring; disabled look when `!canShoot`) and `DsButton.primary`
    "Done" (disabled while `shots.isEmpty`).
  - Flash overlay: a white `AnimatedOpacity` over the preview, 0 → 0.8 → 0 within
    `DsMotion.fast`, on each successful shot, plus `HapticFeedback.mediumImpact`. Skipped when
    `MediaQuery.disableAnimationsOf` is true.
  - `status == failed`: the preview area shows `DsEmptyState(heading: captureErrorTitle,
    body: captureErrorBody, action: DsButton.secondary(captureRetry → start()))`.
- `PopScope(canPop: shots.isEmpty)`: back with shots asks "Discard photos?" with the existing
  `tomogramDiscardTitle`/`tomogramDiscardBody`/`commonDiscard`; confirming calls `discardAll()`
  and pops with `null`.
- Done: `await controller.takeAll()`, then pop with the paths (guarded by `mounted`). While that
  is pending the button shows `DsButton.primary(loading: true)` and the shutter is disabled: the
  pop is coming, and a shot taken now would land after the flush meant to cover it.
- All strings via `context.l10n`; all colours, radii, spacing and durations via tokens. The
  screen paints the status bar like the shell (already the app-wide overlay style).

### 5.4 Route

`RoutePaths.capturePattern = 'capture'`, `RoutePaths.capture(int opid) => '${tomogram(opid)}/capture'`.
`captureRoute` is a child of `tomogramDetailRoute` with `parentNavigatorKey: rootNavigatorKey` so
it covers the tab bar. If `rootNavigatorKey` is currently declared under `lib/app/`, move it to
`lib/core/navigation/navigator_keys.dart` and re-export it from its old location so the feature
can reference it without importing `app/`. The page uses `FadeThroughPage` like its siblings.

### 5.5 Wiring in `TomogramScreen`

`_add()` keeps the sheet and the permission check. For `MediaSource.camera` it now does
`final shots = await (widget.onCapture ?? _pushCapture)(context); if (shots != null) addFiles(shots)`.
`onCapture` (`Future<List<String>?> Function(BuildContext)?`) is injectable for tests, like
`onPermissionsDenied`. `MediaPickerService.pick(MediaSource)` becomes `pickFromGallery()`; the
camera branch and its `image_picker` camera call are removed. `deniedPermissions(MediaSource)`
stays. The 2000 px / quality 85 constants stay for the gallery path.

### 5.6 Apply to all

`TomogramController.applyDescriptionToAll(String id)` copies draft `id`'s description onto every
draft. `TomogramCard` gains `onApplyToAll: VoidCallback?`; when non-null it renders
`DsButton.ghost(label: tomogramApplyToAll)` right-aligned under the description field. The screen
passes it only when `drafts.length > 1`, and before calling the controller asks
`tomogramApplyAllTitle`/`tomogramApplyAllBody` (confirm label `tomogramApplyToAll`) if any other
draft has a non-empty description different from this one.

## 6. Copy (ARB keys)

| key | text |
| --- | --- |
| `captureDone` | Done |
| `captureShutter` | Take photo |
| `captureCount` | `{count, plural, =0{No photos yet} =1{1 photo} other{{count} photos}}` |
| `captureTorchOn` | Turn torch on |
| `captureTorchOff` | Turn torch off |
| `captureRemoveTitle` | Remove this photo? |
| `captureRemoveBody` | It has not been added yet and will be deleted. |
| `captureRemove` | Remove |
| `captureErrorTitle` | Camera unavailable |
| `captureErrorBody` | Could not start the camera. Check that no other app is using it and try again. |
| `captureRetry` | Try again |
| `captureLimit` | Up to {limit} photos per session (`limit` int) |
| `captureFailed` | Could not take the photo. Try again. |
| `tomogramApplyToAll` | Apply to all |
| `tomogramApplyAllTitle` | Apply to all photos? |
| `tomogramApplyAllBody` | This replaces the descriptions of the other photos. |

Reused: `tomogramDiscardTitle`, `tomogramDiscardBody`, `commonDiscard`, `commonCancel`. A failed
shot gets its own `captureFailed` rather than the generic `tomogramUploadError`: nothing was
uploaded, and the user's next move is to press the shutter again.

## 7. Platform

- Dependencies: `camera: ^0.11.0+2` — the last release supporting Flutter 3.19 / Dart 3.3
  (verified with `flutter pub add --dry-run`: resolves to `camera_android_camerax 0.6.5+2`,
  `camera_avfoundation 0.9.17+5`) — and `image: ^4.1.7` for the orientation bake (§5.1). No
  others.
- Android: `CAMERA` permission and `android.hardware.camera` feature are already declared;
  minSdk 21 and compileSdk 34 satisfy CameraX. The release (R8) build must be re-verified; add
  keep rules only if the build or the emulator run shows a missing class.
- iOS: `NSCameraUsageDescription` already present. Not built in this plan.
- Portrait only (the manifest already locks it).

## 8. Testing

- `capture_controller_test.dart` (fake camera, temp dir): start → ready; start failure → failed
  and retry works; shoot appends in order and toggles `busy`; shoot while busy or at the cap is
  refused; capture failure returns false and keeps the list; remove deletes the file; discardAll
  deletes all; takeAll returns paths in order, clears the list and keeps the files; dispose with
  leftover shots deletes them; toggleTorch forwards.
- `capture_screen_test.dart` (fake camera): shutter adds a thumbnail and updates the count; Done
  is disabled at zero and pops with the paths; tapping a thumbnail asks and removes; close with
  shots asks to discard and deletes; the cap disables the shutter and shows the banner; start
  failure shows "Camera unavailable" and Try again re-starts; torch toggle flips the tooltip.
- `tomogram_screen_test.dart`: "Take Photo" invokes `onCapture` and the returned paths become
  drafts; a `null` result adds nothing; the permission-denied path is unchanged; "Apply to all"
  appears only with two or more drafts, copies the text, and asks first when it would overwrite.
- `tomogram_controller_test.dart`: `applyDescriptionToAll`.
- `media_picker_service_test.dart`: `pickFromGallery` keeps the 2000 px / 85 arguments; no camera
  call remains.
- Device verification (controller-run) on the emulator's virtual camera: three shots, remove one,
  Done → two drafts; apply to all; upload succeeds and the files land in the Tomogram folder at
  ≤ 1920 px; background/resume during capture keeps the shots; release build starts the camera.

## 9. Risks

- CameraX 0.6.5 on the emulator: torch and focus are best-effort and silently ignored where
  unsupported; the plan's device check confirms the screen still works.
- Cold start of the camera (~0.5–1 s) is shown as the `starting` state with the shell background;
  no spinner is needed because the preview appears in place.
- Files are kept in the cache directory; the OS may clear cache under storage pressure. The window
  between capture and upload is short (same visit) and matches today's picker behaviour.
