import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

/// 48 dp navy bar. Full width, left-aligned title, optional trailing widget
/// beside the title (e.g. an OP chip) and actions on the right.
class DsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DsAppBar({
    super.key,
    required this.title,
    this.titleTrailing,
    this.actions = const [],
    this.automaticallyImplyLeading = true,
    this.onBack,
  });

  static const double barHeight = 48;

  final String title;
  final Widget? titleTrailing;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final canPop = onBack != null || (automaticallyImplyLeading && (ModalRoute.of(context)?.canPop ?? false));
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: ds.shell,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: SizedBox(
          height: barHeight,
          width: double.infinity,
          child: Row(
            children: [
              if (canPop)
                IconButton(
                  icon: Icon(Icons.arrow_back, color: ds.textOnShell, size: 24),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                )
              else
                const SizedBox(width: DsSpace.gutter),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: context.dsType.title.withColor(ds.textOnShell),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (titleTrailing != null) ...[const SizedBox(width: DsSpace.x2), titleTrailing!],
                  ],
                ),
              ),
              ...actions,
              const SizedBox(width: DsSpace.x1),
            ],
          ),
        ),
      ),
    );
  }
}
