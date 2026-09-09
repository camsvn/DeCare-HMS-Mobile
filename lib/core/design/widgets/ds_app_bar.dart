import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

/// 48 dp navy bar. Full width, left-aligned title, optional trailing widget
/// beside the title (e.g. an OP chip) and actions on the right.
///
/// The title follows the reader's text size only as far as
/// [DsType.barScaleMax]: a [Scaffold] caps its app bar slot at
/// [preferredSize], so a bar that grew past it would paint over the screen it
/// frames. Within that clamp the title still fits the 48 dp on one line, and
/// anything longer ellipsises rather than being cut off. Content — rows,
/// cards, body copy — scales without a limit.
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
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: DsType.barScaleMax,
          child: SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: barHeight),
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
                            maxLines: 1,
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
        ),
      ),
    );
  }
}
