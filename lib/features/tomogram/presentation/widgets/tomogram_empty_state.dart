import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

class TomogramEmptyState extends StatelessWidget {
  const TomogramEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/images/add_tomogram.svg', width: 200, height: 180),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.tomogramEmptyTitle, style: AppTextStyles.bold, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xxs),
          Text(l10n.tomogramEmptyBody, style: AppTextStyles.fieldLabel, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
