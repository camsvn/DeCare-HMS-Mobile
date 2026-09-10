import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/data/shot.dart';

/// The thumbnails' side. Not a token: the strip has to sit above the shutter
/// row without pushing the preview off the screen, and 56 dp is the largest
/// square that leaves room for both.
const double shotThumbSize = 56;

/// Decode width for the thumbnails. 200 px covers a 56 dp square on a 3x
/// screen; decoding the full 1080p capture per shot would hold twenty
/// full-size bitmaps in the image cache.
const int _thumbCacheWidth = 200;

/// The tag on a labelled thumbnail: small enough not to cover the photo,
/// large enough to be seen at 56 dp.
const double _tagDotSize = 8;

/// The dot's ring, so it reads against a bright photo as well as a dark one.
const double _tagDotBorder = 1;

/// The dot on a labelled thumbnail. One key for all of them: they are never
/// siblings, so a test counts the tags by finding them.
@visibleForTesting
const Key shotTagDotKey = Key('shot-tag-dot');

/// The shots taken so far, oldest first, with a dot on the ones that carry a
/// description. Tapping one hands its index back — the screen opens it.
class ShotStrip extends StatefulWidget {
  const ShotStrip({super.key, required this.shots, required this.onTap});

  final List<Shot> shots;
  final ValueChanged<int> onTap;

  @override
  State<ShotStrip> createState() => _ShotStripState();
}

class _ShotStripState extends State<ShotStrip> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(ShotStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shots.length <= oldWidget.shots.length) return;
    // Follow the shot just taken. After the frame that lays it out, because
    // only then does the list know how much extent it added.
    final duration = DsMotion.of(context, DsMotion.base);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateTo(
        _controller.position.maxScrollExtent,
        duration: duration,
        curve: DsMotion.curve,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shots = widget.shots;
    // Nothing shot yet: no empty row, the count chip already says so.
    if (shots.isEmpty) return const SizedBox.shrink();
    final ds = context.ds;
    final l10n = context.l10n;
    return SizedBox(
      height: shotThumbSize,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: shots.length,
        separatorBuilder: (_, __) => const SizedBox(width: DsSpace.x2),
        itemBuilder: (context, i) {
          final shot = shots[i];
          return MergeSemantics(
            child: Semantics(
              button: true,
              image: true,
              // Which of the shots this is, and what it is of when it says
              // so: a screen reader walking the strip is looking for one
              // photo, and the dot is no help to it.
              label: '${l10n.tomogramCounter(i + 1, shots.length)}'
                  '${shot.label.isEmpty ? '' : ', ${l10n.captureLabelled(shot.label)}'}',
              child: GestureDetector(
                onTap: () => widget.onTap(i),
                child: SizedBox(
                  width: shotThumbSize,
                  height: shotThumbSize,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: DsRadius.smallAll,
                        child: Image.file(
                          File(shot.path),
                          // Keyed by path, so removing one from the middle
                          // rebinds the rest instead of re-decoding them into
                          // the wrong slots.
                          key: ValueKey(shot.path),
                          width: shotThumbSize,
                          height: shotThumbSize,
                          fit: BoxFit.cover,
                          cacheWidth: _thumbCacheWidth,
                          // A cache the OS cleared under storage pressure, or
                          // a file the camera wrote badly: show the gap, do
                          // not throw.
                          errorBuilder: (context, _, __) => ColoredBox(
                            color: ds.shellRaised,
                            child: Icon(Icons.broken_image_outlined, color: ds.textOnShellMuted),
                          ),
                        ),
                      ),
                      // The label, at thumbnail size: there is no room for the
                      // words, and a dot is enough to tell a described shot
                      // from one that will upload without a narration.
                      if (shot.label.isNotEmpty)
                        Positioned(
                          right: DsSpace.x1,
                          bottom: DsSpace.x1,
                          child: Container(
                            key: shotTagDotKey,
                            width: _tagDotSize,
                            height: _tagDotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ds.accentSolid,
                              border: Border.all(color: ds.shell, width: _tagDotBorder),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
