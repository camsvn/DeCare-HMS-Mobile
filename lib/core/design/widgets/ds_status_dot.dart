import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';

class DsStatusDot extends StatelessWidget {
  const DsStatusDot({super.key, required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? ds.success : ds.warning),
    );
  }
}
