import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

/// Row of 56 dp or taller: optional leading icon, title, optional mono value,
/// chevron or trailing icon action (which does not trigger [onTap]).
///
/// Rows carry content, so the title follows the reader's text size all the way
/// and the row grows with it — unlike the shell chrome, which clamps.
class DsListRow extends StatelessWidget {
  const DsListRow({
    super.key,
    required this.title,
    this.leadingIcon,
    this.trailingValue,
    this.chevron = false,
    this.trailingIcon,
    this.trailingTooltip,
    this.onTrailingTap,
    this.onTap,
    this.destructive = false,
  });

  static const double height = 56;

  final String title;
  final IconData? leadingIcon;
  final String? trailingValue;
  final bool chevron;
  final IconData? trailingIcon;

  /// Label for the trailing icon action; the icon alone carries no meaning.
  final String? trailingTooltip;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final titleColor = destructive ? ds.danger : ds.textPrimary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: height),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.x3, vertical: DsSpace.x2),
        child: Row(
          children: [
            // The merge puts the row's label and its button flag on one
            // semantics node. The trailing action stays outside it so that it
            // keeps a node — and a label — of its own.
            Expanded(
              child: MergeSemantics(
                child: InkWell(
                  onTap: onTap,
                  child: Row(
                    children: [
                      if (leadingIcon != null) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: ds.canvas, borderRadius: BorderRadius.circular(DsRadius.small)),
                          alignment: Alignment.center,
                          child: Icon(leadingIcon, size: 20, color: destructive ? ds.danger : ds.textSecondary),
                        ),
                        const SizedBox(width: DsSpace.x3),
                      ],
                      Expanded(
                        child: Text(title, style: type.body.withColor(titleColor), overflow: TextOverflow.ellipsis),
                      ),
                      if (trailingValue != null) ...[
                        const SizedBox(width: DsSpace.x2),
                        Text(trailingValue!, style: type.mono.withColor(ds.textSecondary)),
                      ],
                      if (chevron) Icon(Icons.chevron_right, size: 20, color: ds.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            if (trailingIcon != null)
              IconButton(
                icon: Icon(trailingIcon, size: 20, color: destructive ? ds.danger : ds.textSecondary),
                tooltip: trailingTooltip,
                onPressed: onTrailingTap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
