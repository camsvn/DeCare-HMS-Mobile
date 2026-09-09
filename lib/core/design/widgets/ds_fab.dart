import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';

/// 52 dp gradient circle. The only shadowed element in the system.
class DsFab extends StatelessWidget {
  const DsFab({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ds.accentGradient,
          boxShadow: [BoxShadow(color: ds.accentSolid.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
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
      ),
    );
  }
}
