import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/camera_service.dart';
import 'package:hms_uploader/features/tomogram/application/capture_controller.dart';
import 'package:hms_uploader/features/tomogram/application/capture_grid_controller.dart';
import 'package:hms_uploader/features/tomogram/application/description_suggestions.dart';
import 'package:hms_uploader/features/tomogram/data/shot.dart';
import 'package:hms_uploader/features/tomogram/presentation/shot_preview_screen.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/label_pill.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/label_sheet.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/shot_strip.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/shutter_button.dart';

/// The tap-to-focus ring. Not a token: it is sized to the finger that drew it,
/// big enough to be seen under the thumb and small enough to point at one spot.
const double _focusRingSize = 64;

/// The flash overlay's peak opacity: reads as a shutter without hiding the
/// frame that was just taken.
const double _flashPeak = 0.8;

/// The preview is scaled to cover, so only its ratio matters; this is the
/// height of the box the ratio is applied to.
const double _previewBox = 1000;

/// Done's height. Below the button scale's 44 on purpose: it is the row's
/// second control, and at full size beside the shutter it read as the
/// screen's main action.
const double _doneHeight = 40;

/// The zoom the chip steps up to. One useful step rather than a slider: the
/// pinch is there for anything in between.
const double _zoomStep = 2;

/// The composition grid's lines: faint enough to leave the photo alone, solid
/// enough to line a limb up against.
const double _gridOpacity = 0.35;
const double _gridStroke = 1;

/// The zoom chip's target. Drawn chip-sized, hit thumb-sized, as everywhere
/// else on this screen.
const double _zoomChipTapTarget = 44;

/// The grid overlay, keyed so a test can tell it is on the preview.
@visibleForTesting
const Key captureGridKey = Key('capture-grid');

/// The zoom chip, keyed for the same reason — its text is the level, so a
/// finder for the text would be a finder for a moving target.
@visibleForTesting
const Key captureZoomChipKey = Key('capture-zoom-chip');

/// One focus tap: where it landed and which tap it was, so that two taps on
/// the same pixel are still two taps.
typedef _FocusTap = ({Offset at, int seq});

/// The tappable preview area. Keyed so a test can measure the box a focus tap
/// is mapped against.
@visibleForTesting
const Key capturePreviewAreaKey = Key('capture-preview-area');

/// Where a tap in the preview area lands in the camera frame's own
/// coordinates, 0..1, which is what [CameraService.focusAt] wants.
///
/// The preview is scaled to *cover* the area, so the frame is cropped on one
/// axis: the area's left edge is not the frame's left edge. This inverts that
/// scale, so the camera is pointed at what the finger pointed at rather than
/// at the same fraction of a box the user cannot see. Clamped, because
/// rounding at the edge of a heavily cropped frame can land a hair outside it.
@visibleForTesting
Offset coverTapToFrame(Offset local, Size area, double aspectRatio) {
  if (area.isEmpty || aspectRatio <= 0) return const Offset(0.5, 0.5);
  final box = Size(aspectRatio * _previewBox, _previewBox);
  final scale = math.max(area.width / box.width, area.height / box.height);
  final frame = Offset(
    (local.dx - area.width / 2) / scale + box.width / 2,
    (local.dy - area.height / 2) / scale + box.height / 2,
  );
  return Offset(
    (frame.dx / box.width).clamp(0.0, 1.0),
    (frame.dy / box.height).clamp(0.0, 1.0),
  );
}

