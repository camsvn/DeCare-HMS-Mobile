import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// The caption row under the photo: what this one is of, or the offer to say.
/// Keyed so a test can tap it and tell it from the counter.
@visibleForTesting
const Key photoViewerCaptionKey = Key('photo-viewer-caption');

/// The caption's icon side, and the thumb-sized row it sits in.
const double _captionIconSize = 18;
const double _captionTapTarget = 44;

/// The bottom bar's floor. The caption grows past it on two lines; a one-line
/// caption still gets a bar deep enough to read as one.
const double _bottomBarHeight = 56;

/// The trash icon's target. A destructive control gets the full 48 dp even
/// though the glyph is 24.
const double _removeTapTarget = 48;

/// The scrim under the overlay header: enough of the shell at the top of the
/// frame to keep the close button and the counter legible over a bright photo,
/// fading to nothing before it reaches the middle of the picture.
const double _headerScrimHeight = DsSpace.x8 * 2;
const double _headerScrimOpacity = 0.6;

/// One photo in the viewer: the file, what it is called, and what to suggest
/// it is called when it has no name of its own.
class ViewerPhoto {
  const ViewerPhoto({required this.path, this.caption = '', this.captionHint});

  final String path;

  /// The description, already trimmed by whoever owns it; `''` for none.
  final String caption;

  /// What to show instead of the generic offer when [caption] is blank — the
  /// draft list's "Same as previous photo: …", which is what a blank field
  /// there actually means. Null falls back to "Add a label".
  final String? captionHint;

  @override
  bool operator ==(Object other) =>
      other is ViewerPhoto &&
      other.path == path &&
      other.caption == caption &&
      other.captionHint == captionHint;

  @override
  int get hashCode => Object.hash(path, caption, captionHint);

  @override
  String toString() => 'ViewerPhoto($path, caption: "$caption", hint: $captionHint)';
}

