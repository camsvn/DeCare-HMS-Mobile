import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/keyboard_visibility.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Scrollable so the illustration plus copy never overflows on a short
    // viewport (a small screen with the keyboard up).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HideWithKeyboard(
              child: SvgPicture.asset('assets/images/blank_canvas.svg', width: 220, height: 220),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.homeEmptyTitle, style: AppTextStyles.bold, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xxs),
            Text(l10n.homeEmptyBody, style: AppTextStyles.fieldLabel, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