/// Full-screen burst capture: one tap per photo, a strip of what has been
/// taken, and the whole set handed back on Done.
///
/// Pops with the captured shots in capture order, or with `null` when the
/// session is abandoned (close or back, after confirming the discard).
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, required this.opid});

  /// Whose photos these are. Only the label sheet needs it, for the
  /// descriptions this patient's own uploads have used before.
  final int opid;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> with WidgetsBindingObserver {
  /// The flash and the focus ring are the only things a shot or a focus tap
  /// moves, and they are notifiers rather than `setState` so that neither
  /// rebuilds the screen — and so neither takes the camera preview down and
  /// up with it.
  final _flash = ValueNotifier<bool>(false);
  final _focusTap = ValueNotifier<_FocusTap?>(null);
  int _focusSeq = 0;

  /// Whether Done is waiting for the camera to finish rewriting the shots.
  ///
  /// The whole screen is frozen while it is true: the pop is coming with the
  /// paths, and anything that opens a dialog in the meantime would be sitting
  /// on the navigator when it lands — a `List<String>` popped into a
  /// `Route<bool>`. A shot taken now would also arrive after the flush that
  /// was meant to cover it.
  bool _finishing = false;

  /// The zoom a pinch started from, so the gesture scales that rather than
  /// compounding on itself frame by frame.
  double _zoomBase = 1;

  /// Whether the camera was handed back because the app left the foreground.
  /// One real pause arrives as three states (inactive, hidden, paused), and
  /// only the first of them should release the device.
  bool _backgrounded = false;

  CaptureController get _capture => ref.read(captureControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the frame, not in it: `start` moves the session's state, and a
    // provider may not be modified while the tree reading it is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_capture.start());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flash.dispose();
    _focusTap.dispose();
    super.dispose();
  }

  /// The camera is a device other apps want: hand it back while this one is
  /// away, and re-open it on the way back. The shots are files on disk, so
  /// they survive the round trip.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_backgrounded) return;
      _backgrounded = false;
      unawaited(_capture.start());
      return;
    }
    if (_backgrounded) return;
    _backgrounded = true;
    unawaited(_capture.stop());
  }

  /// Pops with [result]. Not `maybePop`: the enclosing [PopScope] still
  /// reports the pre-clear `canPop` until the next build, so asking the route
  /// again would bounce straight back into the discard prompt.
  void _pop(List<Shot>? result) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(result);
  }

  Future<void> _shoot() async {
    // The shutter is disabled when the session cannot shoot, but a tap can
    // still arrive before that rebuild; refused there, it is not a failure.
    if (!ref.read(captureControllerProvider).canShoot) return;
    final took = await _capture.shoot();
    if (!mounted) return;
    if (!took) {
      showDsBanner(context, context.l10n.captureFailed, kind: DsBannerKind.danger);
      return;
    }
    // Reduced motion takes both signals: the flash and the tick say the same
    // "that worked", and the thumbnail says it too, without moving anything.
    if (MediaQuery.disableAnimationsOf(context)) return;
    // A device with no vibrator (and a widget test with no plugin at all)
    // must not take the shot down with it.
    unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
    _flash.value = true;
  }

  Future<void> _done() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    // Taken before the await: the result belongs to *this* route, and reading
    // the navigator afterwards would hand it to whatever is on top by then.
    final navigator = Navigator.of(context);
    final shots = await _capture.takeAll();
    if (!mounted) return;
    setState(() => _finishing = false);
    if (navigator.canPop()) navigator.pop(shots);
  }

  /// Close and system back. Shots are unsaved work, so confirm first.
  Future<void> _close() async {
    if (_finishing) return;
    if (ref.read(captureControllerProvider).shots.isEmpty) {
      _pop(null);
      return;
    }
    final l10n = context.l10n;
    final discard = await showDsDialog(
      context,
      title: l10n.tomogramDiscardTitle,
      body: l10n.tomogramDiscardBody,
      confirmLabel: l10n.commonDiscard,
      destructive: true,
    );
    if (!discard || !mounted) return;
    await _capture.discardAll();
    if (mounted) _pop(null);
  }

  /// Opens the shot at [index] full screen. A photo is something to look at
  /// before deciding about it; removing it lives in there.
  void _openPreview(int index) {
    if (_finishing) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: DsMotion.of(context, DsMotion.base),
        reverseTransitionDuration: DsMotion.of(context, DsMotion.base),
        pageBuilder: (_, __, ___) => ShotPreviewScreen(initialIndex: index, opid: widget.opid),
        // A fade, not a slide: the preview is the same photo the thumbnail
        // was showing, made big.
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  /// Asks what the next shots are of, offering [suggestions]. Cancelled, it
  /// leaves the session's label as it was — which is not the same as clearing
  /// it.
  Future<void> _openLabelSheet(List<String> suggestions) async {
    if (_finishing) return;
    final label = await showLabelSheet(
      context,
      initial: ref.read(captureControllerProvider).label,
      suggestions: suggestions,
    );
    if (label == null || !mounted) return;
    _capture.setLabel(label);
  }

  /// Drops the label without the sheet. "The next few are of nothing in
  /// particular" was three taps through a sheet; it is one here.
  void _clearLabel() {
    if (_finishing) return;
    _capture.setLabel('');
  }

  Future<void> _toggleTorch() async {
    if (_finishing) return;
    await _capture.toggleTorch();
  }

  Future<void> _toggleGrid() async {
    if (_finishing) return;
    await ref.read(captureGridProvider.notifier).toggle();
  }

  /// A pinch starts from where the zoom already is. Recorded here rather than
  /// read per update, so the gesture is one movement and not a stack of them.
  void _onScaleStart(ScaleStartDetails details) {
    _zoomBase = ref.read(captureControllerProvider).zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // One finger is a drag, not a pinch — and the tap-to-focus gesture is
    // what a single pointer on the preview means.
    if (details.pointerCount < 2 || _finishing) return;
    unawaited(_capture.setZoom(_zoomBase * details.scale));
  }

  /// 1x to [_zoomStep] and back, for a thumb that does not want to pinch.
  /// Clamped by the controller, so a camera that stops short of the step lands
  /// on as much as it has.
  void _cycleZoom() {
    if (_finishing) return;
    final zoom = ref.read(captureControllerProvider).zoom;
    unawaited(_capture.setZoom(zoom < _zoomStep ? _zoomStep : 1));
  }

  void _focusAt(Offset local, Size area) {
    if (area.isEmpty) return;
    final aspectRatio = ref.read(cameraServiceProvider).previewAspectRatio;
    unawaited(_capture.focusAt(coverTapToFrame(local, area, aspectRatio)));
    _focusTap.value = (at: local, seq: _focusSeq++);
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final l10n = context.l10n;
    final state = ref.watch(captureControllerProvider);
    final grid = ref.watch(captureGridProvider);
    // Watched, not read on tap: the patient's history is a provider this
    // screen depends on for as long as it is up, and reading an autoDispose
    // provider nothing listens to schedules its disposal on the spot.
    final suggestions = ref.watch(descriptionSuggestionsProvider(widget.opid));

    // Once, on the way into the cap: the shutter's disabled look says the rest.
    ref.listen(captureControllerProvider, (previous, next) {
      if (next.atLimit && !(previous?.atLimit ?? false)) {
        showDsBanner(context, l10n.captureLimit(captureLimit), kind: DsBannerKind.warning);
      }
    });

    return PopScope(
      canPop: state.shots.isEmpty,
      onPopInvoked: (didPop) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: ds.shell,
        // The label sheet brings a keyboard up over this screen; the camera
        // preview must not relayout under it.
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (state.status == CaptureStatus.failed) _failure() else _previewArea(grid),
                    _topOverlay(state, grid),
                    _zoomOverlay(state),
                  ],
                ),
              ),
              _panel(state, suggestions),
            ],
          ),
        ),
      ),
    );
  }

  /// The preview, and every gesture that lands on the picture itself: one
  /// finger to focus, two to zoom. Both on the same detector, which resolves
  /// them the way the arena does — a tap that does not move stays a tap.
  Widget _previewArea(bool grid) => LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          key: capturePreviewAreaKey,
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _focusAt(details.localPosition, constraints.biggest),
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Const, so a rebuild of this screen leaves it alone: it holds
              // the live camera texture, which must not go down and up again
              // every time a shot lands in the strip.
              const _CameraLayer(),
              // Over the preview only, and never over the bottom panel: it is
              // a framing aid for the picture, not a decoration for the screen.
              if (grid)
                IgnorePointer(
                  child: CustomPaint(
                    key: captureGridKey,
                    painter: _GridPainter(
                      color: context.ds.textOnShell.withOpacity(_gridOpacity),
                    ),
                  ),
                ),
              _FlashOverlay(flash: _flash),
              _FocusRing(tap: _focusTap),
            ],
          ),
        ),
      );

  /// The zoom, just above the panel and centred under the frame: the one place
  /// on the preview a thumb can reach without covering what it is aiming at.
  ///
  /// Absent on a camera that does not zoom — a chip that only ever says "1.0x"
  /// is a control that does nothing.
  Widget _zoomOverlay(CaptureState state) {
    final l10n = context.l10n;
    if (ref.read(cameraServiceProvider).maxZoom <= 1) return const SizedBox.shrink();
    final text = l10n.captureZoomLevel(state.zoom.toStringAsFixed(1));
    return Positioned(
      left: 0,
      right: 0,
      bottom: DsSpace.x3,
      child: Center(
        child: Semantics(
          key: captureZoomChipKey,
          container: true,
          button: true,
          label: text,
          onTap: _cycleZoom,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(DsRadius.full),
            onTap: _cycleZoom,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _zoomChipTapTarget),
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: DsChip(text: text, mono: true, onShell: true),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The camera would not open. On [DsColors.canvas] rather than the shell:
  /// the empty-state pattern is page text, and page text needs a page under it.
  Widget _failure() {
    final l10n = context.l10n;
    return ColoredBox(
      color: context.ds.canvas,
      child: DsEmptyState(
        heading: l10n.captureErrorTitle,
        body: l10n.captureErrorBody,
        action: DsButton.secondary(
          label: l10n.captureRetry,
          expand: false,
          onPressed: () => unawaited(_capture.start()),
        ),
      ),
    );
  }

  Widget _topOverlay(CaptureState state, bool grid) {
    final ds = context.ds;
    final l10n = context.l10n;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.x2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              color: ds.textOnShell,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              // Nothing to leave to: the pop is already on its way.
              onPressed: _finishing ? null : () => unawaited(_close()),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(grid ? Icons.grid_3x3 : Icons.grid_off),
              color: ds.textOnShell,
              tooltip: grid ? l10n.captureGridOff : l10n.captureGridOn,
              onPressed: _finishing ? null : () => unawaited(_toggleGrid()),
            ),
            IconButton(
              icon: const Icon(Icons.flashlight_off_outlined),
              selectedIcon: const Icon(Icons.flashlight_on_outlined),
              isSelected: state.torch,
              color: ds.textOnShell,
              tooltip: state.torch ? l10n.captureTorchOff : l10n.captureTorchOn,
              // Nothing to light up until the device is open.
              onPressed: state.status == CaptureStatus.ready && !_finishing
                  ? () => unawaited(_toggleTorch())
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(CaptureState state, List<String> suggestions) {
    final l10n = context.l10n;
    final shots = state.shots;
    return Padding(
      padding: const EdgeInsets.all(DsSpace.x3),
      child: Column(
        children: [
          ShotStrip(shots: shots, onTap: _openPreview),
          if (shots.isNotEmpty) const SizedBox(height: DsSpace.x3),
          // Above the shutter row and left-aligned, so the label is read on
          // the way to the button that uses it.
          Align(
            alignment: Alignment.centerLeft,
            child: LabelPill(
              label: state.label,
              onTap: () => unawaited(_openLabelSheet(suggestions)),
              onClear: _clearLabel,
            ),
          ),
          const SizedBox(height: DsSpace.x3),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DsChip(text: l10n.captureCount(shots.length), mono: true, onShell: true),
                ),
              ),
              ShutterButton(
                onPressed: state.canShoot && !_finishing ? () => unawaited(_shoot()) : null,
                tooltip: l10n.captureShutter,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: DsButton.primary(
                    label: l10n.captureDone,
                    expand: false,
                    height: _doneHeight,
                    loading: _finishing,
                    onPressed: shots.isEmpty || _finishing ? null : () => unawaited(_done()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Two lines each way over the preview: the thirds a photographer frames
/// against. It draws over whatever box it is given, so the cover crop needs no
/// arithmetic here — the grid is on the screen, which is what the eye lines
/// the subject up against.
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _gridStroke;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.color != color;
}

/// The live preview, scaled to cover its area.
///
/// Watches whether the camera is ready and nothing else: a shot changes
/// `shots` and `busy`, and neither is a reason to rebuild a camera texture.
class _CameraLayer extends ConsumerWidget {
  const _CameraLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(captureControllerProvider.select((s) => s.status == CaptureStatus.ready));
    final camera = ref.watch(cameraServiceProvider);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: camera.previewAspectRatio * _previewBox,
          height: _previewBox,
          child: ready ? camera.preview() : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The shutter's white blink: up to [_flashPeak] and back, the whole gesture
/// inside `DsMotion.fast`.
class _FlashOverlay extends StatelessWidget {
  const _FlashOverlay({required this.flash});

  final ValueNotifier<bool> flash;

  @override
  Widget build(BuildContext context) {
    final half = DsMotion.of(context, DsMotion.fast) * 0.5;
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: flash,
        builder: (context, on, _) => AnimatedOpacity(
          opacity: on ? _flashPeak : 0,
          duration: half,
          curve: DsMotion.curve,
          // The way back down: the rise hands over to the fall, so the flash
          // is one there-and-gone gesture rather than two states to track.
          onEnd: () {
            if (flash.value) flash.value = false;
          },
          child: ColoredBox(color: context.ds.textOnShell),
        ),
      ),
    );
  }
}

/// The ring that lands where the user tapped to focus, and fades out.
class _FocusRing extends StatefulWidget {
  const _FocusRing({required this.tap});

  final ValueListenable<_FocusTap?> tap;

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing> {
  Offset? _point;
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    widget.tap.addListener(_onTap);
  }

  @override
  void didUpdateWidget(_FocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tap == widget.tap) return;
    oldWidget.tap.removeListener(_onTap);
    widget.tap.addListener(_onTap);
  }

  @override
  void dispose() {
    widget.tap.removeListener(_onTap);
    super.dispose();
  }

  void _onTap() {
    setState(() {
      _point = widget.tap.value?.at;
      _opacity = 1;
    });
    // The fade is asked for on the next frame, so the ring lands at full
    // strength and then goes out over `DsMotion.base`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    if (point == null) return const SizedBox.shrink();
    return Positioned(
      left: point.dx - _focusRingSize / 2,
      top: point.dy - _focusRingSize / 2,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: DsMotion.of(context, DsMotion.base),
          curve: DsMotion.curve,
          child: Container(
            width: _focusRingSize,
            height: _focusRingSize,
            decoration: BoxDecoration(
              border: Border.all(color: context.ds.textOnShell),
              borderRadius: BorderRadius.circular(DsRadius.full),
            ),
          ),
        ),
      ),
    );
  }
}