/// A set of photos, full screen and swipeable, with a caption to edit and a
/// bin: the same viewer for the shots of a capture session and the drafts
/// waiting to upload, because looking at a photo is the same job either way.
///
/// It owns no state but the page it is on. [photos] is handed in by whoever
/// owns the list, and a shorter list on the next build is how a removal
/// arrives: the viewer steps back onto the photo that took the slot, or pops
/// itself when the last one goes.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onEditCaption,
    required this.onRemove,
  });

  final List<ViewerPhoto> photos;

  /// The photo that was tapped to get here.
  final int initialIndex;

  /// Rename the photo at this index. The viewer does not care how it is
  /// asked, only that the caller comes back with a shorter or renamed list.
  final Future<void> Function(int index) onEditCaption;

  /// Throw the photo at this index away, asking first if the caller thinks it
  /// should.
  final Future<void> Function(int index) onRemove;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);

  /// The page on screen. Held here rather than read off the controller so the
  /// counter and the caption can be built without waiting for a scroll frame.
  late int _page = widget.initialIndex;

  /// Whether the pop for an emptied list has already been asked for, so a
  /// retry that has been waiting for the route to come back to the top does
  /// not ask twice.
  bool _popRequested = false;

  @override
  void initState() {
    super.initState();
    // A list that was already empty when the viewer was pushed — an owner
    // whose last photo went while the route was in flight. Checked after the
    // frame, because there is no route to pop until there is one.
    WidgetsBinding.instance.addPostFrameCallback((_) => _popIfEmpty());
  }

  @override
  void didUpdateWidget(PhotoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final count = widget.photos.length;
    if (count == oldWidget.photos.length) return;
    if (count == 0) {
      // After the frame: a pop in the middle of the owner's build would be a
      // route change inside a layout pass.
      WidgetsBinding.instance.addPostFrameCallback((_) => _popIfEmpty());
      return;
    }
    if (_page < count) return;
    // The photo that was on screen is gone, so the one that took its slot is
    // shown. No `setState`: a rebuild follows this call anyway.
    _page = count - 1;
    // The controller has to be told too, once the shorter list is laid out:
    // its own page is still the one that no longer exists, and a swipe from
    // here would jump.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(_page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Leaves when there is nothing left to look at.
  ///
  /// Pops *this* route and only this one. `mounted` stays true all through an
  /// exit transition, and `canPop` says nothing about what is on top, so a
  /// deferred pop that trusted either would take the page underneath when the
  /// owner had already popped the viewer itself — or land on the sheet or
  /// dialog that is above it when the list empties. So: nothing unless this
  /// route is the current one, and when it is not, ask again next frame. The
  /// retry ends when the route reaches the top or the widget goes away with
  /// it; an idle app schedules no frames, so it costs nothing while it waits.
  void _popIfEmpty() {
    if (_popRequested || !mounted || widget.photos.isNotEmpty) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    if (!route.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _popIfEmpty());
      return;
    }
    _popRequested = true;
    Navigator.of(context).pop();
  }

  /// The page to show. Clamped, because the rebuild that follows a removal can
  /// arrive before the callback that steps the page back — and zero for an
  /// empty list, which is on its way out and has no page at all.
  int get _index =>
      widget.photos.isEmpty ? 0 : _page.clamp(0, widget.photos.length - 1);

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Scaffold(
      backgroundColor: context.ds.shell,
      // On its way out with the last photo: the frame it would build has no
      // picture in it and no page to count.
      body: photos.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: [
                // Edge to edge, status bar included: this is a photo viewer,
                // and a photo in a frame of margins is a form field. The
                // header floats on top of the picture instead of taking a
                // band of its own.
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _pages(photos),
                      Positioned(top: 0, left: 0, right: 0, child: _header(photos)),
                    ],
                  ),
                ),
                _bottomBar(photos[_index]),
              ],
            ),
    );
  }

  /// Close on the left, which photo this is on the right, floating over the
  /// top of the picture on a scrim. Nothing else: the caption used to sit in
  /// here too, where it read as metadata about the photo rather than as its
  /// caption.
  ///
  /// Only the buttons take pointers. Everything else in here — the scrim, the
  /// gap the counter sits in — lets a swipe through to the photo underneath,
  /// so the header costs the gesture nothing as well as costing no height.
  Widget _header(List<ViewerPhoto> photos) {
    final ds = context.ds;
    final l10n = context.l10n;
    return Stack(
      children: [
        IgnorePointer(
          child: Container(
            height: _headerScrimHeight + MediaQuery.paddingOf(context).top,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ds.shell.withOpacity(_headerScrimOpacity),
                  ds.shell.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
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
                      text: l10n.tomogramCounter(_index + 1, photos.length),
                      mono: true,
                      onShell: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The one bar under the photo: what this photo is of, and the way to throw
  /// it away. Both on the same row, because a caption and its bin are the two
  /// things a viewer does with the picture it is looking at.
  Widget _bottomBar(ViewerPhoto photo) => ColoredBox(
        color: context.ds.shell,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _bottomBarHeight),
            child: Row(
              children: [
                Expanded(child: _caption(photo)),
                _removeButton(),
              ],
            ),
          ),
        ),
      );

  /// The bin. An icon rather than a labelled button: it is the one thing in
  /// here that destroys something, and a viewer's controls are marks, not
  /// sentences. Whether it asks first is the caller's business.
  Widget _removeButton() {
    final ds = context.ds;
    final l10n = context.l10n;
    void remove() => unawaited(widget.onRemove(_index));
    return Semantics(
      container: true,
      button: true,
      label: l10n.captureRemove,
      onTap: remove,
      // One node with the words and the action on it: the tooltip underneath
      // would otherwise say "Remove" a second time.
      excludeSemantics: true,
      child: IconButton(
        icon: const Icon(Icons.delete_outline),
        color: ds.danger,
        tooltip: l10n.captureRemove,
        constraints: const BoxConstraints(
          minWidth: _removeTapTarget,
          minHeight: _removeTapTarget,
        ),
        onPressed: remove,
      ),
    );
  }

  /// This photo's description, as a caption across the foot of it: the viewer
  /// is where a photo is looked at, so it is where a wrong or missing
  /// description gets fixed.
  ///
  /// Two lines deep and as wide as the bar leaves it, because a description
  /// is a phrase and a chip would truncate most of them.
  Widget _caption(ViewerPhoto photo) {
    final ds = context.ds;
    final type = context.dsType;
    final l10n = context.l10n;
    final empty = photo.caption.isEmpty;
    final text = empty ? (photo.captionHint ?? l10n.captureAddLabel) : photo.caption;
    void edit() => unawaited(widget.onEditCaption(_index));
    return Semantics(
      key: photoViewerCaptionKey,
      container: true,
      button: true,
      label: text,
      onTap: edit,
      excludeSemantics: true,
      child: InkWell(
        onTap: edit,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _captionTapTarget),
          child: Padding(
            // Tighter on the right than the left: the bin is next to it, and
            // its own 48 dp box carries the rest of the inset.
            padding: const EdgeInsets.fromLTRB(
              DsSpace.gutter,
              DsSpace.x3,
              DsSpace.x2,
              DsSpace.x3,
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
    );
  }

  Widget _pages(List<ViewerPhoto> photos) {
    final l10n = context.l10n;
    // Decoded to the screen, not to the sensor: a 12 MP capture would put a
    // 48 MB bitmap in the image cache per page, and the page is 1080-odd
    // pixels wide.
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();
    return PageView.builder(
      controller: _controller,
      itemCount: photos.length,
      onPageChanged: (page) => setState(() => _page = page),
      itemBuilder: (context, i) => Semantics(
        image: true,
        // The photo is the screen: undescribed it is a blank to a reader, and
        // the header's chip is a separate node it may never reach.
        label: '${l10n.tomogramCounter(i + 1, photos.length)}'
            '${photos[i].caption.isEmpty ? '' : ', ${l10n.captureLabelled(photos[i].caption)}'}',
        child: Image.file(
          File(photos[i].path),
          // Keyed by path, so a removal rebinds the pages that shifted up
          // rather than re-decoding them into the wrong slots.
          key: ValueKey(photos[i].path),
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
