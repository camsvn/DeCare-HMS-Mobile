import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/camera_service.dart';
import 'package:hms_uploader/features/tomogram/application/capture_controller.dart';
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

/// Full-screen burst capture: one tap per photo, a strip of what has been
/// taken, and the whole set handed back on Done.
///
/// Pops with the captured paths in capture order, or with `null` when the
/// session is abandoned (close or back, after confirming the discard).
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> with WidgetsBindingObserver {
  /// Where the last tap-to-focus landed, in preview coordinates, and the
  /// opacity its ring is heading for.
  Offset? _focusPoint;
  double _focusOpacity = 0;

  bool _flash = false;

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
  void _pop(List<String>? result) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(result);
  }

  Future<void> _shoot() async {
    final took = await _capture.shoot();
    if (!took || !mounted) return;
    // Reduced motion takes both signals: the flash and the tick say the same
    // "that worked", and the thumbnail says it too, without moving anything.
    if (MediaQuery.disableAnimationsOf(context)) return;
    // A device with no vibrator (and a widget test with no plugin at all)
    // must not take the shot down with it.
    unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
    setState(() => _flash = true);
  }

  void _done() => _pop(_capture.takeAll());

  /// Close and system back. Shots are unsaved work, so confirm first.
  Future<void> _close() async {
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

  Future<void> _confirmRemove(String path) async {
    final l10n = context.l10n;
    final remove = await showDsDialog(
      context,
      title: l10n.captureRemoveTitle,
      body: l10n.captureRemoveBody,
      confirmLabel: l10n.captureRemove,
      destructive: true,
    );
    if (!remove || !mounted) return;
    await _capture.remove(path);
  }

  void _focusAt(Offset local, Size area) {
    if (area.isEmpty) return;
    unawaited(_capture.focusAt(Offset(local.dx / area.width, local.dy / area.height)));
    setState(() {
      _focusPoint = local;
      _focusOpacity = 1;
    });
    // The fade is asked for on the next frame, so the ring lands at full
    // strength and then goes out over `DsMotion.base`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _focusOpacity = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final l10n = context.l10n;
    final state = ref.watch(captureControllerProvider);
    final camera = ref.watch(cameraServiceProvider);

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
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (state.status == CaptureStatus.failed) _failure() else _preview(camera),
                    _topOverlay(state),
                  ],
                ),
              ),
              _panel(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(CameraService camera) => LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _focusAt(details.localPosition, constraints.biggest),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: camera.previewAspectRatio * _previewBox,
                    height: _previewBox,
                    child: camera.preview(),
                  ),
                ),
              ),
              _flashOverlay(),
              _focusRing(),
            ],
          ),
        ),
      );

  Widget _flashOverlay() => IgnorePointer(
        child: AnimatedOpacity(
          opacity: _flash ? _flashPeak : 0,
          duration: DsMotion.of(context, DsMotion.fast),
          curve: DsMotion.curve,
          // The way back down. The flash is one there-and-gone gesture, not
          // two states worth tracking, so the rise hands over to the fall.
          onEnd: () {
            if (_flash && mounted) setState(() => _flash = false);
          },
          child: ColoredBox(color: context.ds.textOnShell),
        ),
      );

  Widget _focusRing() {
    final point = _focusPoint;
    if (point == null) return const SizedBox.shrink();
    return Positioned(
      left: point.dx - _focusRingSize / 2,
      top: point.dy - _focusRingSize / 2,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _focusOpacity,
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

  Widget _topOverlay(CaptureState state) {
    final ds = context.ds;
    final l10n = context.l10n;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.x2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              color: ds.textOnShell,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => unawaited(_close()),
            ),
            IconButton(
              icon: const Icon(Icons.flashlight_off_outlined),
              selectedIcon: const Icon(Icons.flashlight_on_outlined),
              isSelected: state.torch,
              color: ds.textOnShell,
              tooltip: state.torch ? l10n.captureTorchOff : l10n.captureTorchOn,
              // Nothing to light up until the device is open.
              onPressed: state.status == CaptureStatus.ready ? () => unawaited(_capture.toggleTorch()) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(CaptureState state) {
    final l10n = context.l10n;
    final shots = state.shots;
    return Padding(
      padding: const EdgeInsets.all(DsSpace.x3),
      child: Column(
        children: [
          ShotStrip(paths: shots, onTap: (path) => unawaited(_confirmRemove(path))),
          if (shots.isNotEmpty) const SizedBox(height: DsSpace.x3),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DsChip(text: l10n.captureCount(shots.length), mono: true, onShell: true),
                ),
              ),
              ShutterButton(
                onPressed: state.canShoot ? () => unawaited(_shoot()) : null,
                tooltip: l10n.captureShutter,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: DsButton.primary(
                    label: l10n.captureDone,
                    expand: false,
                    onPressed: shots.isEmpty ? null : _done,
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
