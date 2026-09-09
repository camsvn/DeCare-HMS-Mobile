import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// The thumbnails' side. Not a token: the strip has to sit above the shutter
/// row without pushing the preview off the screen, and 56 dp is the largest
/// square that leaves room for both.
const double shotThumbSize = 56;

/// Decode width for the thumbnails. 200 px covers a 56 dp square on a 3x
/// screen; decoding the full 1080p capture per shot would hold twenty
/// full-size bitmaps in the image cache.
const int _thumbCacheWidth = 200;

/// The shots taken so far, oldest first. Tapping one hands its path back —
/// the screen asks before removing it.
class ShotStrip extends StatefulWidget {
  const ShotStrip({super.key, required this.paths, required this.onTap});

  final List<String> paths;
  final ValueChanged<String> onTap;

  @override
  State<ShotStrip> createState() => _ShotStripState();
}

class _ShotStripState extends State<ShotStrip> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(ShotStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paths.length <= oldWidget.paths.length) return;
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
    final paths = widget.paths;
    // Nothing shot yet: no empty row, the count chip already says so.
    if (paths.isEmpty) return const SizedBox.shrink();
    final ds = context.ds;
    final l10n = context.l10n;
    return SizedBox(
      height: shotThumbSize,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: DsSpace.x2),
        itemBuilder: (context, i) => MergeSemantics(
          child: Semantics(
            button: true,
            image: true,
            label: l10n.tomogramCounter(i + 1, paths.length),
            child: GestureDetector(
              onTap: () => widget.onTap(paths[i]),
              child: ClipRRect(
                borderRadius: DsRadius.smallAll,
                child: Image.file(
                  File(paths[i]),
                  // Keyed by path, so removing one from the middle rebinds the
                  // rest instead of re-decoding them into the wrong slots.
                  key: ValueKey(paths[i]),
                  width: shotThumbSize,
                  height: shotThumbSize,
                  fit: BoxFit.cover,
                  cacheWidth: _thumbCacheWidth,
                  // A cache the OS cleared under storage pressure, or a file
                  // the camera wrote badly: show the gap, do not throw.
                  errorBuilder: (context, _, __) => SizedBox(
                    width: shotThumbSize,
                    height: shotThumbSize,
                    child: ColoredBox(
                      color: ds.shellRaised,
                      child: Icon(Icons.broken_image_outlined, color: ds.textOnShellMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
