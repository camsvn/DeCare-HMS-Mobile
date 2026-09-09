import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';

class DsStatusDot extends StatelessWidget {
  const DsStatusDot({super.key, required this.ok, this.color});

  final bool ok;

  /// Overrides the ok/warning colour, e.g. for an indeterminate state.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color ?? (ok ? ds.success : ds.warning)),
    );
  }
}
