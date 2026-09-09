import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';

/// Gradient square with a white icon: the module-card and empty-state motif.
class DsIconTile extends StatelessWidget {
  const DsIconTile({super.key, required this.icon, this.size = defaultSize});

  static const double defaultSize = 40;

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: context.ds.accentGradient, borderRadius: BorderRadius.circular(DsRadius.small)),
      alignment: Alignment.center,
      child: Icon(icon, color: context.ds.textOnShell, size: size * 0.55),
    );
  }
}
