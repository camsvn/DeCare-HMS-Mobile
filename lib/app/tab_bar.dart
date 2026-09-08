import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Two text tabs on the dark primary bar, matching the React Native tab bar.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final labels = [context.l10n.settingsTabHome, context.l10n.settingsTabSettings];
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppColors.primary,
      child: SizedBox(
        height: 74 + bottom,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) Container(width: 0.5, height: 44, color: Colors.white),
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: i == currentIndex ? Colors.black.withOpacity(0.5) : Colors.transparent,
                        border: i == currentIndex
                            ? const Border(bottom: BorderSide(color: AppColors.offWhite, width: 2))
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(labels[i], style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
