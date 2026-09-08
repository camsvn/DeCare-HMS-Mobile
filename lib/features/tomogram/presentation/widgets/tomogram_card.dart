import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';

class TomogramCard extends StatefulWidget {
  const TomogramCard({super.key, required this.draft, required this.onDelete, required this.onDescriptionChanged});

  final TomogramDraft draft;
  final VoidCallback onDelete;
  final ValueChanged<String> onDescriptionChanged;

  @override
  State<TomogramCard> createState() => _TomogramCardState();
}

class _TomogramCardState extends State<TomogramCard> {
  late final TextEditingController _controller = TextEditingController(text: widget.draft.description);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(widget.draft.filePath),
                height: 200,
                fit: BoxFit.cover,
                // Decode down: the preview is 200 px tall, the source is a
                // full-resolution camera JPEG. Upload bytes are read from the
                // file separately and stay untouched.
                cacheWidth: 1080,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.rowGrey,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.dim, size: 48),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _controller,
              label: context.l10n.tomogramDescription,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              onChanged: widget.onDescriptionChanged,
            ),
          ],
        ),
      ),
    );
  }
}
