import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

/// 56 dp row: optional leading icon, title, optional mono value, chevron or
/// trailing icon action (which does not trigger [onTap]).
class DsListRow extends StatelessWidget {
  const DsListRow({
    super.key,
    required this.title,
    this.leadingIcon,
    this.trailingValue,
    this.chevron = false,
    this.trailingIcon,
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
  final VoidCallback? onTrailingTap;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final titleColor = destructive ? ds.danger : ds.textPrimary;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.x3),
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
              if (trailingIcon != null)
                IconButton(
                  icon: Icon(trailingIcon, size: 20, color: destructive ? ds.danger : ds.textSecondary),
                  onPressed: onTrailingTap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
