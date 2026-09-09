import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/media_picker_service.dart';

Future<MediaSource?> showAddSourceSheet(BuildContext context) {
  final l10n = context.l10n;
  return showDsSheet<MediaSource>(
    context,
    builder: (sheet) => [
      DsListRow(
        leadingIcon: Icons.photo_library_outlined,
        title: l10n.tomogramChooseGallery,
        onTap: () => Navigator.of(sheet).pop(MediaSource.gallery),
      ),
      DsListRow(
        leadingIcon: Icons.photo_camera_outlined,
        title: l10n.tomogramTakePhoto,
        onTap: () => Navigator.of(sheet).pop(MediaSource.camera),
      ),
      const SizedBox(height: DsSpace.x2),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.gutter),
        child: DsButton.ghost(
          label: l10n.commonCancel,
          expand: true,
          onPressed: () => Navigator.of(sheet).pop(),
        ),
      ),
    ],
  );
}
