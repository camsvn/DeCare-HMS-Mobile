import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/suggestion_chips.dart';

/// One draft photo: 16:10 preview with a mono "n of total" chip and a
/// destructive delete, plus the description field — with the description it
/// will inherit as its placeholder, and tap-to-fill suggestions under it while
/// it is empty.
class TomogramCard extends StatefulWidget {
  const TomogramCard({
    super.key,
    required this.draft,
    required this.index,
    required this.total,
    required this.onDelete,
    required this.onDescriptionChanged,
    this.onTapImage,
    this.inheritedDescription,
    this.suggestions = const [],
    this.onSuggestion,
    this.onSuggestionLongPress,
    this.removableSuggestions = const {},
  });

  final TomogramDraft draft;
  final int index;
  final int total;
  final VoidCallback onDelete;
  final ValueChanged<String> onDescriptionChanged;

  /// Open this photo full screen. The card crops to 16:10, which is enough to
  /// tell one photo from another and not enough to check one. Null leaves the
  /// image inert rather than offering a reader a button that does nothing.
  final VoidCallback? onTapImage;

  /// What this photo would upload with if left blank — the previous photo's
  /// effective description — shown as the field's placeholder so the
  /// inheritance is visible and a single tap to type over. Null when there is
  /// nothing to inherit.
  final String? inheritedDescription;

  /// Descriptions worth offering, newest first. Shown under the field only
  /// while it is blank — spaces included, the way `resolvedDrafts` reads it:
  /// a field with text in it has nothing left to suggest.
  final List<String> suggestions;

  /// A suggestion was tapped. Null leaves the chips out entirely.
  final ValueChanged<String>? onSuggestion;

  /// A suggestion was held down — the offer to stop offering it.
  final ValueChanged<String>? onSuggestionLongPress;

  /// Which suggestions this device could stop offering, lower-cased.
  final Set<String> removableSuggestions;

  @override
  State<TomogramCard> createState() => _TomogramCardState();
}

class _TomogramCardState extends State<TomogramCard> {
  late final TextEditingController _controller = TextEditingController(text: widget.draft.description);

  /// A suggestion chip rewrites the draft from outside this card, so the field
  /// has to follow. Only a change in the draft moves the controller: while the
  /// user is typing the two already agree, so their cursor is left alone.
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

  /// The cropped preview, tappable when there is somewhere to go. The chip
  /// and the delete button sit over it as siblings, so they keep their own
  /// taps.
  Widget _photo(VoidCallback? onTap) {
    final ds = context.ds;
    final l10n = context.l10n;
    final image = ClipRRect(
      borderRadius: DsRadius.smallAll,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Image.file(
          File(widget.draft.filePath),
          fit: BoxFit.cover,
          // Decode down: the preview is a few hundred px wide, the source is a
          // full-resolution camera JPEG. Upload bytes are read from the file
          // separately and stay untouched.
          cacheWidth: 1080,
          errorBuilder: (_, _, _) => ColoredBox(
            color: ds.canvas,
            child: Center(child: Icon(Icons.broken_image_outlined, color: ds.textSecondary, size: 40)),
          ),
        ),
      ),
    );
    if (onTap == null) return image;
    return Semantics(
      button: true,
      label: l10n.tomogramCounter(widget.index + 1, widget.total),
      onTap: onTap,
      child: InkWell(
        borderRadius: DsRadius.smallAll,
        onTap: onTap,
        child: image,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final l10n = context.l10n;
    final inherited = widget.inheritedDescription;
    final onSuggestion = widget.onSuggestion;
    final onTapImage = widget.onTapImage;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              _photo(onTapImage),
              Positioned(
                left: DsSpace.x2,
                top: DsSpace.x2,
                // Seen, not heard: the photo it sits on is a button that
                // already announces which of the set this is.
                child: ExcludeSemantics(
                  child: DsChip(
                    text: l10n.tomogramCounter(widget.index + 1, widget.total),
                    mono: true,
                  ),
                ),
              ),
              Positioned(
                right: DsSpace.x2,
                top: DsSpace.x2,
                // Translucent disc so the icon stays legible over a light photo.
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ds.card.withValues(alpha: 0.85)),
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
            hint: inherited == null ? null : l10n.tomogramSameAsPrevious(inherited),
            // An inherited description can be 200 characters; two lines of it
            // is enough to recognise, and the rest ellipsises.
            hintMaxLines: 2,
            maxLines: 3,
            maxLength: 200,
            showCounter: true,
            keyboardType: TextInputType.multiline,
            onChanged: widget.onDescriptionChanged,
          ),
          if (onSuggestion != null &&
              widget.draft.description.trim().isEmpty &&
              widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: DsSpace.x2),
            SuggestionChips(
              suggestions: widget.suggestions,
              onPick: onSuggestion,
              removable: widget.removableSuggestions,
              onLongPress: widget.onSuggestionLongPress,
            ),
          ],
        ],
      ),
    );
  }
}
