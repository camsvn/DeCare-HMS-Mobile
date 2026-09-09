import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';

/// One draft photo: 16:10 preview with a mono "n of total" chip and a
/// destructive delete, plus the description field and — when there is more
/// than one photo — an "Apply to all" shortcut under it.
class TomogramCard extends StatefulWidget {
  const TomogramCard({
    super.key,
    required this.draft,
    required this.index,
    required this.total,
    required this.onDelete,
    required this.onDescriptionChanged,
    this.onApplyToAll,
  });

  final TomogramDraft draft;
  final int index;
  final int total;
  final VoidCallback onDelete;
  final ValueChanged<String> onDescriptionChanged;

  /// Copies this photo's description onto the others. Null hides the button,
  /// which is what a single-photo list wants.
  final VoidCallback? onApplyToAll;

  @override
  State<TomogramCard> createState() => _TomogramCardState();
}

class _TomogramCardState extends State<TomogramCard> {
  late final TextEditingController _controller = TextEditingController(text: widget.draft.description);

  /// "Apply to all" rewrites the draft from outside this card, so the field has
  /// to follow. Only a change in the draft moves the controller: while the user
  /// is typing the two already agree, so their cursor is left alone.
  @override
  void didUpdateWidget(TomogramCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final description = widget.draft.description;
    if (description != oldWidget.draft.description && description != _controller.text) {
      _controller.text = description;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final l10n = context.l10n;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: DsRadius.smallAll,
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.file(
                    File(widget.draft.filePath),
                    fit: BoxFit.cover,
                    // Decode down: the preview is a few hundred px wide, the
                    // source is a full-resolution camera JPEG. Upload bytes are
                    // read from the file separately and stay untouched.
                    cacheWidth: 1080,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: ds.canvas,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: ds.textSecondary, size: 40)),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: DsSpace.x2,
                top: DsSpace.x2,
                child: DsChip(text: l10n.tomogramCounter(widget.index + 1, widget.total), mono: true),
              ),
              Positioned(
                right: DsSpace.x2,
                top: DsSpace.x2,
                // Translucent disc so the icon stays legible over a light photo.
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ds.card.withOpacity(0.85)),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: Icon(Icons.delete_outline, color: ds.danger, size: 20),
                      onPressed: widget.onDelete,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.x3),
          DsTextField(
            controller: _controller,
            label: l10n.tomogramDescription,
            maxLines: 3,
            maxLength: 200,
            showCounter: true,
            keyboardType: TextInputType.multiline,
            onChanged: widget.onDescriptionChanged,
          ),
          if (widget.onApplyToAll != null)
            Align(
              alignment: Alignment.centerRight,
              child: DsButton.ghost(label: l10n.tomogramApplyToAll, onPressed: widget.onApplyToAll),
            ),
        ],
      ),
    );
  }
}
