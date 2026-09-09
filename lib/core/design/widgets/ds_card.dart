import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';

/// White surface with a 1 px subtle border. No shadow.
class DsCard extends StatelessWidget {
  const DsCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Material(
      color: ds.card,
      shape: RoundedRectangleBorder(
        borderRadius: DsRadius.mediumAll,
        side: BorderSide(color: ds.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? const EdgeInsets.all(DsSpace.cardPadding), child: child),
      ),
    );
  }
}
