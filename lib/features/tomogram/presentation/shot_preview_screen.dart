import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/capture_controller.dart';
import 'package:hms_uploader/features/tomogram/data/shot.dart';

/// The label line under the counter, keyed so a test can tell "no label" from
/// "a label that happens to read like the counter".
@visibleForTesting
const Key shotPreviewLabelKey = Key('shot-preview-label');

/// One capture session's shots, full screen, swipeable.
///
/// This is what a thumbnail tap opens: a photo is something to look at before
/// deciding about it, so removing it is a button in here rather than the only
/// thing a tap on the strip could ever do.
class ShotPreviewScreen extends ConsumerStatefulWidget {
  const ShotPreviewScreen({super.key, required this.initialIndex});

  /// The shot the strip was tapped on.
  final int initialIndex;

  @override
  ConsumerState<ShotPreviewScreen> createState() => _ShotPreviewScreenState();
}

class _ShotPreviewScreenState extends ConsumerState<ShotPreviewScreen> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);

  /// The page on screen. Held here rather than read off the controller so the
  /// counter and the label can be built without waiting for a scroll frame.
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Keeps the page in step with a set that got shorter under it: the shot
  /// that was on screen is gone, so the one that took its slot is shown —
  /// or, when the last one went, there is nothing left to preview.
  void _onShotsChanged(List<Shot> shots) {
    if (shots.isEmpty) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
      return;
    }
    if (_page < shots.length) return;
    final page = shots.length - 1;
    setState(() => _page = page);
    // The controller has to be told too: its own page is still the one that
    // no longer exists, and a swipe from here would jump.
    if (_controller.hasClients) _controller.jumpToPage(page);
  }

  Future<void> _remove(String path) async {
    final l10n = context.l10n;
    final remove = await showDsDialog(
      context,
      title: l10n.captureRemoveTitle,
      body: l10n.captureRemoveBody,
      confirmLabel: l10n.captureRemove,
      destructive: true,
    );
    if (!remove || !mounted) return;
    await ref.read(captureControllerProvider.notifier).remove(path);
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final l10n = context.l10n;
    final shots = ref.watch(captureControllerProvider.select((s) => s.shots));

    ref.listen(captureControllerProvider.select((s) => s.shots), (_, next) => _onShotsChanged(next));

    return Scaffold(
      backgroundColor: ds.shell,
      // On its way out with the last shot: the frame it would build has no
      // photo in it and no page to count.
      body: shots.isEmpty
          ? const SizedBox.shrink()
          : SafeArea(
              child: Column(
                children: [
                  _header(shots),
                  Expanded(child: _pages(shots)),
                  Padding(
                    padding: const EdgeInsets.all(DsSpace.x4),
                    child: DsButton.destructive(
                      label: l10n.captureRemove,
                      expand: false,
                      onPressed: () => unawaited(_remove(shots[_index(shots)].path)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// The page to show. Clamped, because the rebuild that follows a removal can
  /// arrive before the listener that steps the page back.
  int _index(List<Shot> shots) => _page.clamp(0, shots.length - 1);

  Widget _header(List<Shot> shots) {
    final ds = context.ds;
    final type = context.dsType;
    final l10n = context.l10n;
    final shot = shots[_index(shots)];
    return Padding(
      padding: const EdgeInsets.all(DsSpace.x2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            color: ds.textOnShell,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsChip(
                  text: l10n.tomogramCounter(_index(shots) + 1, shots.length),
                  mono: true,
                  onShell: true,
                ),
                if (shot.label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpace.x1, left: DsSpace.x2),
                    child: Text(
                      shot.label,
                      key: shotPreviewLabelKey,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.label.withColor(ds.textOnShellMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pages(List<Shot> shots) {
    final l10n = context.l10n;
    // Decoded to the screen, not to the sensor: a 12 MP capture would put a
    // 48 MB bitmap in the image cache per page, and the page is 1080-odd
    // pixels wide.
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();
    return PageView.builder(
      controller: _controller,
      itemCount: shots.length,
      onPageChanged: (page) => setState(() => _page = page),
      itemBuilder: (context, i) => Semantics(
        image: true,
        // The photo is the screen: unlabelled it is a blank to a reader, and
        // the header's chip is a separate node it may never reach.
        label: '${l10n.tomogramCounter(i + 1, shots.length)}'
            '${shots[i].label.isEmpty ? '' : ', ${l10n.captureLabelled(shots[i].label)}'}',
        child: Image.file(
          File(shots[i].path),
          // Keyed by path, so a removal rebinds the pages that shifted up
          // rather than re-decoding them into the wrong slots.
          key: ValueKey(shots[i].path),
          fit: BoxFit.contain,
          cacheWidth: cacheWidth,
          // A file the camera wrote badly, or one the OS cleared: show the
          // gap, do not throw on the frame that is meant to reassure.
          errorBuilder: (context, _, __) => Center(
            child: Icon(Icons.broken_image_outlined, color: context.ds.textOnShellMuted),
          ),
        ),
      ),
    );
  }
}
