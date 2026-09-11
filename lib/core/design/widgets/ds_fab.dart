import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';

/// 52 dp gradient circle. The only shadowed element in the system.
class DsFab extends StatelessWidget {
  const DsFab({super.key, required this.icon, required this.onPressed, required this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;

  /// Doubles as the semantics label, so it is never optional.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final enabled = onPressed != null;
    Widget button = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ds.accentGradient,
        boxShadow: enabled
            ? [BoxShadow(color: ds.accentSolid.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(icon, color: ds.textOnShell, size: 26),
        ),
      ),
    );
    if (!enabled) button = Opacity(opacity: 0.5, child: button);
    if (tooltip.isNotEmpty) button = Tooltip(message: tooltip, child: button);
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: button,
    );
  }
}
