import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

class DsDestination {
  const DsDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Navy bottom bar; the active destination gets a gradient underline.
class DsBottomBar extends StatelessWidget {
  const DsBottomBar({super.key, required this.currentIndex, required this.onTap, required this.destinations});

  static const double barHeight = 60;

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<DsDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: ds.shell,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: MergeSemantics(
                    child: Semantics(
                      selected: i == currentIndex,
                      button: true,
                      label: destinations[i].label,
                      child: InkWell(
                        onTap: () => onTap(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(destinations[i].icon,
                                size: 24, color: i == currentIndex ? ds.textOnShell : ds.textOnShellMuted),
                            const SizedBox(height: 2),
                            Text(destinations[i].label,
                                style: context.dsType.label
                                    .withColor(i == currentIndex ? ds.textOnShell : ds.textOnShellMuted)),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: DsMotion.of(context, DsMotion.base),
                              curve: DsMotion.curve,
                              height: 2,
                              width: i == currentIndex ? 28 : 0,
                              decoration:
                                  BoxDecoration(gradient: ds.accentGradient, borderRadius: BorderRadius.circular(1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
