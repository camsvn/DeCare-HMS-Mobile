import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Blocks [child] with a "Please wait" card while [visible] is true.
class LoaderModal extends StatelessWidget {
  const LoaderModal({super.key, required this.visible, required this.text, required this.child});

  final bool visible;
  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: AppColors.scrim,
                alignment: Alignment.center,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 200,
                    height: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(context.l10n.commonPleaseWait),
                        const SizedBox(height: AppSpacing.xs),
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('. . . $text . . .', style: const TextStyle(fontSize: 13, color: AppColors.dim)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
