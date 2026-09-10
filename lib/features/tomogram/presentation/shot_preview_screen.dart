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

/// The label chip under the counter: this shot's description, or the offer to
/// give it one. Keyed so a test can tap it and tell it from the counter.
@visibleForTesting
const Key shotPreviewLabelKey = Key('shot-preview-label');

/// The chip's icon side, and the thumb-sized box it sits in. Same bargain as
/// the capture screen's pill: drawn small, hit big.
const double _chipIconSize = 16;
const double _chipTapTarget = 44;

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
                  _header(shots, suggestions),
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

  Widget _header(List<Shot> shots, List<String> suggestions) {
    final ds = context.ds;
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
                _labelChip(shot, suggestions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// This shot's description, as a chip that opens the sheet: the preview is
  /// where a photo is looked at, so it is where a wrong or missing label gets
  /// fixed — for this shot only, not for the session.
  Widget _labelChip(Shot shot, List<String> suggestions) {
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
      child: InkWell(
        borderRadius: BorderRadius.circular(DsRadius.full),
        onTap: () => unawaited(_relabel(shot, suggestions)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _chipTapTarget),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: DsSpace.x1),
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.x2, vertical: DsSpace.x1),
              decoration: BoxDecoration(
                color: ds.shellRaised,
                borderRadius: BorderRadius.circular(DsRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    empty ? Icons.label_outline : Icons.edit_outlined,
                    size: _chipIconSize,
                    color: empty ? ds.textOnShellMuted : ds.accentSolid,
                  ),
                  const SizedBox(width: DsSpace.x2),
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.label.withColor(empty ? ds.textOnShellMuted : ds.textOnShell),
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
