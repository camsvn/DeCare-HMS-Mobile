import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/capture_controller.dart';
import 'package:hms_uploader/features/tomogram/application/description_suggestions.dart';
import 'package:hms_uploader/features/tomogram/data/shot.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/label_sheet.dart';

/// The caption under the photo: this shot's description, or the offer to give
/// it one. Keyed so a test can tap it and tell it from the counter.
@visibleForTesting
const Key shotPreviewLabelKey = Key('shot-preview-label');

/// The caption's icon side, and the thumb-sized row it sits in.
const double _captionIconSize = 18;
const double _captionTapTarget = 44;

/// One capture session's shots, full screen, swipeable.
///
/// This is what a thumbnail tap opens: a photo is something to look at before
/// deciding about it, so removing it is a button in here rather than the only
/// thing a tap on the strip could ever do.
class ShotPreviewScreen extends ConsumerStatefulWidget {
  const ShotPreviewScreen({super.key, required this.initialIndex, required this.opid});

  /// The shot the strip was tapped on.
  final int initialIndex;

  /// Whose photos these are. Only the label sheet needs it, for the
  /// descriptions this patient's own uploads have used before.
  final int opid;

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

  /// Asks what this one shot is of, and re-describes only it. Cancelled, it
  /// leaves the label as it was — which is not the same as clearing it, which
  /// the sheet's own Clear does by returning `''`.
  Future<void> _relabel(Shot shot, List<String> suggestions) async {
    final label = await showLabelSheet(
      context,
      initial: shot.label,
      suggestions: suggestions,
    );
    if (label == null || !mounted) return;
    ref.read(captureControllerProvider.notifier).relabel(shot.path, label);
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
    // Watched, not read on tap: the patient's history is a provider this
    // screen depends on for as long as it is up, and reading an autoDispose
    // provider nothing listens to schedules its disposal on the spot.
    final suggestions = ref.watch(descriptionSuggestionsProvider(widget.opid));

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
                  // The photo gives up the room: a two-line caption is worth
                  // more than the last few pixels of a letterboxed frame.
                  Expanded(child: _pages(shots)),
                  _caption(shots[_index(shots)], suggestions),
                  Padding(
                    padding: const EdgeInsets.all(DsSpace.gutter),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: DsButton.destructive(
                        label: l10n.captureRemove,
                        expand: false,
                        onPressed: () => unawaited(_remove(shots[_index(shots)].path)),
                      ),
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

  /// Close on the left, which page this is on the right. Nothing else: the
  /// label used to sit in here too, where it read as metadata about the photo
  /// rather than as the caption it is.
  Widget _header(List<Shot> shots) {
    final ds = context.ds;
    final l10n = context.l10n;
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
            child: Align(
              alignment: Alignment.centerRight,
              child: DsChip(
                text: l10n.tomogramCounter(_index(shots) + 1, shots.length),
                mono: true,
                onShell: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// This shot's description, as a caption across the foot of the photo: the
  /// preview is where a photo is looked at, so it is where a wrong or missing
  /// label gets fixed — for this shot only, not for the session.
  ///
  /// Full width and two lines deep, because a description is a phrase and the
  /// chip this used to be truncated most of them.
  Widget _caption(Shot shot, List<String> suggestions) {
    final ds = context.ds;
    final type = context.dsType;
    final l10n = context.l10n;
    final empty = shot.label.isEmpty;
    final text = empty ? l10n.captureAddLabel : shot.label;
    return Semantics(
      key: shotPreviewLabelKey,
      container: true,
      button: true,
      label: text,
      onTap: () => unawaited(_relabel(shot, suggestions)),
      excludeSemantics: true,
      child: ColoredBox(
        color: ds.shell,
        child: InkWell(
          onTap: () => unawaited(_relabel(shot, suggestions)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _captionTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpace.gutter,
                vertical: DsSpace.x3,
              ),
              child: Row(
                // The mark stays on the caption's first line rather than
                // floating to the middle of a two-line description.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    empty ? Icons.label_outline : Icons.edit_outlined,
                    size: _captionIconSize,
                    color: ds.textOnShellMuted,
                  ),
                  const SizedBox(width: DsSpace.x3),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.body.withColor(empty ? ds.textOnShellMuted : ds.textOnShell),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
