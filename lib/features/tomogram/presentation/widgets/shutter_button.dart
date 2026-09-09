import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';

/// The shutter's diameter. Not a token: it is the one control on the capture
/// screen that has to be found by thumb without looking at it, so it is sized
/// for that rather than to the button scale.
const double shutterButtonSize = 72;

/// The white ring around the disc, so the shutter reads on a bright preview.
const double _ringWidth = 3;

/// A camera shutter: a ring with a gradient disc inside it.
///
/// Disabled (a null [onPressed]) while the camera is starting, a capture is in
/// flight or the session is at its cap; the disc goes flat and muted, which is
/// the only state this button has to spell out.
class ShutterButton extends StatelessWidget {
  const ShutterButton({super.key, required this.onPressed, required this.tooltip});

  final VoidCallback? onPressed;

  /// Doubles as the semantic label: the button carries no text of its own.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final enabled = onPressed != null;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          // The label is on the Semantics above; the tooltip would announce
          // the same words a second time.
          excludeFromSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: Container(
              width: shutterButtonSize,
              height: shutterButtonSize,
              padding: const EdgeInsets.all(DsSpace.x1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ds.textOnShell, width: _ringWidth),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: enabled ? ds.accentGradient : null,
                  color: enabled ? null : ds.textOnShellMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
