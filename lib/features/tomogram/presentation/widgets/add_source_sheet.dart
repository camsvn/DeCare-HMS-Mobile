import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/widgets/app_bottom_sheet.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/media_picker_service.dart';

Future<MediaSource?> showAddSourceSheet(BuildContext context) {
  final l10n = context.l10n;
  return showAppBottomSheet<MediaSource>(
    context,
    builder: (sheet) => [
      ListTile(
        leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
        title: Text(l10n.tomogramChooseGallery),
        onTap: () => Navigator.of(sheet).pop(MediaSource.gallery),
      ),
      ListTile(
        leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
        title: Text(l10n.tomogramTakePhoto),
        onTap: () => Navigator.of(sheet).pop(MediaSource.camera),
      ),
      const Divider(height: 1),
      ListTile(
        title: Text(l10n.commonCancel, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.dim)),
        onTap: () => Navigator.of(sheet).pop(),
      ),
    ],
  );
}
