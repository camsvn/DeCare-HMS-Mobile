import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';

/// Small pill for values like OP numbers, hosts, counts.
class DsChip extends StatelessWidget {
  const DsChip({super.key, required this.text, this.mono = false, this.onShell = false});

  final String text;
  final bool mono;
  final bool onShell;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    // A mono chip keeps the label's size, so that a count and a word read as
    // the same kind of thing; only the figures change.
    final style = (mono ? type.mono : type.label).copyWith(
      fontSize: type.label.fontSize,
      color: onShell ? ds.textOnShell : ds.textSecondary,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.x2, vertical: DsSpace.x1),
      decoration: BoxDecoration(
        color: onShell ? ds.shellRaised : ds.canvas,
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: onShell ? null : Border.all(color: ds.borderSubtle),
      ),
      child: Text(text, style: style),
    );
  }
}
