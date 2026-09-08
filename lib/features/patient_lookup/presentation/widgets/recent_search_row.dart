import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';

class RecentSearchRow extends StatelessWidget {
  const RecentSearchRow({super.key, required this.patient, required this.onTap, required this.onDelete});

  final Patient patient;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.rowGrey,
      elevation: 1,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xxs, AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.homeRecentRow(patient.name, patient.opid),
                  style: AppTextStyles.body,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
